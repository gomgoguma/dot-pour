import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class EspressoVessel {
  final String id, name;
  final double grams;

  const EspressoVessel({
    required this.id,
    required this.name,
    required this.grams,
  });

  Map<String, Object> toJson() => {'id': id, 'name': name, 'grams': grams};

  static EspressoVessel? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final id = json['id'];
    final name = json['name'];
    final grams = json['grams'];
    if (id is! String ||
        id.isEmpty ||
        name is! String ||
        name.trim().isEmpty ||
        grams is! num ||
        !grams.isFinite ||
        grams <= 0) {
      return null;
    }
    return EspressoVessel(id: id, name: name, grams: grams.toDouble());
  }
}

class EspressoVesselStore {
  static const key = 'espresso.vessels.v1';
  final SharedPreferences preferences;
  const EspressoVesselStore(this.preferences);

  List<EspressoVessel> load() {
    try {
      final data = jsonDecode(preferences.getString(key) ?? '[]');
      if (data is List) {
        return List.unmodifiable(
          data.map(EspressoVessel.fromJson).whereType<EspressoVessel>(),
        );
      }
    } on FormatException {
      return const [];
    }
    return const [];
  }

  Future<bool> save(List<EspressoVessel> vessels) =>
      preferences.setString(key, jsonEncode(vessels));
}
