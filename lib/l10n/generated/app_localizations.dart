import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_it.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
    Locale('es'),
    Locale('fr'),
    Locale('it'),
  ];

  /// No description provided for @accentColor.
  ///
  /// In en, this message translates to:
  /// **'Accent color'**
  String get accentColor;

  /// No description provided for @accentColorDescription.
  ///
  /// In en, this message translates to:
  /// **'Wear a color of your own over this theme, or keep the one it ships with.'**
  String get accentColorDescription;

  /// No description provided for @appBackground.
  ///
  /// In en, this message translates to:
  /// **'App background'**
  String get appBackground;

  /// No description provided for @appBackgroundDescription.
  ///
  /// In en, this message translates to:
  /// **'A colour behind the whole app — the page under the panels, and the glow in the corners of the Liquid layout.'**
  String get appBackgroundDescription;

  /// No description provided for @backgroundGlow.
  ///
  /// In en, this message translates to:
  /// **'Glowing corners'**
  String get backgroundGlow;

  /// No description provided for @backgroundGlowDescription.
  ///
  /// In en, this message translates to:
  /// **'Colours the top-left and bottom-right of the Liquid layout’s background. Off makes it one flat colour.'**
  String get backgroundGlowDescription;

  /// No description provided for @blur.
  ///
  /// In en, this message translates to:
  /// **'Blur'**
  String get blur;

  /// No description provided for @chatWallpaper.
  ///
  /// In en, this message translates to:
  /// **'Chat wallpaper'**
  String get chatWallpaper;

  /// No description provided for @chatWallpaperDescription.
  ///
  /// In en, this message translates to:
  /// **'An image behind the messages. Fades and blurs to taste so text stays readable.'**
  String get chatWallpaperDescription;

  /// No description provided for @chooseImage.
  ///
  /// In en, this message translates to:
  /// **'Choose image'**
  String get chooseImage;

  /// No description provided for @clearSearch.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get clearSearch;

  /// No description provided for @closeToTrayDescription.
  ///
  /// In en, this message translates to:
  /// **'Closing the window keeps Protea running in the system tray.'**
  String get closeToTrayDescription;

  /// No description provided for @closeToTrayTitle.
  ///
  /// In en, this message translates to:
  /// **'Close to tray'**
  String get closeToTrayTitle;

  /// No description provided for @accept.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get accept;

  /// No description provided for @access.
  ///
  /// In en, this message translates to:
  /// **'Access'**
  String get access;

  /// No description provided for @accessToken.
  ///
  /// In en, this message translates to:
  /// **'Access token'**
  String get accessToken;

  /// No description provided for @accessTokenWarning.
  ///
  /// In en, this message translates to:
  /// **'Never share your access token. It grants full control over your account.'**
  String get accessTokenWarning;

  /// No description provided for @account.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get account;

  /// No description provided for @accounts.
  ///
  /// In en, this message translates to:
  /// **'Accounts'**
  String get accounts;

  /// No description provided for @activitiesAndObjects.
  ///
  /// In en, this message translates to:
  /// **'Activities & objects'**
  String get activitiesAndObjects;

  /// No description provided for @addACaption.
  ///
  /// In en, this message translates to:
  /// **'Add a caption…'**
  String get addACaption;

  /// No description provided for @addAccount.
  ///
  /// In en, this message translates to:
  /// **'Add account'**
  String get addAccount;

  /// No description provided for @addOption.
  ///
  /// In en, this message translates to:
  /// **'Add option'**
  String get addOption;

  /// No description provided for @addReaction.
  ///
  /// In en, this message translates to:
  /// **'Add reaction'**
  String get addReaction;

  /// No description provided for @addSticker.
  ///
  /// In en, this message translates to:
  /// **'Add sticker'**
  String get addSticker;

  /// No description provided for @addToFavorites.
  ///
  /// In en, this message translates to:
  /// **'Add to favorites'**
  String get addToFavorites;

  /// No description provided for @admin.
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get admin;

  /// No description provided for @all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// No description provided for @animalsAndNature.
  ///
  /// In en, this message translates to:
  /// **'Animals & nature'**
  String get animalsAndNature;

  /// No description provided for @anyone.
  ///
  /// In en, this message translates to:
  /// **'Anyone'**
  String get anyone;

  /// No description provided for @appLayout.
  ///
  /// In en, this message translates to:
  /// **'App layout'**
  String get appLayout;

  /// No description provided for @appLayoutDescription.
  ///
  /// In en, this message translates to:
  /// **'Workspace shows a spaces rail with a channel list per space, Split pairs the room list with the chat, List opens chats as their own page.'**
  String get appLayoutDescription;

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Protea'**
  String get appTitle;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @areTyping.
  ///
  /// In en, this message translates to:
  /// **'{name1} and {name2} are typing…'**
  String areTyping(String name1, String name2);

  /// No description provided for @arrowUpToEditDescription.
  ///
  /// In en, this message translates to:
  /// **'Pressing arrow up in the empty message box starts editing your last message.'**
  String get arrowUpToEditDescription;

  /// No description provided for @arrowUpToEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit last message with arrow up'**
  String get arrowUpToEditTitle;

  /// No description provided for @attachFile.
  ///
  /// In en, this message translates to:
  /// **'Attach file'**
  String get attachFile;

  /// No description provided for @attachments.
  ///
  /// In en, this message translates to:
  /// **'Attachments'**
  String get attachments;

  /// No description provided for @autoAway.
  ///
  /// In en, this message translates to:
  /// **'Auto-away'**
  String get autoAway;

  /// No description provided for @autoAwayDescription.
  ///
  /// In en, this message translates to:
  /// **'Set the status to away after 10 minutes without keyboard or mouse input.'**
  String get autoAwayDescription;

  /// No description provided for @away.
  ///
  /// In en, this message translates to:
  /// **'Away'**
  String get away;

  /// No description provided for @ban.
  ///
  /// In en, this message translates to:
  /// **'Ban'**
  String get ban;

  /// No description provided for @banUserTitle.
  ///
  /// In en, this message translates to:
  /// **'Ban {name}?'**
  String banUserTitle(String name);

  /// No description provided for @bannedUsers.
  ///
  /// In en, this message translates to:
  /// **'Banned users'**
  String get bannedUsers;

  /// No description provided for @block.
  ///
  /// In en, this message translates to:
  /// **'Block'**
  String get block;

  /// No description provided for @bubbles.
  ///
  /// In en, this message translates to:
  /// **'Bubbles'**
  String get bubbles;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @categoryName.
  ///
  /// In en, this message translates to:
  /// **'Category name'**
  String get categoryName;

  /// No description provided for @changeBanner.
  ///
  /// In en, this message translates to:
  /// **'Change banner'**
  String get changeBanner;

  /// No description provided for @changeImage.
  ///
  /// In en, this message translates to:
  /// **'Change image'**
  String get changeImage;

  /// No description provided for @changeProfilePicture.
  ///
  /// In en, this message translates to:
  /// **'Change profile picture'**
  String get changeProfilePicture;

  /// No description provided for @changeSettings.
  ///
  /// In en, this message translates to:
  /// **'Change settings'**
  String get changeSettings;

  /// No description provided for @changeSpaceImage.
  ///
  /// In en, this message translates to:
  /// **'Change space image'**
  String get changeSpaceImage;

  /// No description provided for @channelSettings.
  ///
  /// In en, this message translates to:
  /// **'Channel settings'**
  String get channelSettings;

  /// No description provided for @channels.
  ///
  /// In en, this message translates to:
  /// **'Channels'**
  String get channels;

  /// No description provided for @chatBackup.
  ///
  /// In en, this message translates to:
  /// **'Chat backup'**
  String get chatBackup;

  /// No description provided for @chatBackupEnabled.
  ///
  /// In en, this message translates to:
  /// **'Chat backup enabled'**
  String get chatBackupEnabled;

  /// No description provided for @chatBackupEnabledDescription.
  ///
  /// In en, this message translates to:
  /// **'Cross-signing and key backup are active on this device.'**
  String get chatBackupEnabledDescription;

  /// No description provided for @chatBackupLocked.
  ///
  /// In en, this message translates to:
  /// **'Chat backup is locked'**
  String get chatBackupLocked;

  /// No description provided for @chatBackupLockedDescription.
  ///
  /// In en, this message translates to:
  /// **'Unlock it with your recovery key to read old encrypted messages on this device.'**
  String get chatBackupLockedDescription;

  /// No description provided for @chatBackupNotSetUp.
  ///
  /// In en, this message translates to:
  /// **'Chat backup is not set up'**
  String get chatBackupNotSetUp;

  /// No description provided for @chatBackupNotSetUpDescription.
  ///
  /// In en, this message translates to:
  /// **'Set up cross-signing and key backup so encrypted messages survive on new devices.'**
  String get chatBackupNotSetUpDescription;

  /// No description provided for @chatBackupSetUp.
  ///
  /// In en, this message translates to:
  /// **'Chat backup is set up!'**
  String get chatBackupSetUp;

  /// No description provided for @checking.
  ///
  /// In en, this message translates to:
  /// **'Checking…'**
  String get checking;

  /// No description provided for @clickToSave.
  ///
  /// In en, this message translates to:
  /// **'Click to save'**
  String get clickToSave;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @closeThread.
  ///
  /// In en, this message translates to:
  /// **'Close thread'**
  String get closeThread;

  /// No description provided for @cmdBan.
  ///
  /// In en, this message translates to:
  /// **'Ban a user from this room'**
  String get cmdBan;

  /// No description provided for @cmdDiscardSession.
  ///
  /// In en, this message translates to:
  /// **'Discard the outbound encryption session'**
  String get cmdDiscardSession;

  /// No description provided for @cmdDm.
  ///
  /// In en, this message translates to:
  /// **'Open a direct chat'**
  String get cmdDm;

  /// No description provided for @cmdHelp.
  ///
  /// In en, this message translates to:
  /// **'List available commands'**
  String get cmdHelp;

  /// No description provided for @cmdHtml.
  ///
  /// In en, this message translates to:
  /// **'Send raw HTML'**
  String get cmdHtml;

  /// No description provided for @cmdIgnore.
  ///
  /// In en, this message translates to:
  /// **'Ignore a user'**
  String get cmdIgnore;

  /// No description provided for @cmdInvite.
  ///
  /// In en, this message translates to:
  /// **'Invite a user to this room'**
  String get cmdInvite;

  /// No description provided for @cmdJoin.
  ///
  /// In en, this message translates to:
  /// **'Join a room'**
  String get cmdJoin;

  /// No description provided for @cmdKick.
  ///
  /// In en, this message translates to:
  /// **'Kick a user from this room'**
  String get cmdKick;

  /// No description provided for @cmdLeave.
  ///
  /// In en, this message translates to:
  /// **'Leave this room'**
  String get cmdLeave;

  /// No description provided for @cmdLenny.
  ///
  /// In en, this message translates to:
  /// **'Append ( ͡° ͜ʖ ͡°)'**
  String get cmdLenny;

  /// No description provided for @cmdMe.
  ///
  /// In en, this message translates to:
  /// **'Send an emote'**
  String get cmdMe;

  /// No description provided for @cmdMyRoomNick.
  ///
  /// In en, this message translates to:
  /// **'Change your name in this room only'**
  String get cmdMyRoomNick;

  /// No description provided for @cmdNick.
  ///
  /// In en, this message translates to:
  /// **'Change your display name'**
  String get cmdNick;

  /// No description provided for @cmdOp.
  ///
  /// In en, this message translates to:
  /// **'Set a user\'s power level'**
  String get cmdOp;

  /// No description provided for @cmdPlain.
  ///
  /// In en, this message translates to:
  /// **'Send without markdown formatting'**
  String get cmdPlain;

  /// No description provided for @cmdReact.
  ///
  /// In en, this message translates to:
  /// **'React to the message you reply to'**
  String get cmdReact;

  /// No description provided for @cmdRoomUpgrade.
  ///
  /// In en, this message translates to:
  /// **'Upgrade this room'**
  String get cmdRoomUpgrade;

  /// No description provided for @cmdShrug.
  ///
  /// In en, this message translates to:
  /// **'Append ¯\\_(ツ)_/¯'**
  String get cmdShrug;

  /// No description provided for @cmdSpoiler.
  ///
  /// In en, this message translates to:
  /// **'Hide the message behind a spoiler'**
  String get cmdSpoiler;

  /// No description provided for @cmdTableflip.
  ///
  /// In en, this message translates to:
  /// **'Append (╯°□°)╯︵ ┻━┻'**
  String get cmdTableflip;

  /// No description provided for @cmdTopic.
  ///
  /// In en, this message translates to:
  /// **'Set the room topic'**
  String get cmdTopic;

  /// No description provided for @cmdUnban.
  ///
  /// In en, this message translates to:
  /// **'Unban a user'**
  String get cmdUnban;

  /// No description provided for @cmdUnflip.
  ///
  /// In en, this message translates to:
  /// **'Append ┬─┬ ノ( ゜-゜ノ)'**
  String get cmdUnflip;

  /// No description provided for @cmdUnignore.
  ///
  /// In en, this message translates to:
  /// **'Stop ignoring a user'**
  String get cmdUnignore;

  /// No description provided for @color.
  ///
  /// In en, this message translates to:
  /// **'Color'**
  String get color;

  /// No description provided for @colorAccent.
  ///
  /// In en, this message translates to:
  /// **'Accent'**
  String get colorAccent;

  /// No description provided for @colorBackground.
  ///
  /// In en, this message translates to:
  /// **'Background'**
  String get colorBackground;

  /// No description provided for @colorMutedText.
  ///
  /// In en, this message translates to:
  /// **'Muted text'**
  String get colorMutedText;

  /// No description provided for @colorOutline.
  ///
  /// In en, this message translates to:
  /// **'Outline'**
  String get colorOutline;

  /// No description provided for @colorPanels.
  ///
  /// In en, this message translates to:
  /// **'Panels'**
  String get colorPanels;

  /// No description provided for @colorText.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get colorText;

  /// No description provided for @commands.
  ///
  /// In en, this message translates to:
  /// **'Commands'**
  String get commands;

  /// No description provided for @compact.
  ///
  /// In en, this message translates to:
  /// **'Compact'**
  String get compact;

  /// No description provided for @compareAndConfirmMatch.
  ///
  /// In en, this message translates to:
  /// **'Compare with the other device. Confirm only if they match exactly, in the same order.'**
  String get compareAndConfirmMatch;

  /// No description provided for @compareEmojis.
  ///
  /// In en, this message translates to:
  /// **'Compare emojis'**
  String get compareEmojis;

  /// No description provided for @compareEmojisToVerify.
  ///
  /// In en, this message translates to:
  /// **'Compare a short list of emojis with the other device to verify it.'**
  String get compareEmojisToVerify;

  /// No description provided for @copiedToClipboard.
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard'**
  String get copiedToClipboard;

  /// No description provided for @copy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copy;

  /// No description provided for @copyRoomId.
  ///
  /// In en, this message translates to:
  /// **'Copy room ID'**
  String get copyRoomId;

  /// No description provided for @copyText.
  ///
  /// In en, this message translates to:
  /// **'Copy text'**
  String get copyText;

  /// No description provided for @copyImage.
  ///
  /// In en, this message translates to:
  /// **'Copy image'**
  String get copyImage;

  /// No description provided for @findOrStartConversation.
  ///
  /// In en, this message translates to:
  /// **'Find or start a conversation'**
  String get findOrStartConversation;

  /// No description provided for @imageCopied.
  ///
  /// In en, this message translates to:
  /// **'Image copied'**
  String get imageCopied;

  /// No description provided for @noSearchResults.
  ///
  /// In en, this message translates to:
  /// **'No results.'**
  String get noSearchResults;

  /// No description provided for @quickSwitcherHint.
  ///
  /// In en, this message translates to:
  /// **'Where would you like to go?'**
  String get quickSwitcherHint;

  /// No description provided for @quickSwitcherTip.
  ///
  /// In en, this message translates to:
  /// **'Tip: start with @ to search people or # to search rooms. ↑↓ to navigate, Enter to open.'**
  String get quickSwitcherTip;

  /// No description provided for @retrySend.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retrySend;

  /// No description provided for @messageNotSent.
  ///
  /// In en, this message translates to:
  /// **'Not sent'**
  String get messageNotSent;

  /// No description provided for @spreadsheetEmpty.
  ///
  /// In en, this message translates to:
  /// **'This sheet is empty.'**
  String get spreadsheetEmpty;

  /// No description provided for @spreadsheetTruncated.
  ///
  /// In en, this message translates to:
  /// **'Large sheet: only the first {rows} rows and {columns} columns are shown.'**
  String spreadsheetTruncated(int rows, int columns);

  /// No description provided for @spreadsheetUnreadable.
  ///
  /// In en, this message translates to:
  /// **'This spreadsheet could not be read.'**
  String get spreadsheetUnreadable;

  /// No description provided for @uploadFailed.
  ///
  /// In en, this message translates to:
  /// **'Upload failed: {filename}'**
  String uploadFailed(String filename);

  /// No description provided for @fileNoLongerCached.
  ///
  /// In en, this message translates to:
  /// **'The file is no longer available to resend. Delete the message and send it again.'**
  String get fileNoLongerCached;

  /// No description provided for @downloadImage.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get downloadImage;

  /// No description provided for @copyThemeCode.
  ///
  /// In en, this message translates to:
  /// **'Copy theme code'**
  String get copyThemeCode;

  /// No description provided for @couldNotUnlock.
  ///
  /// In en, this message translates to:
  /// **'Could not unlock. Please check the recovery key.'**
  String get couldNotUnlock;

  /// No description provided for @couldNotUnlockBackup.
  ///
  /// In en, this message translates to:
  /// **'Could not unlock the backup. Please check the recovery key.'**
  String get couldNotUnlockBackup;

  /// No description provided for @cozy.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get cozy;

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @createPoll.
  ///
  /// In en, this message translates to:
  /// **'Create poll'**
  String get createPoll;

  /// No description provided for @crossSignedPendingVerification.
  ///
  /// In en, this message translates to:
  /// **'cross-signed · trusted once this session is verified'**
  String get crossSignedPendingVerification;

  /// No description provided for @currentRoomVersion.
  ///
  /// In en, this message translates to:
  /// **'Currently room version {version}'**
  String currentRoomVersion(String version);

  /// No description provided for @customThemeColors.
  ///
  /// In en, this message translates to:
  /// **'Custom colors'**
  String get customThemeColors;

  /// No description provided for @customThemeColorsDescription.
  ///
  /// In en, this message translates to:
  /// **'Six colors make the whole theme: the surface shades in between are worked out from the background and the panel color.'**
  String get customThemeColorsDescription;

  /// No description provided for @dark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get dark;

  /// No description provided for @decline.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get decline;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @deleteMessageTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete message?'**
  String get deleteMessageTitle;

  /// No description provided for @deleteMessageWarning.
  ///
  /// In en, this message translates to:
  /// **'The message will be removed for everyone.'**
  String get deleteMessageWarning;

  /// No description provided for @desktopNotificationsDescription.
  ///
  /// In en, this message translates to:
  /// **'Show system notifications for new messages while the window is in the background.'**
  String get desktopNotificationsDescription;

  /// No description provided for @desktopNotificationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Desktop notifications'**
  String get desktopNotificationsTitle;

  /// No description provided for @direct.
  ///
  /// In en, this message translates to:
  /// **'Direct'**
  String get direct;

  /// No description provided for @directMessages.
  ///
  /// In en, this message translates to:
  /// **'Direct messages'**
  String get directMessages;

  /// No description provided for @discardRecording.
  ///
  /// In en, this message translates to:
  /// **'Discard recording'**
  String get discardRecording;

  /// No description provided for @displayName.
  ///
  /// In en, this message translates to:
  /// **'Display name'**
  String get displayName;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @doubleSlashHint.
  ///
  /// In en, this message translates to:
  /// **'Start a message with // to send text beginning with a slash.'**
  String get doubleSlashHint;

  /// No description provided for @dropFilesToUpload.
  ///
  /// In en, this message translates to:
  /// **'Drop files to upload'**
  String get dropFilesToUpload;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @editDisplayName.
  ///
  /// In en, this message translates to:
  /// **'Edit display name'**
  String get editDisplayName;

  /// No description provided for @editTopic.
  ///
  /// In en, this message translates to:
  /// **'Edit topic'**
  String get editTopic;

  /// No description provided for @edited.
  ///
  /// In en, this message translates to:
  /// **'(edited)'**
  String get edited;

  /// No description provided for @editingMessage.
  ///
  /// In en, this message translates to:
  /// **'Editing message'**
  String get editingMessage;

  /// No description provided for @emoji.
  ///
  /// In en, this message translates to:
  /// **'Emoji'**
  String get emoji;

  /// No description provided for @enableEncryptionTitle.
  ///
  /// In en, this message translates to:
  /// **'Enable end-to-end encryption'**
  String get enableEncryptionTitle;

  /// No description provided for @enableEncryptionWarning.
  ///
  /// In en, this message translates to:
  /// **'Encryption cannot be turned off later. Messages will only be readable on verified devices.'**
  String get enableEncryptionWarning;

  /// No description provided for @emotes.
  ///
  /// In en, this message translates to:
  /// **'Emotes'**
  String get emotes;

  /// No description provided for @encryptedNotSearchable.
  ///
  /// In en, this message translates to:
  /// **'Encrypted rooms are not included — the server cannot search encrypted messages.'**
  String get encryptedNotSearchable;

  /// No description provided for @encryptNewDmsDescription.
  ///
  /// In en, this message translates to:
  /// **'Enable end-to-end encryption when starting a new direct chat.'**
  String get encryptNewDmsDescription;

  /// No description provided for @encryptNewDmsTitle.
  ///
  /// In en, this message translates to:
  /// **'Encrypt new direct chats'**
  String get encryptNewDmsTitle;

  /// No description provided for @encryptionNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'End-to-end encryption is not available'**
  String get encryptionNotAvailable;

  /// No description provided for @encryptionNotAvailableDescription.
  ///
  /// In en, this message translates to:
  /// **'The crypto library could not be initialized on this platform.'**
  String get encryptionNotAvailableDescription;

  /// No description provided for @endPoll.
  ///
  /// In en, this message translates to:
  /// **'End poll'**
  String get endPoll;

  /// No description provided for @endToEndEncrypted.
  ///
  /// In en, this message translates to:
  /// **'End-to-end encrypted'**
  String get endToEndEncrypted;

  /// No description provided for @endToEndEncryptionNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'End-to-end encryption is not available.'**
  String get endToEndEncryptionNotAvailable;

  /// No description provided for @enterRecoveryKeyToUnlockBackup.
  ///
  /// In en, this message translates to:
  /// **'Enter your recovery key to unlock the chat backup and verify this session. You got the recovery key when the backup was set up (it looks like: EsT* ****…).'**
  String get enterRecoveryKeyToUnlockBackup;

  /// No description provided for @enterRecoveryKeyToVerify.
  ///
  /// In en, this message translates to:
  /// **'Enter your recovery key to verify with your secure backup, or skip to compare emojis with the other device instead.'**
  String get enterRecoveryKeyToVerify;

  /// No description provided for @expert.
  ///
  /// In en, this message translates to:
  /// **'Expert'**
  String get expert;

  /// No description provided for @explorePublicRooms.
  ///
  /// In en, this message translates to:
  /// **'Explore public rooms'**
  String get explorePublicRooms;

  /// No description provided for @exploreRooms.
  ///
  /// In en, this message translates to:
  /// **'Explore rooms'**
  String get exploreRooms;

  /// No description provided for @fadeAmount.
  ///
  /// In en, this message translates to:
  /// **'Fade'**
  String get fadeAmount;

  /// No description provided for @favorites.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get favorites;

  /// No description provided for @filterRoomsHint.
  ///
  /// In en, this message translates to:
  /// **'Filter rooms…'**
  String get filterRoomsHint;

  /// No description provided for @finalResults.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{Final results · {count} vote} other{Final results · {count} votes}}'**
  String finalResults(int count);

  /// No description provided for @floating.
  ///
  /// In en, this message translates to:
  /// **'Floating'**
  String get floating;

  /// No description provided for @focus.
  ///
  /// In en, this message translates to:
  /// **'Focus'**
  String get focus;

  /// No description provided for @fontSize.
  ///
  /// In en, this message translates to:
  /// **'Font size'**
  String get fontSize;

  /// No description provided for @foodAndDrink.
  ///
  /// In en, this message translates to:
  /// **'Food & drink'**
  String get foodAndDrink;

  /// No description provided for @formatBold.
  ///
  /// In en, this message translates to:
  /// **'Bold'**
  String get formatBold;

  /// No description provided for @formatCodeBlock.
  ///
  /// In en, this message translates to:
  /// **'Code block'**
  String get formatCodeBlock;

  /// No description provided for @formatInlineCode.
  ///
  /// In en, this message translates to:
  /// **'Inline code'**
  String get formatInlineCode;

  /// No description provided for @formatItalic.
  ///
  /// In en, this message translates to:
  /// **'Italic'**
  String get formatItalic;

  /// No description provided for @formatLink.
  ///
  /// In en, this message translates to:
  /// **'Link'**
  String get formatLink;

  /// No description provided for @formatSpoiler.
  ///
  /// In en, this message translates to:
  /// **'Spoiler'**
  String get formatSpoiler;

  /// No description provided for @formatStrikethrough.
  ///
  /// In en, this message translates to:
  /// **'Strikethrough'**
  String get formatStrikethrough;

  /// No description provided for @formatting.
  ///
  /// In en, this message translates to:
  /// **'Text formatting'**
  String get formatting;

  /// No description provided for @forward.
  ///
  /// In en, this message translates to:
  /// **'Forward'**
  String get forward;

  /// No description provided for @forwardTo.
  ///
  /// In en, this message translates to:
  /// **'Forward to…'**
  String get forwardTo;

  /// No description provided for @forwardedTo.
  ///
  /// In en, this message translates to:
  /// **'Forwarded to {name}'**
  String forwardedTo(String name);

  /// No description provided for @gestures.
  ///
  /// In en, this message translates to:
  /// **'Gestures'**
  String get gestures;

  /// No description provided for @gif.
  ///
  /// In en, this message translates to:
  /// **'GIF'**
  String get gif;

  /// No description provided for @gifSearchKlipy.
  ///
  /// In en, this message translates to:
  /// **'GIF search (Klipy)'**
  String get gifSearchKlipy;

  /// No description provided for @gifSearchNeedsKlipyKey.
  ///
  /// In en, this message translates to:
  /// **'GIF search needs a free Klipy API key.\nGet one at klipy.com and add it in the settings.'**
  String get gifSearchNeedsKlipyKey;

  /// No description provided for @gifs.
  ///
  /// In en, this message translates to:
  /// **'GIFs'**
  String get gifs;

  /// No description provided for @gifProxyTitle.
  ///
  /// In en, this message translates to:
  /// **'Send GIFs through a proxy'**
  String get gifProxyTitle;

  /// No description provided for @gifProxyDescription.
  ///
  /// In en, this message translates to:
  /// **'Sends a link to the GIF instead of uploading a copy to your homeserver. Faster, and the file stays off your server — the proxy and everyone’s homeserver see the request.'**
  String get gifProxyDescription;

  /// No description provided for @gifProxyServer.
  ///
  /// In en, this message translates to:
  /// **'GIF proxy server'**
  String get gifProxyServer;

  /// No description provided for @goToPage.
  ///
  /// In en, this message translates to:
  /// **'Go to page'**
  String get goToPage;

  /// No description provided for @group.
  ///
  /// In en, this message translates to:
  /// **'Group'**
  String get group;

  /// No description provided for @groupName.
  ///
  /// In en, this message translates to:
  /// **'Group name'**
  String get groupName;

  /// No description provided for @guestAccess.
  ///
  /// In en, this message translates to:
  /// **'Guest access'**
  String get guestAccess;

  /// No description provided for @heartsAndSymbols.
  ///
  /// In en, this message translates to:
  /// **'Hearts & symbols'**
  String get heartsAndSymbols;

  /// No description provided for @hexColor.
  ///
  /// In en, this message translates to:
  /// **'Hex'**
  String get hexColor;

  /// No description provided for @hide.
  ///
  /// In en, this message translates to:
  /// **'Hide'**
  String get hide;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @homeserver.
  ///
  /// In en, this message translates to:
  /// **'Homeserver'**
  String get homeserver;

  /// No description provided for @hue.
  ///
  /// In en, this message translates to:
  /// **'Hue'**
  String get hue;

  /// No description provided for @huge.
  ///
  /// In en, this message translates to:
  /// **'Huge'**
  String get huge;

  /// No description provided for @iSavedMyRecoveryKey.
  ///
  /// In en, this message translates to:
  /// **'I saved my recovery key'**
  String get iSavedMyRecoveryKey;

  /// No description provided for @images.
  ///
  /// In en, this message translates to:
  /// **'Images'**
  String get images;

  /// No description provided for @integrations.
  ///
  /// In en, this message translates to:
  /// **'Integrations'**
  String get integrations;

  /// No description provided for @invisible.
  ///
  /// In en, this message translates to:
  /// **'Invisible'**
  String get invisible;

  /// No description provided for @invitation.
  ///
  /// In en, this message translates to:
  /// **'Invitation'**
  String get invitation;

  /// No description provided for @invitationTapToRespond.
  ///
  /// In en, this message translates to:
  /// **'Invitation — tap to respond'**
  String get invitationTapToRespond;

  /// No description provided for @invite.
  ///
  /// In en, this message translates to:
  /// **'Invite'**
  String get invite;

  /// No description provided for @inviteToRoom.
  ///
  /// In en, this message translates to:
  /// **'Invite to room'**
  String get inviteToRoom;

  /// No description provided for @inviteToSpace.
  ///
  /// In en, this message translates to:
  /// **'Invite to space'**
  String get inviteToSpace;

  /// No description provided for @inviteUser.
  ///
  /// In en, this message translates to:
  /// **'Invite {userId}'**
  String inviteUser(String userId);

  /// No description provided for @invitedBy.
  ///
  /// In en, this message translates to:
  /// **'Invited by {name}'**
  String invitedBy(String name);

  /// No description provided for @invitedUser.
  ///
  /// In en, this message translates to:
  /// **'Invited {userId}'**
  String invitedUser(String userId);

  /// No description provided for @isTyping.
  ///
  /// In en, this message translates to:
  /// **'{name} is typing…'**
  String isTyping(String name);

  /// No description provided for @join.
  ///
  /// In en, this message translates to:
  /// **'Join'**
  String get join;

  /// No description provided for @joined.
  ///
  /// In en, this message translates to:
  /// **'Joined'**
  String get joined;

  /// No description provided for @jumpToLatestMessages.
  ///
  /// In en, this message translates to:
  /// **'Jump to latest messages'**
  String get jumpToLatestMessages;

  /// No description provided for @jumpToRoomHint.
  ///
  /// In en, this message translates to:
  /// **'Jump to room…'**
  String get jumpToRoomHint;

  /// No description provided for @kick.
  ///
  /// In en, this message translates to:
  /// **'Kick'**
  String get kick;

  /// No description provided for @kickUserTitle.
  ///
  /// In en, this message translates to:
  /// **'Kick {name}?'**
  String kickUserTitle(String name);

  /// No description provided for @klipyApiKey.
  ///
  /// In en, this message translates to:
  /// **'Klipy API key'**
  String get klipyApiKey;

  /// No description provided for @klipyApiKeyDescription.
  ///
  /// In en, this message translates to:
  /// **'The GIF picker uses the Klipy API. Get a free API key at klipy.com and paste it here.'**
  String get klipyApiKeyDescription;

  /// No description provided for @knock.
  ///
  /// In en, this message translates to:
  /// **'Knock'**
  String get knock;

  /// No description provided for @knockPending.
  ///
  /// In en, this message translates to:
  /// **'Knock pending'**
  String get knockPending;

  /// No description provided for @knockPendingWaiting.
  ///
  /// In en, this message translates to:
  /// **'Knock pending — waiting for a room moderator to let you in.'**
  String get knockPendingWaiting;

  /// No description provided for @knocked.
  ///
  /// In en, this message translates to:
  /// **'Knocked'**
  String get knocked;

  /// No description provided for @knockedWaitingForApproval.
  ///
  /// In en, this message translates to:
  /// **'Knocked — waiting for approval.'**
  String get knockedWaitingForApproval;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @large.
  ///
  /// In en, this message translates to:
  /// **'Large'**
  String get large;

  /// No description provided for @lastSeenDaysAgo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{Last seen {count} day ago} other{Last seen {count} days ago}}'**
  String lastSeenDaysAgo(int count);

  /// No description provided for @lastSeenHoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{Last seen {count} hour ago} other{Last seen {count} hours ago}}'**
  String lastSeenHoursAgo(int count);

  /// No description provided for @lastSeenJustNow.
  ///
  /// In en, this message translates to:
  /// **'Last seen just now'**
  String get lastSeenJustNow;

  /// No description provided for @lastSeenMinutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{Last seen {count} minute ago} other{Last seen {count} minutes ago}}'**
  String lastSeenMinutesAgo(int count);

  /// No description provided for @layout.
  ///
  /// In en, this message translates to:
  /// **'Layout'**
  String get layout;

  /// No description provided for @leave.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get leave;

  /// No description provided for @leaveRoom.
  ///
  /// In en, this message translates to:
  /// **'Leave room?'**
  String get leaveRoom;

  /// No description provided for @leaveRoomAction.
  ///
  /// In en, this message translates to:
  /// **'Leave room'**
  String get leaveRoomAction;

  /// No description provided for @leaveRoomTitle.
  ///
  /// In en, this message translates to:
  /// **'Leave room?'**
  String get leaveRoomTitle;

  /// No description provided for @leaveSpace.
  ///
  /// In en, this message translates to:
  /// **'Leave space'**
  String get leaveSpace;

  /// No description provided for @leaveSpaceTitle.
  ///
  /// In en, this message translates to:
  /// **'Leave space?'**
  String get leaveSpaceTitle;

  /// No description provided for @left.
  ///
  /// In en, this message translates to:
  /// **'Left'**
  String get left;

  /// No description provided for @light.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get light;

  /// No description provided for @lightness.
  ///
  /// In en, this message translates to:
  /// **'Lightness'**
  String get lightness;

  /// No description provided for @liquid.
  ///
  /// In en, this message translates to:
  /// **'Liquid'**
  String get liquid;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get loading;

  /// No description provided for @loadingDevices.
  ///
  /// In en, this message translates to:
  /// **'Loading devices…'**
  String get loadingDevices;

  /// No description provided for @location.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get location;

  /// No description provided for @locationInputHelp.
  ///
  /// In en, this message translates to:
  /// **'Paste \"lat, lon\", a geo: URI or an OpenStreetMap / Google Maps link.'**
  String get locationInputHelp;

  /// No description provided for @locationInputHint.
  ///
  /// In en, this message translates to:
  /// **'Coordinates or map link'**
  String get locationInputHint;

  /// No description provided for @makeAdmin.
  ///
  /// In en, this message translates to:
  /// **'Make admin'**
  String get makeAdmin;

  /// No description provided for @makeAdminWarning.
  ///
  /// In en, this message translates to:
  /// **'Admins have the same power as you — you may not be able to demote them afterwards.'**
  String get makeAdminWarning;

  /// No description provided for @makeModerator.
  ///
  /// In en, this message translates to:
  /// **'Make moderator'**
  String get makeModerator;

  /// No description provided for @makeUserAdminTitle.
  ///
  /// In en, this message translates to:
  /// **'Make {name} an admin?'**
  String makeUserAdminTitle(String name);

  /// No description provided for @managePacks.
  ///
  /// In en, this message translates to:
  /// **'Manage packs'**
  String get managePacks;

  /// No description provided for @manyTyping.
  ///
  /// In en, this message translates to:
  /// **'{count} people are typing…'**
  String manyTyping(int count);

  /// No description provided for @markUnread.
  ///
  /// In en, this message translates to:
  /// **'Mark as unread'**
  String get markUnread;

  /// No description provided for @member.
  ///
  /// In en, this message translates to:
  /// **'Member'**
  String get member;

  /// No description provided for @members.
  ///
  /// In en, this message translates to:
  /// **'Members'**
  String get members;

  /// No description provided for @membersCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 member} other{{count} members}}'**
  String membersCount(int count);

  /// No description provided for @membersWithCount.
  ///
  /// In en, this message translates to:
  /// **'Members — {count}'**
  String membersWithCount(int count);

  /// No description provided for @mentions.
  ///
  /// In en, this message translates to:
  /// **'Mentions'**
  String get mentions;

  /// No description provided for @message.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get message;

  /// No description provided for @messageHistory.
  ///
  /// In en, this message translates to:
  /// **'Message history'**
  String get messageHistory;

  /// No description provided for @messageLayout.
  ///
  /// In en, this message translates to:
  /// **'Message layout'**
  String get messageLayout;

  /// No description provided for @messageLayoutDescription.
  ///
  /// In en, this message translates to:
  /// **'How messages are displayed in chats.'**
  String get messageLayoutDescription;

  /// No description provided for @microphonePermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Microphone permission denied.'**
  String get microphonePermissionDenied;

  /// No description provided for @moderator.
  ///
  /// In en, this message translates to:
  /// **'Moderator'**
  String get moderator;

  /// No description provided for @more.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get more;

  /// No description provided for @moreAttachments.
  ///
  /// In en, this message translates to:
  /// **'More attachments'**
  String get moreAttachments;

  /// No description provided for @moreResults.
  ///
  /// In en, this message translates to:
  /// **'More results'**
  String get moreResults;

  /// No description provided for @muted.
  ///
  /// In en, this message translates to:
  /// **'Muted'**
  String get muted;

  /// No description provided for @myStickers.
  ///
  /// In en, this message translates to:
  /// **'My stickers'**
  String get myStickers;

  /// No description provided for @name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get name;

  /// No description provided for @newCategory.
  ///
  /// In en, this message translates to:
  /// **'New category'**
  String get newCategory;

  /// No description provided for @newChat.
  ///
  /// In en, this message translates to:
  /// **'New chat'**
  String get newChat;

  /// No description provided for @newGroup.
  ///
  /// In en, this message translates to:
  /// **'New group'**
  String get newGroup;

  /// No description provided for @newMessages.
  ///
  /// In en, this message translates to:
  /// **'New messages'**
  String get newMessages;

  /// No description provided for @newRoomVersion.
  ///
  /// In en, this message translates to:
  /// **'New room version'**
  String get newRoomVersion;

  /// No description provided for @newSpace.
  ///
  /// In en, this message translates to:
  /// **'New space'**
  String get newSpace;

  /// No description provided for @nextPage.
  ///
  /// In en, this message translates to:
  /// **'Next page'**
  String get nextPage;

  /// No description provided for @noDevicesWithEncryptionKeys.
  ///
  /// In en, this message translates to:
  /// **'No devices with encryption keys found'**
  String get noDevicesWithEncryptionKeys;

  /// No description provided for @noFavoriteGifsHint.
  ///
  /// In en, this message translates to:
  /// **'No favorite GIFs yet. Hover a GIF and press the star to keep it here.'**
  String get noFavoriteGifsHint;

  /// No description provided for @noGifsFound.
  ///
  /// In en, this message translates to:
  /// **'No GIFs found.'**
  String get noGifsFound;

  /// No description provided for @noMatchingMembers.
  ///
  /// In en, this message translates to:
  /// **'No matching members.'**
  String get noMatchingMembers;

  /// No description provided for @noMatchingRooms.
  ///
  /// In en, this message translates to:
  /// **'No matching rooms.'**
  String get noMatchingRooms;

  /// No description provided for @noMessagesFound.
  ///
  /// In en, this message translates to:
  /// **'No messages found.'**
  String get noMessagesFound;

  /// No description provided for @noMessagesYet.
  ///
  /// In en, this message translates to:
  /// **'No messages yet. Say hello!'**
  String get noMessagesYet;

  /// No description provided for @noMessagesYetShort.
  ///
  /// In en, this message translates to:
  /// **'No messages yet'**
  String get noMessagesYetShort;

  /// No description provided for @noPinnedMessages.
  ///
  /// In en, this message translates to:
  /// **'No pinned messages in this room.'**
  String get noPinnedMessages;

  /// No description provided for @noPublicRoomsFound.
  ///
  /// In en, this message translates to:
  /// **'No public rooms found.'**
  String get noPublicRoomsFound;

  /// No description provided for @noRepliesYet.
  ///
  /// In en, this message translates to:
  /// **'No replies yet.'**
  String get noRepliesYet;

  /// No description provided for @noRoomsHereYet.
  ///
  /// In en, this message translates to:
  /// **'No rooms here yet.'**
  String get noRoomsHereYet;

  /// No description provided for @noRoomsYet.
  ///
  /// In en, this message translates to:
  /// **'No rooms yet.\nJoin a room from another client to get started.'**
  String get noRoomsYet;

  /// No description provided for @noStickerPacksHint.
  ///
  /// In en, this message translates to:
  /// **'No sticker packs yet.\nUse \"Manage packs\" to add your own stickers, or join rooms that share sticker packs.'**
  String get noStickerPacksHint;

  /// No description provided for @noTopicSet.
  ///
  /// In en, this message translates to:
  /// **'No topic set'**
  String get noTopicSet;

  /// No description provided for @normal.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get normal;

  /// No description provided for @notEncrypted.
  ///
  /// In en, this message translates to:
  /// **'Not encrypted'**
  String get notEncrypted;

  /// No description provided for @notJoined.
  ///
  /// In en, this message translates to:
  /// **'Not joined'**
  String get notJoined;

  /// No description provided for @notificationSounds.
  ///
  /// In en, this message translates to:
  /// **'Notification sounds'**
  String get notificationSounds;

  /// No description provided for @notificationSoundsDescription.
  ///
  /// In en, this message translates to:
  /// **'Play the system sound with desktop notifications.'**
  String get notificationSoundsDescription;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @offline.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get offline;

  /// No description provided for @ofPages.
  ///
  /// In en, this message translates to:
  /// **'of {total}'**
  String ofPages(int total);

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @online.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get online;

  /// No description provided for @opacity.
  ///
  /// In en, this message translates to:
  /// **'Opacity'**
  String get opacity;

  /// No description provided for @openMap.
  ///
  /// In en, this message translates to:
  /// **'Open map'**
  String get openMap;

  /// No description provided for @openPreview.
  ///
  /// In en, this message translates to:
  /// **'Open preview'**
  String get openPreview;

  /// No description provided for @openSettings.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get openSettings;

  /// No description provided for @optionNumber.
  ///
  /// In en, this message translates to:
  /// **'Option {number}'**
  String optionNumber(int number);

  /// No description provided for @or.
  ///
  /// In en, this message translates to:
  /// **'or'**
  String get or;

  /// No description provided for @otherDeviceShowsShield.
  ///
  /// In en, this message translates to:
  /// **'Is the other device showing a green shield?'**
  String get otherDeviceShowsShield;

  /// No description provided for @owner.
  ///
  /// In en, this message translates to:
  /// **'Owner'**
  String get owner;

  /// No description provided for @packEmpty.
  ///
  /// In en, this message translates to:
  /// **'This pack is empty.'**
  String get packEmpty;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @pasteThemeCode.
  ///
  /// In en, this message translates to:
  /// **'Paste a theme code'**
  String get pasteThemeCode;

  /// No description provided for @pauseGifsDescription.
  ///
  /// In en, this message translates to:
  /// **'Stop GIF animations while the window is in the background.'**
  String get pauseGifsDescription;

  /// No description provided for @pauseGifsTitle.
  ///
  /// In en, this message translates to:
  /// **'Pause GIFs while in background'**
  String get pauseGifsTitle;

  /// No description provided for @permissions.
  ///
  /// In en, this message translates to:
  /// **'Permissions'**
  String get permissions;

  /// No description provided for @pin.
  ///
  /// In en, this message translates to:
  /// **'Pin'**
  String get pin;

  /// No description provided for @pinned.
  ///
  /// In en, this message translates to:
  /// **'Pinned'**
  String get pinned;

  /// No description provided for @pinnedMessages.
  ///
  /// In en, this message translates to:
  /// **'Pinned messages'**
  String get pinnedMessages;

  /// No description provided for @playVideo.
  ///
  /// In en, this message translates to:
  /// **'Play video'**
  String get playVideo;

  /// No description provided for @pleaseFillInAllFields.
  ///
  /// In en, this message translates to:
  /// **'Please fill in all fields.'**
  String get pleaseFillInAllFields;

  /// No description provided for @poll.
  ///
  /// In en, this message translates to:
  /// **'Poll'**
  String get poll;

  /// No description provided for @pollNeedsQuestionAndOptions.
  ///
  /// In en, this message translates to:
  /// **'A poll needs a question and at least two options.'**
  String get pollNeedsQuestionAndOptions;

  /// No description provided for @presenceWithStatus.
  ///
  /// In en, this message translates to:
  /// **'{presence} — {status}'**
  String presenceWithStatus(String presence, String status);

  /// No description provided for @previousPage.
  ///
  /// In en, this message translates to:
  /// **'Previous page'**
  String get previousPage;

  /// No description provided for @privacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get privacy;

  /// No description provided for @public.
  ///
  /// In en, this message translates to:
  /// **'Public'**
  String get public;

  /// No description provided for @publicSpace.
  ///
  /// In en, this message translates to:
  /// **'Public space'**
  String get publicSpace;

  /// No description provided for @publishToDirectory.
  ///
  /// In en, this message translates to:
  /// **'Publish in room directory'**
  String get publishToDirectory;

  /// No description provided for @question.
  ///
  /// In en, this message translates to:
  /// **'Question'**
  String get question;

  /// No description provided for @quit.
  ///
  /// In en, this message translates to:
  /// **'Quit'**
  String get quit;

  /// No description provided for @reactWith.
  ///
  /// In en, this message translates to:
  /// **'React with {emoji}'**
  String reactWith(String emoji);

  /// No description provided for @readBy.
  ///
  /// In en, this message translates to:
  /// **'Read by {names}'**
  String readBy(String names);

  /// No description provided for @recoveryKey.
  ///
  /// In en, this message translates to:
  /// **'Recovery key'**
  String get recoveryKey;

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// No description provided for @reject.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get reject;

  /// No description provided for @removeBanner.
  ///
  /// In en, this message translates to:
  /// **'Remove banner'**
  String get removeBanner;

  /// No description provided for @removeFromFavorites.
  ///
  /// In en, this message translates to:
  /// **'Remove from favorites'**
  String get removeFromFavorites;

  /// No description provided for @removeImage.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get removeImage;

  /// No description provided for @removeMessages.
  ///
  /// In en, this message translates to:
  /// **'Remove messages'**
  String get removeMessages;

  /// No description provided for @removeOption.
  ///
  /// In en, this message translates to:
  /// **'Remove option'**
  String get removeOption;

  /// No description provided for @rename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get rename;

  /// No description provided for @repliesCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 reply} other{{count} replies}}'**
  String repliesCount(int count);

  /// No description provided for @reply.
  ///
  /// In en, this message translates to:
  /// **'Reply'**
  String get reply;

  /// No description provided for @replyInThread.
  ///
  /// In en, this message translates to:
  /// **'Reply in thread'**
  String get replyInThread;

  /// No description provided for @requests.
  ///
  /// In en, this message translates to:
  /// **'Requests'**
  String get requests;

  /// No description provided for @reset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get reset;

  /// No description provided for @resetBackup.
  ///
  /// In en, this message translates to:
  /// **'Reset backup'**
  String get resetBackup;

  /// No description provided for @resetChatBackup.
  ///
  /// In en, this message translates to:
  /// **'Reset chat backup?'**
  String get resetChatBackup;

  /// No description provided for @resetChatBackupWarning.
  ///
  /// In en, this message translates to:
  /// **'This discards the existing cross-signing keys and key backup and creates new ones. Devices verified before will need to be verified again, and history encrypted with lost keys stays unreadable.'**
  String get resetChatBackupWarning;

  /// No description provided for @resetToMember.
  ///
  /// In en, this message translates to:
  /// **'Reset to member'**
  String get resetToMember;

  /// No description provided for @resetToTheme.
  ///
  /// In en, this message translates to:
  /// **'Start over from the Material theme'**
  String get resetToTheme;

  /// No description provided for @resetZoom.
  ///
  /// In en, this message translates to:
  /// **'Reset zoom'**
  String get resetZoom;

  /// No description provided for @right.
  ///
  /// In en, this message translates to:
  /// **'Right'**
  String get right;

  /// No description provided for @roomAddress.
  ///
  /// In en, this message translates to:
  /// **'Room address'**
  String get roomAddress;

  /// No description provided for @roomEncryptedNoE2eeSupport.
  ///
  /// In en, this message translates to:
  /// **'This room is end-to-end encrypted. This build of Protea was compiled without E2EE support, so messages cannot be read or sent here.'**
  String get roomEncryptedNoE2eeSupport;

  /// No description provided for @roomIdOrAliasLabel.
  ///
  /// In en, this message translates to:
  /// **'Room ID or alias (#room:server)'**
  String get roomIdOrAliasLabel;

  /// No description provided for @roomUpgradedNotice.
  ///
  /// In en, this message translates to:
  /// **'Room upgraded — the replacement appears shortly.'**
  String get roomUpgradedNotice;

  /// No description provided for @rooms.
  ///
  /// In en, this message translates to:
  /// **'Rooms'**
  String get rooms;

  /// No description provided for @saturation.
  ///
  /// In en, this message translates to:
  /// **'Saturation'**
  String get saturation;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @saveFile.
  ///
  /// In en, this message translates to:
  /// **'Save file'**
  String get saveFile;

  /// No description provided for @saveRecoveryKeySomewhereSafe.
  ///
  /// In en, this message translates to:
  /// **'Save this recovery key somewhere safe (e.g. a password manager). You will need it to read your encrypted message history on new devices:'**
  String get saveRecoveryKeySomewhereSafe;

  /// No description provided for @saveWithSize.
  ///
  /// In en, this message translates to:
  /// **'{size} · save'**
  String saveWithSize(String size);

  /// No description provided for @savedFile.
  ///
  /// In en, this message translates to:
  /// **'Saved {name}'**
  String savedFile(String name);

  /// No description provided for @scanQrToVerify.
  ///
  /// In en, this message translates to:
  /// **'Scan this QR code with the other device, or compare emojis instead.'**
  String get scanQrToVerify;

  /// No description provided for @searchAllRooms.
  ///
  /// In en, this message translates to:
  /// **'Search all rooms'**
  String get searchAllRooms;

  /// No description provided for @searchAllRoomsPrompt.
  ///
  /// In en, this message translates to:
  /// **'Search your message history in all rooms.'**
  String get searchAllRoomsPrompt;

  /// No description provided for @searchFurtherBack.
  ///
  /// In en, this message translates to:
  /// **'Search further back'**
  String get searchFurtherBack;

  /// No description provided for @searchGifs.
  ///
  /// In en, this message translates to:
  /// **'Search GIFs…'**
  String get searchGifs;

  /// No description provided for @searchEmoji.
  ///
  /// In en, this message translates to:
  /// **'Search emoji…'**
  String get searchEmoji;

  /// No description provided for @defaultRole.
  ///
  /// In en, this message translates to:
  /// **'Default role'**
  String get defaultRole;

  /// No description provided for @notifyEveryone.
  ///
  /// In en, this message translates to:
  /// **'Notify everyone (@room)'**
  String get notifyEveryone;

  /// No description provided for @changePermissions.
  ///
  /// In en, this message translates to:
  /// **'Change permissions'**
  String get changePermissions;

  /// No description provided for @changeHistoryVisibility.
  ///
  /// In en, this message translates to:
  /// **'Change history visibility'**
  String get changeHistoryVisibility;

  /// No description provided for @roles.
  ///
  /// In en, this message translates to:
  /// **'Roles'**
  String get roles;

  /// No description provided for @assignRole.
  ///
  /// In en, this message translates to:
  /// **'Assign role'**
  String get assignRole;

  /// No description provided for @noEmojiFound.
  ///
  /// In en, this message translates to:
  /// **'No emoji found'**
  String get noEmojiFound;

  /// No description provided for @overview.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get overview;

  /// No description provided for @changeAccess.
  ///
  /// In en, this message translates to:
  /// **'Change access settings'**
  String get changeAccess;

  /// No description provided for @searchResultCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} result} other{{count} results}}'**
  String searchResultCount(int count);

  /// No description provided for @serverAcl.
  ///
  /// In en, this message translates to:
  /// **'Change server ACLs'**
  String get serverAcl;

  /// No description provided for @manageSpaceRooms.
  ///
  /// In en, this message translates to:
  /// **'Manage rooms in this space'**
  String get manageSpaceRooms;

  /// No description provided for @deleteOwnMessages.
  ///
  /// In en, this message translates to:
  /// **'Delete own messages'**
  String get deleteOwnMessages;

  /// No description provided for @shareLocation.
  ///
  /// In en, this message translates to:
  /// **'Share location'**
  String get shareLocation;

  /// No description provided for @shareTheme.
  ///
  /// In en, this message translates to:
  /// **'Share theme'**
  String get shareTheme;

  /// No description provided for @showApp.
  ///
  /// In en, this message translates to:
  /// **'Show Protea'**
  String get showApp;

  /// No description provided for @startCalls.
  ///
  /// In en, this message translates to:
  /// **'Start calls'**
  String get startCalls;

  /// No description provided for @messageDeletedFrom.
  ///
  /// In en, this message translates to:
  /// **'Message from {name} deleted'**
  String messageDeletedFrom(String name);

  /// No description provided for @searchMembersHint.
  ///
  /// In en, this message translates to:
  /// **'Search members…'**
  String get searchMembersHint;

  /// No description provided for @searchMessages.
  ///
  /// In en, this message translates to:
  /// **'Search messages'**
  String get searchMessages;

  /// No description provided for @searchMessagesHint.
  ///
  /// In en, this message translates to:
  /// **'Search messages…'**
  String get searchMessagesHint;

  /// No description provided for @searchRoomHistoryPrompt.
  ///
  /// In en, this message translates to:
  /// **'Search the history of this room.'**
  String get searchRoomHistoryPrompt;

  /// No description provided for @searchRoomsHint.
  ///
  /// In en, this message translates to:
  /// **'Search rooms…'**
  String get searchRoomsHint;

  /// No description provided for @searchUserHint.
  ///
  /// In en, this message translates to:
  /// **'Search by name, or enter @user:server'**
  String get searchUserHint;

  /// No description provided for @searchedBackTo.
  ///
  /// In en, this message translates to:
  /// **'Searched back to {date}'**
  String searchedBackTo(String date);

  /// No description provided for @searchedBackToBeginning.
  ///
  /// In en, this message translates to:
  /// **'Searched back to {date} (beginning)'**
  String searchedBackToBeginning(String date);

  /// No description provided for @security.
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get security;

  /// No description provided for @selectChannelToStartChatting.
  ///
  /// In en, this message translates to:
  /// **'Select a channel to start chatting.'**
  String get selectChannelToStartChatting;

  /// No description provided for @selectChatToStartMessaging.
  ///
  /// In en, this message translates to:
  /// **'Select a chat to start messaging.'**
  String get selectChatToStartMessaging;

  /// No description provided for @send.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get send;

  /// No description provided for @sendFilesTitle.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Send file?} other{Send {count} files?}}'**
  String sendFilesTitle(int count);

  /// No description provided for @sendMessages.
  ///
  /// In en, this message translates to:
  /// **'Send messages'**
  String get sendMessages;

  /// No description provided for @sendReadReceiptsDescription.
  ///
  /// In en, this message translates to:
  /// **'Let others see which messages you have read.'**
  String get sendReadReceiptsDescription;

  /// No description provided for @sendReadReceiptsTitle.
  ///
  /// In en, this message translates to:
  /// **'Send read receipts'**
  String get sendReadReceiptsTitle;

  /// No description provided for @sendTypingNotificationsDescription.
  ///
  /// In en, this message translates to:
  /// **'Let others see when you are typing.'**
  String get sendTypingNotificationsDescription;

  /// No description provided for @sendTypingNotificationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Send typing indicators'**
  String get sendTypingNotificationsTitle;

  /// No description provided for @sendVoiceMessage.
  ///
  /// In en, this message translates to:
  /// **'Send voice message'**
  String get sendVoiceMessage;

  /// No description provided for @sending.
  ///
  /// In en, this message translates to:
  /// **'Sending…'**
  String get sending;

  /// No description provided for @server.
  ///
  /// In en, this message translates to:
  /// **'Server'**
  String get server;

  /// No description provided for @sessionNotVerified.
  ///
  /// In en, this message translates to:
  /// **'This session is not verified'**
  String get sessionNotVerified;

  /// No description provided for @sessionNotVerifiedDescription.
  ///
  /// In en, this message translates to:
  /// **'Your other devices are cross-signed, but this session does not trust your identity key yet, so they all show as unverified. Verify this session from one of your other devices to fix that.'**
  String get sessionNotVerifiedDescription;

  /// No description provided for @setStatus.
  ///
  /// In en, this message translates to:
  /// **'Set status'**
  String get setStatus;

  /// No description provided for @setUp.
  ///
  /// In en, this message translates to:
  /// **'Set up'**
  String get setUp;

  /// No description provided for @settingUp.
  ///
  /// In en, this message translates to:
  /// **'Setting up…'**
  String get settingUp;

  /// No description provided for @settingUpBackupFailed.
  ///
  /// In en, this message translates to:
  /// **'Setting up the backup failed.'**
  String get settingUpBackupFailed;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @show.
  ///
  /// In en, this message translates to:
  /// **'Show'**
  String get show;

  /// No description provided for @showDeletedMessagesDescription.
  ///
  /// In en, this message translates to:
  /// **'Keep a placeholder where a message was deleted.'**
  String get showDeletedMessagesDescription;

  /// No description provided for @showDeletedMessagesTitle.
  ///
  /// In en, this message translates to:
  /// **'Deleted messages'**
  String get showDeletedMessagesTitle;

  /// No description provided for @showMembershipEventsDescription.
  ///
  /// In en, this message translates to:
  /// **'Show when members join, leave, or are invited.'**
  String get showMembershipEventsDescription;

  /// No description provided for @showMembershipEventsTitle.
  ///
  /// In en, this message translates to:
  /// **'Joins and leaves'**
  String get showMembershipEventsTitle;

  /// No description provided for @showProfileChangeEventsDescription.
  ///
  /// In en, this message translates to:
  /// **'Show display name and profile picture changes.'**
  String get showProfileChangeEventsDescription;

  /// No description provided for @showProfileChangeEventsTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile changes'**
  String get showProfileChangeEventsTitle;

  /// No description provided for @showReadReceiptsDescription.
  ///
  /// In en, this message translates to:
  /// **'Show who has read a message beneath it.'**
  String get showReadReceiptsDescription;

  /// No description provided for @showReadReceiptsTitle.
  ///
  /// In en, this message translates to:
  /// **'Show read receipts'**
  String get showReadReceiptsTitle;

  /// No description provided for @showUrlPreviewsDescription.
  ///
  /// In en, this message translates to:
  /// **'Show a preview card under messages that contain links.'**
  String get showUrlPreviewsDescription;

  /// No description provided for @showUrlPreviewsTitle.
  ///
  /// In en, this message translates to:
  /// **'Show link previews'**
  String get showUrlPreviewsTitle;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signIn;

  /// No description provided for @signInToYourMatrixAccount.
  ///
  /// In en, this message translates to:
  /// **'Sign in to your Matrix account'**
  String get signInToYourMatrixAccount;

  /// No description provided for @signInWithProvider.
  ///
  /// In en, this message translates to:
  /// **'Sign in with {provider}'**
  String signInWithProvider(String provider);

  /// No description provided for @signInWithSso.
  ///
  /// In en, this message translates to:
  /// **'Sign in with SSO'**
  String get signInWithSso;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOut;

  /// No description provided for @signOutConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Do you want to sign out of your account?'**
  String get signOutConfirmation;

  /// No description provided for @sinceInvited.
  ///
  /// In en, this message translates to:
  /// **'Since invited'**
  String get sinceInvited;

  /// No description provided for @sinceJoined.
  ///
  /// In en, this message translates to:
  /// **'Since joined'**
  String get sinceJoined;

  /// No description provided for @skip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// No description provided for @small.
  ///
  /// In en, this message translates to:
  /// **'Small'**
  String get small;

  /// No description provided for @smileys.
  ///
  /// In en, this message translates to:
  /// **'Smileys'**
  String get smileys;

  /// No description provided for @smoothScrollingDescription.
  ///
  /// In en, this message translates to:
  /// **'Glide smoothly when scrolling with the mouse wheel instead of jumping in steps.'**
  String get smoothScrollingDescription;

  /// No description provided for @smoothScrollingTitle.
  ///
  /// In en, this message translates to:
  /// **'Smooth scrolling'**
  String get smoothScrollingTitle;

  /// No description provided for @space.
  ///
  /// In en, this message translates to:
  /// **'Space'**
  String get space;

  /// No description provided for @spaceHasNoRooms.
  ///
  /// In en, this message translates to:
  /// **'This space has no rooms.'**
  String get spaceHasNoRooms;

  /// No description provided for @spaceLobby.
  ///
  /// In en, this message translates to:
  /// **'Space lobby'**
  String get spaceLobby;

  /// No description provided for @spaceMembers.
  ///
  /// In en, this message translates to:
  /// **'Space members'**
  String get spaceMembers;

  /// No description provided for @spaceName.
  ///
  /// In en, this message translates to:
  /// **'Space name'**
  String get spaceName;

  /// No description provided for @spaceSettings.
  ///
  /// In en, this message translates to:
  /// **'Space settings'**
  String get spaceSettings;

  /// No description provided for @spacesListPosition.
  ///
  /// In en, this message translates to:
  /// **'Spaces list position'**
  String get spacesListPosition;

  /// No description provided for @ssoLoginTimedOut.
  ///
  /// In en, this message translates to:
  /// **'SSO login timed out. Please try again.'**
  String get ssoLoginTimedOut;

  /// No description provided for @startChat.
  ///
  /// In en, this message translates to:
  /// **'Start chat'**
  String get startChat;

  /// No description provided for @status.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get status;

  /// No description provided for @statusMessage.
  ///
  /// In en, this message translates to:
  /// **'Status message'**
  String get statusMessage;

  /// No description provided for @statusUpdated.
  ///
  /// In en, this message translates to:
  /// **'Status updated'**
  String get statusUpdated;

  /// No description provided for @sticker.
  ///
  /// In en, this message translates to:
  /// **'Sticker'**
  String get sticker;

  /// No description provided for @stickers.
  ///
  /// In en, this message translates to:
  /// **'Stickers'**
  String get stickers;

  /// No description provided for @switchAccount.
  ///
  /// In en, this message translates to:
  /// **'Switch account'**
  String get switchAccount;

  /// No description provided for @syncing.
  ///
  /// In en, this message translates to:
  /// **'Syncing…'**
  String get syncing;

  /// No description provided for @systemDefault.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get systemDefault;

  /// No description provided for @systemMessages.
  ///
  /// In en, this message translates to:
  /// **'System messages'**
  String get systemMessages;

  /// No description provided for @systemMessagesDescription.
  ///
  /// In en, this message translates to:
  /// **'Choose which room events appear in the timeline.'**
  String get systemMessagesDescription;

  /// No description provided for @text.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get text;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @themeCode.
  ///
  /// In en, this message translates to:
  /// **'Theme code'**
  String get themeCode;

  /// No description provided for @themeCodeApplied.
  ///
  /// In en, this message translates to:
  /// **'Theme applied.'**
  String get themeCodeApplied;

  /// No description provided for @themeCodeCopied.
  ///
  /// In en, this message translates to:
  /// **'Theme code copied.'**
  String get themeCodeCopied;

  /// No description provided for @themeCodeInvalid.
  ///
  /// In en, this message translates to:
  /// **'That is not a Protea theme code.'**
  String get themeCodeInvalid;

  /// No description provided for @themeDefault.
  ///
  /// In en, this message translates to:
  /// **'Theme default'**
  String get themeDefault;

  /// No description provided for @theyDontMatch.
  ///
  /// In en, this message translates to:
  /// **'They don\'t match'**
  String get theyDontMatch;

  /// No description provided for @theyMatch.
  ///
  /// In en, this message translates to:
  /// **'They match'**
  String get theyMatch;

  /// No description provided for @thisDevice.
  ///
  /// In en, this message translates to:
  /// **'this device'**
  String get thisDevice;

  /// No description provided for @thread.
  ///
  /// In en, this message translates to:
  /// **'Thread'**
  String get thread;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @topic.
  ///
  /// In en, this message translates to:
  /// **'Topic'**
  String get topic;

  /// No description provided for @trending.
  ///
  /// In en, this message translates to:
  /// **'Trending'**
  String get trending;

  /// No description provided for @typeTwoCharactersToSearch.
  ///
  /// In en, this message translates to:
  /// **'Type at least two characters to search the user directory.'**
  String get typeTwoCharactersToSearch;

  /// No description provided for @unban.
  ///
  /// In en, this message translates to:
  /// **'Unban'**
  String get unban;

  /// No description provided for @unblock.
  ///
  /// In en, this message translates to:
  /// **'Unblock'**
  String get unblock;

  /// No description provided for @unknownChannel.
  ///
  /// In en, this message translates to:
  /// **'Unknown channel'**
  String get unknownChannel;

  /// No description provided for @unknownCommand.
  ///
  /// In en, this message translates to:
  /// **'Unknown command /{command} — start with // to send it as text.'**
  String unknownCommand(String command);

  /// No description provided for @unknownUser.
  ///
  /// In en, this message translates to:
  /// **'Unknown user'**
  String get unknownUser;

  /// No description provided for @unlock.
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get unlock;

  /// No description provided for @unpin.
  ///
  /// In en, this message translates to:
  /// **'Unpin'**
  String get unpin;

  /// No description provided for @unverified.
  ///
  /// In en, this message translates to:
  /// **'unverified'**
  String get unverified;

  /// No description provided for @upgrade.
  ///
  /// In en, this message translates to:
  /// **'Upgrade'**
  String get upgrade;

  /// No description provided for @upgradeRoom.
  ///
  /// In en, this message translates to:
  /// **'Upgrade room'**
  String get upgradeRoom;

  /// No description provided for @upgradeRoomExplanation.
  ///
  /// In en, this message translates to:
  /// **'This creates a new room on version {newVersion} and closes this one (version {currentVersion}) with a pointer to the replacement. Members need to rejoin the new room.'**
  String upgradeRoomExplanation(String newVersion, String currentVersion);

  /// No description provided for @upgradeRoomTitle.
  ///
  /// In en, this message translates to:
  /// **'Upgrade room?'**
  String get upgradeRoomTitle;

  /// No description provided for @userIdLabel.
  ///
  /// In en, this message translates to:
  /// **'User ID (@user:server)'**
  String get userIdLabel;

  /// No description provided for @username.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get username;

  /// No description provided for @verificationFailed.
  ///
  /// In en, this message translates to:
  /// **'Verification failed or was cancelled.\n{reason}'**
  String verificationFailed(String reason);

  /// No description provided for @verificationSuccessful.
  ///
  /// In en, this message translates to:
  /// **'Verification successful! The device is now trusted.'**
  String get verificationSuccessful;

  /// No description provided for @verified.
  ///
  /// In en, this message translates to:
  /// **'verified'**
  String get verified;

  /// No description provided for @verify.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get verify;

  /// No description provided for @verifyDevice.
  ///
  /// In en, this message translates to:
  /// **'Verify device'**
  String get verifyDevice;

  /// No description provided for @verifySession.
  ///
  /// In en, this message translates to:
  /// **'Verify session'**
  String get verifySession;

  /// No description provided for @versionDefault.
  ///
  /// In en, this message translates to:
  /// **'{version} (default)'**
  String versionDefault(String version);

  /// No description provided for @voiceMessage.
  ///
  /// In en, this message translates to:
  /// **'Voice message'**
  String get voiceMessage;

  /// No description provided for @voteCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} vote} other{{count} votes}}'**
  String voteCount(int count);

  /// No description provided for @waitingForOtherDeviceToAccept.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the other device to accept…\n\nMake sure the other device is online and the request was accepted there.'**
  String get waitingForOtherDeviceToAccept;

  /// No description provided for @waitingForOtherDeviceToConfirm.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the other device to confirm…'**
  String get waitingForOtherDeviceToConfirm;

  /// No description provided for @wantsToVerifyDevice.
  ///
  /// In en, this message translates to:
  /// **'{user} wants to verify a device.'**
  String wantsToVerifyDevice(String user);

  /// No description provided for @wantsToVerifyDeviceWithId.
  ///
  /// In en, this message translates to:
  /// **'{user} wants to verify a device ({deviceId}).'**
  String wantsToVerifyDeviceWithId(String user, String deviceId);

  /// No description provided for @whatsHappening.
  ///
  /// In en, this message translates to:
  /// **'What\'s happening?'**
  String get whatsHappening;

  /// No description provided for @whoCanJoin.
  ///
  /// In en, this message translates to:
  /// **'Who can join'**
  String get whoCanJoin;

  /// No description provided for @withdrawKnock.
  ///
  /// In en, this message translates to:
  /// **'Withdraw knock'**
  String get withdrawKnock;

  /// No description provided for @workspace.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get workspace;

  /// No description provided for @yesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get yesterday;

  /// No description provided for @yesVerify.
  ///
  /// In en, this message translates to:
  /// **'Yes, verify'**
  String get yesVerify;

  /// No description provided for @youHaveBeenInvited.
  ///
  /// In en, this message translates to:
  /// **'You have been invited to this room.'**
  String get youHaveBeenInvited;

  /// No description provided for @youWillNoLongerSee.
  ///
  /// In en, this message translates to:
  /// **'You will no longer see {roomName}.'**
  String youWillNoLongerSee(String roomName);

  /// No description provided for @zoomIn.
  ///
  /// In en, this message translates to:
  /// **'Zoom in'**
  String get zoomIn;

  /// No description provided for @zoomOut.
  ///
  /// In en, this message translates to:
  /// **'Zoom out'**
  String get zoomOut;

  /// No description provided for @setNickname.
  ///
  /// In en, this message translates to:
  /// **'Set nickname'**
  String get setNickname;

  /// No description provided for @nicknameHint.
  ///
  /// In en, this message translates to:
  /// **'Only you can see this. Leave empty to remove it.'**
  String get nicknameHint;

  /// No description provided for @roomNameResetHint.
  ///
  /// In en, this message translates to:
  /// **'Leave empty to reset to the default name'**
  String get roomNameResetHint;

  /// No description provided for @reactions.
  ///
  /// In en, this message translates to:
  /// **'Reactions'**
  String get reactions;

  /// No description provided for @viewReactions.
  ///
  /// In en, this message translates to:
  /// **'View reactions'**
  String get viewReactions;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['de', 'en', 'es', 'fr', 'it'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fr':
      return AppLocalizationsFr();
    case 'it':
      return AppLocalizationsIt();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
