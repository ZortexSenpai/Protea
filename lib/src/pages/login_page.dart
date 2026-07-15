import 'dart:async';

import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';

import '../l10n.dart';
import '../sso.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.client});

  final Client client;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _homeserverController = TextEditingController(text: 'matrix.org');
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _loading = false;

  /// Login flows supported by the current homeserver, or null while unknown.
  List<LoginFlow>? _flows;
  Timer? _flowsDebounce;
  int _flowsRequest = 0;
  StreamSubscription<LoginState>? _loginStateSubscription;

  @override
  void initState() {
    super.initState();
    _homeserverController.addListener(_onHomeserverChanged);
    _fetchLoginFlows();
    // When this page was pushed to add another account, close it on success.
    // As the app's home (first login) it is replaced by main.dart instead.
    _loginStateSubscription = widget.client.onLoginStateChanged.stream.listen((
      state,
    ) {
      if (state == LoginState.loggedIn && mounted) {
        final navigator = Navigator.of(context);
        if (navigator.canPop()) navigator.pop();
      }
    });
  }

  @override
  void dispose() {
    _loginStateSubscription?.cancel();
    _flowsDebounce?.cancel();
    _homeserverController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Uri get _homeserverUri {
    final homeserver = _homeserverController.text.trim();
    return Uri.parse(
      homeserver.startsWith('http') ? homeserver : 'https://$homeserver',
    );
  }

  void _onHomeserverChanged() {
    _flowsDebounce?.cancel();
    setState(() => _flows = null);
    _flowsDebounce = Timer(const Duration(milliseconds: 700), _fetchLoginFlows);
  }

  Future<void> _fetchLoginFlows() async {
    final request = ++_flowsRequest;
    try {
      final (_, _, flows, _) = await widget.client.checkHomeserver(
        _homeserverUri,
      );
      if (mounted && request == _flowsRequest) {
        setState(() => _flows = flows);
      }
    } catch (e) {
      // Homeserver unreachable or incompatible; keep the password form
      // visible as a fallback but log why flow detection failed.
      Logs().w('Could not fetch login flows for $_homeserverUri', e);
      if (mounted && request == _flowsRequest) {
        setState(() => _flows = const []);
      }
    }
  }

  bool get _supportsPassword {
    final flows = _flows;
    return flows == null ||
        flows.isEmpty ||
        flows.any((f) => f.type == AuthenticationTypes.password);
  }

  List<SsoIdentityProvider> get _ssoProviders =>
      _flows == null ? const [] : ssoProvidersFromFlows(_flows!);

  Future<void> _loginWithPassword() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text;
    if (_homeserverController.text.trim().isEmpty ||
        username.isEmpty ||
        password.isEmpty) {
      _showError(context.l10n.pleaseFillInAllFields);
      return;
    }

    setState(() => _loading = true);
    try {
      await widget.client.checkHomeserver(_homeserverUri);
      await widget.client.login(
        AuthenticationTypes.password,
        identifier: AuthenticationUserIdentifier(user: username),
        password: password,
        initialDeviceDisplayName: 'Protea',
      );
      // Success is handled by the LoginState stream in main.dart.
    } on MatrixException catch (e) {
      _showError(e.errorMessage);
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loginWithSso(SsoIdentityProvider provider) async {
    setState(() => _loading = true);
    try {
      await widget.client.checkHomeserver(_homeserverUri);
      await ssoLogin(widget.client, idpId: provider.id);
      // Success is handled by the LoginState stream in main.dart.
    } on MatrixException catch (e) {
      _showError(e.errorMessage);
    } on TimeoutException {
      if (mounted) _showError(context.l10n.ssoLoginTimedOut);
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final ssoProviders = _ssoProviders;
    return Scaffold(
      appBar: Navigator.of(context).canPop()
          ? AppBar(title: Text(context.l10n.addAccount))
          : null,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(Icons.local_florist, size: 64, color: colorScheme.primary),
                const SizedBox(height: 8),
                Text(
                  'Protea',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                Text(
                  context.l10n.signInToYourMatrixAccount,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: _homeserverController,
                  enabled: !_loading,
                  decoration: InputDecoration(
                    labelText: context.l10n.homeserver,
                    prefixIcon: const Icon(Icons.dns_outlined),
                    border: const OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                ),
                if (_supportsPassword) ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: _usernameController,
                    enabled: !_loading,
                    decoration: InputDecoration(
                      labelText: context.l10n.username,
                      prefixIcon: const Icon(Icons.account_circle_outlined),
                      border: const OutlineInputBorder(),
                    ),
                    autocorrect: false,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _passwordController,
                    enabled: !_loading,
                    decoration: InputDecoration(
                      labelText: context.l10n.password,
                      prefixIcon: const Icon(Icons.lock_outline),
                      border: const OutlineInputBorder(),
                    ),
                    obscureText: true,
                    onSubmitted: (_) => _loginWithPassword(),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _loading ? null : _loginWithPassword,
                    child: _loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(context.l10n.signIn),
                  ),
                ],
                if (ssoProviders.isNotEmpty) ...[
                  if (_supportsPassword)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        children: [
                          const Expanded(child: Divider()),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(context.l10n.or),
                          ),
                          const Expanded(child: Divider()),
                        ],
                      ),
                    )
                  else
                    const SizedBox(height: 24),
                  for (final provider in ssoProviders)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: OutlinedButton.icon(
                        onPressed: _loading
                            ? null
                            : () => _loginWithSso(provider),
                        icon: const Icon(Icons.open_in_browser),
                        label: Text(
                          provider.id == null
                              ? context.l10n.signInWithSso
                              : context.l10n.signInWithProvider(provider.name),
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
