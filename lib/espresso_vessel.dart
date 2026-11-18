import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

enum EspressoVesselKind { portafilter, dosingCup }

class EspressoVessel {
  final String id, name;
  final EspressoVesselKind kind;
  final double grams;

  const EspressoVessel({
    required this.id,
    required this.name,
    required this.kind,
    required this.grams,
  });

  Map<String, Object> toJson() => {
    'id': id,
    'name': name,
    'kind': kind.name,
    'grams': grams,
  };

  static EspressoVessel? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final id = json['id'];
    final name = json['name'];
    final grams = json['grams'];
    final kind =
        EspressoVesselKind.values
            .where((kind) => kind.name == json['kind'])
            .firstOrNull;
    if (id is! String ||
        id.isEmpty ||
        name is! String ||
        name.trim().isEmpty ||
        grams is! num ||
        !grams.isFinite ||
        grams <= 0 ||
        kind == null) {
      return null;
    }
    return EspressoVessel(
      id: id,
      name: name,
      kind: kind,
      grams: grams.toDouble(),
    );
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
