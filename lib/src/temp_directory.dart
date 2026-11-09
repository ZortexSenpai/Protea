import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// [getTemporaryDirectory], created if it doesn't exist yet.
///
/// On macOS path_provider resolves it to `Library/Caches/<bundle id>` and,
/// unlike for [getApplicationCacheDirectory], never creates that folder, so
/// writing a temp file fails with a PathNotFoundException until something
/// else happens to create it.
Future<Directory> temporaryDirectory() async =>
    (await getTemporaryDirectory()).create(recursive: true);
