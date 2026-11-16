import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'brew_session.dart';
import 'dot_scale.dart';
import 'recipe.dart';
import 'recipe_store.dart';

class BrewController extends ChangeNotifier {
  final SharedPreferences preferences;
  final DotScale scale = DotScale();
  final BrewSession brew;
  late final RecipeStore store;
  late final Timer _ticker;
  List<BrewRecipe> recipes = [];
  BrewRecipe? reference;
  String? notice;
  String? savedId;
  bool demo = false, demoAuto = false, libraryBusy = false;
  double demoWeight = 0;
  bool _alerted = false, _disposed = false;
  DateTime? _lastSample;
  DateTime _lastTick = DateTime.now();

  BrewController(this.preferences, {BrewSession? session})
    : brew = session ?? BrewSession() {
    store = RecipeStore(preferences);
    final dose = preferences.getDouble('dose') ?? 20;
    final ratio = preferences.getDouble('ratio') ?? 16;
    if (BrewSession.validate(dose, ratio) == null) {
      brew.dose = dose;
      brew.ratio = ratio;
    }
    try {
      recipes = store.load();
    } catch (_) {
      notice = '저장된 레시피를 읽지 못했습니다. 기존 데이터는 보존됩니다.';
    }
    scale.addListener(_onScale);
    _ticker = Timer.periodic(const Duration(milliseconds: 100), (_) {
      final now = DateTime.now();
      final dt = now.difference(_lastTick).inMicroseconds / 1000000;
      _lastTick = now;
      if (!brew.active) return;
      if (demo) {
        if (demoAuto) {
          if (reference != null) {
            demoWeight = math.max(
              demoWeight,
              reference!.expectedGrams(brew.seconds + 0.3),
            );
          } else {
            demoWeight += 6 * dt.clamp(0, 0.5);
          }
        }
        brew.update(demoWeight);
        _targetAlert();
      } else if (!scale.fresh) {
        interrupt('무게 데이터가 멈췄습니다. 연결을 확인하고 새 추출을 시작해 주세요.');
      }
      brew.tick();
      _changed();
    });
  }
  bool get setup => brew.phase == BrewPhase.setup;
  bool get usable => demo || (scale.fresh && !scale.reading!.overloaded);
  bool get canSave => brew.canSave && savedId == null && !libraryBusy;
  PourGuide? get guide =>
      reference == null
          ? null
          : PourGuide(reference!, brew.seconds, brew.water);
  void _changed() {
    if (!_disposed) notifyListeners();
  }

  void _onScale() {
    if (_disposed || demo) return;
    if (brew.active) {
      if (!scale.connected || !scale.gramsConfirmed) {
        interrupt('연결이 끊겨 추출을 중단했습니다. 다시 연결한 뒤 새로 시작해 주세요.');
      } else if (scale.reading?.overloaded == true) {
        interrupt('저울 용량을 초과했습니다. 추출을 중단했습니다.');
      } else if (scale.fresh && _lastSample != scale.lastReading) {
        _lastSample = scale.lastReading;
        if (brew.vesselRemoved(scale.reading!.grams)) {
          interrupt('시작 무게보다 2g 이상 줄었습니다. 용기 위치와 영점을 확인해 주세요.');
        } else {
          brew.update(
            scale.reading!.grams,
            flowGramsPerSecond: scale.reading!.flow,
          );
          _targetAlert();
        }
      }
    }
    _changed();
  }

  void _keepAwake(bool enabled) {
    unawaited(
      WakelockPlus.toggle(enable: enabled).catchError((Object e) {
        debugPrint('Wake lock unavailable: $e');
      }),
    );
  }

  void _targetAlert() {
    if (brew.reached && !_alerted) {
      _alerted = true;
      unawaited(HapticFeedback.mediumImpact());
      unawaited(SystemSound.play(SystemSoundType.click));
    }
  }

  Future<void> configure(double dose, double ratio) async {
    if (!setup) return;
    final error = BrewSession.validate(dose, ratio);
    if (error != null) throw ArgumentError(error);
    reference = reference?.scaled(dose, ratio);
    brew.dose = dose;
    brew.ratio = ratio;
    await preferences.setDouble('dose', dose);
    await preferences.setDouble('ratio', ratio);
    _changed();
  }

  void start() {
    if (!setup || !usable || scale.busy) return;
    brew.start(
      rawGrams: demo ? demoWeight : scale.reading!.grams,
      dose: brew.dose,
      ratio: brew.ratio,
    );
    _lastSample = scale.lastReading;
    _lastTick = DateTime.now();
    savedId = null;
    notice = null;
    _alerted = false;
    _keepAwake(true);
    _changed();
  }

  void finish() {
    if (!brew.active) return;
    brew.finish();
    demoAuto = false;
    _keepAwake(false);
    _changed();
  }

  void interrupt(String message) {
    brew.interrupt();
    demoAuto = false;
    notice = message;
    _keepAwake(false);
    _changed();
  }

  void reset() {
    brew.reset();
    demoWeight = 0;
    demoAuto = false;
    savedId = null;
    notice = null;
    _keepAwake(false);
    _changed();
  }

  Future<void> toggleDemo() async {
    if (brew.active || scale.busy) return;
    await scale.disconnect();
    if (_disposed) return;
    demo = !demo;
    reset();
  }

  void toggleDemoPour() {
    demoAuto = !demoAuto;
    _changed();
  }

  void setDemoWeight(double value) {
    demoAuto = false;
    demoWeight = value;
    _changed();
  }

  Future<void> loadRecipe(BrewRecipe recipe) async {
    if (brew.active) return;
    reset();
    reference = recipe;
    await configure(recipe.dose, recipe.ratio);
    _changed();
  }

  void clearRecipe() {
    if (setup) {
      reference = null;
      _changed();
    }
  }

  Future<void> upsertRecipe(BrewRecipe recipe) async {
    if (libraryBusy) throw StateError('저장 중입니다. 잠시 후 다시 시도해 주세요.');
    libraryBusy = true;
    _changed();
    try {
      final next = [recipe, ...recipes.where((r) => r.id != recipe.id)];
      await store.save(next);
      recipes = next;
    } finally {
      libraryBusy = false;
      _changed();
    }
  }

  Future<void> saveFinished(String name) async {
    if (!canSave) throw StateError('저장할 새 추출 기록이 없습니다.');
    final recipe = brew.toRecipe(name, isDemo: demo);
    await upsertRecipe(recipe);
    savedId = recipe.id;
    _changed();
  }

  Future<void> deleteRecipe(String id) async {
    if (libraryBusy) return;
    libraryBusy = true;
    _changed();
    try {
      final next = recipes.where((r) => r.id != id).toList();
      await store.save(next);
      recipes = next;
      if (setup && reference?.id == id) reference = null;
    } finally {
      libraryBusy = false;
      _changed();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _ticker.cancel();
    scale.removeListener(_onScale);
    scale.dispose();
    _keepAwake(false);
    super.dispose();
  }
}
