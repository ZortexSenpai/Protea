// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get accentColor => 'Couleur d’accent';

  @override
  String get accentColorDescription =>
      'Appliquez votre propre couleur sur ce thème, ou gardez la sienne.';

  @override
  String get appBackground => 'Fond de l’application';

  @override
  String get appBackgroundDescription =>
      'Une couleur derrière toute l’application : la page sous les panneaux et la lueur dans les coins de la disposition Liquid.';

  @override
  String get backgroundGlow => 'Coins colorés';

  @override
  String get backgroundGlowDescription =>
      'Colore le fond de la disposition Liquid en haut à gauche et en bas à droite. Désactivé, le fond est uni.';

  @override
  String get blur => 'Flou';

  @override
  String get chatWallpaper => 'Fond de conversation';

  @override
  String get chatWallpaperDescription =>
      'Une image derrière les messages. Opacité et flou réglables pour garder le texte lisible.';

  @override
  String get chooseImage => 'Choisir une image';

  @override
  String get clearSearch => 'Effacer la recherche';

  @override
  String get closeToTrayDescription =>
      'Fermer la fenêtre laisse Protea actif dans la zone de notification.';

  @override
  String get closeToTrayTitle => 'Fermer vers la zone de notification';

  @override
  String get accept => 'Accepter';

  @override
  String get access => 'Accès';

  @override
  String get accessToken => 'Jeton d\'accès';

  @override
  String get accessTokenWarning =>
      'Ne partagez jamais votre jeton d\'accès. Il donne un contrôle total sur votre compte.';

  @override
  String get account => 'Compte';

  @override
  String get accounts => 'Comptes';

  @override
  String get activitiesAndObjects => 'Activités et objets';

  @override
  String get addACaption => 'Ajouter une légende…';

  @override
  String get addAccount => 'Ajouter un compte';

  @override
  String get addOption => 'Ajouter une option';

  @override
  String get addReaction => 'Ajouter une réaction';

  @override
  String get addSticker => 'Ajouter un sticker';

  @override
  String get addToFavorites => 'Ajouter aux favoris';

  @override
  String get admin => 'Administrateur';

  @override
  String get all => 'Tout';

  @override
  String get animalsAndNature => 'Animaux et nature';

  @override
  String get anyone => 'Tout le monde';

  @override
  String get appLayout => 'Disposition de l\'application';

  @override
  String get appLayoutDescription =>
      'Espace de travail affiche une barre d\'espaces avec une liste de canaux par espace, Scindé associe la liste des salons au chat, Liste ouvre les chats dans leur propre page.';

  @override
  String get appTitle => 'Protea';

  @override
  String get appearance => 'Apparence';

  @override
  String areTyping(String name1, String name2) {
    return '$name1 et $name2 écrivent…';
  }

  @override
  String get arrowUpToEditDescription =>
      'Appuyer sur la flèche haut dans le champ de message vide modifie votre dernier message.';

  @override
  String get arrowUpToEditTitle =>
      'Modifier le dernier message avec la flèche haut';

  @override
  String get attachFile => 'Joindre un fichier';

  @override
  String get attachments => 'Pièces jointes';

  @override
  String get autoAway => 'Absence automatique';

  @override
  String get autoAwayDescription =>
      'Passe le statut en absent après 10 minutes sans activité du clavier ou de la souris.';

  @override
  String get away => 'Absent';

  @override
  String get ban => 'Bannir';

  @override
  String banUserTitle(String name) {
    return 'Bannir $name ?';
  }

  @override
  String get bannedUsers => 'Utilisateurs bannis';

  @override
  String get block => 'Bloquer';

  @override
  String get bubbles => 'Bulles';

  @override
  String get cancel => 'Annuler';

  @override
  String get categoryName => 'Nom de la catégorie';

  @override
  String get changeBanner => 'Changer la bannière';

  @override
  String get changeImage => 'Changer l\'image';

  @override
  String get changeProfilePicture => 'Changer la photo de profil';

  @override
  String get changeSettings => 'Modifier les paramètres';

  @override
  String get changeSpaceImage => 'Changer l\'image de l\'espace';

  @override
  String get channelSettings => 'Paramètres du canal';

  @override
  String get channels => 'Canaux';

  @override
  String get chatBackup => 'Sauvegarde des discussions';

  @override
  String get chatBackupEnabled => 'Sauvegarde des discussions activée';

  @override
  String get chatBackupEnabledDescription =>
      'La signature croisée et la sauvegarde des clés sont actives sur cet appareil.';

  @override
  String get chatBackupLocked =>
      'La sauvegarde des discussions est verrouillée';

  @override
  String get chatBackupLockedDescription =>
      'Déverrouillez-la avec votre clé de récupération pour lire les anciens messages chiffrés sur cet appareil.';

  @override
  String get chatBackupNotSetUp =>
      'La sauvegarde des discussions n\'est pas configurée';

  @override
  String get chatBackupNotSetUpDescription =>
      'Configurez la signature croisée et la sauvegarde des clés pour que les messages chiffrés survivent sur les nouveaux appareils.';

  @override
  String get chatBackupSetUp =>
      'La sauvegarde des discussions est configurée !';

  @override
  String get checking => 'Vérification…';

  @override
  String get clickToSave => 'Cliquer pour enregistrer';

  @override
  String get close => 'Fermer';

  @override
  String get closeThread => 'Fermer le fil';

  @override
  String get cmdBan => 'Bannir un utilisateur de ce salon';

  @override
  String get cmdDiscardSession =>
      'Abandonner la session de chiffrement sortante';

  @override
  String get cmdDm => 'Ouvrir une discussion directe';

  @override
  String get cmdHelp => 'Lister les commandes disponibles';

  @override
  String get cmdHtml => 'Envoyer du HTML brut';

  @override
  String get cmdIgnore => 'Ignorer un utilisateur';

  @override
  String get cmdInvite => 'Inviter un utilisateur dans ce salon';

  @override
  String get cmdJoin => 'Rejoindre un salon';

  @override
  String get cmdKick => 'Expulser un utilisateur de ce salon';

  @override
  String get cmdLeave => 'Quitter ce salon';

  @override
  String get cmdLenny => 'Ajouter ( ͡° ͜ʖ ͡°)';

  @override
  String get cmdMe => 'Envoyer une action (emote)';

  @override
  String get cmdMyRoomNick => 'Changer votre nom dans ce salon uniquement';

  @override
  String get cmdNick => 'Changer votre nom d\'affichage';

  @override
  String get cmdOp => 'Définir le rang d\'un utilisateur';

  @override
  String get cmdPlain => 'Envoyer sans mise en forme markdown';

  @override
  String get cmdReact => 'Réagir au message auquel vous répondez';

  @override
  String get cmdRoomUpgrade => 'Mettre à niveau ce salon';

  @override
  String get cmdShrug => 'Ajouter ¯\\_(ツ)_/¯';

  @override
  String get cmdSpoiler => 'Masquer le message derrière un spoiler';

  @override
  String get cmdTableflip => 'Ajouter (╯°□°)╯︵ ┻━┻';

  @override
  String get cmdTopic => 'Définir le sujet du salon';

  @override
  String get cmdUnban => 'Révoquer le bannissement d\'un utilisateur';

  @override
  String get cmdUnflip => 'Ajouter ┬─┬ ノ( ゜-゜ノ)';

  @override
  String get cmdUnignore => 'Ne plus ignorer un utilisateur';

  @override
  String get color => 'Couleur';

  @override
  String get colorAccent => 'Accent';

  @override
  String get colorBackground => 'Fond';

  @override
  String get colorMutedText => 'Texte atténué';

  @override
  String get colorOutline => 'Contour';

  @override
  String get colorPanels => 'Panneaux';

  @override
  String get colorText => 'Texte';

  @override
  String get commands => 'Commandes';

  @override
  String get compact => 'Compact';

  @override
  String get compareAndConfirmMatch =>
      'Comparez avec l\'autre appareil. Ne confirmez que s\'ils correspondent exactement, dans le même ordre.';

  @override
  String get compareEmojis => 'Comparer les émojis';

  @override
  String get compareEmojisToVerify =>
      'Comparez une courte liste d\'émojis avec l\'autre appareil pour le vérifier.';

  @override
  String get copiedToClipboard => 'Copié dans le presse-papiers';

  @override
  String get copy => 'Copier';

  @override
  String get copyRoomId => 'Copier l\'ID du salon';

  @override
  String get copyText => 'Copier le texte';

  @override
  String get copyImage => 'Copier l\'image';

  @override
  String get findOrStartConversation => 'Trouver ou démarrer une conversation';

  @override
  String get imageCopied => 'Image copiée';

  @override
  String get noSearchResults => 'Aucun résultat.';

  @override
  String get quickSwitcherHint => 'Où veux-tu aller ?';

  @override
  String get quickSwitcherTip =>
      'Astuce : commence par @ pour chercher des personnes ou # pour des salons. ↑↓ pour naviguer, Entrée pour ouvrir.';

  @override
  String get retrySend => 'Réessayer';

  @override
  String get messageNotSent => 'Non envoyé';

  @override
  String get spreadsheetEmpty => 'Cette feuille est vide.';

  @override
  String spreadsheetTruncated(int rows, int columns) {
    return 'Feuille volumineuse : seules les $rows premières lignes et $columns premières colonnes sont affichées.';
  }

  @override
  String get spreadsheetUnreadable => 'Impossible de lire ce tableur.';

  @override
  String uploadFailed(String filename) {
    return 'Échec de l’envoi : $filename';
  }

  @override
  String get fileNoLongerCached =>
      'Le fichier n\'est plus disponible pour le renvoi. Supprimez le message et renvoyez-le.';

  @override
  String get downloadImage => 'Télécharger';

  @override
  String get copyThemeCode => 'Copier le code du thème';

  @override
  String get couldNotUnlock =>
      'Déverrouillage impossible. Vérifiez la clé de récupération.';

  @override
  String get couldNotUnlockBackup =>
      'Impossible de déverrouiller la sauvegarde. Vérifiez la clé de récupération.';

  @override
  String get cozy => 'Par défaut';

  @override
  String get create => 'Créer';

  @override
  String get createPoll => 'Créer un sondage';

  @override
  String get crossSignedPendingVerification =>
      'signature croisée · fiable une fois cette session vérifiée';

  @override
  String currentRoomVersion(String version) {
    return 'Actuellement en version de salon $version';
  }

  @override
  String get customThemeColors => 'Couleurs personnalisées';

  @override
  String get customThemeColorsDescription =>
      'Six couleurs composent tout le thème : les nuances de surface intermédiaires sont déduites du fond et de la couleur des panneaux.';

  @override
  String get dark => 'Sombre';

  @override
  String get decline => 'Refuser';

  @override
  String get delete => 'Supprimer';

  @override
  String get deleteMessageTitle => 'Supprimer le message ?';

  @override
  String get deleteMessageWarning =>
      'Le message sera supprimé pour tout le monde.';

  @override
  String get desktopNotificationsDescription =>
      'Affiche des notifications système pour les nouveaux messages lorsque la fenêtre est en arrière-plan.';

  @override
  String get desktopNotificationsTitle => 'Notifications de bureau';

  @override
  String get direct => 'Direct';

  @override
  String get directMessages => 'Messages directs';

  @override
  String get discardRecording => 'Abandonner l\'enregistrement';

  @override
  String get displayName => 'Nom d\'affichage';

  @override
  String get done => 'Terminé';

  @override
  String get doubleSlashHint =>
      'Commencez un message par // pour envoyer un texte débutant par une barre oblique.';

  @override
  String get dropFilesToUpload => 'Déposez des fichiers pour les téléverser';

  @override
  String get edit => 'Modifier';

  @override
  String get editDisplayName => 'Modifier le nom d\'affichage';

  @override
  String get editTopic => 'Modifier le sujet';

  @override
  String get edited => '(modifié)';

  @override
  String get editingMessage => 'Modification du message';

  @override
  String get emoji => 'Émoji';

  @override
  String get enableEncryptionTitle => 'Activer le chiffrement de bout en bout';

  @override
  String get enableEncryptionWarning =>
      'Le chiffrement ne pourra plus être désactivé. Les messages ne seront lisibles que sur les appareils vérifiés.';

  @override
  String get emotes => 'Émotes';

  @override
  String get encryptedNotSearchable =>
      'Les salons chiffrés ne sont pas inclus — le serveur ne peut pas rechercher dans les messages chiffrés.';

  @override
  String get encryptNewDmsDescription =>
      'Active le chiffrement de bout en bout lors du démarrage d\'une nouvelle discussion directe.';

  @override
  String get encryptNewDmsTitle =>
      'Chiffrer les nouvelles discussions directes';

  @override
  String get encryptionNotAvailable =>
      'Le chiffrement de bout en bout n\'est pas disponible';

  @override
  String get encryptionNotAvailableDescription =>
      'La bibliothèque cryptographique n\'a pas pu être initialisée sur cette plateforme.';

  @override
  String get endPoll => 'Clore le sondage';

  @override
  String get endToEndEncrypted => 'Chiffré de bout en bout';

  @override
  String get endToEndEncryptionNotAvailable =>
      'Le chiffrement de bout en bout n\'est pas disponible.';

  @override
  String get enterRecoveryKeyToUnlockBackup =>
      'Saisissez votre clé de récupération pour déverrouiller la sauvegarde des discussions et vérifier cette session. Vous avez reçu la clé lors de la configuration de la sauvegarde (elle ressemble à : EsT* ****…).';

  @override
  String get enterRecoveryKeyToVerify =>
      'Saisissez votre clé de récupération pour vous vérifier via votre sauvegarde sécurisée, ou passez cette étape et comparez plutôt des émojis avec l\'autre appareil.';

  @override
  String get expert => 'Expert';

  @override
  String get explorePublicRooms => 'Explorer les salons publics';

  @override
  String get exploreRooms => 'Explorer les salons';

  @override
  String get fadeAmount => 'Fondu';

  @override
  String get favorites => 'Favoris';

  @override
  String get filterRoomsHint => 'Filtrer les salons…';

  @override
  String finalResults(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Résultats finaux · $count votes',
      one: 'Résultats finaux · $count vote',
    );
    return '$_temp0';
  }

  @override
  String get floating => 'Flottant';

  @override
  String get focus => 'Focus';

  @override
  String get fontSize => 'Taille du texte';

  @override
  String get foodAndDrink => 'Nourriture et boissons';

  @override
  String get formatBold => 'Gras';

  @override
  String get formatCodeBlock => 'Bloc de code';

  @override
  String get formatInlineCode => 'Code en ligne';

  @override
  String get formatItalic => 'Italique';

  @override
  String get formatLink => 'Lien';

  @override
  String get formatSpoiler => 'Spoiler';

  @override
  String get formatStrikethrough => 'Barré';

  @override
  String get formatting => 'Mise en forme du texte';

  @override
  String get forward => 'Transférer';

  @override
  String get forwardTo => 'Transférer à…';

  @override
  String forwardedTo(String name) {
    return 'Transféré à $name';
  }

  @override
  String get gestures => 'Gestes';

  @override
  String get gif => 'GIF';

  @override
  String get gifSearchKlipy => 'Recherche de GIF (Klipy)';

  @override
  String get gifSearchNeedsKlipyKey =>
      'La recherche de GIF nécessite une clé API Klipy gratuite.\nObtenez-en une sur klipy.com et ajoutez-la dans les paramètres.';

  @override
  String get gifs => 'GIFs';

  @override
  String get gifProxyTitle => 'Envoyer les GIF via un proxy';

  @override
  String get gifProxyDescription =>
      'Envoie un lien vers le GIF au lieu d’en téléverser une copie sur votre serveur. Plus rapide, et le fichier reste hors de votre serveur — le proxy et les serveurs de chacun voient la requête.';

  @override
  String get gifProxyServer => 'Serveur proxy GIF';

  @override
  String get goToPage => 'Aller à la page';

  @override
  String get group => 'Groupe';

  @override
  String get groupName => 'Nom du groupe';

  @override
  String get guestAccess => 'Accès invités';

  @override
  String get heartsAndSymbols => 'Cœurs et symboles';

  @override
  String get hexColor => 'Hex';

  @override
  String get hide => 'Masquer';

  @override
  String get home => 'Accueil';

  @override
  String get homeserver => 'Serveur d\'accueil';

  @override
  String get hue => 'Teinte';

  @override
  String get huge => 'Très grand';

  @override
  String get iSavedMyRecoveryKey => 'J\'ai enregistré ma clé de récupération';

  @override
  String get images => 'Images';

  @override
  String get integrations => 'Intégrations';

  @override
  String get invisible => 'Invisible';

  @override
  String get invitation => 'Invitation';

  @override
  String get invitationTapToRespond => 'Invitation — appuyez pour répondre';

  @override
  String get invite => 'Inviter';

  @override
  String get inviteToRoom => 'Inviter dans le salon';

  @override
  String get inviteToSpace => 'Inviter dans l\'espace';

  @override
  String inviteUser(String userId) {
    return 'Inviter $userId';
  }

  @override
  String invitedBy(String name) {
    return 'Invitation de $name';
  }

  @override
  String invitedUser(String userId) {
    return '$userId invité';
  }

  @override
  String isTyping(String name) {
    return '$name écrit…';
  }

  @override
  String get join => 'Rejoindre';

  @override
  String get joined => 'Rejoint';

  @override
  String get jumpToLatestMessages => 'Aller aux derniers messages';

  @override
  String get jumpToRoomHint => 'Aller au salon…';

  @override
  String get kick => 'Expulser';

  @override
  String kickUserTitle(String name) {
    return 'Expulser $name ?';
  }

  @override
  String get klipyApiKey => 'Clé API Klipy';

  @override
  String get klipyApiKeyDescription =>
      'Le sélecteur de GIF utilise l\'API Klipy. Obtenez une clé API gratuite sur klipy.com et collez-la ici.';

  @override
  String get knock => 'Frapper';

  @override
  String get knockPending => 'Demande d\'entrée en attente';

  @override
  String get knockPendingWaiting =>
      'Demande d\'entrée en attente — un modérateur du salon doit vous laisser entrer.';

  @override
  String get knocked => 'Demande envoyée';

  @override
  String get knockedWaitingForApproval =>
      'Demande envoyée — en attente d\'approbation.';

  @override
  String get language => 'Langue';

  @override
  String get large => 'Grand';

  @override
  String lastSeenDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Vu pour la dernière fois il y a $count jours',
      one: 'Vu pour la dernière fois il y a $count jour',
    );
    return '$_temp0';
  }

  @override
  String lastSeenHoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Vu pour la dernière fois il y a $count heures',
      one: 'Vu pour la dernière fois il y a $count heure',
    );
    return '$_temp0';
  }

  @override
  String get lastSeenJustNow => 'Vu à l\'instant';

  @override
  String lastSeenMinutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Vu pour la dernière fois il y a $count minutes',
      one: 'Vu pour la dernière fois il y a $count minute',
    );
    return '$_temp0';
  }

  @override
  String get layout => 'Disposition';

  @override
  String get leave => 'Quitter';

  @override
  String get leaveRoom => 'Quitter le salon ?';

  @override
  String get leaveRoomAction => 'Quitter le salon';

  @override
  String get leaveRoomTitle => 'Quitter le salon ?';

  @override
  String get leaveSpace => 'Quitter l\'espace';

  @override
  String get leaveSpaceTitle => 'Quitter l\'espace ?';

  @override
  String get left => 'Gauche';

  @override
  String get light => 'Clair';

  @override
  String get lightness => 'Luminosité';

  @override
  String get liquid => 'Liquid';

  @override
  String get loading => 'Chargement…';

  @override
  String get loadingDevices => 'Chargement des appareils…';

  @override
  String get location => 'Position';

  @override
  String get locationInputHelp =>
      'Collez \"lat, lon\", un URI geo: ou un lien OpenStreetMap / Google Maps.';

  @override
  String get locationInputHint => 'Coordonnées ou lien de carte';

  @override
  String get makeAdmin => 'Promouvoir administrateur';

  @override
  String get makeAdminWarning =>
      'Les administrateurs ont les mêmes pouvoirs que vous — vous ne pourrez peut-être plus les rétrograder ensuite.';

  @override
  String get makeModerator => 'Promouvoir modérateur';

  @override
  String makeUserAdminTitle(String name) {
    return 'Promouvoir $name administrateur ?';
  }

  @override
  String get managePacks => 'Gérer les packs';

  @override
  String manyTyping(int count) {
    return '$count personnes écrivent…';
  }

  @override
  String get markUnread => 'Marquer comme non lu';

  @override
  String get member => 'Membre';

  @override
  String get members => 'Membres';

  @override
  String membersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count membres',
      one: '1 membre',
    );
    return '$_temp0';
  }

  @override
  String membersWithCount(int count) {
    return 'Membres — $count';
  }

  @override
  String get mentions => 'Mentions';

  @override
  String get message => 'Message';

  @override
  String get messageHistory => 'Historique des messages';

  @override
  String get messageLayout => 'Disposition des messages';

  @override
  String get messageLayoutDescription =>
      'Comment les messages sont affichés dans les discussions.';

  @override
  String get microphonePermissionDenied =>
      'Autorisation du microphone refusée.';

  @override
  String get moderator => 'Modérateur';

  @override
  String get more => 'Plus';

  @override
  String get moreAttachments => 'Autres pièces jointes';

  @override
  String get moreResults => 'Plus de résultats';

  @override
  String get muted => 'En sourdine';

  @override
  String get myStickers => 'Mes stickers';

  @override
  String get name => 'Nom';

  @override
  String get newCategory => 'Nouvelle catégorie';

  @override
  String get newChat => 'Nouvelle discussion';

  @override
  String get newGroup => 'Nouveau groupe';

  @override
  String get newMessages => 'Nouveaux messages';

  @override
  String get newRoomVersion => 'Nouvelle version du salon';

  @override
  String get newSpace => 'Nouvel espace';

  @override
  String get nextPage => 'Page suivante';

  @override
  String get noDevicesWithEncryptionKeys =>
      'Aucun appareil avec des clés de chiffrement trouvé';

  @override
  String get noFavoriteGifsHint =>
      'Aucun GIF favori pour le moment. Survolez un GIF et cliquez sur l\'étoile pour le garder ici.';

  @override
  String get noGifsFound => 'Aucun GIF trouvé.';

  @override
  String get noMatchingMembers => 'Aucun membre correspondant.';

  @override
  String get noMatchingRooms => 'Aucun salon correspondant.';

  @override
  String get noMessagesFound => 'Aucun message trouvé.';

  @override
  String get noMessagesYet => 'Pas encore de messages. Dites bonjour !';

  @override
  String get noMessagesYetShort => 'Pas encore de messages';

  @override
  String get noPinnedMessages => 'Aucun message épinglé dans ce salon.';

  @override
  String get noPublicRoomsFound => 'Aucun salon public trouvé.';

  @override
  String get noRepliesYet => 'Pas encore de réponses.';

  @override
  String get noRoomsHereYet => 'Pas encore de salons ici.';

  @override
  String get noRoomsYet =>
      'Pas encore de salons.\nRejoignez un salon depuis un autre client pour commencer.';

  @override
  String get noStickerPacksHint =>
      'Pas encore de packs de stickers.\nUtilisez « Gérer les packs » pour ajouter vos propres stickers, ou rejoignez des salons qui partagent des packs.';

  @override
  String get noTopicSet => 'Aucun sujet défini';

  @override
  String get normal => 'Normal';

  @override
  String get notEncrypted => 'Non chiffré';

  @override
  String get notJoined => 'Non rejoints';

  @override
  String get notificationSounds => 'Sons de notification';

  @override
  String get notificationSoundsDescription =>
      'Jouer le son système avec les notifications de bureau.';

  @override
  String get notifications => 'Notifications';

  @override
  String get offline => 'Hors ligne';

  @override
  String ofPages(int total) {
    return 'sur $total';
  }

  @override
  String get ok => 'OK';

  @override
  String get online => 'En ligne';

  @override
  String get opacity => 'Opacité';

  @override
  String get openMap => 'Ouvrir la carte';

  @override
  String get openPreview => 'Ouvrir l\'aperçu';

  @override
  String get openSettings => 'Ouvrir les paramètres';

  @override
  String optionNumber(int number) {
    return 'Option $number';
  }

  @override
  String get or => 'ou';

  @override
  String get otherDeviceShowsShield =>
      'L\'autre appareil affiche-t-il un bouclier vert ?';

  @override
  String get owner => 'Propriétaire';

  @override
  String get packEmpty => 'Ce pack est vide.';

  @override
  String get password => 'Mot de passe';

  @override
  String get pasteThemeCode => 'Coller un code de thème';

  @override
  String get pauseGifsDescription =>
      'Arrête les animations GIF lorsque la fenêtre est en arrière-plan.';

  @override
  String get pauseGifsTitle => 'Suspendre les GIF en arrière-plan';

  @override
  String get permissions => 'Permissions';

  @override
  String get pin => 'Épingler';

  @override
  String get pinned => 'Épinglé';

  @override
  String get pinnedMessages => 'Messages épinglés';

  @override
  String get playVideo => 'Lire la vidéo';

  @override
  String get pleaseFillInAllFields => 'Veuillez remplir tous les champs.';

  @override
  String get poll => 'Sondage';

  @override
  String get pollNeedsQuestionAndOptions =>
      'Un sondage nécessite une question et au moins deux options.';

  @override
  String presenceWithStatus(String presence, String status) {
    return '$presence — $status';
  }

  @override
  String get previousPage => 'Page précédente';

  @override
  String get privacy => 'Confidentialité';

  @override
  String get public => 'Public';

  @override
  String get publicSpace => 'Espace public';

  @override
  String get publishToDirectory => 'Publier dans l\'annuaire des salons';

  @override
  String get question => 'Question';

  @override
  String get quit => 'Quitter';

  @override
  String reactWith(String emoji) {
    return 'Réagir avec $emoji';
  }

  @override
  String readBy(String names) {
    return 'Lu par $names';
  }

  @override
  String get recoveryKey => 'Clé de récupération';

  @override
  String get refresh => 'Actualiser';

  @override
  String get reject => 'Refuser';

  @override
  String get removeBanner => 'Supprimer la bannière';

  @override
  String get removeFromFavorites => 'Retirer des favoris';

  @override
  String get removeImage => 'Retirer';

  @override
  String get removeMessages => 'Supprimer des messages';

  @override
  String get removeOption => 'Retirer l\'option';

  @override
  String get rename => 'Renommer';

  @override
  String repliesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count réponses',
      one: '1 réponse',
    );
    return '$_temp0';
  }

  @override
  String get reply => 'Répondre';

  @override
  String get replyInThread => 'Répondre dans le fil';

  @override
  String get requests => 'Demandes';

  @override
  String get reset => 'Réinitialiser';

  @override
  String get resetBackup => 'Réinitialiser la sauvegarde';

  @override
  String get resetChatBackup => 'Réinitialiser la sauvegarde des discussions ?';

  @override
  String get resetChatBackupWarning =>
      'Ceci abandonne les clés de signature croisée et la sauvegarde des clés existantes et en crée de nouvelles. Les appareils vérifiés auparavant devront l\'être à nouveau, et l\'historique chiffré avec des clés perdues restera illisible.';

  @override
  String get resetToMember => 'Rétrograder membre';

  @override
  String get resetToTheme => 'Repartir du thème Material';

  @override
  String get resetZoom => 'Réinitialiser le zoom';

  @override
  String get right => 'Droite';

  @override
  String get roomAddress => 'Adresse du salon';

  @override
  String get roomEncryptedNoE2eeSupport =>
      'Ce salon est chiffré de bout en bout. Cette version de Protea a été compilée sans prise en charge E2EE, il est donc impossible d\'y lire ou d\'y envoyer des messages.';

  @override
  String get roomIdOrAliasLabel => 'ID ou alias du salon (#salon:serveur)';

  @override
  String get roomUpgradedNotice =>
      'Salon mis à niveau — le remplaçant apparaît sous peu.';

  @override
  String get rooms => 'Salons';

  @override
  String get saturation => 'Saturation';

  @override
  String get save => 'Enregistrer';

  @override
  String get saveFile => 'Enregistrer le fichier';

  @override
  String get saveRecoveryKeySomewhereSafe =>
      'Conservez cette clé de récupération en lieu sûr (p. ex. un gestionnaire de mots de passe). Vous en aurez besoin pour lire votre historique de messages chiffrés sur de nouveaux appareils :';

  @override
  String saveWithSize(String size) {
    return '$size · enregistrer';
  }

  @override
  String savedFile(String name) {
    return '$name enregistré';
  }

  @override
  String get scanQrToVerify =>
      'Scannez ce code QR avec l\'autre appareil, ou comparez plutôt des émojis.';

  @override
  String get searchAllRooms => 'Rechercher dans tous les salons';

  @override
  String get searchAllRoomsPrompt =>
      'Recherchez dans l\'historique de vos messages de tous les salons.';

  @override
  String get searchFurtherBack => 'Chercher plus loin en arrière';

  @override
  String get searchGifs => 'Rechercher des GIF…';

  @override
  String get searchEmoji => 'Rechercher un emoji…';

  @override
  String get defaultRole => 'Rôle par défaut';

  @override
  String get notifyEveryone => 'Notifier tout le monde (@room)';

  @override
  String get changePermissions => 'Modifier les permissions';

  @override
  String get changeHistoryVisibility =>
      'Modifier la visibilité de l\'historique';

  @override
  String get roles => 'Rôles';

  @override
  String get assignRole => 'Attribuer un rôle';

  @override
  String get noEmojiFound => 'Aucun emoji trouvé';

  @override
  String get overview => 'Aperçu';

  @override
  String get changeAccess => 'Modifier les paramètres d\'accès';

  @override
  String searchResultCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count résultats',
      one: '$count résultat',
    );
    return '$_temp0';
  }

  @override
  String get serverAcl => 'Modifier les ACL du serveur';

  @override
  String get manageSpaceRooms => 'Gérer les salons de cet espace';

  @override
  String get deleteOwnMessages => 'Supprimer ses propres messages';

  @override
  String get shareLocation => 'Partager la position';

  @override
  String get shareTheme => 'Partager le thème';

  @override
  String get showApp => 'Afficher Protea';

  @override
  String get startCalls => 'Démarrer des appels';

  @override
  String messageDeletedFrom(String name) {
    return 'Message de $name supprimé';
  }

  @override
  String get searchMembersHint => 'Rechercher des membres…';

  @override
  String get searchMessages => 'Rechercher des messages';

  @override
  String get searchMessagesHint => 'Rechercher des messages…';

  @override
  String get searchRoomHistoryPrompt =>
      'Recherchez dans l\'historique de ce salon.';

  @override
  String get searchRoomsHint => 'Rechercher des salons…';

  @override
  String get searchUserHint =>
      'Recherchez par nom ou saisissez @utilisateur:serveur';

  @override
  String searchedBackTo(String date) {
    return 'Recherche effectuée jusqu\'au $date';
  }

  @override
  String searchedBackToBeginning(String date) {
    return 'Recherche effectuée jusqu\'au $date (début)';
  }

  @override
  String get security => 'Sécurité';

  @override
  String get selectChannelToStartChatting =>
      'Sélectionnez un canal pour commencer à discuter.';

  @override
  String get selectChatToStartMessaging =>
      'Sélectionnez une discussion pour commencer.';

  @override
  String get send => 'Envoyer';

  @override
  String sendFilesTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Envoyer $count fichiers ?',
      one: 'Envoyer le fichier ?',
    );
    return '$_temp0';
  }

  @override
  String get sendMessages => 'Envoyer des messages';

  @override
  String get sendReadReceiptsDescription =>
      'Permet aux autres de voir quels messages vous avez lus.';

  @override
  String get sendReadReceiptsTitle => 'Envoyer les accusés de lecture';

  @override
  String get sendTypingNotificationsDescription =>
      'Permet aux autres de voir quand vous écrivez.';

  @override
  String get sendTypingNotificationsTitle =>
      'Envoyer les indicateurs de saisie';

  @override
  String get sendVoiceMessage => 'Envoyer un message vocal';

  @override
  String get sending => 'Envoi…';

  @override
  String get server => 'Serveur';

  @override
  String get sessionNotVerified => 'Cette session n\'est pas vérifiée';

  @override
  String get sessionNotVerifiedDescription =>
      'Vos autres appareils sont signés de manière croisée, mais cette session ne fait pas encore confiance à votre clé d\'identité, ils apparaissent donc tous comme non vérifiés. Vérifiez cette session depuis un autre de vos appareils pour corriger cela.';

  @override
  String get setStatus => 'Définir le statut';

  @override
  String get setUp => 'Configurer';

  @override
  String get settingUp => 'Configuration…';

  @override
  String get settingUpBackupFailed =>
      'La configuration de la sauvegarde a échoué.';

  @override
  String get settings => 'Paramètres';

  @override
  String get show => 'Afficher';

  @override
  String get showDeletedMessagesDescription =>
      'Conserve un espace réservé là où un message a été supprimé.';

  @override
  String get showDeletedMessagesTitle => 'Messages supprimés';

  @override
  String get showMembershipEventsDescription =>
      'Affiche quand des membres rejoignent, quittent ou sont invités.';

  @override
  String get showMembershipEventsTitle => 'Arrivées et départs';

  @override
  String get showProfileChangeEventsDescription =>
      'Affiche les changements de nom d\'affichage et de photo de profil.';

  @override
  String get showProfileChangeEventsTitle => 'Changements de profil';

  @override
  String get showReadReceiptsDescription =>
      'Affiche sous un message qui l\'a lu.';

  @override
  String get showReadReceiptsTitle => 'Afficher les accusés de lecture';

  @override
  String get showUrlPreviewsDescription =>
      'Affiche une carte d’aperçu sous les messages contenant des liens.';

  @override
  String get showUrlPreviewsTitle => 'Afficher les aperçus de liens';

  @override
  String get signIn => 'Se connecter';

  @override
  String get signInToYourMatrixAccount =>
      'Connectez-vous à votre compte Matrix';

  @override
  String signInWithProvider(String provider) {
    return 'Se connecter avec $provider';
  }

  @override
  String get signInWithSso => 'Se connecter avec SSO';

  @override
  String get signOut => 'Se déconnecter';

  @override
  String get signOutConfirmation =>
      'Voulez-vous vous déconnecter de votre compte ?';

  @override
  String get sinceInvited => 'Depuis l\'invitation';

  @override
  String get sinceJoined => 'Depuis l\'arrivée';

  @override
  String get skip => 'Passer';

  @override
  String get small => 'Petit';

  @override
  String get smileys => 'Smileys';

  @override
  String get smoothScrollingDescription =>
      'Fait glisser la molette de la souris en douceur au lieu de sauter par paliers.';

  @override
  String get smoothScrollingTitle => 'Défilement fluide';

  @override
  String get space => 'Espace';

  @override
  String get spaceHasNoRooms => 'Cet espace n\'a pas de salons.';

  @override
  String get spaceLobby => 'Hall de l\'espace';

  @override
  String get spaceMembers => 'Membres de l\'espace';

  @override
  String get spaceName => 'Nom de l\'espace';

  @override
  String get spaceSettings => 'Paramètres de l\'espace';

  @override
  String get spacesListPosition => 'Position de la barre d\'espaces';

  @override
  String get ssoLoginTimedOut =>
      'La connexion SSO a expiré. Veuillez réessayer.';

  @override
  String get startChat => 'Démarrer la discussion';

  @override
  String get status => 'Statut';

  @override
  String get statusMessage => 'Message de statut';

  @override
  String get statusUpdated => 'Statut mis à jour';

  @override
  String get sticker => 'Sticker';

  @override
  String get stickers => 'Stickers';

  @override
  String get switchAccount => 'Changer de compte';

  @override
  String get syncing => 'Synchronisation…';

  @override
  String get systemDefault => 'Système';

  @override
  String get systemMessages => 'Messages système';

  @override
  String get systemMessagesDescription =>
      'Choisissez quels événements du salon apparaissent dans le fil.';

  @override
  String get text => 'Texte';

  @override
  String get theme => 'Thème';

  @override
  String get themeCode => 'Code de thème';

  @override
  String get themeCodeApplied => 'Thème appliqué.';

  @override
  String get themeCodeCopied => 'Code du thème copié.';

  @override
  String get themeCodeInvalid => 'Ce n’est pas un code de thème Protea.';

  @override
  String get themeDefault => 'Couleur du thème';

  @override
  String get theyDontMatch => 'Ils ne correspondent pas';

  @override
  String get theyMatch => 'Ils correspondent';

  @override
  String get thisDevice => 'cet appareil';

  @override
  String get thread => 'Fil';

  @override
  String get today => 'Aujourd\'hui';

  @override
  String get topic => 'Sujet';

  @override
  String get trending => 'Tendances';

  @override
  String get typeTwoCharactersToSearch =>
      'Saisissez au moins deux caractères pour rechercher dans l\'annuaire des utilisateurs.';

  @override
  String get unban => 'Débannir';

  @override
  String get unblock => 'Débloquer';

  @override
  String get unknownChannel => 'Canal inconnu';

  @override
  String unknownCommand(String command) {
    return 'Commande inconnue /$command — commencez par // pour l\'envoyer comme texte.';
  }

  @override
  String get unknownUser => 'Utilisateur inconnu';

  @override
  String get unlock => 'Déverrouiller';

  @override
  String get unpin => 'Désépingler';

  @override
  String get unverified => 'non vérifié';

  @override
  String get upgrade => 'Mettre à niveau';

  @override
  String get upgradeRoom => 'Mettre à niveau le salon';

  @override
  String upgradeRoomExplanation(String newVersion, String currentVersion) {
    return 'Ceci crée un nouveau salon en version $newVersion et ferme celui-ci (version $currentVersion) avec un lien vers son remplaçant. Les membres devront rejoindre le nouveau salon.';
  }

  @override
  String get upgradeRoomTitle => 'Mettre à niveau le salon ?';

  @override
  String get userIdLabel => 'ID utilisateur (@utilisateur:serveur)';

  @override
  String get username => 'Nom d\'utilisateur';

  @override
  String verificationFailed(String reason) {
    return 'La vérification a échoué ou a été annulée.\n$reason';
  }

  @override
  String get verificationSuccessful =>
      'Vérification réussie ! L\'appareil est désormais fiable.';

  @override
  String get verified => 'vérifié';

  @override
  String get verify => 'Vérifier';

  @override
  String get verifyDevice => 'Vérifier l\'appareil';

  @override
  String get verifySession => 'Vérifier la session';

  @override
  String versionDefault(String version) {
    return '$version (par défaut)';
  }

  @override
  String get voiceMessage => 'Message vocal';

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
      'En attente de l\'acceptation par l\'autre appareil…\n\nAssurez-vous que l\'autre appareil est en ligne et que la demande y a été acceptée.';

  @override
  String get waitingForOtherDeviceToConfirm =>
      'En attente de la confirmation de l\'autre appareil…';

  @override
  String wantsToVerifyDevice(String user) {
    return '$user veut vérifier un appareil.';
  }

  @override
  String wantsToVerifyDeviceWithId(String user, String deviceId) {
    return '$user veut vérifier un appareil ($deviceId).';
  }

  @override
  String get whatsHappening => 'Quoi de neuf ?';

  @override
  String get whoCanJoin => 'Qui peut rejoindre';

  @override
  String get withdrawKnock => 'Retirer la demande';

  @override
  String get workspace => 'Par défaut';

  @override
  String get yesterday => 'Hier';

  @override
  String get yesVerify => 'Oui, vérifier';

  @override
  String get youHaveBeenInvited => 'Vous avez été invité dans ce salon.';

  @override
  String youWillNoLongerSee(String roomName) {
    return 'Vous ne verrez plus $roomName.';
  }

  @override
  String get zoomIn => 'Zoomer';

  @override
  String get zoomOut => 'Dézoomer';

  @override
  String get setNickname => 'Définir un surnom';

  @override
  String get nicknameHint =>
      'Visible uniquement par vous. Laissez vide pour le supprimer.';

  @override
  String get roomNameResetHint =>
      'Laissez vide pour rétablir le nom par défaut';

  @override
  String get reactions => 'Réactions';

  @override
  String get viewReactions => 'Voir les réactions';
}
