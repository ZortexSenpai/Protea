// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get accentColor => 'Color de acento';

  @override
  String get accentColorDescription =>
      'Ponle un color propio a este tema o conserva el suyo.';

  @override
  String get appBackground => 'Fondo de la aplicación';

  @override
  String get appBackgroundDescription =>
      'Un color detrás de toda la aplicación: la página bajo los paneles y el brillo en las esquinas del diseño Liquid.';

  @override
  String get backgroundGlow => 'Esquinas con brillo';

  @override
  String get backgroundGlowDescription =>
      'Colorea el fondo del diseño Liquid arriba a la izquierda y abajo a la derecha. Desactivado, el fondo es de un solo color.';

  @override
  String get blur => 'Desenfoque';

  @override
  String get chatWallpaper => 'Fondo del chat';

  @override
  String get chatWallpaperDescription =>
      'Una imagen detrás de los mensajes. Ajusta opacidad y desenfoque para que el texto siga legible.';

  @override
  String get chooseImage => 'Elegir imagen';

  @override
  String get clearSearch => 'Borrar búsqueda';

  @override
  String get closeToTrayDescription =>
      'Al cerrar la ventana, Protea sigue ejecutándose en la bandeja del sistema.';

  @override
  String get closeToTrayTitle => 'Cerrar a la bandeja';

  @override
  String get accept => 'Aceptar';

  @override
  String get access => 'Acceso';

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
  String get addACaption => 'Añadir un pie de foto…';

  @override
  String get addAccount => 'Añadir cuenta';

  @override
  String get addOption => 'Añadir opción';

  @override
  String get addReaction => 'Añadir reacción';

  @override
  String get addSticker => 'Añadir sticker';

  @override
  String get addToFavorites => 'Añadir a favoritos';

  @override
  String get admin => 'Administrador';

  @override
  String get all => 'Todo';

  @override
  String get animalsAndNature => 'Animales y naturaleza';

  @override
  String get anyone => 'Cualquiera';

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
  String get arrowUpToEditDescription =>
      'Pulsar la flecha arriba con el campo de mensaje vacío edita tu último mensaje.';

  @override
  String get arrowUpToEditTitle =>
      'Editar el último mensaje con la flecha arriba';

  @override
  String get attachFile => 'Adjuntar archivo';

  @override
  String get attachments => 'Adjuntos';

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
  String get bannedUsers => 'Usuarios vetados';

  @override
  String get block => 'Bloquear';

  @override
  String get bubbles => 'Burbujas';

  @override
  String get cancel => 'Cancelar';

  @override
  String get categoryName => 'Nombre de la categoría';

  @override
  String get changeBanner => 'Cambiar banner';

  @override
  String get changeImage => 'Cambiar imagen';

  @override
  String get changeProfilePicture => 'Cambiar foto de perfil';

  @override
  String get changeSettings => 'Cambiar ajustes';

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
  String get colorAccent => 'Acento';

  @override
  String get colorBackground => 'Fondo';

  @override
  String get colorMutedText => 'Texto atenuado';

  @override
  String get colorOutline => 'Contorno';

  @override
  String get colorPanels => 'Paneles';

  @override
  String get colorText => 'Texto';

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
  String get copyImage => 'Copiar imagen';

  @override
  String get findOrStartConversation => 'Buscar o iniciar una conversación';

  @override
  String get imageCopied => 'Imagen copiada';

  @override
  String get noSearchResults => 'Sin resultados.';

  @override
  String get quickSwitcherHint => '¿A dónde quieres ir?';

  @override
  String get quickSwitcherTip =>
      'Consejo: empieza con @ para buscar personas o # para salas. ↑↓ para navegar, Intro para abrir.';

  @override
  String get retrySend => 'Reintentar';

  @override
  String get messageNotSent => 'No enviado';

  @override
  String get spreadsheetEmpty => 'Esta hoja está vacía.';

  @override
  String spreadsheetTruncated(int rows, int columns) {
    return 'Hoja grande: solo se muestran las primeras $rows filas y $columns columnas.';
  }

  @override
  String get spreadsheetUnreadable => 'No se pudo leer esta hoja de cálculo.';

  @override
  String uploadFailed(String filename) {
    return 'Error al subir: $filename';
  }

  @override
  String get fileNoLongerCached =>
      'El archivo ya no está disponible para reenviarlo. Elimina el mensaje y envíalo de nuevo.';

  @override
  String get downloadImage => 'Descargar';

  @override
  String get copyThemeCode => 'Copiar código del tema';

  @override
  String get couldNotUnlock =>
      'No se pudo desbloquear. Comprueba la clave de recuperación.';

  @override
  String get couldNotUnlockBackup =>
      'No se pudo desbloquear la copia de seguridad. Comprueba la clave de recuperación.';

  @override
  String get cozy => 'Predeterminado';

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
  String get customThemeColors => 'Colores personalizados';

  @override
  String get customThemeColorsDescription =>
      'Seis colores forman todo el tema: los tonos de superficie intermedios se calculan a partir del fondo y el color de los paneles.';

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
  String get edited => '(editado)';

  @override
  String get editingMessage => 'Editando mensaje';

  @override
  String get emoji => 'Emoji';

  @override
  String get enableEncryptionTitle => 'Activar cifrado de extremo a extremo';

  @override
  String get enableEncryptionWarning =>
      'El cifrado no se puede desactivar después. Los mensajes solo se podrán leer en dispositivos verificados.';

  @override
  String get emotes => 'Emotes';

  @override
  String get encryptedNotSearchable =>
      'Las salas cifradas no se incluyen: el servidor no puede buscar en mensajes cifrados.';

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
  String get fadeAmount => 'Fundido';

  @override
  String get favorites => 'Favoritos';

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
  String get floating => 'Flotante';

  @override
  String get focus => 'Enfoque';

  @override
  String get fontSize => 'Tamaño de letra';

  @override
  String get foodAndDrink => 'Comida y bebida';

  @override
  String get formatBold => 'Negrita';

  @override
  String get formatCodeBlock => 'Bloque de código';

  @override
  String get formatInlineCode => 'Código en línea';

  @override
  String get formatItalic => 'Cursiva';

  @override
  String get formatLink => 'Enlace';

  @override
  String get formatSpoiler => 'Spoiler';

  @override
  String get formatStrikethrough => 'Tachado';

  @override
  String get formatting => 'Formato de texto';

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
  String get gifs => 'GIFs';

  @override
  String get gifProxyTitle => 'Enviar GIF a través de un proxy';

  @override
  String get gifProxyDescription =>
      'Envía un enlace al GIF en lugar de subir una copia a tu servidor. Más rápido, y el archivo no pasa por tu servidor — el proxy y los servidores de cada persona ven la petición.';

  @override
  String get gifProxyServer => 'Servidor proxy de GIF';

  @override
  String get goToPage => 'Ir a la página';

  @override
  String get group => 'Grupo';

  @override
  String get groupName => 'Nombre del grupo';

  @override
  String get guestAccess => 'Acceso de invitados';

  @override
  String get heartsAndSymbols => 'Corazones y símbolos';

  @override
  String get hexColor => 'Hex';

  @override
  String get hide => 'Ocultar';

  @override
  String get home => 'Inicio';

  @override
  String get homeserver => 'Servidor';

  @override
  String get hue => 'Tono';

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
  String get invitation => 'Invitación';

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
  String invitedBy(String name) {
    return 'Invitación de $name';
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
  String get lightness => 'Luminosidad';

  @override
  String get liquid => 'Liquid';

  @override
  String get loading => 'Cargando…';

  @override
  String get loadingDevices => 'Cargando dispositivos…';

  @override
  String get location => 'Ubicación';

  @override
  String get locationInputHelp =>
      'Pega \"lat, lon\", un URI geo: o un enlace de OpenStreetMap / Google Maps.';

  @override
  String get locationInputHint => 'Coordenadas o enlace de mapa';

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
  String get markUnread => 'Marcar como no leído';

  @override
  String get member => 'Miembro';

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
  String get messageHistory => 'Historial de mensajes';

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
  String get moreResults => 'Más resultados';

  @override
  String get muted => 'Silenciado';

  @override
  String get myStickers => 'Mis stickers';

  @override
  String get name => 'Nombre';

  @override
  String get newCategory => 'Nueva categoría';

  @override
  String get newChat => 'Nuevo chat';

  @override
  String get newGroup => 'Nuevo grupo';

  @override
  String get newMessages => 'Mensajes nuevos';

  @override
  String get newRoomVersion => 'Nueva versión de la sala';

  @override
  String get newSpace => 'Nuevo espacio';

  @override
  String get nextPage => 'Página siguiente';

  @override
  String get noDevicesWithEncryptionKeys =>
      'No se encontraron dispositivos con claves de cifrado';

  @override
  String get noFavoriteGifsHint =>
      'Aún no hay GIFs favoritos. Pasa el cursor sobre un GIF y pulsa la estrella para guardarlo aquí.';

  @override
  String get noGifsFound => 'No se encontraron GIF.';

  @override
  String get noMatchingMembers => 'No hay miembros que coincidan.';

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
      'Aún no hay paquetes de stickers.\nUsa «Gestionar paquetes» para añadir tus propios stickers o únete a salas que compartan paquetes.';

  @override
  String get noTopicSet => 'Sin tema';

  @override
  String get normal => 'Normal';

  @override
  String get notEncrypted => 'Sin cifrar';

  @override
  String get notJoined => 'No unidos';

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
  String ofPages(int total) {
    return 'de $total';
  }

  @override
  String get ok => 'OK';

  @override
  String get online => 'En línea';

  @override
  String get opacity => 'Opacidad';

  @override
  String get openMap => 'Abrir mapa';

  @override
  String get openPreview => 'Abrir vista previa';

  @override
  String get openSettings => 'Abrir ajustes';

  @override
  String optionNumber(int number) {
    return 'Opción $number';
  }

  @override
  String get or => 'o';

  @override
  String get otherDeviceShowsShield =>
      '¿El otro dispositivo muestra un escudo verde?';

  @override
  String get owner => 'Propietario';

  @override
  String get packEmpty => 'Este paquete está vacío.';

  @override
  String get password => 'Contraseña';

  @override
  String get pasteThemeCode => 'Pegar un código de tema';

  @override
  String get pauseGifsDescription =>
      'Detiene las animaciones GIF mientras la ventana está en segundo plano.';

  @override
  String get pauseGifsTitle => 'Pausar GIFs en segundo plano';

  @override
  String get permissions => 'Permisos';

  @override
  String get pin => 'Fijar';

  @override
  String get pinned => 'Fijado';

  @override
  String get pinnedMessages => 'Mensajes fijados';

  @override
  String get playVideo => 'Reproducir vídeo';

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
  String get previousPage => 'Página anterior';

  @override
  String get privacy => 'Privacidad';

  @override
  String get public => 'Público';

  @override
  String get publicSpace => 'Espacio público';

  @override
  String get publishToDirectory => 'Publicar en el directorio de salas';

  @override
  String get question => 'Pregunta';

  @override
  String get quit => 'Salir';

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
  String get removeBanner => 'Quitar banner';

  @override
  String get removeFromFavorites => 'Quitar de favoritos';

  @override
  String get removeImage => 'Quitar';

  @override
  String get removeMessages => 'Eliminar mensajes';

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
  String get requests => 'Solicitudes';

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
  String get resetToTheme => 'Empezar de nuevo desde el tema Material';

  @override
  String get resetZoom => 'Restablecer zoom';

  @override
  String get right => 'Derecha';

  @override
  String get roomAddress => 'Dirección de la sala';

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
  String get saturation => 'Saturación';

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
  String get scanQrToVerify =>
      'Escanea este código QR con el otro dispositivo o compara emojis en su lugar.';

  @override
  String get searchAllRooms => 'Buscar en todas las salas';

  @override
  String get searchAllRoomsPrompt =>
      'Busca en tu historial de mensajes de todas las salas.';

  @override
  String get searchFurtherBack => 'Buscar más atrás';

  @override
  String get searchGifs => 'Buscar GIF…';

  @override
  String get searchEmoji => 'Buscar emoji…';

  @override
  String get defaultRole => 'Rol predeterminado';

  @override
  String get notifyEveryone => 'Notificar a todos (@room)';

  @override
  String get changePermissions => 'Cambiar permisos';

  @override
  String get changeHistoryVisibility => 'Cambiar visibilidad del historial';

  @override
  String get roles => 'Roles';

  @override
  String get assignRole => 'Asignar rol';

  @override
  String get noEmojiFound => 'No se encontraron emojis';

  @override
  String get overview => 'Resumen';

  @override
  String get changeAccess => 'Cambiar ajustes de acceso';

  @override
  String searchResultCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count resultados',
      one: '$count resultado',
    );
    return '$_temp0';
  }

  @override
  String get serverAcl => 'Cambiar ACL del servidor';

  @override
  String get manageSpaceRooms => 'Gestionar salas de este espacio';

  @override
  String get deleteOwnMessages => 'Eliminar mensajes propios';

  @override
  String get shareLocation => 'Compartir ubicación';

  @override
  String get shareTheme => 'Compartir tema';

  @override
  String get showApp => 'Mostrar Protea';

  @override
  String get startCalls => 'Iniciar llamadas';

  @override
  String messageDeletedFrom(String name) {
    return 'Mensaje de $name eliminado';
  }

  @override
  String get searchMembersHint => 'Buscar miembros…';

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
  String get sendMessages => 'Enviar mensajes';

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
  String get showReadReceiptsDescription =>
      'Muestra debajo de un mensaje quién lo ha leído.';

  @override
  String get showReadReceiptsTitle => 'Mostrar confirmaciones de lectura';

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
  String get sinceInvited => 'Desde la invitación';

  @override
  String get sinceJoined => 'Desde la unión';

  @override
  String get skip => 'Omitir';

  @override
  String get small => 'Pequeño';

  @override
  String get smileys => 'Caritas';

  @override
  String get smoothScrollingDescription =>
      'Se desliza suavemente al usar la rueda del ratón en lugar de saltar a pasos.';

  @override
  String get smoothScrollingTitle => 'Desplazamiento suave';

  @override
  String get space => 'Espacio';

  @override
  String get spaceHasNoRooms => 'Este espacio no tiene salas.';

  @override
  String get spaceLobby => 'Vestíbulo del espacio';

  @override
  String get spaceMembers => 'Miembros del espacio';

  @override
  String get spaceName => 'Nombre del espacio';

  @override
  String get spaceSettings => 'Ajustes del espacio';

  @override
  String get spacesListPosition => 'Posición de la barra de espacios';

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
  String get themeCode => 'Código de tema';

  @override
  String get themeCodeApplied => 'Tema aplicado.';

  @override
  String get themeCodeCopied => 'Código del tema copiado.';

  @override
  String get themeCodeInvalid => 'Eso no es un código de tema de Protea.';

  @override
  String get themeDefault => 'Color del tema';

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
  String get trending => 'Tendencias';

  @override
  String get typeTwoCharactersToSearch =>
      'Escribe al menos dos caracteres para buscar en el directorio de usuarios.';

  @override
  String get unban => 'Levantar veto';

  @override
  String get unblock => 'Desbloquear';

  @override
  String get unknownChannel => 'Canal desconocido';

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
  String get whoCanJoin => 'Quién puede unirse';

  @override
  String get withdrawKnock => 'Retirar la llamada';

  @override
  String get workspace => 'Predeterminado';

  @override
  String get yesterday => 'Ayer';

  @override
  String get yesVerify => 'Sí, verificar';

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

  @override
  String get setNickname => 'Establecer apodo';

  @override
  String get nicknameHint =>
      'Solo tú puedes verlo. Déjalo vacío para quitarlo.';

  @override
  String get roomNameResetHint =>
      'Déjalo vacío para restablecer el nombre predeterminado';

  @override
  String get reactions => 'Reacciones';

  @override
  String get viewReactions => 'Ver reacciones';

  @override
  String get about => 'Acerca de';

  @override
  String get versionLabel => 'Versión';

  @override
  String get buildLabel => 'Compilación';

  @override
  String get commitLabel => 'Commit';

  @override
  String get localBuild => 'Compilación local';

  @override
  String get copyVersionInfo => 'Copiar información de versión';

  @override
  String get checkForUpdates => 'Buscar actualizaciones';

  @override
  String get checkingForUpdates => 'Buscando actualizaciones…';

  @override
  String get upToDate => 'Protea está actualizado.';

  @override
  String updateAvailable(String version) {
    return 'Protea $version está disponible';
  }

  @override
  String get preReleaseBadge => 'Beta';

  @override
  String updateCheckFailed(String error) {
    return 'No se pudieron buscar actualizaciones: $error';
  }

  @override
  String get installAndRestart => 'Instalar y reiniciar';

  @override
  String get downloadUpdate => 'Descargar';

  @override
  String downloadingUpdate(int percent) {
    return 'Descargando… $percent %';
  }

  @override
  String get installingUpdate =>
      'Instalando — Protea se reiniciará en un momento.';

  @override
  String updateInstallFailed(String error) {
    return 'La actualización falló: $error';
  }

  @override
  String get releaseNotes => 'Notas de la versión';

  @override
  String get allReleases => 'Todas las versiones';

  @override
  String get autoCheckUpdatesTitle => 'Buscar actualizaciones automáticamente';

  @override
  String get autoCheckUpdatesDescription =>
      'Busca una nueva versión en GitHub una vez al día.';

  @override
  String get betaUpdatesTitle => 'Incluir versiones beta';

  @override
  String get betaUpdatesDescription =>
      'Ofrecer también versiones preliminares. Reciben las novedades antes, pero pueden ser menos estables.';

  @override
  String get updateManualInstall =>
      'Esta copia de Protea no puede actualizarse sola (Flatpak, macOS o no instalada con el script de instalación). Descarga la nueva versión e instálala igual que instalaste esta.';

  @override
  String get updateNeedsAdmin =>
      'La instalación necesita permisos de administrador; se te pedirán cuando Protea se haya cerrado.';

  @override
  String updatedTo(String version) {
    return 'Protea se actualizó a $version.';
  }

  @override
  String get updateFailedTitle => 'La actualización falló';

  @override
  String updateFailedBody(String version) {
    return 'No se pudo instalar Protea $version, así que se volvió a iniciar esta versión. Los detalles están en el registro:';
  }

  @override
  String get viewUpdate => 'Ver';
}
