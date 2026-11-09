import 'dart:async';

import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';

import '../l10n.dart';
import '../sso.dart';

/// Two-step sign-in: the homeserver is entered and checked first, then the
/// sign-in methods it offers (password and/or SSO) are shown. The server is
/// only queried when the user submits it, never while typing.
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

  /// A homeserver check or sign-in is in progress.
  bool _loading = false;

  /// Login flows of the checked homeserver. Null while on the homeserver
  /// step; set once the server was checked successfully.
  List<LoginFlow>? _flows;

  /// Why the last homeserver check failed, shown under the field.
  String? _homeserverError;

  StreamSubscription<LoginState>? _loginStateSubscription;

  @override
  void initState() {
    super.initState();
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
    _homeserverController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String get _homeserverInput => _homeserverController.text.trim();

  Uri get _homeserverUri {
    final homeserver = _homeserverInput;
    return Uri.parse(
      homeserver.startsWith('http') ? homeserver : 'https://$homeserver',
    );
  }

  /// Step 1 → 2: checks the entered homeserver and fetches its login flows.
  Future<void> _submitHomeserver() async {
    if (_loading || _homeserverInput.isEmpty) return;
    setState(() {
      _loading = true;
      _homeserverError = null;
    });
    try {
      final (_, _, flows, _) = await widget.client.checkHomeserver(
        _homeserverUri,
      );
      if (mounted) setState(() => _flows = flows);
    } on BadServerLoginTypesException catch (e) {
      Logs().w('No supported login flow on $_homeserverInput', e);
      if (mounted) {
        setState(
          () => _homeserverError = context.l10n.homeserverNoSupportedLogin,
        );
      }
    } catch (e) {
      Logs().w('Could not reach homeserver $_homeserverInput', e);
      if (mounted) {
        setState(() => _homeserverError = context.l10n.homeserverUnreachable);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Step 2 → 1.
  void _changeHomeserver() => setState(() => _flows = null);

  /// The homeserver was set by [_submitHomeserver], but a failed sign-in
  /// (e.g. Client.init throwing after a successful /login) clears it again.
  Future<void> _ensureHomeserver() async {
    if (widget.client.homeserver == null) {
      await widget.client.checkHomeserver(_homeserverUri);
    }
  }

  bool get _supportsPassword {
    final flows = _flows ?? const [];
    // Show the password form as a fallback if nothing else is offered.
    return flows.any((f) => f.type == AuthenticationTypes.password) ||
        _ssoProviders.isEmpty;
  }

  List<SsoIdentityProvider> get _ssoProviders =>
      _flows == null ? const [] : ssoProvidersFromFlows(_flows!);

  Future<void> _loginWithPassword() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text;
    if (username.isEmpty || password.isEmpty) {
      _showError(context.l10n.pleaseFillInAllFields);
      return;
    }

    setState(() => _loading = true);
    try {
      await _ensureHomeserver();
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
      await _ensureHomeserver();
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
                // Grow/shrink smoothly between the steps instead of making
                // the centered header jump.
                AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  alignment: Alignment.topCenter,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    layoutBuilder: (current, previous) => Stack(
                      alignment: Alignment.topCenter,
                      children: [...previous, ?current],
                    ),
                    child: _flows == null
                        ? _buildHomeserverStep(context)
                        : _buildAuthStep(context),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHomeserverStep(BuildContext context) {
    return Column(
      key: const ValueKey('homeserverStep'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _homeserverController,
          enabled: !_loading,
          autofocus: true,
          decoration: InputDecoration(
            labelText: context.l10n.homeserver,
            prefixIcon: const Icon(Icons.dns_outlined),
            border: const OutlineInputBorder(),
            errorText: _homeserverError,
            errorMaxLines: 3,
          ),
          keyboardType: TextInputType.url,
          textInputAction: TextInputAction.go,
          autocorrect: false,
          onChanged: (_) {
            if (_homeserverError != null) {
              setState(() => _homeserverError = null);
            }
          },
          onSubmitted: (_) => _submitHomeserver(),
        ),
        const SizedBox(height: 24),
        ValueListenableBuilder(
          valueListenable: _homeserverController,
          builder: (context, value, _) => FilledButton(
            onPressed: _loading || value.text.trim().isEmpty
                ? null
                : _submitHomeserver,
            child: _loading
                ? const _ButtonSpinner()
                : Text(context.l10n.continueButton),
          ),
        ),
      ],
    );
  }

  Widget _buildAuthStep(BuildContext context) {
    final ssoProviders = _ssoProviders;
    final supportsPassword = _supportsPassword;
    return Column(
      key: const ValueKey('authStep'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InputDecorator(
          decoration: InputDecoration(
            labelText: context.l10n.homeserver,
            prefixIcon: const Icon(Icons.dns_outlined),
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: context.l10n.changeHomeserver,
              onPressed: _loading ? null : _changeHomeserver,
            ),
          ),
          child: Text(_homeserverInput, overflow: TextOverflow.ellipsis),
        ),
        if (supportsPassword) ...[
          const SizedBox(height: 16),
          TextField(
            controller: _usernameController,
            enabled: !_loading,
            autofocus: true,
            decoration: InputDecoration(
              labelText: context.l10n.username,
              prefixIcon: const Icon(Icons.account_circle_outlined),
              border: const OutlineInputBorder(),
            ),
            textInputAction: TextInputAction.next,
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
                ? const _ButtonSpinner()
                : Text(context.l10n.signIn),
          ),
        ],
        if (ssoProviders.isNotEmpty) ...[
          if (supportsPassword)
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
                onPressed: _loading ? null : () => _loginWithSso(provider),
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
    );
  }
}

class _ButtonSpinner extends StatelessWidget {
  const _ButtonSpinner();

  @override
  Widget build(BuildContext context) => const SizedBox(
    width: 20,
    height: 20,
    child: CircularProgressIndicator(strokeWidth: 2),
  );
}
