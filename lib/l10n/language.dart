import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'generated/app_localizations.dart';

export 'generated/app_localizations.dart';

enum AppLanguage {
  english('en', 'English'),
  korean('ko', '한국어'),
  japanese('ja', '日本語'),
  chinese('zh', '简体中文'),
  spanish('es', 'Español'),
  portuguese('pt', 'Português (Brasil)');

  const AppLanguage(this.code, this.nameInLanguage);

  static const preferenceKey = 'app.language';
  final String code;
  final String nameInLanguage;

  Locale get locale => Locale(code);
  AppLocalizations get strings => lookupAppLocalizations(locale);

  static AppLanguage? saved(SharedPreferences preferences) {
    final code = preferences.getString(preferenceKey);
    return values.where((language) => language.code == code).firstOrNull;
  }

  static AppLanguage forDevice(List<Locale> locales) {
    for (final locale in locales) {
      final language =
          values
              .where((language) => language.code == locale.languageCode)
              .firstOrNull;
      if (language != null) return language;
    }
    return english;
  }
}

extension LocalizedContext on BuildContext {
  AppLocalizations get l10n =>
      AppLocalizations.of(this) ?? AppLanguage.korean.strings;
}
