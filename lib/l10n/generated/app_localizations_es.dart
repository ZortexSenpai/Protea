// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get accept => 'Aceptar';

  @override
  String get accessToken => 'Token de acceso';

  @override
  String get accessTokenWarning =>
      'Nunca compartas tu token de acceso. Otorga control total sobre tu cuenta.';

  @override
  String get account => 'Cuenta';

  @override
  String get accounts => 'Cuentas';

  @override
  String get activitiesAndObjects => 'Actividades y objetos';

  @override
  String get addAccount => 'Añadir cuenta';

  @override
  String get addOption => 'Añadir opción';

  @override
  String get addReaction => 'Añadir reacción';

  @override
  String get addSticker => 'Añadir sticker';

  @override
  String get admin => 'Administrador';

  @override
  String get all => 'Todo';

  @override
  String get animalsAndNature => 'Animales y naturaleza';

  @override
  String get appLayout => 'Diseño de la aplicación';

  @override
  String get appLayoutDescription =>
      'Espacio de trabajo muestra una barra de espacios con lista de canales por espacio, Dividido combina la lista de salas con el chat, Lista abre los chats en su propia página.';

  @override
  String get appTitle => 'Protea';

  @override
  String get appearance => 'Apariencia';

  @override
  String areTyping(String name1, String name2) {
    return '$name1 y $name2 están escribiendo…';
  }

  @override
  String get attachFile => 'Adjuntar archivo';

  @override
  String get autoAway => 'Ausencia automática';

  @override
  String get autoAwayDescription =>
      'Cambia el estado a ausente tras 10 minutos sin actividad de teclado o ratón.';

  @override
  String get away => 'Ausente';

  @override
  String get ban => 'Vetar';

  @override
  String banUserTitle(String name) {
    return '¿Vetar a $name?';
  }

  @override
  String get block => 'Bloquear';

  @override
  String get bubbles => 'Burbujas';

  @override
  String get cancel => 'Cancelar';

  @override
  String get changeBanner => 'Cambiar banner';

  @override
  String get changeImage => 'Cambiar imagen';

  @override
  String get changeProfilePicture => 'Cambiar foto de perfil';

  @override
  String get changeSpaceImage => 'Cambiar imagen del espacio';

  @override
  String get channelSettings => 'Ajustes del canal';

  @override
  String get channels => 'Canales';

  @override
  String get chatBackup => 'Copia de seguridad del chat';

  @override
  String get chatBackupEnabled => 'Copia de seguridad del chat activada';

  @override
  String get chatBackupEnabledDescription =>
      'La firma cruzada y la copia de claves están activas en este dispositivo.';

  @override
  String get chatBackupLocked =>
      'La copia de seguridad del chat está bloqueada';

  @override
  String get chatBackupLockedDescription =>
      'Desbloquéala con tu clave de recuperación para leer mensajes cifrados antiguos en este dispositivo.';

  @override
  String get chatBackupNotSetUp =>
      'La copia de seguridad del chat no está configurada';

  @override
  String get chatBackupNotSetUpDescription =>
      'Configura la firma cruzada y la copia de claves para que los mensajes cifrados sobrevivan en dispositivos nuevos.';

  @override
  String get chatBackupSetUp =>
      '¡La copia de seguridad del chat está configurada!';

  @override
  String get checking => 'Comprobando…';

  @override
  String get clickToSave => 'Haz clic para guardar';

  @override
  String get close => 'Cerrar';

  @override
  String get closeThread => 'Cerrar hilo';

  @override
  String get cmdBan => 'Vetar a un usuario de esta sala';

  @override
  String get cmdDiscardSession => 'Descartar la sesión de cifrado saliente';

  @override
  String get cmdDm => 'Abrir un chat directo';

  @override
  String get cmdHelp => 'Listar los comandos disponibles';

  @override
  String get cmdHtml => 'Enviar HTML sin procesar';

  @override
  String get cmdIgnore => 'Ignorar a un usuario';

  @override
  String get cmdInvite => 'Invitar a un usuario a esta sala';

  @override
  String get cmdJoin => 'Unirse a una sala';

  @override
  String get cmdKick => 'Expulsar a un usuario de esta sala';

  @override
  String get cmdLeave => 'Salir de esta sala';

  @override
  String get cmdLenny => 'Añadir ( ͡° ͜ʖ ͡°)';

  @override
  String get cmdMe => 'Enviar un emote';

  @override
  String get cmdMyRoomNick => 'Cambiar tu nombre solo en esta sala';

  @override
  String get cmdNick => 'Cambiar tu nombre visible';

  @override
  String get cmdOp => 'Establecer el nivel de poder de un usuario';

  @override
  String get cmdPlain => 'Enviar sin formato markdown';

  @override
  String get cmdReact => 'Reaccionar al mensaje al que respondes';

  @override
  String get cmdRoomUpgrade => 'Actualizar esta sala';

  @override
  String get cmdShrug => 'Añadir ¯\\_(ツ)_/¯';

  @override
  String get cmdSpoiler => 'Ocultar el mensaje tras un spoiler';

  @override
  String get cmdTableflip => 'Añadir (╯°□°)╯︵ ┻━┻';

  @override
  String get cmdTopic => 'Establecer el tema de la sala';

  @override
  String get cmdUnban => 'Levantar el veto a un usuario';

  @override
  String get cmdUnflip => 'Añadir ┬─┬ ノ( ゜-゜ノ)';

  @override
  String get cmdUnignore => 'Dejar de ignorar a un usuario';

  @override
  String get color => 'Color';

  @override
  String get commands => 'Comandos';

  @override
  String get compact => 'Compacto';

  @override
  String get compareAndConfirmMatch =>
      'Compara con el otro dispositivo. Confirma solo si coinciden exactamente y en el mismo orden.';

  @override
  String get compareEmojis => 'Comparar emojis';

  @override
  String get compareEmojisToVerify =>
      'Compara una breve lista de emojis con el otro dispositivo para verificarlo.';

  @override
  String get copiedToClipboard => 'Copiado al portapapeles';

  @override
  String get copy => 'Copiar';

  @override
  String get copyRoomId => 'Copiar ID de la sala';

  @override
  String get copyText => 'Copiar texto';

  @override
  String get couldNotUnlock =>
      'No se pudo desbloquear. Comprueba la clave de recuperación.';

  @override
  String get couldNotUnlockBackup =>
      'No se pudo desbloquear la copia de seguridad. Comprueba la clave de recuperación.';

  @override
  String get cozy => 'Acogedor';

  @override
  String get create => 'Crear';

  @override
  String get createPoll => 'Crear encuesta';

  @override
  String get crossSignedPendingVerification =>
      'con firma cruzada · de confianza cuando esta sesión esté verificada';

  @override
  String currentRoomVersion(String version) {
    return 'Actualmente versión de sala $version';
  }

  @override
  String get dark => 'Oscuro';

  @override
  String get decline => 'Rechazar';

  @override
  String get delete => 'Eliminar';

  @override
  String get deleteMessageTitle => '¿Eliminar mensaje?';

  @override
  String get deleteMessageWarning => 'El mensaje se eliminará para todos.';

  @override
  String get deletePack => 'Eliminar paquete';

  @override
  String get desktopNotificationsDescription =>
      'Muestra notificaciones del sistema para mensajes nuevos mientras la ventana está en segundo plano.';

  @override
  String get desktopNotificationsTitle => 'Notificaciones de escritorio';

  @override
  String get direct => 'Directo';

  @override
  String get directMessages => 'Mensajes directos';

  @override
  String get discardRecording => 'Descartar grabación';

  @override
  String get displayName => 'Nombre visible';

  @override
  String get done => 'Hecho';

  @override
  String get doubleSlashHint =>
      'Empieza un mensaje con // para enviar texto que comience con una barra.';

  @override
  String get dropFilesToUpload => 'Suelta archivos para subirlos';

  @override
  String get edit => 'Editar';

  @override
  String get editDisplayName => 'Editar nombre visible';

  @override
  String get editTopic => 'Editar tema';

  @override
  String get editingMessage => 'Editando mensaje';

  @override
  String get emoji => 'Emoji';

  @override
  String get encryptNewDmsDescription =>
      'Activa el cifrado de extremo a extremo al iniciar un nuevo chat directo.';

  @override
  String get encryptNewDmsTitle => 'Cifrar nuevos chats directos';

  @override
  String get encryptionNotAvailable =>
      'El cifrado de extremo a extremo no está disponible';

  @override
  String get encryptionNotAvailableDescription =>
      'La biblioteca criptográfica no pudo inicializarse en esta plataforma.';

  @override
  String get endPoll => 'Finalizar encuesta';

  @override
  String get endToEndEncrypted => 'Cifrado de extremo a extremo';

  @override
  String get endToEndEncryptionNotAvailable =>
      'El cifrado de extremo a extremo no está disponible.';

  @override
  String get enterRecoveryKeyToUnlockBackup =>
      'Introduce tu clave de recuperación para desbloquear la copia de seguridad del chat y verificar esta sesión. Recibiste la clave al configurar la copia (tiene este aspecto: EsT* ****…).';

  @override
  String get enterRecoveryKeyToVerify =>
      'Introduce tu clave de recuperación para verificarte con tu copia segura, u omite este paso y compara emojis con el otro dispositivo.';

  @override
  String get expert => 'Experto';

  @override
  String get explorePublicRooms => 'Explorar salas públicas';

  @override
  String get exploreRooms => 'Explorar salas';

  @override
  String get filterRoomsHint => 'Filtrar salas…';

  @override
  String finalResults(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Resultados finales · $count votos',
      one: 'Resultados finales · $count voto',
    );
    return '$_temp0';
  }

  @override
  String get fontSize => 'Tamaño de letra';

  @override
  String get foodAndDrink => 'Comida y bebida';

  @override
  String get forward => 'Reenviar';

  @override
  String get forwardTo => 'Reenviar a…';

  @override
  String forwardedTo(String name) {
    return 'Reenviado a $name';
  }

  @override
  String get gestures => 'Gestos';

  @override
  String get gif => 'GIF';

  @override
  String get gifSearchKlipy => 'Búsqueda de GIF (Klipy)';

  @override
  String get gifSearchNeedsKlipyKey =>
      'La búsqueda de GIF necesita una clave API gratuita de Klipy.\nConsigue una en klipy.com y añádela en los ajustes.';

  @override
  String get group => 'Grupo';

  @override
  String get groupName => 'Nombre del grupo';

  @override
  String get heartsAndSymbols => 'Corazones y símbolos';

  @override
  String get hide => 'Ocultar';

  @override
  String get home => 'Inicio';

  @override
  String get homeserver => 'Servidor';

  @override
  String get huge => 'Enorme';

  @override
  String get iSavedMyRecoveryKey => 'He guardado mi clave de recuperación';

  @override
  String get images => 'Imágenes';

  @override
  String get integrations => 'Integraciones';

  @override
  String get invisible => 'Invisible';

  @override
  String get invitationTapToRespond => 'Invitación — toca para responder';

  @override
  String get invite => 'Invitar';

  @override
  String get inviteToRoom => 'Invitar a la sala';

  @override
  String get inviteToSpace => 'Invitar al espacio';

  @override
  String inviteUser(String userId) {
    return 'Invitar a $userId';
  }

  @override
  String invitedUser(String userId) {
    return 'Se invitó a $userId';
  }

  @override
  String isTyping(String name) {
    return '$name está escribiendo…';
  }

  @override
  String get join => 'Unirse';

  @override
  String get joined => 'Unido';

  @override
  String get jumpToLatestMessages => 'Ir a los últimos mensajes';

  @override
  String get jumpToRoomHint => 'Ir a la sala…';

  @override
  String get kick => 'Expulsar';

  @override
  String kickUserTitle(String name) {
    return '¿Expulsar a $name?';
  }

  @override
  String get klipyApiKey => 'Clave API de Klipy';

  @override
  String get klipyApiKeyDescription =>
      'El selector de GIF usa la API de Klipy. Consigue una clave API gratuita en klipy.com y pégala aquí.';

  @override
  String get knock => 'Llamar';

  @override
  String get knockPending => 'Llamada pendiente';

  @override
  String get knockPendingWaiting =>
      'Llamada pendiente — esperando a que un moderador de la sala te deje entrar.';

  @override
  String get knocked => 'Llamada enviada';

  @override
  String get knockedWaitingForApproval =>
      'Llamada enviada — esperando aprobación.';

  @override
  String get language => 'Idioma';

  @override
  String get large => 'Grande';

  @override
  String lastSeenDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Visto por última vez hace $count días',
      one: 'Visto por última vez hace $count día',
    );
    return '$_temp0';
  }

  @override
  String lastSeenHoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Visto por última vez hace $count horas',
      one: 'Visto por última vez hace $count hora',
    );
    return '$_temp0';
  }

  @override
  String get lastSeenJustNow => 'Visto por última vez ahora mismo';

  @override
  String lastSeenMinutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Visto por última vez hace $count minutos',
      one: 'Visto por última vez hace $count minuto',
    );
    return '$_temp0';
  }

  @override
  String get layout => 'Diseño';

  @override
  String get leave => 'Salir';

  @override
  String get leaveRoom => '¿Salir de la sala?';

  @override
  String get leaveRoomAction => 'Salir de la sala';

  @override
  String get leaveRoomTitle => '¿Salir de la sala?';

  @override
  String get leaveSpace => 'Salir del espacio';

  @override
  String get leaveSpaceTitle => '¿Salir del espacio?';

  @override
  String get left => 'Izquierda';

  @override
  String get light => 'Claro';

  @override
  String get list => 'Lista';

  @override
  String get loading => 'Cargando…';

  @override
  String get loadingDevices => 'Cargando dispositivos…';

  @override
  String get makeAdmin => 'Hacer administrador';

  @override
  String get makeAdminWarning =>
      'Los administradores tienen el mismo poder que tú — puede que luego no puedas degradarlos.';

  @override
  String get makeModerator => 'Hacer moderador';

  @override
  String makeUserAdminTitle(String name) {
    return '¿Hacer administrador a $name?';
  }

  @override
  String get managePacks => 'Gestionar paquetes';

  @override
  String manyTyping(int count) {
    return '$count personas están escribiendo…';
  }

  @override
  String get members => 'Miembros';

  @override
  String membersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count miembros',
      one: '1 miembro',
    );
    return '$_temp0';
  }

  @override
  String membersWithCount(int count) {
    return 'Miembros — $count';
  }

  @override
  String get mentions => 'Menciones';

  @override
  String get message => 'Mensaje';

  @override
  String get messageLayout => 'Diseño de mensajes';

  @override
  String get messageLayoutDescription =>
      'Cómo se muestran los mensajes en los chats.';

  @override
  String get microphonePermissionDenied => 'Permiso de micrófono denegado.';

  @override
  String get moderator => 'Moderador';

  @override
  String get more => 'Más';

  @override
  String get moreAttachments => 'Más adjuntos';

  @override
  String get muted => 'Silenciado';

  @override
  String get name => 'Nombre';

  @override
  String get newChat => 'Nuevo chat';

  @override
  String get newMessages => 'Mensajes nuevos';

  @override
  String get newPack => 'Nuevo paquete';

  @override
  String get newRoomVersion => 'Nueva versión de la sala';

  @override
  String get newStickerPack => 'Nuevo paquete de stickers';

  @override
  String get noDevicesWithEncryptionKeys =>
      'No se encontraron dispositivos con claves de cifrado';

  @override
  String get noGifsFound => 'No se encontraron GIF.';

  @override
  String get noMatchingRooms => 'No hay salas que coincidan.';

  @override
  String get noMessagesFound => 'No se encontraron mensajes.';

  @override
  String get noMessagesYet => 'Aún no hay mensajes. ¡Di hola!';

  @override
  String get noMessagesYetShort => 'Aún no hay mensajes';

  @override
  String get noPinnedMessages => 'No hay mensajes fijados en esta sala.';

  @override
  String get noPublicRoomsFound => 'No se encontraron salas públicas.';

  @override
  String get noRepliesYet => 'Aún no hay respuestas.';

  @override
  String get noRoomsHereYet => 'Aún no hay salas aquí.';

  @override
  String get noRoomsYet =>
      'Aún no hay salas.\nÚnete a una sala desde otro cliente para empezar.';

  @override
  String get noStickerPacksHint =>
      'Aún no hay paquetes de stickers.\nUsa «Gestionar paquetes» para crear uno y añadirle imágenes.';

  @override
  String get noTopicSet => 'Sin tema';

  @override
  String get normal => 'Normal';

  @override
  String get notEncrypted => 'Sin cifrar';

  @override
  String get notificationSounds => 'Sonidos de notificación';

  @override
  String get notificationSoundsDescription =>
      'Reproducir el sonido del sistema con las notificaciones de escritorio.';

  @override
  String get notifications => 'Notificaciones';

  @override
  String get offline => 'Desconectado';

  @override
  String get ok => 'OK';

  @override
  String get online => 'En línea';

  @override
  String get openSettings => 'Abrir ajustes';

  @override
  String optionNumber(int number) {
    return 'Opción $number';
  }

  @override
  String get or => 'o';

  @override
  String get owner => 'Propietario';

  @override
  String get packEmpty => 'Este paquete está vacío.';

  @override
  String get packName => 'Nombre del paquete';

  @override
  String get password => 'Contraseña';

  @override
  String get pin => 'Fijar';

  @override
  String get pinned => 'Fijado';

  @override
  String get pinnedMessages => 'Mensajes fijados';

  @override
  String get pleaseFillInAllFields => 'Rellena todos los campos.';

  @override
  String get poll => 'Encuesta';

  @override
  String get pollNeedsQuestionAndOptions =>
      'Una encuesta necesita una pregunta y al menos dos opciones.';

  @override
  String presenceWithStatus(String presence, String status) {
    return '$presence — $status';
  }

  @override
  String get privacy => 'Privacidad';

  @override
  String get question => 'Pregunta';

  @override
  String reactWith(String emoji) {
    return 'Reaccionar con $emoji';
  }

  @override
  String readBy(String names) {
    return 'Leído por $names';
  }

  @override
  String get recoveryKey => 'Clave de recuperación';

  @override
  String get refresh => 'Actualizar';

  @override
  String get reject => 'Rechazar';

  @override
  String get removeOption => 'Quitar opción';

  @override
  String get rename => 'Renombrar';

  @override
  String repliesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count respuestas',
      one: '1 respuesta',
    );
    return '$_temp0';
  }

  @override
  String get reply => 'Responder';

  @override
  String get replyInThread => 'Responder en hilo';

  @override
  String get reset => 'Restablecer';

  @override
  String get resetBackup => 'Restablecer copia';

  @override
  String get resetChatBackup => '¿Restablecer la copia de seguridad del chat?';

  @override
  String get resetChatBackupWarning =>
      'Esto descarta las claves de firma cruzada y la copia de claves existentes y crea otras nuevas. Los dispositivos verificados antes deberán verificarse de nuevo, y el historial cifrado con claves perdidas seguirá siendo ilegible.';

  @override
  String get resetToMember => 'Restablecer a miembro';

  @override
  String get resetZoom => 'Restablecer zoom';

  @override
  String get right => 'Derecha';

  @override
  String get roomEncryptedNoE2eeSupport =>
      'Esta sala está cifrada de extremo a extremo. Esta compilación de Protea se creó sin soporte E2EE, por lo que aquí no se pueden leer ni enviar mensajes.';

  @override
  String get roomIdOrAliasLabel => 'ID o alias de la sala (#sala:servidor)';

  @override
  String get roomUpgradedNotice =>
      'Sala actualizada — el reemplazo aparecerá en breve.';

  @override
  String get rooms => 'Salas';

  @override
  String get save => 'Guardar';

  @override
  String get saveFile => 'Guardar archivo';

  @override
  String get saveRecoveryKeySomewhereSafe =>
      'Guarda esta clave de recuperación en un lugar seguro (p. ej. un gestor de contraseñas). La necesitarás para leer tu historial de mensajes cifrados en dispositivos nuevos:';

  @override
  String saveWithSize(String size) {
    return '$size · guardar';
  }

  @override
  String savedFile(String name) {
    return '$name guardado';
  }

  @override
  String get searchFurtherBack => 'Buscar más atrás';

  @override
  String get searchGifs => 'Buscar GIF…';

  @override
  String get searchMessages => 'Buscar mensajes';

  @override
  String get searchMessagesHint => 'Buscar mensajes…';

  @override
  String get searchRoomHistoryPrompt => 'Busca en el historial de esta sala.';

  @override
  String get searchRoomsHint => 'Buscar salas…';

  @override
  String get searchUserHint => 'Busca por nombre o escribe @usuario:servidor';

  @override
  String searchedBackTo(String date) {
    return 'Buscado hasta $date';
  }

  @override
  String searchedBackToBeginning(String date) {
    return 'Buscado hasta $date (principio)';
  }

  @override
  String get security => 'Seguridad';

  @override
  String get selectChannelToStartChatting =>
      'Selecciona un canal para empezar a chatear.';

  @override
  String get selectChatToStartMessaging => 'Selecciona un chat para empezar.';

  @override
  String get send => 'Enviar';

  @override
  String sendFilesTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '¿Enviar $count archivos?',
      one: '¿Enviar archivo?',
    );
    return '$_temp0';
  }

  @override
  String get sendReadReceiptsDescription =>
      'Permite que otros vean qué mensajes has leído.';

  @override
  String get sendReadReceiptsTitle => 'Enviar confirmaciones de lectura';

  @override
  String get sendTypingNotificationsDescription =>
      'Permite que otros vean cuando estás escribiendo.';

  @override
  String get sendTypingNotificationsTitle => 'Enviar indicadores de escritura';

  @override
  String get sendVoiceMessage => 'Enviar mensaje de voz';

  @override
  String get sending => 'Enviando…';

  @override
  String get server => 'Servidor';

  @override
  String get sessionNotVerified => 'Esta sesión no está verificada';

  @override
  String get sessionNotVerifiedDescription =>
      'Tus otros dispositivos tienen firma cruzada, pero esta sesión aún no confía en tu clave de identidad, por lo que todos aparecen como no verificados. Verifica esta sesión desde otro de tus dispositivos para solucionarlo.';

  @override
  String get setStatus => 'Establecer estado';

  @override
  String get setUp => 'Configurar';

  @override
  String get settingUp => 'Configurando…';

  @override
  String get settingUpBackupFailed =>
      'La configuración de la copia de seguridad falló.';

  @override
  String get settings => 'Ajustes';

  @override
  String get show => 'Mostrar';

  @override
  String get showDeletedMessagesDescription =>
      'Mantén un marcador donde se eliminó un mensaje.';

  @override
  String get showDeletedMessagesTitle => 'Mensajes eliminados';

  @override
  String get showMembershipEventsDescription =>
      'Muestra cuando los miembros entran, salen o son invitados.';

  @override
  String get showMembershipEventsTitle => 'Entradas y salidas';

  @override
  String get showProfileChangeEventsDescription =>
      'Muestra cambios de nombre visible y foto de perfil.';

  @override
  String get showProfileChangeEventsTitle => 'Cambios de perfil';

  @override
  String get showUrlPreviewsDescription =>
      'Muestra una tarjeta de vista previa bajo los mensajes con enlaces.';

  @override
  String get showUrlPreviewsTitle => 'Mostrar vistas previas de enlaces';

  @override
  String get signIn => 'Iniciar sesión';

  @override
  String get signInToYourMatrixAccount =>
      'Inicia sesión en tu cuenta de Matrix';

  @override
  String signInWithProvider(String provider) {
    return 'Iniciar sesión con $provider';
  }

  @override
  String get signInWithSso => 'Iniciar sesión con SSO';

  @override
  String get signOut => 'Cerrar sesión';

  @override
  String get signOutConfirmation => '¿Quieres cerrar la sesión de tu cuenta?';

  @override
  String get skip => 'Omitir';

  @override
  String get small => 'Pequeño';

  @override
  String get smileys => 'Caritas';

  @override
  String get space => 'Espacio';

  @override
  String get spaceHasNoRooms => 'Este espacio no tiene salas.';

  @override
  String get spaceLobby => 'Vestíbulo del espacio';

  @override
  String get spaceSettings => 'Ajustes del espacio';

  @override
  String get spacesListPosition => 'Posición de la barra de espacios';

  @override
  String get split => 'Dividido';

  @override
  String get ssoLoginTimedOut =>
      'El inicio de sesión SSO tardó demasiado. Inténtalo de nuevo.';

  @override
  String get startChat => 'Iniciar chat';

  @override
  String get status => 'Estado';

  @override
  String get statusMessage => 'Mensaje de estado';

  @override
  String get statusUpdated => 'Estado actualizado';

  @override
  String get sticker => 'Sticker';

  @override
  String stickerCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count stickers',
      one: '$count sticker',
    );
    return '$_temp0';
  }

  @override
  String get stickerPacks => 'Paquetes de stickers';

  @override
  String get stickers => 'Stickers';

  @override
  String get switchAccount => 'Cambiar de cuenta';

  @override
  String get syncing => 'Sincronizando…';

  @override
  String get systemDefault => 'Sistema';

  @override
  String get systemMessages => 'Mensajes del sistema';

  @override
  String get systemMessagesDescription =>
      'Elige qué eventos de la sala aparecen en la conversación.';

  @override
  String get text => 'Texto';

  @override
  String get theme => 'Tema';

  @override
  String get theyDontMatch => 'No coinciden';

  @override
  String get theyMatch => 'Coinciden';

  @override
  String get thisDevice => 'este dispositivo';

  @override
  String get thread => 'Hilo';

  @override
  String get today => 'Hoy';

  @override
  String get topic => 'Tema';

  @override
  String get typeTwoCharactersToSearch =>
      'Escribe al menos dos caracteres para buscar en el directorio de usuarios.';

  @override
  String get unblock => 'Desbloquear';

  @override
  String unknownCommand(String command) {
    return 'Comando desconocido /$command — empieza con // para enviarlo como texto.';
  }

  @override
  String get unknownUser => 'Usuario desconocido';

  @override
  String get unlock => 'Desbloquear';

  @override
  String get unpin => 'Desfijar';

  @override
  String get unverified => 'sin verificar';

  @override
  String get upgrade => 'Actualizar';

  @override
  String get upgradeRoom => 'Actualizar sala';

  @override
  String upgradeRoomExplanation(String newVersion, String currentVersion) {
    return 'Esto crea una sala nueva con la versión $newVersion y cierra esta (versión $currentVersion) con un enlace al reemplazo. Los miembros deberán unirse de nuevo a la sala nueva.';
  }

  @override
  String get upgradeRoomTitle => '¿Actualizar sala?';

  @override
  String get userIdLabel => 'ID de usuario (@usuario:servidor)';

  @override
  String get username => 'Nombre de usuario';

  @override
  String verificationFailed(String reason) {
    return 'La verificación falló o fue cancelada.\n$reason';
  }

  @override
  String get verificationStepNotSupported =>
      'Protea no admite este paso de verificación. Usa la verificación por emojis.';

  @override
  String get verificationSuccessful =>
      '¡Verificación correcta! El dispositivo ahora es de confianza.';

  @override
  String get verified => 'verificado';

  @override
  String get verify => 'Verificar';

  @override
  String get verifyDevice => 'Verificar dispositivo';

  @override
  String get verifySession => 'Verificar sesión';

  @override
  String versionDefault(String version) {
    return '$version (predeterminada)';
  }

  @override
  String get voiceMessage => 'Mensaje de voz';

  @override
  String voteCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count votos',
      one: '$count voto',
    );
    return '$_temp0';
  }

  @override
  String get waitingForOtherDeviceToAccept =>
      'Esperando a que el otro dispositivo acepte…\n\nAsegúrate de que el otro dispositivo esté en línea y de que la solicitud se haya aceptado allí.';

  @override
  String get waitingForOtherDeviceToConfirm =>
      'Esperando a que el otro dispositivo confirme…';

  @override
  String wantsToVerifyDevice(String user) {
    return '$user quiere verificar un dispositivo.';
  }

  @override
  String wantsToVerifyDeviceWithId(String user, String deviceId) {
    return '$user quiere verificar un dispositivo ($deviceId).';
  }

  @override
  String get whatsHappening => '¿Qué está pasando?';

  @override
  String get withdrawKnock => 'Retirar la llamada';

  @override
  String get workspace => 'Espacio de trabajo';

  @override
  String get yesterday => 'Ayer';

  @override
  String get youHaveBeenInvited => 'Te han invitado a esta sala.';

  @override
  String youWillNoLongerSee(String roomName) {
    return 'Ya no verás $roomName.';
  }

  @override
  String get zoomIn => 'Acercar';

  @override
  String get zoomOut => 'Alejar';
}
