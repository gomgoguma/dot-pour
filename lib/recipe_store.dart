import 'dart:convert';
import 'l10n/language.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'recipe.dart';

class RecipeStore {
  static const key = 'dot_pour.recipes.v1';
  final SharedPreferences preferences;
  AppLocalizations get strings =>
      (AppLanguage.saved(preferences) ?? AppLanguage.korean).strings;
  RecipeStore(this.preferences);

  List<BrewRecipe> load() {
    final raw = preferences.getString(key);
    if (raw == null) return [];
    final data = jsonDecode(raw) as Map<String, dynamic>;
    if (data['version'] != 1) {
      throw FormatException(strings.invalidStorageFormat);
    }
    return (data['recipes'] as List)
        .map((e) => BrewRecipe.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> save(List<BrewRecipe> recipes) async {
    // Never silently overwrite an unreadable library. Keep its original bytes.
    try {
      load();
    } catch (_) {
      final raw = preferences.getString(key);
      if (raw != null &&
          !await preferences.setString(
            '$key.backup.${DateTime.now().microsecondsSinceEpoch}',
            raw,
          )) {
        throw StateError(strings.recipeBackupError);
      }
    }
    for (final recipe in recipes) {
      final error = recipe.validate(strings);
      if (error != null) throw FormatException(error);
    }
    if (!await preferences.setString(
      key,
      jsonEncode({
        'version': 1,
        'recipes': recipes.map((r) => r.toJson()).toList(),
      }),
    )) {
      throw StateError(strings.recipeSaveError);
    }
  }
}
