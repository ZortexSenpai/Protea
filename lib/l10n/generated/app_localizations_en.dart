// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get accentColor => 'Accent color';

  @override
  String get accentColorDescription =>
      'Wear a color of your own over this theme, or keep the one it ships with.';

  @override
  String get appBackground => 'App background';

  @override
  String get appBackgroundDescription =>
      'A colour behind the whole app — the page under the panels, and the glow in the corners of the Liquid layout.';

  @override
  String get backgroundGlow => 'Glowing corners';

  @override
  String get backgroundGlowDescription =>
      'Colours the top-left and bottom-right of the Liquid layout’s background. Off makes it one flat colour.';

  @override
  String get blur => 'Blur';

  @override
  String get chatWallpaper => 'Chat wallpaper';

  @override
  String get chatWallpaperDescription =>
      'An image behind the messages. Fades and blurs to taste so text stays readable.';

  @override
  String get chooseImage => 'Choose image';

  @override
  String get clearSearch => 'Clear search';

  @override
  String get closeToTrayDescription =>
      'Closing the window keeps Protea running in the system tray.';

  @override
  String get closeToTrayTitle => 'Close to tray';

  @override
  String get accept => 'Accept';

  @override
  String get access => 'Access';

  @override
  String get accessToken => 'Access token';

  @override
  String get accessTokenWarning =>
      'Never share your access token. It grants full control over your account.';

  @override
  String get account => 'Account';

  @override
  String get accounts => 'Accounts';

  @override
  String get activitiesAndObjects => 'Activities & objects';

  @override
  String get addACaption => 'Add a caption…';

  @override
  String get addAccount => 'Add account';

  @override
  String get addOption => 'Add option';

  @override
  String get addReaction => 'Add reaction';

  @override
  String get addSticker => 'Add sticker';

  @override
  String get addToFavorites => 'Add to favorites';

  @override
  String get admin => 'Admin';

  @override
  String get all => 'All';

  @override
  String get animalsAndNature => 'Animals & nature';

  @override
  String get anyone => 'Anyone';

  @override
  String get appLayout => 'App layout';

  @override
  String get appLayoutDescription =>
      'Workspace shows a spaces rail with a channel list per space, Split pairs the room list with the chat, List opens chats as their own page.';

  @override
  String get appTitle => 'Protea';

  @override
  String get appearance => 'Appearance';

  @override
  String areTyping(String name1, String name2) {
    return '$name1 and $name2 are typing…';
  }

  @override
  String get arrowUpToEditDescription =>
      'Pressing arrow up in the empty message box starts editing your last message.';

  @override
  String get arrowUpToEditTitle => 'Edit last message with arrow up';

  @override
  String get attachFile => 'Attach file';

  @override
  String get attachments => 'Attachments';

  @override
  String get autoAway => 'Auto-away';

  @override
  String get autoAwayDescription =>
      'Set the status to away after 10 minutes without keyboard or mouse input.';

  @override
  String get away => 'Away';

  @override
  String get ban => 'Ban';

  @override
  String banUserTitle(String name) {
    return 'Ban $name?';
  }

  @override
  String get bannedUsers => 'Banned users';

  @override
  String get block => 'Block';

  @override
  String get bubbles => 'Bubbles';

  @override
  String get cancel => 'Cancel';

  @override
  String get categoryName => 'Category name';

  @override
  String get changeBanner => 'Change banner';

  @override
  String get changeImage => 'Change image';

  @override
  String get changeProfilePicture => 'Change profile picture';

  @override
  String get changeSettings => 'Change settings';

  @override
  String get changeSpaceImage => 'Change space image';

  @override
  String get channelSettings => 'Channel settings';

  @override
  String get channels => 'Channels';

  @override
  String get chatBackup => 'Chat backup';

  @override
  String get chatBackupEnabled => 'Chat backup enabled';

  @override
  String get chatBackupEnabledDescription =>
      'Cross-signing and key backup are active on this device.';

  @override
  String get chatBackupLocked => 'Chat backup is locked';

  @override
  String get chatBackupLockedDescription =>
      'Unlock it with your recovery key to read old encrypted messages on this device.';

  @override
  String get chatBackupNotSetUp => 'Chat backup is not set up';

  @override
  String get chatBackupNotSetUpDescription =>
      'Set up cross-signing and key backup so encrypted messages survive on new devices.';

  @override
  String get chatBackupSetUp => 'Chat backup is set up!';

  @override
  String get checking => 'Checking…';

  @override
  String get clickToSave => 'Click to save';

  @override
  String get close => 'Close';

  @override
  String get closeThread => 'Close thread';

  @override
  String get cmdBan => 'Ban a user from this room';

  @override
  String get cmdDiscardSession => 'Discard the outbound encryption session';

  @override
  String get cmdDm => 'Open a direct chat';

  @override
  String get cmdHelp => 'List available commands';

  @override
  String get cmdHtml => 'Send raw HTML';

  @override
  String get cmdIgnore => 'Ignore a user';

  @override
  String get cmdInvite => 'Invite a user to this room';

  @override
  String get cmdJoin => 'Join a room';

  @override
  String get cmdKick => 'Kick a user from this room';

  @override
  String get cmdLeave => 'Leave this room';

  @override
  String get cmdLenny => 'Append ( ͡° ͜ʖ ͡°)';

  @override
  String get cmdMe => 'Send an emote';

  @override
  String get cmdMyRoomNick => 'Change your name in this room only';

  @override
  String get cmdNick => 'Change your display name';

  @override
  String get cmdOp => 'Set a user\'s power level';

  @override
  String get cmdPlain => 'Send without markdown formatting';

  @override
  String get cmdReact => 'React to the message you reply to';

  @override
  String get cmdRoomUpgrade => 'Upgrade this room';

  @override
  String get cmdShrug => 'Append ¯\\_(ツ)_/¯';

  @override
  String get cmdSpoiler => 'Hide the message behind a spoiler';

  @override
  String get cmdTableflip => 'Append (╯°□°)╯︵ ┻━┻';

  @override
  String get cmdTopic => 'Set the room topic';

  @override
  String get cmdUnban => 'Unban a user';

  @override
  String get cmdUnflip => 'Append ┬─┬ ノ( ゜-゜ノ)';

  @override
  String get cmdUnignore => 'Stop ignoring a user';

  @override
  String get color => 'Color';

  @override
  String get colorAccent => 'Accent';

  @override
  String get colorBackground => 'Background';

  @override
  String get colorMutedText => 'Muted text';

  @override
  String get colorOutline => 'Outline';

  @override
  String get colorPanels => 'Panels';

  @override
  String get colorText => 'Text';

  @override
  String get commands => 'Commands';

  @override
  String get compact => 'Compact';

  @override
  String get compareAndConfirmMatch =>
      'Compare with the other device. Confirm only if they match exactly, in the same order.';

  @override
  String get compareEmojis => 'Compare emojis';

  @override
  String get compareEmojisToVerify =>
      'Compare a short list of emojis with the other device to verify it.';

  @override
  String get copiedToClipboard => 'Copied to clipboard';

  @override
  String get copy => 'Copy';

  @override
  String get copyRoomId => 'Copy room ID';

  @override
  String get copyText => 'Copy text';

  @override
  String get copyImage => 'Copy image';

  @override
  String get findOrStartConversation => 'Find or start a conversation';

  @override
  String get imageCopied => 'Image copied';

  @override
  String get noSearchResults => 'No results.';

  @override
  String get quickSwitcherHint => 'Where would you like to go?';

  @override
  String get quickSwitcherTip =>
      'Tip: start with @ to search people or # to search rooms. ↑↓ to navigate, Enter to open.';

  @override
  String get retrySend => 'Retry';

  @override
  String get messageNotSent => 'Not sent';

  @override
  String get spreadsheetEmpty => 'This sheet is empty.';

  @override
  String spreadsheetTruncated(int rows, int columns) {
    return 'Large sheet: only the first $rows rows and $columns columns are shown.';
  }

  @override
  String get spreadsheetUnreadable => 'This spreadsheet could not be read.';

  @override
  String uploadFailed(String filename) {
    return 'Upload failed: $filename';
  }

  @override
  String get fileNoLongerCached =>
      'The file is no longer available to resend. Delete the message and send it again.';

  @override
  String get downloadImage => 'Download';

  @override
  String get copyThemeCode => 'Copy theme code';

  @override
  String get couldNotUnlock =>
      'Could not unlock. Please check the recovery key.';

  @override
  String get couldNotUnlockBackup =>
      'Could not unlock the backup. Please check the recovery key.';

  @override
  String get cozy => 'Default';

  @override
  String get create => 'Create';

  @override
  String get createPoll => 'Create poll';

  @override
  String get crossSignedPendingVerification =>
      'cross-signed · trusted once this session is verified';

  @override
  String currentRoomVersion(String version) {
    return 'Currently room version $version';
  }

  @override
  String get customThemeColors => 'Custom colors';

  @override
  String get customThemeColorsDescription =>
      'Six colors make the whole theme: the surface shades in between are worked out from the background and the panel color.';

  @override
  String get dark => 'Dark';

  @override
  String get decline => 'Decline';

  @override
  String get delete => 'Delete';

  @override
  String get deleteMessageTitle => 'Delete message?';

  @override
  String get deleteMessageWarning =>
      'The message will be removed for everyone.';

  @override
  String get desktopNotificationsDescription =>
      'Show system notifications for new messages while the window is in the background.';

  @override
  String get desktopNotificationsTitle => 'Desktop notifications';

  @override
  String get direct => 'Direct';

  @override
  String get directMessages => 'Direct messages';

  @override
  String get discardRecording => 'Discard recording';

  @override
  String get displayName => 'Display name';

  @override
  String get done => 'Done';

  @override
  String get doubleSlashHint =>
      'Start a message with // to send text beginning with a slash.';

  @override
  String get dropFilesToUpload => 'Drop files to upload';

  @override
  String get edit => 'Edit';

  @override
  String get editDisplayName => 'Edit display name';

  @override
  String get editTopic => 'Edit topic';

  @override
  String get edited => '(edited)';

  @override
  String get editingMessage => 'Editing message';

  @override
  String get emoji => 'Emoji';

  @override
  String get enableEncryptionTitle => 'Enable end-to-end encryption';

  @override
  String get enableEncryptionWarning =>
      'Encryption cannot be turned off later. Messages will only be readable on verified devices.';

  @override
  String get emotes => 'Emotes';

  @override
  String get encryptedNotSearchable =>
      'Encrypted rooms are not included — the server cannot search encrypted messages.';

  @override
  String get encryptNewDmsDescription =>
      'Enable end-to-end encryption when starting a new direct chat.';

  @override
  String get encryptNewDmsTitle => 'Encrypt new direct chats';

  @override
  String get encryptionNotAvailable => 'End-to-end encryption is not available';

  @override
  String get encryptionNotAvailableDescription =>
      'The crypto library could not be initialized on this platform.';

  @override
  String get endPoll => 'End poll';

  @override
  String get endToEndEncrypted => 'End-to-end encrypted';

  @override
  String get endToEndEncryptionNotAvailable =>
      'End-to-end encryption is not available.';

  @override
  String get enterRecoveryKeyToUnlockBackup =>
      'Enter your recovery key to unlock the chat backup and verify this session. You got the recovery key when the backup was set up (it looks like: EsT* ****…).';

  @override
  String get enterRecoveryKeyToVerify =>
      'Enter your recovery key to verify with your secure backup, or skip to compare emojis with the other device instead.';

  @override
  String get expert => 'Expert';

  @override
  String get explorePublicRooms => 'Explore public rooms';

  @override
  String get exploreRooms => 'Explore rooms';

  @override
  String get fadeAmount => 'Fade';

  @override
  String get favorites => 'Favorites';

  @override
  String get filterRoomsHint => 'Filter rooms…';

  @override
  String finalResults(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Final results · $count votes',
      one: 'Final results · $count vote',
    );
    return '$_temp0';
  }

  @override
  String get floating => 'Floating';

  @override
  String get focus => 'Focus';

  @override
  String get fontSize => 'Font size';

  @override
  String get foodAndDrink => 'Food & drink';

  @override
  String get formatBold => 'Bold';

  @override
  String get formatCodeBlock => 'Code block';

  @override
  String get formatInlineCode => 'Inline code';

  @override
  String get formatItalic => 'Italic';

  @override
  String get formatLink => 'Link';

  @override
  String get formatSpoiler => 'Spoiler';

  @override
  String get formatStrikethrough => 'Strikethrough';

  @override
  String get formatting => 'Text formatting';

  @override
  String get forward => 'Forward';

  @override
  String get forwardTo => 'Forward to…';

  @override
  String forwardedTo(String name) {
    return 'Forwarded to $name';
  }

  @override
  String get gestures => 'Gestures';

  @override
  String get gif => 'GIF';

  @override
  String get gifSearchKlipy => 'GIF search (Klipy)';

  @override
  String get gifSearchNeedsKlipyKey =>
      'GIF search needs a free Klipy API key.\nGet one at klipy.com and add it in the settings.';

  @override
  String get gifs => 'GIFs';

  @override
  String get gifProxyTitle => 'Send GIFs through a proxy';

  @override
  String get gifProxyDescription =>
      'Sends a link to the GIF instead of uploading a copy to your homeserver. Faster, and the file stays off your server — the proxy and everyone’s homeserver see the request.';

  @override
  String get gifProxyServer => 'GIF proxy server';

  @override
  String get goToPage => 'Go to page';

  @override
  String get group => 'Group';

  @override
  String get groupName => 'Group name';

  @override
  String get guestAccess => 'Guest access';

  @override
  String get heartsAndSymbols => 'Hearts & symbols';

  @override
  String get hexColor => 'Hex';

  @override
  String get hide => 'Hide';

  @override
  String get home => 'Home';

  @override
  String get homeserver => 'Homeserver';

  @override
  String get hue => 'Hue';

  @override
  String get huge => 'Huge';

  @override
  String get iSavedMyRecoveryKey => 'I saved my recovery key';

  @override
  String get images => 'Images';

  @override
  String get integrations => 'Integrations';

  @override
  String get invisible => 'Invisible';

  @override
  String get invitation => 'Invitation';

  @override
  String get invitationTapToRespond => 'Invitation — tap to respond';

  @override
  String get invite => 'Invite';

  @override
  String get inviteToRoom => 'Invite to room';

  @override
  String get inviteToSpace => 'Invite to space';

  @override
  String inviteUser(String userId) {
    return 'Invite $userId';
  }

  @override
  String invitedBy(String name) {
    return 'Invited by $name';
  }

  @override
  String invitedUser(String userId) {
    return 'Invited $userId';
  }

  @override
  String isTyping(String name) {
    return '$name is typing…';
  }

  @override
  String get join => 'Join';

  @override
  String get joined => 'Joined';

  @override
  String get jumpToLatestMessages => 'Jump to latest messages';

  @override
  String get jumpToRoomHint => 'Jump to room…';

  @override
  String get kick => 'Kick';

  @override
  String kickUserTitle(String name) {
    return 'Kick $name?';
  }

  @override
  String get klipyApiKey => 'Klipy API key';

  @override
  String get klipyApiKeyDescription =>
      'The GIF picker uses the Klipy API. Get a free API key at klipy.com and paste it here.';

  @override
  String get knock => 'Knock';

  @override
  String get knockPending => 'Knock pending';

  @override
  String get knockPendingWaiting =>
      'Knock pending — waiting for a room moderator to let you in.';

  @override
  String get knocked => 'Knocked';

  @override
  String get knockedWaitingForApproval => 'Knocked — waiting for approval.';

  @override
  String get language => 'Language';

  @override
  String get large => 'Large';

  @override
  String lastSeenDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Last seen $count days ago',
      one: 'Last seen $count day ago',
    );
    return '$_temp0';
  }

  @override
  String lastSeenHoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Last seen $count hours ago',
      one: 'Last seen $count hour ago',
    );
    return '$_temp0';
  }

  @override
  String get lastSeenJustNow => 'Last seen just now';

  @override
  String lastSeenMinutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Last seen $count minutes ago',
      one: 'Last seen $count minute ago',
    );
    return '$_temp0';
  }

  @override
  String get layout => 'Layout';

  @override
  String get leave => 'Leave';

  @override
  String get leaveRoom => 'Leave room?';

  @override
  String get leaveRoomAction => 'Leave room';

  @override
  String get leaveRoomTitle => 'Leave room?';

  @override
  String get leaveSpace => 'Leave space';

  @override
  String get leaveSpaceTitle => 'Leave space?';

  @override
  String get left => 'Left';

  @override
  String get light => 'Light';

  @override
  String get lightness => 'Lightness';

  @override
  String get liquid => 'Liquid';

  @override
  String get loading => 'Loading…';

  @override
  String get loadingDevices => 'Loading devices…';

  @override
  String get location => 'Location';

  @override
  String get locationInputHelp =>
      'Paste \"lat, lon\", a geo: URI or an OpenStreetMap / Google Maps link.';

  @override
  String get locationInputHint => 'Coordinates or map link';

  @override
  String get makeAdmin => 'Make admin';

  @override
  String get makeAdminWarning =>
      'Admins have the same power as you — you may not be able to demote them afterwards.';

  @override
  String get makeModerator => 'Make moderator';

  @override
  String makeUserAdminTitle(String name) {
    return 'Make $name an admin?';
  }

  @override
  String get managePacks => 'Manage packs';

  @override
  String manyTyping(int count) {
    return '$count people are typing…';
  }

  @override
  String get markUnread => 'Mark as unread';

  @override
  String get member => 'Member';

  @override
  String get members => 'Members';

  @override
  String membersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count members',
      one: '1 member',
    );
    return '$_temp0';
  }

  @override
  String membersWithCount(int count) {
    return 'Members — $count';
  }

  @override
  String get mentions => 'Mentions';

  @override
  String get message => 'Message';

  @override
  String get messageHistory => 'Message history';

  @override
  String get messageLayout => 'Message layout';

  @override
  String get messageLayoutDescription => 'How messages are displayed in chats.';

  @override
  String get microphonePermissionDenied => 'Microphone permission denied.';

  @override
  String get moderator => 'Moderator';

  @override
  String get more => 'More';

  @override
  String get moreAttachments => 'More attachments';

  @override
  String get moreResults => 'More results';

  @override
  String get muted => 'Muted';

  @override
  String get myStickers => 'My stickers';

  @override
  String get name => 'Name';

  @override
  String get newCategory => 'New category';

  @override
  String get newChat => 'New chat';

  @override
  String get newGroup => 'New group';

  @override
  String get newMessages => 'New messages';

  @override
  String get newRoomVersion => 'New room version';

  @override
  String get newSpace => 'New space';

  @override
  String get nextPage => 'Next page';

  @override
  String get noDevicesWithEncryptionKeys =>
      'No devices with encryption keys found';

  @override
  String get noFavoriteGifsHint =>
      'No favorite GIFs yet. Hover a GIF and press the star to keep it here.';

  @override
  String get noGifsFound => 'No GIFs found.';

  @override
  String get noMatchingMembers => 'No matching members.';

  @override
  String get noMatchingRooms => 'No matching rooms.';

  @override
  String get noMessagesFound => 'No messages found.';

  @override
  String get noMessagesYet => 'No messages yet. Say hello!';

  @override
  String get noMessagesYetShort => 'No messages yet';

  @override
  String get noPinnedMessages => 'No pinned messages in this room.';

  @override
  String get noPublicRoomsFound => 'No public rooms found.';

  @override
  String get noRepliesYet => 'No replies yet.';

  @override
  String get noRoomsHereYet => 'No rooms here yet.';

  @override
  String get noRoomsYet =>
      'No rooms yet.\nJoin a room from another client to get started.';

  @override
  String get noStickerPacksHint =>
      'No sticker packs yet.\nUse \"Manage packs\" to add your own stickers, or join rooms that share sticker packs.';

  @override
  String get noTopicSet => 'No topic set';

  @override
  String get normal => 'Normal';

  @override
  String get notEncrypted => 'Not encrypted';

  @override
  String get notJoined => 'Not joined';

  @override
  String get notificationSounds => 'Notification sounds';

  @override
  String get notificationSoundsDescription =>
      'Play the system sound with desktop notifications.';

  @override
  String get notifications => 'Notifications';

  @override
  String get offline => 'Offline';

  @override
  String ofPages(int total) {
    return 'of $total';
  }

  @override
  String get ok => 'OK';

  @override
  String get online => 'Online';

  @override
  String get opacity => 'Opacity';

  @override
  String get openMap => 'Open map';

  @override
  String get openPreview => 'Open preview';

  @override
  String get openSettings => 'Open settings';

  @override
  String optionNumber(int number) {
    return 'Option $number';
  }

  @override
  String get or => 'or';

  @override
  String get otherDeviceShowsShield =>
      'Is the other device showing a green shield?';

  @override
  String get owner => 'Owner';

  @override
  String get packEmpty => 'This pack is empty.';

  @override
  String get password => 'Password';

  @override
  String get pasteThemeCode => 'Paste a theme code';

  @override
  String get pauseGifsDescription =>
      'Stop GIF animations while the window is in the background.';

  @override
  String get pauseGifsTitle => 'Pause GIFs while in background';

  @override
  String get permissions => 'Permissions';

  @override
  String get pin => 'Pin';

  @override
  String get pinned => 'Pinned';

  @override
  String get pinnedMessages => 'Pinned messages';

  @override
  String get playVideo => 'Play video';

  @override
  String get pleaseFillInAllFields => 'Please fill in all fields.';

  @override
  String get poll => 'Poll';

  @override
  String get pollNeedsQuestionAndOptions =>
      'A poll needs a question and at least two options.';

  @override
  String presenceWithStatus(String presence, String status) {
    return '$presence — $status';
  }

  @override
  String get previousPage => 'Previous page';

  @override
  String get privacy => 'Privacy';

  @override
  String get public => 'Public';

  @override
  String get publicSpace => 'Public space';

  @override
  String get publishToDirectory => 'Publish in room directory';

  @override
  String get question => 'Question';

  @override
  String get quit => 'Quit';

  @override
  String reactWith(String emoji) {
    return 'React with $emoji';
  }

  @override
  String readBy(String names) {
    return 'Read by $names';
  }

  @override
  String get recoveryKey => 'Recovery key';

  @override
  String get refresh => 'Refresh';

  @override
  String get reject => 'Reject';

  @override
  String get removeBanner => 'Remove banner';

  @override
  String get removeFromFavorites => 'Remove from favorites';

  @override
  String get removeImage => 'Remove';

  @override
  String get removeMessages => 'Remove messages';

  @override
  String get removeOption => 'Remove option';

  @override
  String get rename => 'Rename';

  @override
  String repliesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count replies',
      one: '1 reply',
    );
    return '$_temp0';
  }

  @override
  String get reply => 'Reply';

  @override
  String get replyInThread => 'Reply in thread';

  @override
  String get requests => 'Requests';

  @override
  String get reset => 'Reset';

  @override
  String get resetBackup => 'Reset backup';

  @override
  String get resetChatBackup => 'Reset chat backup?';

  @override
  String get resetChatBackupWarning =>
      'This discards the existing cross-signing keys and key backup and creates new ones. Devices verified before will need to be verified again, and history encrypted with lost keys stays unreadable.';

  @override
  String get resetToMember => 'Reset to member';

  @override
  String get resetToTheme => 'Start over from the Material theme';

  @override
  String get resetZoom => 'Reset zoom';

  @override
  String get right => 'Right';

  @override
  String get roomAddress => 'Room address';

  @override
  String get roomEncryptedNoE2eeSupport =>
      'This room is end-to-end encrypted. This build of Protea was compiled without E2EE support, so messages cannot be read or sent here.';

  @override
  String get roomIdOrAliasLabel => 'Room ID or alias (#room:server)';

  @override
  String get roomUpgradedNotice =>
      'Room upgraded — the replacement appears shortly.';

  @override
  String get rooms => 'Rooms';

  @override
  String get saturation => 'Saturation';

  @override
  String get save => 'Save';

  @override
  String get saveFile => 'Save file';

  @override
  String get saveRecoveryKeySomewhereSafe =>
      'Save this recovery key somewhere safe (e.g. a password manager). You will need it to read your encrypted message history on new devices:';

  @override
  String saveWithSize(String size) {
    return '$size · save';
  }

  @override
  String savedFile(String name) {
    return 'Saved $name';
  }

  @override
  String get scanQrToVerify =>
      'Scan this QR code with the other device, or compare emojis instead.';

  @override
  String get searchAllRooms => 'Search all rooms';

  @override
  String get searchAllRoomsPrompt =>
      'Search your message history in all rooms.';

  @override
  String get searchFurtherBack => 'Search further back';

  @override
  String get searchGifs => 'Search GIFs…';

  @override
  String get searchEmoji => 'Search emoji…';

  @override
  String get defaultRole => 'Default role';

  @override
  String get notifyEveryone => 'Notify everyone (@room)';

  @override
  String get changePermissions => 'Change permissions';

  @override
  String get changeHistoryVisibility => 'Change history visibility';

  @override
  String get roles => 'Roles';

  @override
  String get assignRole => 'Assign role';

  @override
  String get noEmojiFound => 'No emoji found';

  @override
  String get overview => 'Overview';

  @override
  String get changeAccess => 'Change access settings';

  @override
  String searchResultCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count results',
      one: '$count result',
    );
    return '$_temp0';
  }

  @override
  String get serverAcl => 'Change server ACLs';

  @override
  String get manageSpaceRooms => 'Manage rooms in this space';

  @override
  String get deleteOwnMessages => 'Delete own messages';

  @override
  String get shareLocation => 'Share location';

  @override
  String get shareTheme => 'Share theme';

  @override
  String get showApp => 'Show Protea';

  @override
  String get startCalls => 'Start calls';

  @override
  String messageDeletedFrom(String name) {
    return 'Message from $name deleted';
  }

  @override
  String get searchMembersHint => 'Search members…';

  @override
  String get searchMessages => 'Search messages';

  @override
  String get searchMessagesHint => 'Search messages…';

  @override
  String get searchRoomHistoryPrompt => 'Search the history of this room.';

  @override
  String get searchRoomsHint => 'Search rooms…';

  @override
  String get searchUserHint => 'Search by name, or enter @user:server';

  @override
  String searchedBackTo(String date) {
    return 'Searched back to $date';
  }

  @override
  String searchedBackToBeginning(String date) {
    return 'Searched back to $date (beginning)';
  }

  @override
  String get security => 'Security';

  @override
  String get selectChannelToStartChatting =>
      'Select a channel to start chatting.';

  @override
  String get selectChatToStartMessaging => 'Select a chat to start messaging.';

  @override
  String get send => 'Send';

  @override
  String sendFilesTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Send $count files?',
      one: 'Send file?',
    );
    return '$_temp0';
  }

  @override
  String get sendMessages => 'Send messages';

  @override
  String get sendReadReceiptsDescription =>
      'Let others see which messages you have read.';

  @override
  String get sendReadReceiptsTitle => 'Send read receipts';

  @override
  String get sendTypingNotificationsDescription =>
      'Let others see when you are typing.';

  @override
  String get sendTypingNotificationsTitle => 'Send typing indicators';

  @override
  String get sendVoiceMessage => 'Send voice message';

  @override
  String get sending => 'Sending…';

  @override
  String get server => 'Server';

  @override
  String get sessionNotVerified => 'This session is not verified';

  @override
  String get sessionNotVerifiedDescription =>
      'Your other devices are cross-signed, but this session does not trust your identity key yet, so they all show as unverified. Verify this session from one of your other devices to fix that.';

  @override
  String get setStatus => 'Set status';

  @override
  String get setUp => 'Set up';

  @override
  String get settingUp => 'Setting up…';

  @override
  String get settingUpBackupFailed => 'Setting up the backup failed.';

  @override
  String get settings => 'Settings';

  @override
  String get show => 'Show';

  @override
  String get showDeletedMessagesDescription =>
      'Keep a placeholder where a message was deleted.';

  @override
  String get showDeletedMessagesTitle => 'Deleted messages';

  @override
  String get showMembershipEventsDescription =>
      'Show when members join, leave, or are invited.';

  @override
  String get showMembershipEventsTitle => 'Joins and leaves';

  @override
  String get showProfileChangeEventsDescription =>
      'Show display name and profile picture changes.';

  @override
  String get showProfileChangeEventsTitle => 'Profile changes';

  @override
  String get showReadReceiptsDescription =>
      'Show who has read a message beneath it.';

  @override
  String get showReadReceiptsTitle => 'Show read receipts';

  @override
  String get showUrlPreviewsDescription =>
      'Show a preview card under messages that contain links.';

  @override
  String get showUrlPreviewsTitle => 'Show link previews';

  @override
  String get signIn => 'Sign in';

  @override
  String get signInToYourMatrixAccount => 'Sign in to your Matrix account';

  @override
  String signInWithProvider(String provider) {
    return 'Sign in with $provider';
  }

  @override
  String get signInWithSso => 'Sign in with SSO';

  @override
  String get signOut => 'Sign out';

  @override
  String get signOutConfirmation => 'Do you want to sign out of your account?';

  @override
  String get sinceInvited => 'Since invited';

  @override
  String get sinceJoined => 'Since joined';

  @override
  String get skip => 'Skip';

  @override
  String get small => 'Small';

  @override
  String get smileys => 'Smileys';

  @override
  String get smoothScrollingDescription =>
      'Glide smoothly when scrolling with the mouse wheel instead of jumping in steps.';

  @override
  String get smoothScrollingTitle => 'Smooth scrolling';

  @override
  String get space => 'Space';

  @override
  String get spaceHasNoRooms => 'This space has no rooms.';

  @override
  String get spaceLobby => 'Space lobby';

  @override
  String get spaceMembers => 'Space members';

  @override
  String get spaceName => 'Space name';

  @override
  String get spaceSettings => 'Space settings';

  @override
  String get spacesListPosition => 'Spaces list position';

  @override
  String get ssoLoginTimedOut => 'SSO login timed out. Please try again.';

  @override
  String get startChat => 'Start chat';

  @override
  String get status => 'Status';

  @override
  String get statusMessage => 'Status message';

  @override
  String get statusUpdated => 'Status updated';

  @override
  String get sticker => 'Sticker';

  @override
  String get stickers => 'Stickers';

  @override
  String get switchAccount => 'Switch account';

  @override
  String get syncing => 'Syncing…';

  @override
  String get systemDefault => 'System';

  @override
  String get systemMessages => 'System messages';

  @override
  String get systemMessagesDescription =>
      'Choose which room events appear in the timeline.';

  @override
  String get text => 'Text';

  @override
  String get theme => 'Theme';

  @override
  String get themeCode => 'Theme code';

  @override
  String get themeCodeApplied => 'Theme applied.';

  @override
  String get themeCodeCopied => 'Theme code copied.';

  @override
  String get themeCodeInvalid => 'That is not a Protea theme code.';

  @override
  String get themeDefault => 'Theme default';

  @override
  String get theyDontMatch => 'They don\'t match';

  @override
  String get theyMatch => 'They match';

  @override
  String get thisDevice => 'this device';

  @override
  String get thread => 'Thread';

  @override
  String get today => 'Today';

  @override
  String get topic => 'Topic';

  @override
  String get trending => 'Trending';

  @override
  String get typeTwoCharactersToSearch =>
      'Type at least two characters to search the user directory.';

  @override
  String get unban => 'Unban';

  @override
  String get unblock => 'Unblock';

  @override
  String get unknownChannel => 'Unknown channel';

  @override
  String unknownCommand(String command) {
    return 'Unknown command /$command — start with // to send it as text.';
  }

  @override
  String get unknownUser => 'Unknown user';

  @override
  String get unlock => 'Unlock';

  @override
  String get unpin => 'Unpin';

  @override
  String get unverified => 'unverified';

  @override
  String get upgrade => 'Upgrade';

  @override
  String get upgradeRoom => 'Upgrade room';

  @override
  String upgradeRoomExplanation(String newVersion, String currentVersion) {
    return 'This creates a new room on version $newVersion and closes this one (version $currentVersion) with a pointer to the replacement. Members need to rejoin the new room.';
  }

  @override
  String get upgradeRoomTitle => 'Upgrade room?';

  @override
  String get userIdLabel => 'User ID (@user:server)';

  @override
  String get username => 'Username';

  @override
  String verificationFailed(String reason) {
    return 'Verification failed or was cancelled.\n$reason';
  }

  @override
  String get verificationSuccessful =>
      'Verification successful! The device is now trusted.';

  @override
  String get verified => 'verified';

  @override
  String get verify => 'Verify';

  @override
  String get verifyDevice => 'Verify device';

  @override
  String get verifySession => 'Verify session';

  @override
  String versionDefault(String version) {
    return '$version (default)';
  }

  @override
  String get voiceMessage => 'Voice message';

  @override
  String voteCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count votes',
      one: '$count vote',
    );
    return '$_temp0';
  }

  @override
  String get waitingForOtherDeviceToAccept =>
      'Waiting for the other device to accept…\n\nMake sure the other device is online and the request was accepted there.';

  @override
  String get waitingForOtherDeviceToConfirm =>
      'Waiting for the other device to confirm…';

  @override
  String wantsToVerifyDevice(String user) {
    return '$user wants to verify a device.';
  }

  @override
  String wantsToVerifyDeviceWithId(String user, String deviceId) {
    return '$user wants to verify a device ($deviceId).';
  }

  @override
  String get whatsHappening => 'What\'s happening?';

  @override
  String get whoCanJoin => 'Who can join';

  @override
  String get withdrawKnock => 'Withdraw knock';

  @override
  String get workspace => 'Default';

  @override
  String get yesterday => 'Yesterday';

  @override
  String get yesVerify => 'Yes, verify';

  @override
  String get youHaveBeenInvited => 'You have been invited to this room.';

  @override
  String youWillNoLongerSee(String roomName) {
    return 'You will no longer see $roomName.';
  }

  @override
  String get zoomIn => 'Zoom in';

  @override
  String get zoomOut => 'Zoom out';

  @override
  String get setNickname => 'Set nickname';

  @override
  String get nicknameHint => 'Only you can see this. Leave empty to remove it.';

  @override
  String get roomNameResetHint => 'Leave empty to reset to the default name';

  @override
  String get reactions => 'Reactions';

  @override
  String get viewReactions => 'View reactions';
}
