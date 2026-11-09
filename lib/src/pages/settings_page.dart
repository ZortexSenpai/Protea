import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:matrix/matrix.dart';

import '../l10n.dart';
import '../theme_code.dart';
import '../motion.dart';
import '../room_actions.dart';
import '../gif_proxy.dart';
import '../settings.dart';
import '../themes.dart';
import '../widgets/bootstrap_dialog.dart';
import '../widgets/chat_wallpaper.dart';
import '../widgets/color_picker_dialog.dart';
import '../widgets/initials_avatar.dart';
import '../widgets/key_verification_dialog.dart';
import '../widgets/mxc_avatar.dart';
import '../widgets/text_prompt_dialog.dart';
import '../widgets/user_banner.dart';

/// Opens the settings as a modal dialog.
Future<void> showSettingsDialog(
  BuildContext context, {
  required Client client,
  required AppSettings settings,
}) => showDialog(
  context: context,
  builder: (_) => SettingsDialog(client: client, settings: settings),
);

/// Settings categories shown in the navigation sidebar, Discord-style.
enum _SettingsTab {
  account,
  appearance,
  notifications,
  privacy,
  security,
  integrations,
  expert,
}

class SettingsDialog extends StatefulWidget {
  const SettingsDialog({
    super.key,
    required this.client,
    required this.settings,
  });

  final Client client;
  final AppSettings settings;

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  _SettingsTab _tab = _SettingsTab.account;

  /// Narrow screens show the category list and the selected category as
  /// two stacked pages instead of side by side; true while the category
  /// page is open.
  bool _narrowDetail = false;

  Client get client => widget.client;
  AppSettings get settings => widget.settings;

  String _tabLabel(BuildContext context, _SettingsTab tab) => switch (tab) {
    _SettingsTab.account => context.l10n.account,
    _SettingsTab.appearance => context.l10n.appearance,
    _SettingsTab.notifications => context.l10n.notifications,
    _SettingsTab.privacy => context.l10n.privacy,
    _SettingsTab.security => context.l10n.security,
    _SettingsTab.integrations => context.l10n.integrations,
    _SettingsTab.expert => context.l10n.expert,
  };

  IconData _tabIcon(_SettingsTab tab) => switch (tab) {
    _SettingsTab.account => Icons.person_outline,
    _SettingsTab.appearance => Icons.palette_outlined,
    _SettingsTab.notifications => Icons.notifications_outlined,
    _SettingsTab.privacy => Icons.shield_outlined,
    _SettingsTab.security => Icons.lock_outline,
    _SettingsTab.integrations => Icons.extension_outlined,
    _SettingsTab.expert => Icons.code,
  };

  List<Widget> _tabChildren(BuildContext context) => switch (_tab) {
    _SettingsTab.account => _accountChildren(context),
    _SettingsTab.appearance => _appearanceChildren(context),
    _SettingsTab.notifications => _notificationsChildren(context),
    _SettingsTab.privacy => _privacyChildren(context),
    _SettingsTab.security => _securityChildren(context),
    _SettingsTab.integrations => _integrationsChildren(context),
    _SettingsTab.expert => _expertChildren(context),
  };

  List<Widget> _accountChildren(BuildContext context) => [
    _ProfileSection(client: client),
    const Divider(height: 32),
    _SectionHeader(context.l10n.status),
    _StatusSection(client: client, settings: settings),
    SwitchListTile(
      secondary: const Icon(Icons.snooze_outlined),
      title: Text(context.l10n.autoAway),
      subtitle: Text(context.l10n.autoAwayDescription),
      value: settings.autoAway,
      onChanged: (value) => settings.setAutoAway(value),
    ),
    const Divider(height: 32),
    ListTile(
      leading: Icon(Icons.logout, color: Theme.of(context).colorScheme.error),
      title: Text(
        context.l10n.signOut,
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
      onTap: () => confirmLogout(context, client),
    ),
  ];

  /// Picks [theme]. Choosing the custom theme for the first time copies the
  /// colors of the theme on screen into it, so the editor opens on something
  /// readable instead of on whatever the defaults happen to be.
  Future<void> _selectTheme(BuildContext context, AppTheme theme) async {
    if (theme == AppTheme.custom) {
      for (final brightness in Brightness.values) {
        if (settings.hasCustomPalette(brightness)) continue;
        await settings.setCustomPalette(
          brightness,
          CustomPalette.fromScheme(
            schemeFor(
              settings.appTheme,
              settings.themeColor,
              brightness,
              custom: settings.customPalette(brightness),
              accent: settings.effectiveAccent,
            ),
          ),
        );
      }
    }
    await settings.setAppTheme(theme);
  }

  List<Widget> _appearanceChildren(BuildContext context) => [
    ListTile(
      leading: const Icon(Icons.language),
      title: Text(context.l10n.language),
      trailing: DropdownButton<String>(
        value: settings.locale?.languageCode ?? '',
        onChanged: (value) =>
            settings.setLocale(value == null || value.isEmpty ? null : value),
        items: [
          DropdownMenuItem(value: '', child: Text(context.l10n.systemDefault)),
          const DropdownMenuItem(value: 'en', child: Text('English')),
          const DropdownMenuItem(value: 'de', child: Text('Deutsch')),
          const DropdownMenuItem(value: 'es', child: Text('Español')),
          const DropdownMenuItem(value: 'fr', child: Text('Français')),
          const DropdownMenuItem(value: 'it', child: Text('Italiano')),
        ],
      ),
    ),
    const SizedBox(height: 16),
    ListTile(title: Text(context.l10n.theme)),
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SegmentedButton<ThemeMode>(
        segments: [
          ButtonSegment(
            value: ThemeMode.system,
            label: Text(context.l10n.systemDefault),
            icon: const Icon(Icons.brightness_auto),
          ),
          ButtonSegment(
            value: ThemeMode.light,
            label: Text(context.l10n.light),
            icon: const Icon(Icons.light_mode_outlined),
          ),
          ButtonSegment(
            value: ThemeMode.dark,
            label: Text(context.l10n.dark),
            icon: const Icon(Icons.dark_mode_outlined),
          ),
        ],
        selected: {settings.themeMode},
        onSelectionChanged: (selection) =>
            settings.setThemeMode(selection.single),
      ),
    ),
    const SizedBox(height: 16),
    ListTile(title: Text(context.l10n.color)),
    // Seed swatches for the Material theme, above the theme cards so the
    // picked color is visible in the Material card's preview right below.
    AnimatedCollapse(
      collapsed: settings.appTheme != AppTheme.material,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final color in AppThemeColor.values)
              _ColorSwatch(
                color: color,
                selected: settings.themeColor == color,
                onTap: () => settings.setThemeColor(color),
              ),
          ],
        ),
      ),
    ),
    // The same swatches over a theme that ships its own palette are an
    // accent worn on top of it, so that row leads with keeping the
    // theme's own and is stored separately from the Material seed.
    AnimatedCollapse(
      collapsed:
          settings.appTheme == AppTheme.material ||
          settings.appTheme == AppTheme.custom,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            title: Text(context.l10n.accentColor),
            subtitle: Text(context.l10n.accentColorDescription),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _ThemeDefaultSwatch(
                  selected: settings.accentOverride == null,
                  onTap: () => settings.setAccentOverride(null),
                ),
                for (final color in AppThemeColor.values)
                  _ColorSwatch(
                    color: color,
                    selected: settings.accentOverride == color,
                    onTap: () => settings.setAccentOverride(color),
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
    AnimatedCollapse(
      collapsed: settings.appTheme != AppTheme.custom,
      child: _CustomThemeEditor(settings: settings),
    ),
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final theme in AppTheme.values)
            _ThemePreviewCard(
              theme: theme,
              seed: settings.themeColor,
              custom: settings.customPalette(Theme.of(context).brightness),
              accent: settings.accentOverride?.seed,
              selected: settings.appTheme == theme,
              onTap: () => _selectTheme(context, theme),
            ),
        ],
      ),
    ),
    const SizedBox(height: 8),
    _AppBackgroundSection(settings: settings),
    const SizedBox(height: 16),
    ListTile(
      title: Text(context.l10n.messageLayout),
      subtitle: Text(context.l10n.messageLayoutDescription),
    ),
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final layout in const [
            MessageLayout.cozy,
            MessageLayout.bubbles,
            MessageLayout.text,
          ])
            _MessageLayoutPreviewCard(
              layout: layout,
              label: switch (layout) {
                MessageLayout.cozy => context.l10n.cozy,
                MessageLayout.bubbles => context.l10n.bubbles,
                MessageLayout.text => context.l10n.text,
              },
              selected: settings.messageLayout == layout,
              onTap: () => settings.setMessageLayout(layout),
            ),
        ],
      ),
    ),
    const SizedBox(height: 16),
    _ChatWallpaperSection(settings: settings),
    const SizedBox(height: 16),
    ListTile(title: Text(context.l10n.fontSize)),
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SegmentedButton<double>(
        segments: [
          ButtonSegment(value: 0.85, label: Text(context.l10n.small)),
          ButtonSegment(value: 1.0, label: Text(context.l10n.normal)),
          ButtonSegment(value: 1.15, label: Text(context.l10n.large)),
          ButtonSegment(value: 1.3, label: Text(context.l10n.huge)),
        ],
        selected: {settings.textScale},
        onSelectionChanged: (selection) =>
            settings.setTextScale(selection.single),
      ),
    ),
    const Divider(height: 32),
    _SectionHeader(context.l10n.layout),
    ListTile(
      title: Text(context.l10n.appLayout),
      subtitle: Text(context.l10n.appLayoutDescription),
    ),
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final layout in AppLayout.values)
            _LayoutPreviewCard(
              layout: layout,
              label: switch (layout) {
                AppLayout.workspace => context.l10n.workspace,
                AppLayout.liquid => context.l10n.liquid,
                AppLayout.floating => context.l10n.floating,
                AppLayout.focus => context.l10n.focus,
              },
              selected: settings.layout == layout,
              onTap: () => settings.setLayout(layout),
            ),
        ],
      ),
    ),
    const SizedBox(height: 16),
    ListTile(title: Text(context.l10n.spacesListPosition)),
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final position in RailPosition.values)
            _RailPositionPreviewCard(
              position: position,
              label: switch (position) {
                RailPosition.left => context.l10n.left,
                RailPosition.right => context.l10n.right,
              },
              selected: settings.railPosition == position,
              onTap: () => settings.setRailPosition(position),
            ),
        ],
      ),
    ),
    const Divider(height: 32),
    SwitchListTile(
      secondary: const Icon(Icons.swipe_vertical_outlined),
      title: Text(context.l10n.smoothScrollingTitle),
      subtitle: Text(context.l10n.smoothScrollingDescription),
      value: settings.smoothScrolling,
      onChanged: (value) => settings.setSmoothScrolling(value),
    ),
    SwitchListTile(
      secondary: const Icon(Icons.arrow_upward),
      title: Text(context.l10n.arrowUpToEditTitle),
      subtitle: Text(context.l10n.arrowUpToEditDescription),
      value: settings.arrowUpToEdit,
      onChanged: (value) => settings.setArrowUpToEdit(value),
    ),
  ];

  List<Widget> _notificationsChildren(BuildContext context) => [
    SwitchListTile(
      secondary: const Icon(Icons.notifications_outlined),
      title: Text(context.l10n.desktopNotificationsTitle),
      subtitle: Text(context.l10n.desktopNotificationsDescription),
      value: settings.desktopNotifications,
      onChanged: (value) => settings.setDesktopNotifications(value),
    ),
    SwitchListTile(
      secondary: const Icon(Icons.close_fullscreen_outlined),
      title: Text(context.l10n.closeToTrayTitle),
      subtitle: Text(context.l10n.closeToTrayDescription),
      value: settings.closeToTray,
      onChanged: (value) => settings.setCloseToTray(value),
    ),
    SwitchListTile(
      secondary: const Icon(Icons.notifications_active_outlined),
      title: Text(context.l10n.notificationSounds),
      subtitle: Text(context.l10n.notificationSoundsDescription),
      value: settings.notificationSounds,
      onChanged: settings.desktopNotifications
          ? (value) => settings.setNotificationSounds(value)
          : null,
    ),
  ];

  List<Widget> _privacyChildren(BuildContext context) => [
    SwitchListTile(
      secondary: const Icon(Icons.keyboard_outlined),
      title: Text(context.l10n.sendTypingNotificationsTitle),
      subtitle: Text(context.l10n.sendTypingNotificationsDescription),
      value: settings.sendTypingNotifications,
      onChanged: (value) => settings.setSendTypingNotifications(value),
    ),
    SwitchListTile(
      secondary: const Icon(Icons.done_all),
      title: Text(context.l10n.sendReadReceiptsTitle),
      subtitle: Text(context.l10n.sendReadReceiptsDescription),
      value: settings.sendReadReceipts,
      onChanged: (value) => settings.setSendReadReceipts(value),
    ),
    SwitchListTile(
      secondary: const Icon(Icons.link),
      title: Text(context.l10n.showUrlPreviewsTitle),
      subtitle: Text(context.l10n.showUrlPreviewsDescription),
      value: settings.showUrlPreviews,
      onChanged: (value) => settings.setShowUrlPreviews(value),
    ),
    SwitchListTile(
      secondary: const Icon(Icons.done_all),
      title: Text(context.l10n.showReadReceiptsTitle),
      subtitle: Text(context.l10n.showReadReceiptsDescription),
      value: settings.showReadReceipts,
      onChanged: (value) => settings.setShowReadReceipts(value),
    ),
    SwitchListTile(
      secondary: const Icon(Icons.gif_box_outlined),
      title: Text(context.l10n.pauseGifsTitle),
      subtitle: Text(context.l10n.pauseGifsDescription),
      value: settings.pauseGifsUnfocused,
      onChanged: (value) => settings.setPauseGifsUnfocused(value),
    ),
    const Divider(height: 32),
    _SectionHeader(context.l10n.systemMessages),
    ListTile(subtitle: Text(context.l10n.systemMessagesDescription)),
    SwitchListTile(
      secondary: const Icon(Icons.meeting_room_outlined),
      title: Text(context.l10n.showMembershipEventsTitle),
      subtitle: Text(context.l10n.showMembershipEventsDescription),
      value: settings.showMembershipEvents,
      onChanged: (value) => settings.setShowMembershipEvents(value),
    ),
    SwitchListTile(
      secondary: const Icon(Icons.badge_outlined),
      title: Text(context.l10n.showProfileChangeEventsTitle),
      subtitle: Text(context.l10n.showProfileChangeEventsDescription),
      value: settings.showProfileChangeEvents,
      onChanged: (value) => settings.setShowProfileChangeEvents(value),
    ),
    SwitchListTile(
      secondary: const Icon(Icons.delete_outline),
      title: Text(context.l10n.showDeletedMessagesTitle),
      subtitle: Text(context.l10n.showDeletedMessagesDescription),
      value: settings.showDeletedMessages,
      onChanged: (value) => settings.setShowDeletedMessages(value),
    ),
  ];

  List<Widget> _securityChildren(BuildContext context) => [
    _BackupSection(client: client),
    _DevicesSection(client: client),
  ];

  List<Widget> _integrationsChildren(BuildContext context) => [
    ListTile(
      leading: const Icon(Icons.gif_box_outlined),
      title: Text(context.l10n.gifSearchKlipy),
      subtitle: Text(context.l10n.klipyApiKeyDescription),
    ),
    _KlipyKeyField(settings: settings),
    // The toggle and the server field move together, so the section is built
    // against the settings object rather than the enclosing page.
    ListenableBuilder(
      listenable: settings,
      builder: (context, _) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SwitchListTile(
            secondary: const Icon(Icons.cloud_outlined),
            title: Text(context.l10n.gifProxyTitle),
            subtitle: Text(context.l10n.gifProxyDescription),
            value: settings.gifProxyEnabled,
            onChanged: settings.setGifProxyEnabled,
          ),
          if (settings.gifProxyEnabled) _GifProxyField(settings: settings),
        ],
      ),
    ),
  ];

  List<Widget> _expertChildren(BuildContext context) => [
    SwitchListTile(
      secondary: const Icon(Icons.enhanced_encryption_outlined),
      title: Text(context.l10n.encryptNewDmsTitle),
      subtitle: Text(context.l10n.encryptNewDmsDescription),
      value: settings.encryptNewDirectChats,
      onChanged: (value) => settings.setEncryptNewDirectChats(value),
    ),
    const Divider(height: 32),
    _AccessTokenSection(client: client),
  ];

  /// Fullscreen two-level navigation for narrow screens: the category
  /// list first, the selected category as its own page with a back button
  /// (the system back gesture also returns to the list).
  Widget _buildNarrow(BuildContext context) {
    return Dialog.fullscreen(
      child: PopScope(
        canPop: !_narrowDetail,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) setState(() => _narrowDetail = false);
        },
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: Row(
                children: [
                  if (_narrowDetail)
                    IconButton(
                      tooltip: MaterialLocalizations.of(
                        context,
                      ).backButtonTooltip,
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => setState(() => _narrowDetail = false),
                    ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      _narrowDetail
                          ? _tabLabel(context, _tab)
                          : context.l10n.settings,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: context.l10n.close,
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _narrowDetail
                  ? ListenableBuilder(
                      listenable: settings,
                      builder: (context, _) => ListView(
                        padding: const EdgeInsets.all(16),
                        children: _tabChildren(context),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.all(8),
                      children: [
                        for (final tab in _SettingsTab.values)
                          ListTile(
                            leading: Icon(_tabIcon(tab), size: 20),
                            title: Text(_tabLabel(context, tab)),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => setState(() {
                              _tab = tab;
                              _narrowDetail = true;
                            }),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // The two-pane dialog needs room for the rail next to the content;
    // below that it becomes a fullscreen two-level page.
    if (MediaQuery.sizeOf(context).width < 600) return _buildNarrow(context);
    final colorScheme = Theme.of(context).colorScheme;
    return Dialog(
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 860, maxHeight: 680),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Category navigation, Discord-style.
            Material(
              color: colorScheme.surfaceContainerLow,
              child: SizedBox(
                width: 200,
                child: ListView(
                  padding: const EdgeInsets.all(8),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                      child: Text(
                        context.l10n.settings,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    for (final tab in _SettingsTab.values)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 1),
                        child: ListTile(
                          dense: true,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          leading: Icon(_tabIcon(tab), size: 20),
                          title: Text(
                            _tabLabel(context, tab),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          selected: _tab == tab,
                          selectedTileColor: colorScheme.secondaryContainer,
                          onTap: () => setState(() => _tab = tab),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const VerticalDivider(width: 1),
            Expanded(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 12, 12, 8),
                    child: Row(
                      children: [
                        Text(
                          _tabLabel(context, _tab),
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const Spacer(),
                        IconButton(
                          tooltip: context.l10n.close,
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListenableBuilder(
                      listenable: settings,
                      builder: (context, _) => ListView(
                        padding: const EdgeInsets.all(16),
                        children: _tabChildren(context),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shows the account's access token, hidden until revealed, with a copy
/// button — for use with bots, scripts, and debugging tools.
class _AccessTokenSection extends StatefulWidget {
  const _AccessTokenSection({required this.client});

  final Client client;

  @override
  State<_AccessTokenSection> createState() => _AccessTokenSectionState();
}

class _AccessTokenSectionState extends State<_AccessTokenSection> {
  bool _revealed = false;

  @override
  Widget build(BuildContext context) {
    final token = widget.client.accessToken ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          leading: const Icon(Icons.key_outlined),
          title: Text(context.l10n.accessToken),
          subtitle: Text(context.l10n.accessTokenWarning),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _revealed ? token : '•' * 24,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
              ),
              IconButton(
                tooltip: _revealed ? context.l10n.hide : context.l10n.show,
                icon: Icon(
                  _revealed
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 20,
                ),
                onPressed: () => setState(() => _revealed = !_revealed),
              ),
              IconButton(
                tooltip: context.l10n.copy,
                icon: const Icon(Icons.copy, size: 18),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: token));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(context.l10n.copiedToClipboard)),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The six-color editor for [AppTheme.custom], one palette per brightness,
/// with a code to carry a theme to another Protea.
class _CustomThemeEditor extends StatefulWidget {
  const _CustomThemeEditor({required this.settings});

  final AppSettings settings;

  @override
  State<_CustomThemeEditor> createState() => _CustomThemeEditorState();
}

class _CustomThemeEditorState extends State<_CustomThemeEditor> {
  /// Which palette is being edited. Starts on whichever one is on screen, so
  /// the colors being changed are the ones being looked at.
  Brightness? _editing;

  AppSettings get settings => widget.settings;

  Brightness _brightness(BuildContext context) =>
      _editing ?? Theme.of(context).brightness;

  Future<void> _edit(
    BuildContext context,
    Brightness brightness,
    String title,
    Color current,
    CustomPalette Function(CustomPalette palette, Color color) apply,
  ) async {
    final picked = await showColorPicker(
      context,
      initial: current,
      title: title,
    );
    if (picked == null) return;
    await settings.setCustomPalette(
      brightness,
      apply(settings.customPalette(brightness), picked),
    );
  }

  Future<void> _copyCode() async {
    await Clipboard.setData(
      ClipboardData(
        text: encodePaletteCode(
          settings.customPalette(Brightness.light),
          settings.customPalette(Brightness.dark),
        ),
      ),
    );
    if (mounted) _toast(context.l10n.themeCodeCopied);
  }

  Future<void> _pasteCode() async {
    final code = await showTextPromptDialog(
      context,
      title: context.l10n.pasteThemeCode,
      label: context.l10n.themeCode,
    );
    if (code == null || !mounted) return;
    final pair = decodePaletteCode(code);
    if (pair == null) {
      _toast(context.l10n.themeCodeInvalid);
      return;
    }
    await settings.setCustomPalette(Brightness.light, pair.light);
    await settings.setCustomPalette(Brightness.dark, pair.dark);
    if (mounted) _toast(context.l10n.themeCodeApplied);
  }

  void _toast(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        final brightness = _brightness(context);
        final palette = settings.customPalette(brightness);
        final l10n = context.l10n;
        final rows =
            <(String, Color, CustomPalette Function(CustomPalette, Color))>[
              (
                l10n.colorAccent,
                palette.accent,
                (p, c) => p.copyWith(accent: c),
              ),
              (
                l10n.colorBackground,
                palette.background,
                (p, c) => p.copyWith(background: c),
              ),
              (l10n.colorPanels, palette.panel, (p, c) => p.copyWith(panel: c)),
              (l10n.colorText, palette.text, (p, c) => p.copyWith(text: c)),
              (
                l10n.colorMutedText,
                palette.mutedText,
                (p, c) => p.copyWith(mutedText: c),
              ),
              (
                l10n.colorOutline,
                palette.outline,
                (p, c) => p.copyWith(outline: c),
              ),
            ];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              title: Text(l10n.customThemeColors),
              subtitle: Text(l10n.customThemeColorsDescription),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SegmentedButton<Brightness>(
                segments: [
                  ButtonSegment(
                    value: Brightness.light,
                    label: Text(l10n.light),
                    icon: const Icon(Icons.light_mode_outlined),
                  ),
                  ButtonSegment(
                    value: Brightness.dark,
                    label: Text(l10n.dark),
                    icon: const Icon(Icons.dark_mode_outlined),
                  ),
                ],
                selected: {brightness},
                onSelectionChanged: (selection) =>
                    setState(() => _editing = selection.single),
              ),
            ),
            const SizedBox(height: 8),
            for (final (label, color, apply) in rows)
              ListTile(
                title: Text(label),
                subtitle: Text(_hexOf(color)),
                trailing: _ColorDot(color: color),
                onTap: () => _edit(context, brightness, label, color, apply),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.copy, size: 18),
                    label: Text(l10n.copyThemeCode),
                    onPressed: _copyCode,
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.content_paste, size: 18),
                    label: Text(l10n.pasteThemeCode),
                    onPressed: _pasteCode,
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.restart_alt, size: 18),
                    label: Text(l10n.resetToTheme),
                    onPressed: () => settings.resetCustomPalette(brightness),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

String _hexOf(Color color) =>
    '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

/// A round swatch of one exact color, for the custom theme's rows.
class _ColorDot extends StatelessWidget {
  const _ColorDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 28,
    height: 28,
    decoration: BoxDecoration(
      color: color,
      shape: BoxShape.circle,
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
    ),
  );
}

/// Leads the accent row: keeps the accent the selected theme ships with.
class _ThemeDefaultSwatch extends StatelessWidget {
  const _ThemeDefaultSwatch({required this.selected, required this.onTap});

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final label = context.l10n.themeDefault;
    // Same box as [_ColorSwatch] down to the ring and the gap: the row lays
    // these out in a Wrap, which aligns a shorter item to the top of its
    // line, so a swatch of a different size doesn't just look smaller — it
    // sits visibly higher than the colors beside it.
    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: AnimatedContainer(
            duration: Motion.quick,
            curve: Motion.easeOut,
            width: 44,
            height: 44,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                width: 2.5,
                // The theme's own accent is what this swatch stands for.
                color: selected ? scheme.primary : Colors.transparent,
              ),
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: scheme.surfaceContainerHighest,
              ),
              child: Icon(
                selected ? Icons.check : Icons.auto_awesome,
                size: 20,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The color washed over the app's backdrop, and how much of it shows.
class _AppBackgroundSection extends StatelessWidget {
  const _AppBackgroundSection({required this.settings});

  final AppSettings settings;

  Future<void> _pick(BuildContext context) async {
    final scheme = Theme.of(context).colorScheme;
    final picked = await showColorPicker(
      context,
      initial: settings.appBackgroundColor ?? scheme.surface,
      title: context.l10n.appBackground,
    );
    if (picked != null) await settings.setAppBackgroundColor(picked);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        final l10n = context.l10n;
        final color = settings.appBackgroundColor;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              title: Text(l10n.appBackground),
              subtitle: Text(
                color == null ? l10n.appBackgroundDescription : _hexOf(color),
              ),
              onTap: () => _pick(context),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (color != null)
                    IconButton(
                      tooltip: l10n.themeDefault,
                      icon: const Icon(Icons.restart_alt),
                      onPressed: () => settings.setAppBackgroundColor(null),
                    ),
                  _ColorDot(
                    color: color ?? Theme.of(context).colorScheme.surface,
                  ),
                ],
              ),
            ),
            // Only worth showing once there is a color to fade in.
            AnimatedCollapse(
              collapsed: color == null,
              child: _WallpaperSlider(
                label: l10n.fadeAmount,
                value: settings.appBackgroundFade,
                max: 1,
                onChanged: settings.setAppBackgroundFade,
              ),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.blur_on),
              title: Text(l10n.backgroundGlow),
              subtitle: Text(l10n.backgroundGlowDescription),
              value: settings.backgroundGlow,
              onChanged: settings.setBackgroundGlow,
            ),
          ],
        );
      },
    );
  }
}

/// Picks and tunes the image behind the timeline.
class _ChatWallpaperSection extends StatelessWidget {
  const _ChatWallpaperSection({required this.settings});

  final AppSettings settings;

  Future<void> _pick(BuildContext context) async {
    final path = await pickChatWallpaper();
    if (path == null) return;
    final previous = settings.chatWallpaper;
    await settings.setChatWallpaper(path);
    // Only now that the new one is stored: a failed pick must not leave the
    // chat with a path to a file that has already been deleted.
    await deleteChatWallpaper(previous);
  }

  Future<void> _remove() async {
    final previous = settings.chatWallpaper;
    await settings.setChatWallpaper('');
    await deleteChatWallpaper(previous);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        final l10n = context.l10n;
        final hasWallpaper = settings.chatWallpaper.isNotEmpty;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              title: Text(l10n.chatWallpaper),
              subtitle: Text(l10n.chatWallpaperDescription),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.image_outlined, size: 18),
                    label: Text(l10n.chooseImage),
                    onPressed: () => _pick(context),
                  ),
                  if (hasWallpaper)
                    TextButton.icon(
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: Text(l10n.removeImage),
                      onPressed: _remove,
                    ),
                ],
              ),
            ),
            AnimatedCollapse(
              collapsed: !hasWallpaper,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _WallpaperSlider(
                    label: l10n.opacity,
                    value: settings.chatWallpaperOpacity,
                    max: 1,
                    onChanged: settings.setChatWallpaperOpacity,
                  ),
                  _WallpaperSlider(
                    label: l10n.blur,
                    value: settings.chatWallpaperBlur,
                    max: 24,
                    onChanged: settings.setChatWallpaperBlur,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _WallpaperSlider extends StatelessWidget {
  const _WallpaperSlider({
    required this.label,
    required this.value,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Row(
      children: [
        SizedBox(
          width: 88,
          child: Text(label, style: Theme.of(context).textTheme.bodySmall),
        ),
        Expanded(
          child: Slider(
            value: value.clamp(0, max),
            max: max,
            onChanged: onChanged,
          ),
        ),
      ],
    ),
  );
}

/// Text field storing the server name of the GIF proxy. Emptying it puts
/// [defaultGifProxyServer] back, so the field can't be left in a state where
/// the toggle is on but nothing can be sent through it.
class _GifProxyField extends StatefulWidget {
  const _GifProxyField({required this.settings});

  final AppSettings settings;

  @override
  State<_GifProxyField> createState() => _GifProxyFieldState();
}

class _GifProxyFieldState extends State<_GifProxyField> {
  late final _controller = TextEditingController(
    text: widget.settings.gifProxyServer,
  );
  bool _saved = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final value = _controller.text.trim();
    final server = value.isEmpty ? defaultGifProxyServer : value;
    if (server != value) _controller.text = server;
    await widget.settings.setGifProxyServer(server);
    if (mounted) setState(() => _saved = true);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: TextField(
        controller: _controller,
        autocorrect: false,
        enableSuggestions: false,
        decoration: InputDecoration(
          labelText: context.l10n.gifProxyServer,
          border: const OutlineInputBorder(),
          isDense: true,
          suffixIcon: _saved
              ? const Padding(
                  padding: EdgeInsets.only(right: 12),
                  child: Icon(Icons.check, color: Color(0xFF43A047)),
                )
              : IconButton(
                  tooltip: context.l10n.save,
                  icon: const Icon(Icons.save_outlined),
                  onPressed: _save,
                ),
        ),
        onChanged: (_) {
          if (_saved) setState(() => _saved = false);
        },
        onSubmitted: (_) => _save(),
      ),
    );
  }
}

/// Text field storing the Klipy API key for the GIF picker.
class _KlipyKeyField extends StatefulWidget {
  const _KlipyKeyField({required this.settings});

  final AppSettings settings;

  @override
  State<_KlipyKeyField> createState() => _KlipyKeyFieldState();
}

class _KlipyKeyFieldState extends State<_KlipyKeyField> {
  late final _controller = TextEditingController(
    text: widget.settings.klipyApiKey,
  );
  bool _saved = false;

  /// Secrets stay hidden by default; the eye toggle reveals them.
  bool _obscured = true;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await widget.settings.setKlipyApiKey(_controller.text.trim());
    if (mounted) setState(() => _saved = true);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TextField(
        controller: _controller,
        obscureText: _obscured,
        autocorrect: false,
        enableSuggestions: false,
        decoration: InputDecoration(
          labelText: context.l10n.klipyApiKey,
          border: const OutlineInputBorder(),
          isDense: true,
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: _obscured ? context.l10n.show : context.l10n.hide,
                icon: Icon(
                  _obscured
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
                onPressed: () => setState(() => _obscured = !_obscured),
              ),
              if (_saved)
                const Padding(
                  padding: EdgeInsets.only(right: 12),
                  child: Icon(Icons.check, color: Color(0xFF43A047)),
                )
              else
                IconButton(
                  tooltip: context.l10n.save,
                  icon: const Icon(Icons.save_outlined),
                  onPressed: _save,
                ),
            ],
          ),
        ),
        onChanged: (_) {
          if (_saved) setState(() => _saved = false);
        },
        onSubmitted: (_) => _save(),
      ),
    );
  }
}

/// Shows the cross-signing / key backup state with actions to set it up,
/// unlock it with the recovery key, or reset it.
class _BackupSection extends StatefulWidget {
  const _BackupSection({required this.client});

  final Client client;

  @override
  State<_BackupSection> createState() => _BackupSectionState();
}

class _BackupSectionState extends State<_BackupSection> {
  Future<void> _openBootstrap({bool wipe = false}) async {
    if (wipe) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(context.l10n.resetChatBackup),
          content: Text(context.l10n.resetChatBackupWarning),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(context.l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(context.l10n.reset),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    await showBootstrapDialog(context, client: widget.client, wipe: wipe);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final encryption = widget.client.encryption;
    if (encryption == null) return const SizedBox.shrink();
    final configured =
        encryption.crossSigning.enabled && encryption.keyManager.enabled;
    if (!configured) {
      return ListTile(
        leading: const Icon(Icons.backup_outlined),
        title: Text(context.l10n.chatBackupNotSetUp),
        subtitle: Text(context.l10n.chatBackupNotSetUpDescription),
        trailing: FilledButton(
          onPressed: () => _openBootstrap(),
          child: Text(context.l10n.setUp),
        ),
      );
    }
    return FutureBuilder<List<bool>>(
      future: Future.wait([
        encryption.crossSigning.isCached(),
        encryption.keyManager.isCached(),
      ]),
      builder: (context, snapshot) {
        final cached = snapshot.data?.every((value) => value) ?? false;
        if (!snapshot.hasData) {
          return ListTile(
            leading: const Icon(Icons.backup_outlined),
            title: Text(context.l10n.chatBackup),
            subtitle: Text(context.l10n.checking),
          );
        }
        if (!cached) {
          return ListTile(
            leading: Icon(Icons.lock_clock, color: const Color(0xFFF9A825)),
            title: Text(context.l10n.chatBackupLocked),
            subtitle: Text(context.l10n.chatBackupLockedDescription),
            trailing: FilledButton(
              onPressed: () => _openBootstrap(),
              child: Text(context.l10n.unlock),
            ),
          );
        }
        return ListTile(
          leading: const Icon(Icons.verified_user, color: Color(0xFF43A047)),
          title: Text(context.l10n.chatBackupEnabled),
          subtitle: Text(context.l10n.chatBackupEnabledDescription),
          trailing: PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'reset') _openBootstrap(wipe: true);
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'reset',
                child: Text(context.l10n.resetBackup),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Lists the user's devices with their verification state and lets the user
/// start an interactive verification with any of them.
class _DevicesSection extends StatefulWidget {
  const _DevicesSection({required this.client});

  final Client client;

  @override
  State<_DevicesSection> createState() => _DevicesSectionState();
}

class _DevicesSectionState extends State<_DevicesSection> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  Future<void> _loadDevices() async {
    try {
      await widget.client.updateUserDeviceKeys();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _verify(DeviceKeys deviceKeys) async {
    try {
      final request = await deviceKeys.startVerification();
      if (!mounted) return;
      await KeyVerificationDialog.show(context, request);
      await _loadDevices();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  /// Verifies this session against the user's cross-signing identity: sends
  /// a verification request to all other own devices, to be confirmed on one
  /// of them. On success the master key becomes trusted and every
  /// cross-signed device turns verified here as well.
  Future<void> _verifySession() async {
    final keysList = widget.client.userDeviceKeys[widget.client.userID];
    if (keysList == null) return;
    try {
      final request = await keysList.startVerification();
      if (!mounted) return;
      await KeyVerificationDialog.show(context, request);
      await _loadDevices();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final client = widget.client;
    if (!client.encryptionEnabled) {
      return ListTile(
        leading: const Icon(Icons.no_encryption_outlined),
        title: Text(context.l10n.encryptionNotAvailable),
        subtitle: Text(context.l10n.encryptionNotAvailableDescription),
      );
    }
    if (_loading) {
      return ListTile(
        leading: const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        title: Text(context.l10n.loadingDevices),
      );
    }
    final keysList = client.userDeviceKeys[client.userID];
    final devices = keysList?.deviceKeys.values.toList() ?? [];
    if (devices.isEmpty) {
      return ListTile(
        leading: const Icon(Icons.devices_outlined),
        title: Text(context.l10n.noDevicesWithEncryptionKeys),
      );
    }
    final colorScheme = Theme.of(context).colorScheme;
    const green = Color(0xFF43A047);
    final masterKey = keysList?.masterKey;
    final sessionTrusted = masterKey == null || masterKey.verified;
    return Column(
      children: [
        if (!sessionTrusted)
          ListTile(
            leading: Icon(Icons.gpp_maybe_outlined, color: colorScheme.error),
            title: Text(context.l10n.sessionNotVerified),
            subtitle: Text(context.l10n.sessionNotVerifiedDescription),
            trailing: FilledButton(
              onPressed: _verifySession,
              child: Text(context.l10n.verifySession),
            ),
          ),
        for (final device in devices)
          ListTile(
            leading: Icon(
              device.deviceId == client.deviceID
                  ? Icons.computer
                  : Icons.devices_other_outlined,
            ),
            title: Text(device.deviceDisplayName ?? device.deviceId ?? '?'),
            subtitle: Text(
              [
                device.deviceId ?? '?',
                if (device.deviceId == client.deviceID) context.l10n.thisDevice,
                if (device.verified)
                  context.l10n.verified
                else if (!sessionTrusted && device.signed)
                  context.l10n.crossSignedPendingVerification
                else
                  context.l10n.unverified,
              ].join(' · '),
              style: TextStyle(
                color: device.verified
                    ? green
                    : (!sessionTrusted && device.signed)
                    ? const Color(0xFFF9A825)
                    : colorScheme.error,
              ),
            ),
            trailing: device.deviceId == client.deviceID || device.verified
                ? Icon(
                    device.verified ? Icons.verified_user : Icons.computer,
                    color: device.verified ? green : null,
                  )
                : TextButton(
                    onPressed: () => _verify(device),
                    child: Text(context.l10n.verify),
                  ),
          ),
      ],
    );
  }
}

/// Own profile: avatar, names, and a button to upload a new profile picture.
class _ProfileSection extends StatefulWidget {
  const _ProfileSection({required this.client});

  final Client client;

  @override
  State<_ProfileSection> createState() => _ProfileSectionState();
}

class _ProfileSectionState extends State<_ProfileSection> {
  ProfileInformation? _profile;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final userId = widget.client.userID;
    if (userId == null) return;
    try {
      final profile = await widget.client.getUserProfile(userId);
      if (mounted) setState(() => _profile = profile);
    } catch (_) {}
  }

  Uri? get _bannerUrl => bannerUrlFromProfile(_profile);

  /// The SDK caches profiles for up to a day and does not notice our own
  /// setProfileField writes; mark ours outdated so every consumer (this
  /// preview, the user footer, banner widgets) refetches fresh data.
  Future<void> _invalidateProfileCaches() async {
    final userId = widget.client.userID;
    if (userId == null) return;
    try {
      await widget.client.database.markUserProfileAsOutdated(userId);
    } catch (_) {}
    invalidateUserProfile(userId);
  }

  /// Picks an image, uploads it and stores its mxc URI in the profile field
  /// [fieldName].
  Future<void> _uploadImageTo(String fieldName) async {
    final picked = await openFile(
      acceptedTypeGroups: [
        XTypeGroup(
          label: context.l10n.images,
          extensions: const ['png', 'jpg', 'jpeg', 'gif', 'webp'],
        ),
      ],
    );
    if (picked == null) return;
    setState(() => _busy = true);
    final client = widget.client;
    try {
      final bytes = await picked.readAsBytes();
      final mxc = await client.uploadContent(bytes, filename: picked.name);
      await client.setProfileField(client.userID!, fieldName, {
        fieldName: mxc.toString(),
      });
      await _invalidateProfileCaches();
      await _loadProfile();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editDisplayName() async {
    final newName = await showTextPromptDialog(
      context,
      title: context.l10n.displayName,
      initial: _profile?.displayname ?? '',
    );
    if (newName == null || newName.isEmpty) return;
    setState(() => _busy = true);
    try {
      await widget.client.setProfileField(
        widget.client.userID!,
        'displayname',
        {'displayname': newName},
      );
      await _invalidateProfileCaches();
      await _loadProfile();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final client = widget.client;
    final userId = client.userID ?? context.l10n.unknownUser;
    final displayName = _profile?.displayname ?? userId;
    final bannerUrl = _bannerUrl;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              height: 96,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Fallback color while loading and when no banner is set.
                  ColoredBox(color: InitialsAvatar.colorFor(displayName)),
                  if (bannerUrl != null)
                    MxcImage(
                      client: client,
                      uri: bannerUrl,
                      // Scale keeps the full image server-side; cover fills
                      // the whole strip client-side (like the profile card).
                      thumbnailMethod: ThumbnailMethod.scale,
                      fit: BoxFit.cover,
                      placeholder: (_) => const SizedBox.shrink(),
                    ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: IconButton.filledTonal(
                      tooltip: context.l10n.changeBanner,
                      icon: const Icon(Icons.panorama_outlined, size: 20),
                      onPressed: _busy
                          ? null
                          : () => _uploadImageTo(bannerWriteField),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        ListTile(
          leading: MxcAvatar(
            client: client,
            name: displayName,
            avatarUrl: _profile?.avatarUrl,
          ),
          title: Text(displayName),
          subtitle: Text(
            '$userId · ${client.homeserver?.host ?? ''}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: _busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: context.l10n.editDisplayName,
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: _editDisplayName,
                    ),
                    IconButton(
                      tooltip: context.l10n.changeProfilePicture,
                      icon: const Icon(Icons.add_a_photo_outlined),
                      onPressed: () => _uploadImageTo('avatar_url'),
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}

/// Own presence and status message, applied via the presence API.
class _StatusSection extends StatefulWidget {
  const _StatusSection({required this.client, required this.settings});

  final Client client;
  final AppSettings settings;

  @override
  State<_StatusSection> createState() => _StatusSectionState();
}

class _StatusSectionState extends State<_StatusSection> {
  PresenceType _presence = PresenceType.online;
  final _statusController = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // The chosen presence is local truth — the server-side value is away
    // whenever this account is in the background or the app is idle.
    _presence = widget.settings.presenceFor(widget.client.clientName);
    _loadCurrent();
  }

  @override
  void dispose() {
    _statusController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrent() async {
    final userId = widget.client.userID;
    if (userId == null) return;
    try {
      // The visible status text lives in the extended profile fields
      // ([statusReadFields]), with the presence status message as fallback.
      final profileStatus = statusFromProfile(
        await fetchExtendedProfile(widget.client, userId),
      );
      final statusMsg =
          profileStatus ??
          (await widget.client.fetchCurrentPresence(userId)).statusMsg;
      if (!mounted) return;
      setState(() => _statusController.text = statusMsg ?? '');
    } catch (_) {}
  }

  Future<void> _apply() async {
    final client = widget.client;
    final userId = client.userID;
    if (userId == null) return;
    setState(() => _busy = true);
    try {
      final message = _statusController.text.trim();
      // Persist the choice; the PresenceService derives every account's
      // sync presence from it (background accounts appear offline). The
      // direct presence API call below just makes the change immediate.
      await widget.settings.setPresenceFor(client.clientName, _presence);
      await client.setPresence(
        userId,
        _presence,
        statusMsg: message.isEmpty ? null : message,
      );
      // Mirror the status into the profile fields so it shows in the footer
      // and in other clients. The MSC4426 field is written too because it
      // outranks Commet's: an older value there would otherwise hide this
      // one. The emoji is left empty — any emoji is part of the text.
      await client.setProfileField(userId, msc4426StatusField, {
        msc4426StatusField: {'text': message, 'emoji': ''},
      });
      await client.setProfileField(userId, commetStatusField, {
        commetStatusField: message,
      });
      invalidateUserProfile(userId);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.statusUpdated)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SegmentedButton<PresenceType>(
            segments: [
              ButtonSegment(
                value: PresenceType.online,
                label: Text(context.l10n.online),
                icon: const Icon(
                  Icons.circle,
                  color: Color(0xFF43A047),
                  size: 12,
                ),
              ),
              ButtonSegment(
                value: PresenceType.unavailable,
                label: Text(context.l10n.away),
                icon: const Icon(
                  Icons.circle,
                  color: Color(0xFFF9A825),
                  size: 12,
                ),
              ),
              ButtonSegment(
                value: PresenceType.offline,
                label: Text(context.l10n.invisible),
                icon: const Icon(Icons.circle_outlined, size: 12),
              ),
            ],
            selected: {_presence},
            onSelectionChanged: _busy
                ? null
                : (selection) {
                    setState(() => _presence = selection.single);
                    _apply();
                  },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _statusController,
                  enabled: !_busy,
                  decoration: InputDecoration(
                    labelText: context.l10n.statusMessage,
                    hintText: context.l10n.whatsHappening,
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                  onSubmitted: (_) => _apply(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                tooltip: context.l10n.setStatus,
                onPressed: _busy ? null : _apply,
                icon: const Icon(Icons.check),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A miniature of the app — spaces rail, room list and chat pane — rendered
/// in [theme]'s actual color scheme for the current brightness, with the
/// theme name in its own typography color underneath.
class _ThemePreviewCard extends StatelessWidget {
  const _ThemePreviewCard({
    required this.theme,
    required this.seed,
    required this.selected,
    required this.onTap,
    this.custom,
    this.accent,
  });

  final AppTheme theme;

  /// Seed for the Material theme's card, so it previews the chosen color.
  final AppThemeColor seed;

  /// Colors for the custom theme's card, and the accent worn over the cards
  /// of themes that ship their own palette.
  final CustomPalette? custom;
  final Color? accent;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = schemeFor(
      theme,
      seed,
      Theme.of(context).brightness,
      custom: custom,
      accent: switch (theme) {
        AppTheme.material || AppTheme.custom => null,
        _ => accent,
      },
    );
    return _PreviewCard(
      scheme: scheme,
      label: theme.label,
      selected: selected,
      onTap: onTap,
      mockup: _WorkspaceMiniature(scheme: scheme),
    );
  }
}

/// A miniature of an app layout in the current theme — flat docked panels
/// for Workspace, frosted panels over the gradient for Liquid — with the
/// layout name underneath.
class _LayoutPreviewCard extends StatelessWidget {
  const _LayoutPreviewCard({
    required this.layout,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final AppLayout layout;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _PreviewCard(
      scheme: scheme,
      label: label,
      selected: selected,
      onTap: onTap,
      mockup: switch (layout) {
        AppLayout.workspace => _WorkspaceMiniature(scheme: scheme),
        AppLayout.liquid => _LiquidMiniature(
          scheme: scheme,
          glow: SettingsScope.of(context).backgroundGlow,
        ),
        AppLayout.floating => _FloatingMiniature(scheme: scheme),
        AppLayout.focus => _FocusMiniature(scheme: scheme),
      },
    );
  }
}

/// A miniature of how messages render in the timeline — cozy rows, chat
/// bubbles or terminal-style text lines — with the layout name underneath.
class _MessageLayoutPreviewCard extends StatelessWidget {
  const _MessageLayoutPreviewCard({
    required this.layout,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final MessageLayout layout;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _PreviewCard(
      scheme: scheme,
      label: label,
      selected: selected,
      onTap: onTap,
      mockup: Padding(
        padding: const EdgeInsets.all(6),
        child: switch (layout) {
          MessageLayout.cozy => _MiniChat(scheme: scheme),
          MessageLayout.bubbles => _MiniBubbleChat(scheme: scheme),
          MessageLayout.text => _MiniTextChat(scheme: scheme),
        },
      ),
    );
  }
}

/// A miniature of the workspace with the spaces rail docked on the left or
/// the right, with the side underneath.
class _RailPositionPreviewCard extends StatelessWidget {
  const _RailPositionPreviewCard({
    required this.position,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final RailPosition position;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _PreviewCard(
      scheme: scheme,
      label: label,
      selected: selected,
      onTap: onTap,
      mockup: _WorkspaceMiniature(
        scheme: scheme,
        railRight: position == RailPosition.right,
      ),
    );
  }
}

/// Shared chrome of the preview cards: selection border, ink, the mockup on
/// top and a nameplate with the label and a check mark underneath. Inner
/// colors come from [scheme] so theme cards render in the scheme they
/// preview; the selection border uses the ambient scheme.
class _PreviewCard extends StatelessWidget {
  const _PreviewCard({
    required this.scheme,
    required this.label,
    required this.selected,
    required this.onTap,
    required this.mockup,
  });

  final ColorScheme scheme;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Widget mockup;

  @override
  Widget build(BuildContext context) {
    final outer = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      child: AnimatedContainer(
        duration: Motion.quick,
        curve: Motion.easeOut,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            width: 2,
            color: selected ? outer.primary : outer.outlineVariant,
          ),
        ),
        // Clip the content separately, inset by the border width: clipping
        // the container itself would let the content paint over the border
        // stroke and cut its corners off.
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Material(
            color: scheme.surface,
            child: InkWell(
              onTap: onTap,
              child: SizedBox(
                width: 128,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(height: 72, child: mockup),
                    _nameplate(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _nameplate() => Container(
    color: scheme.surfaceContainerLow,
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    child: Row(
      children: [
        Expanded(
          // Long names (e.g. "Catppuccin Macchiato") shrink to fit the
          // card instead of being cut off with an ellipsis.
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              label,
              maxLines: 1,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: scheme.onSurface,
              ),
            ),
          ),
        ),
        AnimatedScale(
          scale: selected ? 1 : 0,
          duration: Motion.quick,
          curve: Motion.easeOut,
          child: Icon(Icons.check_circle, size: 14, color: scheme.primary),
        ),
      ],
    ),
  );
}

/// The workspace layout in miniature: spaces rail, room list and chat pane
/// as flat docked panels; [railRight] mirrors the panel order like the
/// real rail position setting does.
class _WorkspaceMiniature extends StatelessWidget {
  const _WorkspaceMiniature({required this.scheme, this.railRight = false});

  final ColorScheme scheme;
  final bool railRight;

  @override
  Widget build(BuildContext context) {
    final panels = [
      // Spaces rail.
      Container(
        width: 16,
        color: scheme.surfaceContainerLowest,
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: _MiniRail(scheme: scheme),
      ),
      // Room list.
      Container(
        width: 30,
        color: scheme.surfaceContainerLow,
        padding: const EdgeInsets.all(6),
        child: _MiniRoomList(scheme: scheme),
      ),
      // Chat pane.
      Expanded(
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: _MiniChat(scheme: scheme),
        ),
      ),
    ];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: railRight ? panels.reversed.toList() : panels,
    );
  }
}

/// The liquid layout in miniature: frosted panels floating over the
/// gradient, mirroring the real wide-window liquid scaffold.
class _LiquidMiniature extends StatelessWidget {
  const _LiquidMiniature({required this.scheme, this.glow = true});

  final ColorScheme scheme;

  /// Mirrors the corner glow setting, so the card shows what will be got.
  final bool glow;

  Widget _panel({double? width, required Widget child}) => Container(
    width: width,
    decoration: BoxDecoration(
      color: scheme.surface.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(5),
    ),
    child: child,
  );

  @override
  Widget build(BuildContext context) => Container(
    decoration: liquidBackdrop(
      scheme,
      SettingsScope.of(context).appBackgroundColor,
      SettingsScope.of(context).appBackgroundFade,
      glow: glow,
    ),
    padding: const EdgeInsets.all(5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _panel(
          width: 14,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: _MiniRail(scheme: scheme),
          ),
        ),
        const SizedBox(width: 4),
        _panel(
          width: 26,
          child: Padding(
            padding: const EdgeInsets.all(5),
            child: _MiniRoomList(scheme: scheme),
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: _panel(
            child: Padding(
              padding: const EdgeInsets.all(5),
              child: _MiniChat(scheme: scheme),
            ),
          ),
        ),
      ],
    ),
  );
}

/// The floating layout in miniature: rail and room list docked flat, the
/// chat as a rounded card floating on the sidebar background.
class _FloatingMiniature extends StatelessWidget {
  const _FloatingMiniature({required this.scheme});

  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      // Spaces rail.
      Container(
        width: 16,
        color: scheme.surfaceContainerLowest,
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: _MiniRail(scheme: scheme),
      ),
      // Room list.
      Container(
        width: 30,
        color: scheme.surfaceContainerLow,
        padding: const EdgeInsets.all(6),
        child: _MiniRoomList(scheme: scheme),
      ),
      // Chat card.
      Expanded(
        child: Container(
          color: scheme.surfaceContainerLow,
          padding: const EdgeInsets.all(4),
          child: Container(
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: scheme.outlineVariant),
            ),
            padding: const EdgeInsets.all(5),
            child: _MiniChat(scheme: scheme),
          ),
        ),
      ),
    ],
  );
}

/// The focus layout in miniature: the chat pane alone with a hamburger
/// hint in the corner — no rail or room list.
class _FocusMiniature extends StatelessWidget {
  const _FocusMiniature({required this.scheme});

  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(6),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Hamburger menu hint.
        Row(
          children: [
            Column(
              children: [
                for (var i = 0; i < 3; i++) ...[
                  if (i > 0) const SizedBox(height: 1.5),
                  Container(
                    width: 8,
                    height: 1.5,
                    decoration: BoxDecoration(
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        const SizedBox(height: 5),
        Expanded(child: _MiniChat(scheme: scheme)),
      ],
    ),
  );
}

/// Three space dots, the first one active.
class _MiniRail extends StatelessWidget {
  const _MiniRail({required this.scheme});

  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      _miniDot(scheme.primary, 8),
      const SizedBox(height: 4),
      _miniDot(scheme.surfaceContainerHighest, 8),
      const SizedBox(height: 4),
      _miniDot(scheme.surfaceContainerHighest, 8),
    ],
  );
}

/// Three room bars, the first one selected.
class _MiniRoomList extends StatelessWidget {
  const _MiniRoomList({required this.scheme});

  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _miniBar(scheme.primary),
      const SizedBox(height: 5),
      _miniBar(scheme.onSurfaceVariant.withValues(alpha: 0.45)),
      const SizedBox(height: 5),
      _miniBar(scheme.onSurfaceVariant.withValues(alpha: 0.45)),
    ],
  );
}

/// Two message rows and an input bar.
class _MiniChat extends StatelessWidget {
  const _MiniChat({required this.scheme});

  final ColorScheme scheme;

  Widget _message({required double nameWidth, required double bodyWidth}) =>
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _miniDot(scheme.primary, 9),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FractionallySizedBox(
                  widthFactor: nameWidth,
                  child: _miniBar(scheme.onSurface.withValues(alpha: 0.85)),
                ),
                const SizedBox(height: 3),
                FractionallySizedBox(
                  widthFactor: bodyWidth,
                  child: _miniBar(
                    scheme.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      );

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _message(nameWidth: 0.55, bodyWidth: 0.9),
      const SizedBox(height: 6),
      _message(nameWidth: 0.4, bodyWidth: 0.65),
      const Spacer(),
      Container(
        height: 9,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(4.5),
        ),
      ),
    ],
  );
}

/// Asymmetric chat bubbles — others left, own message right — and an
/// input bar, mirroring the real bubble colors.
class _MiniBubbleChat extends StatelessWidget {
  const _MiniBubbleChat({required this.scheme});

  final ColorScheme scheme;

  Widget _bubble({required double width, required bool own}) => Align(
    alignment: own ? Alignment.centerRight : Alignment.centerLeft,
    child: Container(
      width: width,
      height: 12,
      decoration: BoxDecoration(
        color: own ? scheme.primaryContainer : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _bubble(width: 56, own: false),
      const SizedBox(height: 4),
      _bubble(width: 42, own: true),
      const SizedBox(height: 4),
      _bubble(width: 48, own: false),
      const Spacer(),
      Container(
        height: 9,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(4.5),
        ),
      ),
    ],
  );
}

/// Terminal-style text lines — timestamp, name, message — without avatars,
/// and an input bar.
class _MiniTextChat extends StatelessWidget {
  const _MiniTextChat({required this.scheme});

  final ColorScheme scheme;

  Widget _line({required double bodyWidth}) => Row(
    children: [
      // Timestamp.
      SizedBox(
        width: 8,
        child: _miniBar(scheme.onSurfaceVariant.withValues(alpha: 0.35)),
      ),
      const SizedBox(width: 3),
      // <name>
      SizedBox(width: 13, child: _miniBar(scheme.primary)),
      const SizedBox(width: 3),
      // Message.
      Expanded(
        child: FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: bodyWidth,
          child: _miniBar(scheme.onSurfaceVariant.withValues(alpha: 0.5)),
        ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _line(bodyWidth: 0.9),
      const SizedBox(height: 4),
      _line(bodyWidth: 0.55),
      const SizedBox(height: 4),
      _line(bodyWidth: 0.75),
      const SizedBox(height: 4),
      _line(bodyWidth: 0.4),
      const Spacer(),
      Container(
        height: 9,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(4.5),
        ),
      ),
    ],
  );
}

Widget _miniDot(Color color, double size) => Container(
  width: size,
  height: size,
  decoration: BoxDecoration(shape: BoxShape.circle, color: color),
);

Widget _miniBar(Color color) => Container(
  height: 4,
  decoration: BoxDecoration(
    color: color,
    borderRadius: BorderRadius.circular(2),
  ),
);

class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final AppThemeColor color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Check mark color with enough contrast on the seed itself.
    final onSeed =
        ThemeData.estimateBrightnessForColor(color.seed) == Brightness.dark
        ? Colors.white
        : Colors.black87;
    return Tooltip(
      message: color.label,
      child: Semantics(
        button: true,
        selected: selected,
        label: color.label,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          // Selection ring in the seed color with a gap around the swatch.
          child: AnimatedContainer(
            duration: Motion.quick,
            curve: Motion.easeOut,
            width: 44,
            height: 44,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                width: 2.5,
                color: selected ? color.seed : Colors.transparent,
              ),
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.seed,
              ),
              child: selected
                  ? Icon(Icons.check, color: onSeed, size: 20)
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
