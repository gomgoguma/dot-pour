import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'brew_session.dart';
import 'brew_diagnostics.dart';
import 'scales/scale.dart';
import 'scales/scale_registry.dart';
import 'recipe.dart';
import 'recipe_store.dart';

class BrewController extends ChangeNotifier {
  final SharedPreferences preferences;
  static const selectedScaleKey = 'scale.model';
  final ScaleRegistry scaleRegistry;
  CoffeeScale? _scale;
  CoffeeScale? get scale => _scale;
  bool changingScale = false;
  bool starting = false;
  bool _lastFresh = false;
  bool get canChangeScale =>
      !brew.active && !starting && !changingScale && !(_scale?.busy ?? false);
  final BrewSession brew;
  final bool demoAvailable;
  final diagnostics = BrewDiagnostics();
  bool diagnosticBusy = false;
  CoffeeScale? _diagnosticScale;
  bool _watchingTimings = false;
  bool _notifiedSinceTick = false;
  late final RecipeStore store;
  late final Timer _ticker;
  List<BrewRecipe> recipes = [];
  BrewRecipe? reference;
  String? notice;
  String? savedId;
  bool demo = false, demoAuto = false, libraryBusy = false;
  double demoWeight = 20;
  bool _alerted = false, _disposed = false;
  DateTime? _lastSample;
  DateTime _lastTick = DateTime.now();

  BrewController(
    this.preferences, {
    BrewSession? session,
    ScaleRegistry? scaleRegistry,
    bool? allowDemo,
  }) : demoAvailable = allowDemo ?? !Platform.isAndroid,
       brew = session ?? BrewSession(),
       scaleRegistry = scaleRegistry ?? ScaleRegistry.standard() {
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
    final selected = this.scaleRegistry.find(
      preferences.getString(selectedScaleKey),
    );
    if (selected != null) {
      _scale = selected.create()..addListener(_onScale);
    }
    _ticker = Timer.periodic(const Duration(milliseconds: 100), (_) {
      final now = DateTime.now();
      final dt = now.difference(_lastTick).inMicroseconds / 1000000;
      _lastTick = now;
      if (!brew.active) {
        final fresh = _scale?.fresh ?? false;
        if (_lastFresh != fresh) {
          _lastFresh = fresh;
          _changed();
        }
        return;
      }
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
      } else if (!(_scale?.fresh ?? false)) {
        interrupt('무게 데이터가 멈췄습니다. 연결을 확인하고 새 추출을 시작해 주세요.');
      }
      brew.tick();
      if (!demo && _notifiedSinceTick) {
        _notifiedSinceTick = false;
      } else {
        _changed();
      }
    });
  }
  bool get setup => brew.phase == BrewPhase.setup;
  bool get usable =>
      _scale != null &&
      !changingScale &&
      (demo || (_scale!.fresh && !_scale!.reading!.overloaded));
  bool get canSave => brew.canSave && savedId == null && !libraryBusy;
  double? get currentGrams =>
      demo
          ? demoWeight
          : (_scale?.fresh == true ? _scale!.reading!.grams : null);
  bool get canTare =>
      setup &&
      !starting &&
      !changingScale &&
      _scale != null &&
      !_scale!.busy &&
      (demo ||
          (_scale!.connected &&
              _scale!.measurementsReady &&
              _scale!.info.capabilities.tare));
  bool get canStart =>
      setup &&
      !starting &&
      usable &&
      !_scale!.busy &&
      BrewSession.validate(
            currentGrams!,
            brew.ratio,
            maxWater: _scale!.info.capacityGrams,
          ) ==
          null;
  Future<void> tare() async {
    if (!canTare) return;
    notice = null;
    if (demo) {
      demoWeight = 0;
    } else {
      await _scale!.tare();
    }
    _changed();
  }

  PourGuide? get guide =>
      reference == null
          ? null
          : PourGuide(reference!, brew.seconds, brew.water);
  void _changed() {
    if (!_disposed) notifyListeners();
  }

  void _renderTimings(List<FrameTiming> timings) {
    for (final timing in timings) {
      diagnostics.rendering(
        build: timing.buildDuration,
        raster: timing.rasterDuration,
        total: timing.totalSpan,
      );
    }
  }

  void _stopRenderTimings() {
    if (!_watchingTimings) return;
    SchedulerBinding.instance.removeTimingsCallback(_renderTimings);
    _watchingTimings = false;
  }

  Future<void> toggleDiagnostics() async {
    if (diagnosticBusy || _disposed) return;
    diagnosticBusy = true;
    _changed();
    try {
      if (diagnostics.recording) {
        diagnostics.stop();
        _stopRenderTimings();
        final source = _diagnosticScale;
        _diagnosticScale = null;
        diagnostics.connectionCapture =
            await source?.endDiagnosticCapture() ?? {};
      } else {
        diagnostics.start();
        _diagnosticScale = _scale;
        SchedulerBinding.instance.addTimingsCallback(_renderTimings);
        _watchingTimings = true;
        final start = await _diagnosticScale?.beginDiagnosticCapture() ?? {};
        if (_disposed) {
          await _diagnosticScale?.endDiagnosticCapture();
          return;
        }
        diagnostics.mark(
          start['available'] == true
              ? 'native_capture_started'
              : 'native_capture_unavailable',
        );
      }
    } catch (_) {
      // Optional diagnostics must not interrupt weighing or lose app events.
      if (diagnostics.recording) {
        diagnostics.mark('native_capture_start_failed');
      } else {
        diagnostics.connectionCapture = {
          'available': false,
          'reason': 'capture_stop_failed',
        };
      }
    } finally {
      diagnosticBusy = false;
      _changed();
    }
  }

  void _onScale() {
    if (_disposed || demo) return;
    final scale = _scale;
    if (scale == null) return;
    final newReading = scale.fresh && _lastSample != scale.lastReading;
    if (brew.active) {
      if (!scale.connected || !scale.measurementsReady) {
        interrupt('연결이 끊겨 추출을 중단했습니다. 다시 연결한 뒤 새로 시작해 주세요.');
      } else if (newReading) {
        brew.ingestScaleReading(scale.reading!);
        _targetAlert();
      }
    }
    if (newReading) {
      _lastSample = scale.lastReading;
      diagnostics.input(
        raw: scale.reading!.grams,
        water: brew.water,
        flow: brew.flow,
        holding: brew.holdingMeasurement,
        overloaded: scale.reading!.overloaded,
        phase: brew.phase.name,
      );
    }
    // Render on the next Flutter frame, rather than waiting for the timer.
    // The ticker skips its duplicate notification when input already updated UI.
    _notifiedSinceTick = true;
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
    if (!setup || starting) return;
    final error = BrewSession.validate(
      dose,
      ratio,
      maxWater: _scale?.info.capacityGrams,
    );
    if (error != null) throw ArgumentError(error);
    reference = reference?.scaled(dose, ratio);
    brew.dose = dose;
    brew.ratio = ratio;
    await preferences.setDouble('dose', dose);
    await preferences.setDouble('ratio', ratio);
    _changed();
  }

  Future<void> configureRatio(double ratio) async {
    if (!setup || starting) return;
    if (!ratio.isFinite || ratio < 1 || ratio > 30) {
      throw ArgumentError('비율은 1:1~1:30으로 입력해 주세요.');
    }
    brew.ratio = ratio;
    await preferences.setDouble('ratio', ratio);
    _changed();
  }

  Future<void> start() async {
    final scale = _scale;
    if (scale == null) return;
    if (!setup || !usable || scale.busy || starting) return;
    final measuredDose = currentGrams!;
    final error = BrewSession.validate(
      measuredDose,
      brew.ratio,
      maxWater: scale.info.capacityGrams,
    );
    if (error != null) {
      notice = error;
      _changed();
      return;
    }
    starting = true;
    notice = null;
    _changed();
    try {
      var baseline = measuredDose;
      if (demo) {
        demoWeight = 0;
        baseline = 0;
      } else if (scale.info.capabilities.tare) {
        await scale.tare();
        if (scale.error != null) throw StateError(scale.error!);
        // The command ACK alone is not proof that the live weight has zeroed.
        final zeroed = Completer<void>();
        void checkZero() {
          if (zeroed.isCompleted) return;
          if (!scale.connected) {
            zeroed.completeError(StateError('영점 설정 중 연결이 끊겼습니다.'));
          } else if (scale.fresh &&
              !scale.reading!.overloaded &&
              scale.reading!.grams.abs() <= 0.3) {
            zeroed.complete();
          }
        }

        scale.addListener(checkZero);
        try {
          checkZero();
          await zeroed.future.timeout(const Duration(seconds: 4));
        } finally {
          scale.removeListener(checkZero);
        }
        if (_disposed) return;
        baseline = scale.reading!.grams;
      }
      if (_disposed) return;
      reference = reference?.scaled(measuredDose, brew.ratio);
      brew.start(rawGrams: baseline, dose: measuredDose, ratio: brew.ratio);
      _lastSample = scale.lastReading;
      _lastTick = DateTime.now();
      savedId = null;
      notice = null;
      _alerted = false;
      _keepAwake(true);
    } catch (e) {
      notice = '영점을 확인하지 못해 시작하지 않았습니다. 원두 무게를 다시 계량해 주세요. ($e)';
    } finally {
      starting = false;
    }
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
    demoWeight = 20;
    demoAuto = false;
    savedId = null;
    notice = null;
    _keepAwake(false);
    _changed();
  }

  Future<void> toggleDemo() async {
    if (!demoAvailable || !canChangeScale || _scale == null) return;
    await _scale!.disconnect();
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
    if (brew.active || starting) return;
    final error = BrewSession.validate(
      recipe.dose,
      recipe.ratio,
      maxWater: _scale?.info.capacityGrams,
    );
    if (error != null) throw ArgumentError(error);
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

  Future<void> selectScale(String modelId) async {
    if (!canChangeScale) throw StateError('추출이나 연결 작업을 마친 뒤 저울을 변경해 주세요.');
    if (_scale?.info.id == modelId) return;
    final registration = scaleRegistry.find(modelId);
    if (registration == null) throw ArgumentError('지원하지 않는 저울입니다.');
    changingScale = true;
    _changed();
    CoffeeScale? next;
    try {
      next = registration.create();
      await _scale?.disconnect();
      if (_disposed) return;
      if (!await preferences.setString(selectedScaleKey, modelId)) {
        throw StateError('저울 선택을 저장하지 못했습니다. 다시 시도해 주세요.');
      }
      if (_disposed) return;
      _scale?.removeListener(_onScale);
      _scale?.dispose();
      _scale = next;
      next = null;
      _scale!.addListener(_onScale);
      _lastSample = null;
      notice = null;
    } finally {
      next?.dispose();
      changingScale = false;
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
    _stopRenderTimings();
    diagnostics.stop();
    if (_diagnosticScale != null && !diagnosticBusy) {
      unawaited(
        _diagnosticScale!.endDiagnosticCapture().catchError(
          (Object _) => <String, Object?>{},
        ),
      );
    }
    _ticker.cancel();
    _scale?.removeListener(_onScale);
    _scale?.dispose();
    _keepAwake(false);
    super.dispose();
  }
}
