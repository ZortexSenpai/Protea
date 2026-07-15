// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Italian (`it`).
class AppLocalizationsIt extends AppLocalizations {
  AppLocalizationsIt([String locale = 'it']) : super(locale);

  @override
  String get accept => 'Accetta';

  @override
  String get account => 'Account';

  @override
  String get accounts => 'Account';

  @override
  String get activitiesAndObjects => 'Attività e oggetti';

  @override
  String get addAccount => 'Aggiungi account';

  @override
  String get addOption => 'Aggiungi opzione';

  @override
  String get addReaction => 'Aggiungi reazione';

  @override
  String get addSticker => 'Aggiungi sticker';

  @override
  String get admin => 'Amministratore';

  @override
  String get all => 'Tutti';

  @override
  String get animalsAndNature => 'Animali e natura';

  @override
  String get appLayout => 'Layout dell\'app';

  @override
  String get appLayoutDescription =>
      'Area di lavoro mostra una barra degli spazi con un elenco di canali per spazio, Diviso affianca l\'elenco delle stanze alla chat, Elenco apre le chat in una pagina dedicata.';

  @override
  String get appTitle => 'Protea';

  @override
  String get appearance => 'Aspetto';

  @override
  String areTyping(String name1, String name2) {
    return '$name1 e $name2 stanno scrivendo…';
  }

  @override
  String get attachFile => 'Allega file';

  @override
  String get autoAway => 'Assenza automatica';

  @override
  String get autoAwayDescription =>
      'Imposta lo stato su assente dopo 10 minuti senza input da tastiera o mouse.';

  @override
  String get away => 'Assente';

  @override
  String get ban => 'Bandisci';

  @override
  String banUserTitle(String name) {
    return 'Bandire $name?';
  }

  @override
  String get block => 'Blocca';

  @override
  String get bubbles => 'Fumetti';

  @override
  String get cancel => 'Annulla';

  @override
  String get changeBanner => 'Cambia banner';

  @override
  String get changeImage => 'Cambia immagine';

  @override
  String get changeProfilePicture => 'Cambia immagine del profilo';

  @override
  String get changeSpaceImage => 'Cambia immagine dello spazio';

  @override
  String get channelSettings => 'Impostazioni canale';

  @override
  String get channels => 'Canali';

  @override
  String get chatBackup => 'Backup delle chat';

  @override
  String get chatBackupEnabled => 'Backup delle chat attivo';

  @override
  String get chatBackupEnabledDescription =>
      'La firma incrociata e il backup delle chiavi sono attivi su questo dispositivo.';

  @override
  String get chatBackupLocked => 'Il backup delle chat è bloccato';

  @override
  String get chatBackupLockedDescription =>
      'Sbloccalo con la tua chiave di recupero per leggere i vecchi messaggi cifrati su questo dispositivo.';

  @override
  String get chatBackupNotSetUp => 'Il backup delle chat non è configurato';

  @override
  String get chatBackupNotSetUpDescription =>
      'Configura la firma incrociata e il backup delle chiavi perché i messaggi cifrati sopravvivano sui nuovi dispositivi.';

  @override
  String get chatBackupSetUp => 'Il backup delle chat è configurato!';

  @override
  String get checking => 'Verifica in corso…';

  @override
  String get clickToSave => 'Fai clic per salvare';

  @override
  String get close => 'Chiudi';

  @override
  String get closeThread => 'Chiudi thread';

  @override
  String get cmdBan => 'Bandisci un utente da questa stanza';

  @override
  String get cmdDiscardSession => 'Scarta la sessione di cifratura in uscita';

  @override
  String get cmdDm => 'Apri una chat diretta';

  @override
  String get cmdHelp => 'Elenca i comandi disponibili';

  @override
  String get cmdHtml => 'Invia HTML grezzo';

  @override
  String get cmdIgnore => 'Ignora un utente';

  @override
  String get cmdInvite => 'Invita un utente in questa stanza';

  @override
  String get cmdJoin => 'Entra in una stanza';

  @override
  String get cmdKick => 'Espelli un utente da questa stanza';

  @override
  String get cmdLeave => 'Esci da questa stanza';

  @override
  String get cmdLenny => 'Aggiungi ( ͡° ͜ʖ ͡°)';

  @override
  String get cmdMe => 'Invia un\'azione (emote)';

  @override
  String get cmdMyRoomNick => 'Cambia il tuo nome solo in questa stanza';

  @override
  String get cmdNick => 'Cambia il tuo nome visualizzato';

  @override
  String get cmdOp => 'Imposta il livello di potere di un utente';

  @override
  String get cmdPlain => 'Invia senza formattazione markdown';

  @override
  String get cmdReact => 'Reagisci al messaggio a cui rispondi';

  @override
  String get cmdRoomUpgrade => 'Aggiorna questa stanza';

  @override
  String get cmdShrug => 'Aggiungi ¯\\_(ツ)_/¯';

  @override
  String get cmdSpoiler => 'Nascondi il messaggio dietro uno spoiler';

  @override
  String get cmdTableflip => 'Aggiungi (╯°□°)╯︵ ┻━┻';

  @override
  String get cmdTopic => 'Imposta l\'argomento della stanza';

  @override
  String get cmdUnban => 'Revoca il bando di un utente';

  @override
  String get cmdUnflip => 'Aggiungi ┬─┬ ノ( ゜-゜ノ)';

  @override
  String get cmdUnignore => 'Smetti di ignorare un utente';

  @override
  String get color => 'Colore';

  @override
  String get commands => 'Comandi';

  @override
  String get compact => 'Compatto';

  @override
  String get compareAndConfirmMatch =>
      'Confronta con l\'altro dispositivo. Conferma solo se corrispondono esattamente, nello stesso ordine.';

  @override
  String get compareEmojis => 'Confronta emoji';

  @override
  String get compareEmojisToVerify =>
      'Confronta un breve elenco di emoji con l\'altro dispositivo per verificarlo.';

  @override
  String get copy => 'Copia';

  @override
  String get copyRoomId => 'Copia ID stanza';

  @override
  String get copyText => 'Copia testo';

  @override
  String get couldNotUnlock =>
      'Sblocco non riuscito. Controlla la chiave di recupero.';

  @override
  String get couldNotUnlockBackup =>
      'Impossibile sbloccare il backup. Controlla la chiave di recupero.';

  @override
  String get cozy => 'Accogliente';

  @override
  String get create => 'Crea';

  @override
  String get createPoll => 'Crea sondaggio';

  @override
  String get crossSignedPendingVerification =>
      'firma incrociata · affidabile una volta verificata questa sessione';

  @override
  String currentRoomVersion(String version) {
    return 'Attualmente versione stanza $version';
  }

  @override
  String get dark => 'Scuro';

  @override
  String get decline => 'Rifiuta';

  @override
  String get delete => 'Elimina';

  @override
  String get deleteMessageTitle => 'Eliminare il messaggio?';

  @override
  String get deleteMessageWarning => 'Il messaggio verrà rimosso per tutti.';

  @override
  String get deletePack => 'Elimina pacchetto';

  @override
  String get direct => 'Diretto';

  @override
  String get directMessages => 'Messaggi diretti';

  @override
  String get discardRecording => 'Scarta registrazione';

  @override
  String get displayName => 'Nome visualizzato';

  @override
  String get done => 'Fatto';

  @override
  String get doubleSlashHint =>
      'Inizia un messaggio con // per inviare testo che comincia con una barra.';

  @override
  String get dropFilesToUpload => 'Trascina qui i file per caricarli';

  @override
  String get edit => 'Modifica';

  @override
  String get editDisplayName => 'Modifica nome visualizzato';

  @override
  String get editTopic => 'Modifica argomento';

  @override
  String get editingMessage => 'Modifica del messaggio';

  @override
  String get emoji => 'Emoji';

  @override
  String get encryptionNotAvailable =>
      'La cifratura end-to-end non è disponibile';

  @override
  String get encryptionNotAvailableDescription =>
      'La libreria crittografica non può essere inizializzata su questa piattaforma.';

  @override
  String get endPoll => 'Termina sondaggio';

  @override
  String get endToEndEncrypted => 'Cifrata end-to-end';

  @override
  String get endToEndEncryptionNotAvailable =>
      'La cifratura end-to-end non è disponibile.';

  @override
  String get enterRecoveryKeyToUnlockBackup =>
      'Inserisci la tua chiave di recupero per sbloccare il backup delle chat e verificare questa sessione. Hai ricevuto la chiave quando il backup è stato configurato (ha questo aspetto: EsT* ****…).';

  @override
  String get enterRecoveryKeyToVerify =>
      'Inserisci la tua chiave di recupero per verificarti con il backup sicuro, oppure salta e confronta le emoji con l\'altro dispositivo.';

  @override
  String get explorePublicRooms => 'Esplora le stanze pubbliche';

  @override
  String get exploreRooms => 'Esplora stanze';

  @override
  String get filterRoomsHint => 'Filtra stanze…';

  @override
  String finalResults(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Risultati finali · $count voti',
      one: 'Risultati finali · $count voto',
    );
    return '$_temp0';
  }

  @override
  String get fontSize => 'Dimensione del testo';

  @override
  String get foodAndDrink => 'Cibo e bevande';

  @override
  String get forward => 'Inoltra';

  @override
  String get forwardTo => 'Inoltra a…';

  @override
  String forwardedTo(String name) {
    return 'Inoltrato a $name';
  }

  @override
  String get gestures => 'Gesti';

  @override
  String get gif => 'GIF';

  @override
  String get gifSearchKlipy => 'Ricerca GIF (Klipy)';

  @override
  String get gifSearchNeedsKlipyKey =>
      'La ricerca GIF richiede una chiave API gratuita di Klipy.\nOttienila su klipy.com e aggiungila nelle impostazioni.';

  @override
  String get group => 'Gruppo';

  @override
  String get groupName => 'Nome del gruppo';

  @override
  String get heartsAndSymbols => 'Cuori e simboli';

  @override
  String get home => 'Home';

  @override
  String get homeserver => 'Homeserver';

  @override
  String get huge => 'Enorme';

  @override
  String get iSavedMyRecoveryKey => 'Ho salvato la mia chiave di recupero';

  @override
  String get images => 'Immagini';

  @override
  String get integrations => 'Integrazioni';

  @override
  String get invisible => 'Invisibile';

  @override
  String get invitationTapToRespond => 'Invito — tocca per rispondere';

  @override
  String get invite => 'Invita';

  @override
  String get inviteToRoom => 'Invita nella stanza';

  @override
  String get inviteToSpace => 'Invita nello spazio';

  @override
  String inviteUser(String userId) {
    return 'Invita $userId';
  }

  @override
  String invitedUser(String userId) {
    return '$userId invitato';
  }

  @override
  String isTyping(String name) {
    return '$name sta scrivendo…';
  }

  @override
  String get join => 'Entra';

  @override
  String get joined => 'Entrato';

  @override
  String get jumpToLatestMessages => 'Vai agli ultimi messaggi';

  @override
  String get jumpToRoomHint => 'Vai alla stanza…';

  @override
  String get kick => 'Espelli';

  @override
  String kickUserTitle(String name) {
    return 'Espellere $name?';
  }

  @override
  String get klipyApiKey => 'Chiave API Klipy';

  @override
  String get klipyApiKeyDescription =>
      'Il selettore GIF usa l\'API di Klipy. Ottieni una chiave API gratuita su klipy.com e incollala qui.';

  @override
  String get knock => 'Bussa';

  @override
  String get knockPending => 'Richiesta in attesa';

  @override
  String get knockPendingWaiting =>
      'Richiesta in attesa — un moderatore della stanza deve farti entrare.';

  @override
  String get knocked => 'Richiesta inviata';

  @override
  String get knockedWaitingForApproval =>
      'Richiesta inviata — in attesa di approvazione.';

  @override
  String get language => 'Lingua';

  @override
  String get large => 'Grande';

  @override
  String lastSeenDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Ultimo accesso $count giorni fa',
      one: 'Ultimo accesso $count giorno fa',
    );
    return '$_temp0';
  }

  @override
  String lastSeenHoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Ultimo accesso $count ore fa',
      one: 'Ultimo accesso $count ora fa',
    );
    return '$_temp0';
  }

  @override
  String get lastSeenJustNow => 'Ultimo accesso proprio ora';

  @override
  String lastSeenMinutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Ultimo accesso $count minuti fa',
      one: 'Ultimo accesso $count minuto fa',
    );
    return '$_temp0';
  }

  @override
  String get layout => 'Layout';

  @override
  String get leave => 'Esci';

  @override
  String get leaveRoom => 'Uscire dalla stanza?';

  @override
  String get leaveRoomAction => 'Esci dalla stanza';

  @override
  String get leaveRoomTitle => 'Uscire dalla stanza?';

  @override
  String get leaveSpace => 'Esci dallo spazio';

  @override
  String get leaveSpaceTitle => 'Uscire dallo spazio?';

  @override
  String get left => 'Sinistra';

  @override
  String get light => 'Chiaro';

  @override
  String get list => 'Elenco';

  @override
  String get loading => 'Caricamento…';

  @override
  String get loadingDevices => 'Caricamento dispositivi…';

  @override
  String get makeAdmin => 'Rendi amministratore';

  @override
  String get makeAdminWarning =>
      'Gli amministratori hanno gli stessi poteri tuoi — potresti non riuscire più a retrocederli.';

  @override
  String get makeModerator => 'Rendi moderatore';

  @override
  String makeUserAdminTitle(String name) {
    return 'Rendere $name amministratore?';
  }

  @override
  String get managePacks => 'Gestisci pacchetti';

  @override
  String manyTyping(int count) {
    return '$count persone stanno scrivendo…';
  }

  @override
  String get members => 'Membri';

  @override
  String membersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count membri',
      one: '1 membro',
    );
    return '$_temp0';
  }

  @override
  String membersWithCount(int count) {
    return 'Membri — $count';
  }

  @override
  String get mentions => 'Menzioni';

  @override
  String get message => 'Messaggio';

  @override
  String get messageLayout => 'Layout dei messaggi';

  @override
  String get messageLayoutDescription =>
      'Come vengono mostrati i messaggi nelle chat.';

  @override
  String get microphonePermissionDenied => 'Permesso del microfono negato.';

  @override
  String get moderator => 'Moderatore';

  @override
  String get more => 'Altro';

  @override
  String get moreAttachments => 'Altri allegati';

  @override
  String get muted => 'Silenziato';

  @override
  String get name => 'Nome';

  @override
  String get newChat => 'Nuova chat';

  @override
  String get newMessages => 'Nuovi messaggi';

  @override
  String get newPack => 'Nuovo pacchetto';

  @override
  String get newRoomVersion => 'Nuova versione della stanza';

  @override
  String get newStickerPack => 'Nuovo pacchetto di sticker';

  @override
  String get noDevicesWithEncryptionKeys =>
      'Nessun dispositivo con chiavi di cifratura trovato';

  @override
  String get noGifsFound => 'Nessuna GIF trovata.';

  @override
  String get noMatchingRooms => 'Nessuna stanza corrispondente.';

  @override
  String get noMessagesFound => 'Nessun messaggio trovato.';

  @override
  String get noMessagesYet => 'Ancora nessun messaggio. Saluta!';

  @override
  String get noMessagesYetShort => 'Ancora nessun messaggio';

  @override
  String get noPinnedMessages => 'Nessun messaggio fissato in questa stanza.';

  @override
  String get noPublicRoomsFound => 'Nessuna stanza pubblica trovata.';

  @override
  String get noRepliesYet => 'Ancora nessuna risposta.';

  @override
  String get noRoomsHereYet => 'Qui non ci sono ancora stanze.';

  @override
  String get noRoomsYet =>
      'Ancora nessuna stanza.\nEntra in una stanza da un altro client per iniziare.';

  @override
  String get noStickerPacksHint =>
      'Ancora nessun pacchetto di sticker.\nUsa «Gestisci pacchetti» per crearne uno e aggiungervi immagini.';

  @override
  String get noTopicSet => 'Nessun argomento impostato';

  @override
  String get normal => 'Normale';

  @override
  String get notEncrypted => 'Non cifrata';

  @override
  String get notificationSounds => 'Suoni di notifica';

  @override
  String get notificationSoundsDescription =>
      'Riproduci il suono di sistema con le notifiche desktop.';

  @override
  String get notifications => 'Notifiche';

  @override
  String get offline => 'Offline';

  @override
  String get ok => 'OK';

  @override
  String get online => 'Online';

  @override
  String get openSettings => 'Apri impostazioni';

  @override
  String optionNumber(int number) {
    return 'Opzione $number';
  }

  @override
  String get or => 'oppure';

  @override
  String get owner => 'Proprietario';

  @override
  String get packEmpty => 'Questo pacchetto è vuoto.';

  @override
  String get packName => 'Nome del pacchetto';

  @override
  String get password => 'Password';

  @override
  String get pin => 'Fissa';

  @override
  String get pinned => 'In evidenza';

  @override
  String get pinnedMessages => 'Messaggi fissati';

  @override
  String get pleaseFillInAllFields => 'Compila tutti i campi.';

  @override
  String get poll => 'Sondaggio';

  @override
  String get pollNeedsQuestionAndOptions =>
      'Un sondaggio richiede una domanda e almeno due opzioni.';

  @override
  String presenceWithStatus(String presence, String status) {
    return '$presence — $status';
  }

  @override
  String get question => 'Domanda';

  @override
  String reactWith(String emoji) {
    return 'Reagisci con $emoji';
  }

  @override
  String readBy(String names) {
    return 'Letto da $names';
  }

  @override
  String get recoveryKey => 'Chiave di recupero';

  @override
  String get refresh => 'Aggiorna';

  @override
  String get reject => 'Rifiuta';

  @override
  String get removeOption => 'Rimuovi opzione';

  @override
  String get rename => 'Rinomina';

  @override
  String repliesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count risposte',
      one: '1 risposta',
    );
    return '$_temp0';
  }

  @override
  String get reply => 'Rispondi';

  @override
  String get replyInThread => 'Rispondi nel thread';

  @override
  String get reset => 'Ripristina';

  @override
  String get resetBackup => 'Ripristina backup';

  @override
  String get resetChatBackup => 'Ripristinare il backup delle chat?';

  @override
  String get resetChatBackupWarning =>
      'Questo scarta le chiavi di firma incrociata e il backup delle chiavi esistenti e ne crea di nuovi. I dispositivi verificati in precedenza dovranno essere verificati di nuovo, e la cronologia cifrata con chiavi perse resterà illeggibile.';

  @override
  String get resetToMember => 'Riporta a membro';

  @override
  String get resetZoom => 'Reimposta zoom';

  @override
  String get right => 'Destra';

  @override
  String get roomEncryptedNoE2eeSupport =>
      'Questa stanza è cifrata end-to-end. Questa build di Protea è stata compilata senza supporto E2EE, quindi qui non si possono leggere né inviare messaggi.';

  @override
  String get roomIdOrAliasLabel => 'ID o alias della stanza (#stanza:server)';

  @override
  String get roomUpgradedNotice =>
      'Stanza aggiornata — la sostituta apparirà a breve.';

  @override
  String get rooms => 'Stanze';

  @override
  String get save => 'Salva';

  @override
  String get saveFile => 'Salva file';

  @override
  String get saveRecoveryKeySomewhereSafe =>
      'Conserva questa chiave di recupero in un luogo sicuro (ad es. un gestore di password). Ti servirà per leggere la cronologia dei messaggi cifrati sui nuovi dispositivi:';

  @override
  String saveWithSize(String size) {
    return '$size · salva';
  }

  @override
  String savedFile(String name) {
    return '$name salvato';
  }

  @override
  String get searchFurtherBack => 'Cerca più indietro';

  @override
  String get searchGifs => 'Cerca GIF…';

  @override
  String get searchMessages => 'Cerca messaggi';

  @override
  String get searchMessagesHint => 'Cerca messaggi…';

  @override
  String get searchRoomHistoryPrompt =>
      'Cerca nella cronologia di questa stanza.';

  @override
  String get searchRoomsHint => 'Cerca stanze…';

  @override
  String get searchUserHint => 'Cerca per nome o inserisci @utente:server';

  @override
  String searchedBackTo(String date) {
    return 'Ricerca effettuata fino al $date';
  }

  @override
  String searchedBackToBeginning(String date) {
    return 'Ricerca effettuata fino al $date (inizio)';
  }

  @override
  String get security => 'Sicurezza';

  @override
  String get selectChannelToStartChatting =>
      'Seleziona un canale per iniziare a chattare.';

  @override
  String get selectChatToStartMessaging => 'Seleziona una chat per iniziare.';

  @override
  String get send => 'Invia';

  @override
  String sendFilesTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Inviare $count file?',
      one: 'Inviare il file?',
    );
    return '$_temp0';
  }

  @override
  String get sendVoiceMessage => 'Invia messaggio vocale';

  @override
  String get server => 'Server';

  @override
  String get sessionNotVerified => 'Questa sessione non è verificata';

  @override
  String get sessionNotVerifiedDescription =>
      'Gli altri tuoi dispositivi hanno la firma incrociata, ma questa sessione non si fida ancora della tua chiave di identità, quindi appaiono tutti come non verificati. Verifica questa sessione da un altro dei tuoi dispositivi per risolvere.';

  @override
  String get setStatus => 'Imposta stato';

  @override
  String get setUp => 'Configura';

  @override
  String get settingUp => 'Configurazione…';

  @override
  String get settingUpBackupFailed =>
      'La configurazione del backup non è riuscita.';

  @override
  String get settings => 'Impostazioni';

  @override
  String get signIn => 'Accedi';

  @override
  String get signInToYourMatrixAccount => 'Accedi al tuo account Matrix';

  @override
  String signInWithProvider(String provider) {
    return 'Accedi con $provider';
  }

  @override
  String get signInWithSso => 'Accedi con SSO';

  @override
  String get signOut => 'Esci';

  @override
  String get signOutConfirmation => 'Vuoi uscire dal tuo account?';

  @override
  String get skip => 'Salta';

  @override
  String get small => 'Piccolo';

  @override
  String get smileys => 'Faccine';

  @override
  String get space => 'Spazio';

  @override
  String get spaceHasNoRooms => 'Questo spazio non ha stanze.';

  @override
  String get spaceLobby => 'Atrio dello spazio';

  @override
  String get spaceSettings => 'Impostazioni dello spazio';

  @override
  String get spacesListPosition => 'Posizione della barra degli spazi';

  @override
  String get split => 'Diviso';

  @override
  String get ssoLoginTimedOut => 'L\'accesso SSO è scaduto. Riprova.';

  @override
  String get startChat => 'Avvia chat';

  @override
  String get status => 'Stato';

  @override
  String get statusMessage => 'Messaggio di stato';

  @override
  String get statusUpdated => 'Stato aggiornato';

  @override
  String get sticker => 'Sticker';

  @override
  String stickerCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sticker',
      one: '$count sticker',
    );
    return '$_temp0';
  }

  @override
  String get stickerPacks => 'Pacchetti di sticker';

  @override
  String get stickers => 'Sticker';

  @override
  String get switchAccount => 'Cambia account';

  @override
  String get syncing => 'Sincronizzazione…';

  @override
  String get systemDefault => 'Sistema';

  @override
  String get text => 'Testo';

  @override
  String get theme => 'Tema';

  @override
  String get theyDontMatch => 'Non corrispondono';

  @override
  String get theyMatch => 'Corrispondono';

  @override
  String get thisDevice => 'questo dispositivo';

  @override
  String get thread => 'Thread';

  @override
  String get today => 'Oggi';

  @override
  String get topic => 'Argomento';

  @override
  String get typeTwoCharactersToSearch =>
      'Digita almeno due caratteri per cercare nella directory degli utenti.';

  @override
  String get unblock => 'Sblocca';

  @override
  String unknownCommand(String command) {
    return 'Comando sconosciuto /$command — inizia con // per inviarlo come testo.';
  }

  @override
  String get unknownUser => 'Utente sconosciuto';

  @override
  String get unlock => 'Sblocca';

  @override
  String get unpin => 'Rimuovi dai fissati';

  @override
  String get unverified => 'non verificato';

  @override
  String get upgrade => 'Aggiorna';

  @override
  String get upgradeRoom => 'Aggiorna stanza';

  @override
  String upgradeRoomExplanation(String newVersion, String currentVersion) {
    return 'Questo crea una nuova stanza con versione $newVersion e chiude questa (versione $currentVersion) con un collegamento alla sostituta. I membri dovranno rientrare nella nuova stanza.';
  }

  @override
  String get upgradeRoomTitle => 'Aggiornare la stanza?';

  @override
  String get userIdLabel => 'ID utente (@utente:server)';

  @override
  String get username => 'Nome utente';

  @override
  String verificationFailed(String reason) {
    return 'Verifica non riuscita o annullata.\n$reason';
  }

  @override
  String get verificationStepNotSupported =>
      'Questo passaggio di verifica non è supportato da Protea. Usa la verifica con emoji.';

  @override
  String get verificationSuccessful =>
      'Verifica riuscita! Il dispositivo ora è affidabile.';

  @override
  String get verified => 'verificato';

  @override
  String get verify => 'Verifica';

  @override
  String get verifyDevice => 'Verifica dispositivo';

  @override
  String get verifySession => 'Verifica sessione';

  @override
  String versionDefault(String version) {
    return '$version (predefinita)';
  }

  @override
  String get voiceMessage => 'Messaggio vocale';

  @override
  String voteCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count voti',
      one: '$count voto',
    );
    return '$_temp0';
  }

  @override
  String get waitingForOtherDeviceToAccept =>
      'In attesa che l\'altro dispositivo accetti…\n\nAssicurati che l\'altro dispositivo sia online e che la richiesta sia stata accettata lì.';

  @override
  String get waitingForOtherDeviceToConfirm =>
      'In attesa della conferma dell\'altro dispositivo…';

  @override
  String wantsToVerifyDevice(String user) {
    return '$user vuole verificare un dispositivo.';
  }

  @override
  String wantsToVerifyDeviceWithId(String user, String deviceId) {
    return '$user vuole verificare un dispositivo ($deviceId).';
  }

  @override
  String get whatsHappening => 'Che succede?';

  @override
  String get withdrawKnock => 'Ritira la richiesta';

  @override
  String get workspace => 'Area di lavoro';

  @override
  String get yesterday => 'Ieri';

  @override
  String get youHaveBeenInvited => 'Sei stato invitato in questa stanza.';

  @override
  String youWillNoLongerSee(String roomName) {
    return 'Non vedrai più $roomName.';
  }

  @override
  String get zoomIn => 'Ingrandisci';

  @override
  String get zoomOut => 'Riduci';
}
