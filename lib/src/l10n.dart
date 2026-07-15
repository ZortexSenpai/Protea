import 'package:flutter/widgets.dart';

import '../l10n/generated/app_localizations.dart';

export '../l10n/generated/app_localizations.dart';

/// Shorthand for the generated localizations: `context.l10n.someString`.
extension L10nContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
