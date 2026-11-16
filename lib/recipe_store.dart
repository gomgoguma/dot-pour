import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'recipe.dart';

class RecipeStore {
  static const key = 'dot_pour.recipes.v1';
  final SharedPreferences preferences;
  RecipeStore(this.preferences);

  List<BrewRecipe> load() {
    final raw = preferences.getString(key);
    if (raw == null) return [];
    final data = jsonDecode(raw) as Map<String, dynamic>;
    if (data['version'] != 1) throw const FormatException('지원하지 않는 저장 형식입니다.');
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
        throw StateError('기존 레시피를 백업하지 못했습니다.');
      }
    }
    for (final recipe in recipes) {
      final error = recipe.validate();
      if (error != null) throw FormatException(error);
    }
    if (!await preferences.setString(
      key,
      jsonEncode({
        'version': 1,
        'recipes': recipes.map((r) => r.toJson()).toList(),
      }),
    )) {
      throw StateError('레시피를 저장하지 못했습니다.');
    }
  }
}
