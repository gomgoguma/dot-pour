import 'scale.dart';
import 'timemore_dot/timemore_dot_scale.dart';

class ScaleRegistration {
  final ScaleInfo info;
  final CoffeeScale Function() create;
  const ScaleRegistration(this.info, this.create);
}

/// Add a model here after implementing CoffeeScale. UI and brewing code depend
/// only on the contract; constructing an adapter must not request BLE access.
class ScaleRegistry {
  final List<ScaleRegistration> models;
  ScaleRegistry(List<ScaleRegistration> models)
    : assert(models.isNotEmpty),
      assert(models.map((m) => m.info.id).toSet().length == models.length),
      models = List.unmodifiable(models);

  factory ScaleRegistry.standard() => ScaleRegistry([
    ScaleRegistration(TimemoreDotScale.modelInfo, TimemoreDotScale.new),
  ]);

  ScaleRegistration? find(String? id) {
    for (final model in models) {
      if (model.info.id == id) return model;
    }
    return null;
  }
}
