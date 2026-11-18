import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'brew_session.dart';
import 'dose_preparation.dart';
import 'espresso_session.dart';
import 'espresso_vessel.dart';
import 'l10n/language.dart';
import 'manual_timer.dart';
import 'scale_flow.dart';
import 'scales/scale.dart';
import 'scales/scale_registry.dart';
import 'recipe.dart';
import 'recipe_store.dart';

class BrewController extends ChangeNotifier {
  final SharedPreferences preferences;
  static const selectedScaleKey = 'scale.model';
  AppLocalizations get strings =>
      (AppLanguage.saved(preferences) ?? AppLanguage.korean).strings;
  final ScaleRegistry scaleRegistry;
  CoffeeScale? _scale;
  CoffeeScale? get scale => _scale;
  bool changingScale = false;
  bool starting = false;
  bool taring = false;
  bool _lastFresh = false;
  final _dosePreparation = DosePreparation();
  double? _confirmedDose;
  bool _weighingDose = false;
  bool _preparingAgain = false;
  double? _doseBaseline;
  bool get canChangeScale =>
      !brew.active &&
      !espresso.active &&
      !starting &&
      !taring &&
      !changingScale &&
      !(_scale?.busy ?? false);
  final BrewSession brew;
  final espresso = EspressoSession();
  late final _espressoStore = EspressoVesselStore(preferences);
  late List<EspressoVessel> espressoVessels = _espressoStore.load();
  EspressoVessel? espressoVessel;
  bool _savingVessels = false;
  bool _editingEspressoDose = false;
  bool get espressoNeedsDose => espresso.dose == null || _editingEspressoDose;
  double? _espressoCupBaseline;
  bool _espressoSawEmptyScale = false;
  bool _espressoCupReady = false;
  bool get espressoCupReady => _espressoCupReady;
  DateTime? _espressoCupPlacement;
  double? _espressoCupWeight;
  bool get espressoNeedsEmptyConfirmation => _espressoCupBaseline == null;
  double? _espressoDoseZero;
  int _espressoZeroGeneration = 0;
  bool get espressoZeroedForDose => _espressoDoseZero != null;
  String? espressoNotice;
  bool espressoDemoPour = false;
  bool get brewingActive => brew.active || espresso.active;
  bool get canPrepareEspresso => setup && canChangeScale;
  bool get espressoReadingAvailable =>
      demo || (_scale?.fresh == true && !_scale!.reading!.overloaded);
  double? get _espressoWeightAfterTare {
    final zero = _espressoDoseZero;
    final weight = currentGrams;
    if (zero == null || weight == null || !espressoReadingAvailable) {
      return null;
    }
    return weight - zero;
  }

  double? get espressoRegistrationWeight {
    final weight = _espressoWeightAfterTare;
    return weight == null || weight < 1 ? null : weight;
  }

  double? get espressoNetDose {
    final weight = _espressoWeightAfterTare;
    return weight == null
        ? null
        : ((weight - (espressoVessel?.grams ?? 0)) * 10).round() / 10;
  }

  bool get canStartEspresso =>
      canPrepareEspresso &&
      espresso.phase == EspressoPhase.setup &&
      !espressoNeedsDose &&
      espressoCupReady &&
      espressoReadingAvailable;
  final ManualTimer scaleTimer;
  final _scaleFlow = ScaleFlow();
  bool scaleAutoStart = false;
  bool _scaleMode = true;
  bool _scaleTimerUsed = false;
  double _lastScaleFlow = 0;
  double get scaleFlow => usable ? _scaleFlow.flowAt(DateTime.now()) : 0;
  final bool demoAvailable;
  bool _notifiedSinceTick = false;
  late final RecipeStore store;
  late final Timer _ticker;
  Future<void> _ratioWrite = Future<void>.value();
  List<BrewRecipe> recipes = [];
  BrewRecipe? reference;
  String? notice;
  String? savedId;
  bool demo = false, demoAuto = false, libraryBusy = false;
  double demoWeight = 20;
  double _demoReading = 0;
  bool demoLifted = false;
  bool _alerted = false, _disposed = false;
  DateTime? _lastSample;

  BrewController(
    this.preferences, {
    BrewSession? session,
    ManualTimer? scaleTimer,
    ScaleRegistry? scaleRegistry,
    bool? allowDemo,
  }) : demoAvailable = allowDemo ?? !Platform.isAndroid,
       brew = session ?? BrewSession(),
       scaleTimer = scaleTimer ?? ManualTimer(),
       scaleRegistry = scaleRegistry ?? ScaleRegistry.standard() {
    store = RecipeStore(preferences);
    scaleAutoStart = preferences.getBool('scale.autoStart') ?? false;
    final dose = preferences.getDouble('dose') ?? 20;
    final ratio = preferences.getDouble('ratio') ?? 16;
    if (BrewSession.validate(dose, ratio) == null) {
      brew.dose = dose;
      brew.ratio = ratio;
    }
    try {
      recipes = store.load();
    } catch (_) {
      notice = strings.recipeReadError;
    }
    final selected = this.scaleRegistry.find(
      preferences.getString(selectedScaleKey),
    );
    if (selected != null) {
      final scale = selected.create();
      scale.localizations = () => strings;
      _scale = scale..addListener(_onScale);
    }
    const tickInterval = Duration(milliseconds: 100);
    final tickSeconds = tickInterval.inMilliseconds / 1000;
    _ticker = Timer.periodic(tickInterval, (_) {
      final now = DateTime.now();
      if (espresso.active) {
        if (demo) {
          if (espressoDemoPour) demoWeight += 1.8 * tickSeconds;
          espresso.observe(demoWeight, now);
        } else if (_scale?.fresh != true) {
          espressoNotice = strings.weightStopped;
          espresso.finish(now, interrupted: true);
        }
        _completeEspressoIfInactive();
        _changed();
        return;
      }
      if (!brew.active) {
        if (demo) {
          final wasReady = espressoCupReady;
          final wasEmpty = _espressoSawEmptyScale;
          _observeEspressoCup(demoWeight, now);
          if (wasReady != espressoCupReady ||
              wasEmpty != _espressoSawEmptyScale) {
            _changed();
          }
        }
        if (demo && setup && !starting && !taring) {
          _observeScaleFlow(demoWeight, now);
        }
        final flow = scaleFlow;
        if (this.scaleTimer.running || flow != _lastScaleFlow) _changed();
        _lastScaleFlow = flow;
        if (demo && setup && _confirmedDose == null && !starting && !taring) {
          final stable = hasSetupWeight;
          final ready = equipmentReady;
          final baseline = _doseBaseline;
          final suggested = suggestedDose;
          _observeDosePreparation(
            demoWeight,
            now,
            maxGap: const Duration(seconds: 2),
          );
          if (stable != hasSetupWeight ||
              ready != equipmentReady ||
              baseline != _doseBaseline ||
              suggested != suggestedDose) {
            _changed();
          }
        }
        final fresh = _scale?.fresh ?? false;
        if (_lastFresh != fresh) {
          _lastFresh = fresh;
          _changed();
        }
        return;
      }
      if (demo) {
        if (demoAuto && !demoLifted) {
          if (reference != null) {
            demoWeight = math.max(
              demoWeight,
              reference!.expectedGrams(brew.seconds + 0.3),
            );
          } else {
            demoWeight += 6 * tickSeconds;
          }
        }
        if (!demoLifted) {
          final limit = 40 * tickSeconds;
          _demoReading += (demoWeight - _demoReading).clamp(-limit, limit);
        }
        brew.ingestScaleReading(
          ScaleReading(grams: demoLifted ? -200 : _demoReading),
        );
        _targetAlert();
      } else if (!(_scale?.fresh ?? false)) {
        interrupt(strings.weightStopped);
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
  void setScaleMode(bool enabled) {
    if (_scaleMode == enabled) return;
    _scaleMode = enabled;
    _scaleFlow.reset();
  }

  Future<void> setScaleAutoStart(bool enabled) async {
    scaleAutoStart = enabled;
    _scaleFlow.reset();
    _changed();
    if (!await preferences.setBool('scale.autoStart', enabled)) {
      notice = strings.autoDetectSaveError;
      _changed();
    }
  }

  void _observeScaleFlow(double grams, DateTime at) {
    final poured = _scaleFlow.observe(grams, at);
    if (poured &&
        scaleAutoStart &&
        _scaleMode &&
        setup &&
        !starting &&
        !taring &&
        !_scaleTimerUsed &&
        !scaleTimer.running) {
      _scaleTimerUsed = true;
      scaleTimer.start();
    }
  }

  void toggleScaleTimer() {
    _scaleTimerUsed = true;
    if (scaleTimer.running) {
      scaleTimer.pause();
    } else {
      scaleTimer.start();
    }
    _changed();
  }

  void resetScaleTimer() {
    scaleTimer.reset();
    _scaleTimerUsed = false;
    _scaleFlow.reset();
    _changed();
  }

  bool get usable =>
      _scale != null &&
      !changingScale &&
      (demo || (_scale!.fresh && !_scale!.reading!.overloaded));
  bool get canSave => brew.canSave && savedId == null && !libraryBusy;
  double? get currentGrams =>
      demo
          ? (setup ? demoWeight : (demoLifted ? -200 : _demoReading))
          : (_scale?.fresh == true ? _scale!.reading!.grams : null);
  bool get hasSetupWeight =>
      (demo || _scale?.fresh == true) && _dosePreparation.hasSetupWeight;
  bool get equipmentReady => usable && _dosePreparation.readyForDose;
  bool get isDoseWeighing => _weighingDose;
  bool get preparingAgain => _preparingAgain;
  bool get addingEquipment =>
      setup &&
      isDoseWeighing &&
      _confirmedDose == null &&
      currentGrams != null &&
      _doseBaseline != null &&
      currentGrams! - _doseBaseline! > DosePreparation.maximumBeanAddition;
  double? get confirmedDose => _confirmedDose;
  double? get suggestedDose =>
      !isDoseWeighing &&
              _confirmedDose == null &&
              (demo || _scale?.fresh == true)
          ? _dosePreparation.suggestedDose
          : null;

  double? get setupDose {
    if (!setup || !isDoseWeighing) return null;
    if (_confirmedDose != null) return _confirmedDose;
    final raw = currentGrams;
    final baseline = _doseBaseline;
    if (raw == null || baseline == null || addingEquipment) return null;
    return ((raw - baseline) * 10).roundToDouble() / 10;
  }

  String? validateDose(double dose) => BrewSession.validate(
    dose,
    brew.ratio,
    maxWater: _scale?.info.capacityGrams,
    localizations: strings,
  );

  void setDose(double? dose) {
    if (!setup || starting || taring) return;
    final error = dose == null ? null : validateDose(dose);
    if (error == null) {
      _confirmedDose = dose;
      _weighingDose = dose != null;
      _preparingAgain = false;
      _doseBaseline = null;
      _dosePreparation.reset();
    }
    notice = error;
    _changed();
  }

  void returnToEquipment() {
    if (!setup || !canChangeScale) return;
    _weighingDose = false;
    _preparingAgain = true;
    _doseBaseline = null;
    _confirmedDose = null;
    _dosePreparation.reset();
    notice = null;
    _changed();
  }

  bool get canEnterDoseWeighing =>
      setup && canChangeScale && usable && !isDoseWeighing;

  void enterDoseWeighing() {
    if (!canEnterDoseWeighing) return;
    _doseBaseline = currentGrams!;
    _weighingDose = true;
    _preparingAgain = false;
    _confirmedDose = null;
    _dosePreparation.beginDoseWeighing(
      _doseBaseline!,
      demo ? DateTime.now() : _scale!.lastReading!,
    );
    notice = null;
    _changed();
  }

  bool get canTare =>
      setup &&
      !espresso.active &&
      !starting &&
      !taring &&
      !changingScale &&
      _scale != null &&
      !_scale!.busy &&
      (demo ||
          (_scale!.connected &&
              _scale!.measurementsReady &&
              _scale!.info.capabilities.tare));
  bool get canStart {
    final dose = setupDose;
    return setup &&
        !starting &&
        !taring &&
        usable &&
        !_scale!.busy &&
        dose != null &&
        validateDose(dose) == null;
  }

  Future<double?> tare() async {
    if (!canTare) return null;
    _clearEspressoDoseZero();
    _resetEspressoCup();
    final before = currentGrams;
    final baseline = _doseBaseline;
    notice = null;
    taring = true;
    _scaleFlow.reset();
    _changed();
    try {
      var zero = 0.0;
      if (demo) {
        demoWeight = 0;
      } else {
        final scale = _scale!;
        await scale.tare();
        if (_disposed) return null;
        if (scale.error != null) throw StateError(scale.error!);
        zero = (await _waitForZero(scale)).grams;
        if (_disposed || !scale.connected) return null;
      }
      // Tare changes only the scale's coordinate origin. Keep the measured
      // addition and the explicitly selected preparation stage unchanged.
      if (baseline != null) {
        _doseBaseline = before == null ? null : baseline + zero - before;
        if (before == null && _confirmedDose == null) {
          notice = strings.doseBaselineNeeded;
        }
      }
      _dosePreparation.reset();
      if (isDoseWeighing && _confirmedDose == null && _doseBaseline != null) {
        _dosePreparation.beginDoseWeighing(
          _doseBaseline!,
          demo ? DateTime.now() : _scale!.lastReading!,
        );
      }
      return zero;
    } catch (error) {
      notice = strings.tareConfirmError(error);
      return null;
    } finally {
      taring = false;
      _changed();
    }
  }

  void _clearEspressoDoseZero() {
    _espressoDoseZero = null;
    _espressoZeroGeneration++;
  }

  void selectEspressoVessel(EspressoVessel? vessel) {
    if (!canPrepareEspresso) return;
    espressoVessel = vessel;
    _clearEspressoDoseZero();
    espressoNotice = null;
    _changed();
  }

  Future<void> tareEspressoDose() async {
    if (!canPrepareEspresso || !espressoReadingAvailable) return;
    final pending = tare();
    final generation = _espressoZeroGeneration;
    final zero = await pending;
    if (_disposed || generation != _espressoZeroGeneration) return;
    _espressoDoseZero = zero;
    espressoNotice = zero == null ? notice : null;
    _changed();
  }

  void setEspressoDose(double dose, {bool measured = false}) {
    if (!canPrepareEspresso || !EspressoSession.validDose(dose)) return;
    final bareScaleZero =
        measured && espressoVessel != null ? _espressoDoseZero : null;
    _resetEspressoCup();
    _espressoCupBaseline = bareScaleZero;
    espresso.dose = dose;
    _editingEspressoDose = false;
    _clearEspressoDoseZero();
    espressoNotice = null;
    _changed();
  }

  void editEspressoDose(bool editing) {
    if (!canPrepareEspresso) return;
    _editingEspressoDose = editing;
    _clearEspressoDoseZero();
    espressoNotice = null;
    _changed();
  }

  void confirmEspressoEmptyScale() {
    if (!canPrepareEspresso ||
        espressoNeedsDose ||
        espresso.phase != EspressoPhase.setup ||
        !espressoReadingAvailable ||
        !espressoNeedsEmptyConfirmation) {
      return;
    }
    _espressoCupBaseline = currentGrams;
    _espressoSawEmptyScale = true;
    _changed();
  }

  void _resetEspressoCup() {
    _espressoCupBaseline = null;
    _espressoSawEmptyScale = false;
    _espressoCupReady = false;
    _espressoCupPlacement = null;
    _espressoCupWeight = null;
  }

  void _observeEspressoCup(double? grams, DateTime at) {
    final baseline = _espressoCupBaseline;
    if (baseline == null ||
        espressoNeedsDose ||
        espresso.phase != EspressoPhase.setup ||
        starting ||
        taring) {
      return;
    }
    if (grams == null || !grams.isFinite) {
      _espressoCupReady = false;
      _espressoCupPlacement = null;
      _espressoCupWeight = null;
      return;
    }
    final added = grams - baseline;
    if (_espressoSawEmptyScale && added < -.5) {
      _resetEspressoCup();
      return;
    }
    if (added.abs() <= .5) _espressoSawEmptyScale = true;
    if (!_espressoSawEmptyScale || added < 1) {
      _espressoCupReady = false;
      _espressoCupPlacement = null;
      _espressoCupWeight = null;
      return;
    }
    final previousWeight = _espressoCupWeight;
    if (previousWeight == null || (added - previousWeight).abs() > .5) {
      _espressoCupWeight = added;
      _espressoCupPlacement = at;
    }
    _espressoCupReady =
        at.difference(_espressoCupPlacement!) >=
        const Duration(milliseconds: 200);
  }

  bool get espressoWaitingForCup => _espressoSawEmptyScale && !espressoCupReady;

  Future<bool> registerEspressoVessel(String name) async {
    final weight = espressoRegistrationWeight;
    if (!canPrepareEspresso ||
        !espressoReadingAvailable ||
        _savingVessels ||
        weight == null ||
        name.trim().isEmpty) {
      return false;
    }
    final vessel = EspressoVessel(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name.trim(),
      grams: (weight * 10).round() / 10,
    );
    final saved = await _writeEspressoVessels([vessel, ...espressoVessels]);
    if (saved && !_disposed) clearEspressoWeighing();
    return saved;
  }

  Future<bool> removeEspressoVessel(EspressoVessel vessel) async {
    if (!canPrepareEspresso || _savingVessels) return false;
    final saved = await _writeEspressoVessels(
      espressoVessels.where((entry) => entry.id != vessel.id).toList(),
    );
    if (saved && !_disposed && espressoVessel?.id == vessel.id) {
      selectEspressoVessel(null);
    }
    return saved;
  }

  Future<bool> _writeEspressoVessels(List<EspressoVessel> next) async {
    _savingVessels = true;
    try {
      if (!await _espressoStore.save(next)) return false;
      if (_disposed) return false;
      espressoVessels = List.unmodifiable(next);
      return true;
    } catch (_) {
      return false;
    } finally {
      _savingVessels = false;
      _changed();
    }
  }

  Future<void> startEspresso({required bool automatic}) async {
    if (!canStartEspresso || _scale!.busy) return;
    final scale = _scale!;
    var baseline = currentGrams!;
    var at = DateTime.now();
    if (demo || scale.info.capabilities.tare) {
      final zero = await tare();
      if (_disposed) return;
      if (zero == null || (!demo && !scale.fresh)) {
        espressoNotice = notice ?? strings.startReadingMissing;
        _changed();
        return;
      }
      baseline = zero;
      at = demo ? DateTime.now() : scale.lastReading!;
    }
    espressoNotice = null;
    espressoDemoPour = false;
    _clearEspressoDoseZero();
    espresso.start(baseline: baseline, at: at, automatic: automatic);
    _keepAwake(true);
    _changed();
  }

  void finishEspresso() {
    espresso.finish(DateTime.now());
    _completeEspressoIfInactive();
    _changed();
  }

  void resetEspresso() {
    if (espresso.active) return;
    espresso.reset();
    _resetEspressoCup();
    espressoNotice = null;
    _changed();
  }

  void clearEspressoWeighing() {
    _clearEspressoDoseZero();
    _resetEspressoCup();
    _changed();
  }

  void toggleEspressoDemoPour() {
    if (!demo || !espresso.active) return;
    espressoDemoPour = !espressoDemoPour;
    _changed();
  }

  void _completeEspressoIfInactive() {
    if (espresso.active) return;
    espressoDemoPour = false;
    _keepAwake(false);
  }

  Future<({double grams, DateTime at})> _waitForZero(CoffeeScale scale) async {
    final zeroed = Completer<({double grams, DateTime at})>();
    void checkZero() {
      if (zeroed.isCompleted) return;
      if (!scale.connected) {
        zeroed.completeError(StateError(strings.tareDisconnected));
      } else if (scale.fresh &&
          !scale.reading!.overloaded &&
          scale.reading!.grams.abs() <= 0.3) {
        zeroed.complete((grams: scale.reading!.grams, at: scale.lastReading!));
      }
    }

    scale.addListener(checkZero);
    try {
      checkZero();
      return await zeroed.future.timeout(const Duration(seconds: 4));
    } finally {
      scale.removeListener(checkZero);
    }
  }

  PourGuide? get guide =>
      reference == null
          ? null
          : PourGuide(reference!, brew.seconds, brew.water);
  void _changed() {
    if (!_disposed) notifyListeners();
  }

  void _observeDosePreparation(
    double grams,
    DateTime at, {
    required Duration maxGap,
  }) {
    _dosePreparation.observe(grams, at, maxGap: maxGap);
    final next = _dosePreparation.setupWeight;
    if (isDoseWeighing &&
        _confirmedDose == null &&
        _doseBaseline != null &&
        next != null &&
        next - _doseBaseline! > DosePreparation.maximumBeanAddition) {
      _doseBaseline = next;
    }
  }

  void _onScale() {
    if (_disposed || demo) return;
    final scale = _scale;
    if (scale == null) return;
    final newReading = scale.fresh && _lastSample != scale.lastReading;
    if (!scale.connected || !scale.measurementsReady) {
      _clearEspressoDoseZero();
      _resetEspressoCup();
      _scaleFlow.reset();
      _dosePreparation.reset();
      _doseBaseline = null;
    } else if (setup &&
        _confirmedDose == null &&
        !starting &&
        !taring &&
        newReading) {
      final reading = scale.reading!;
      _observeDosePreparation(
        reading.overloaded ? double.nan : reading.grams,
        scale.lastReading!,
        maxGap: scale.readingTimeout,
      );
    }
    if (newReading && scale.connected && scale.measurementsReady) {
      final reading = scale.reading!;
      _observeEspressoCup(
        reading.overloaded ? null : reading.grams,
        scale.lastReading!,
      );
      if (starting || taring) {
        _scaleFlow.reset();
      } else {
        _observeScaleFlow(
          scale.reading!.overloaded ? double.nan : scale.reading!.grams,
          scale.lastReading!,
        );
      }
    }
    if (brew.active) {
      if (!scale.connected || !scale.measurementsReady) {
        interrupt(strings.brewDisconnected);
      } else if (newReading) {
        brew.ingestScaleReading(scale.reading!);
        _targetAlert();
      }
    }
    if (espresso.active) {
      if (!scale.connected || !scale.measurementsReady) {
        espressoNotice = strings.brewDisconnected;
        espresso.finish(DateTime.now(), interrupted: true);
      } else if (newReading) {
        final reading = scale.reading!;
        espresso.observe(
          reading.overloaded ? null : reading.grams,
          scale.lastReading!,
        );
      }
      _completeEspressoIfInactive();
    }
    if (newReading) {
      _lastSample = scale.lastReading;
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
      localizations: strings,
    );
    if (error != null) throw ArgumentError(error);
    reference = reference?.scaled(dose, ratio);
    brew.dose = dose;
    brew.ratio = ratio;
    await Future.wait([preferences.setDouble('dose', dose), _saveRatio(ratio)]);
    _changed();
  }

  Future<void> configureRatio(double ratio) async {
    if (!setup || starting || taring) return;
    if (!ratio.isFinite || ratio < 1 || ratio > 30) {
      throw ArgumentError(strings.ratioRange);
    }
    if (brew.ratio == ratio) return;
    brew.ratio = ratio;
    final saved = _saveRatio(ratio);
    _changed();
    await saved;
  }

  Future<void> _saveRatio(double ratio) {
    final saved = _ratioWrite.then((_) async {
      if (!await preferences.setDouble('ratio', ratio)) {
        throw StateError(strings.ratioSaveError);
      }
    });
    _ratioWrite = saved.catchError((Object _) {});
    return saved;
  }

  Future<void> start() async {
    final scale = _scale;
    if (scale == null) return;
    if (!setup ||
        espresso.active ||
        !usable ||
        scale.busy ||
        starting ||
        taring) {
      return;
    }
    final measuredDose = setupDose;
    if (measuredDose == null) return;
    final error = validateDose(measuredDose);
    if (error != null) {
      notice = error;
      _changed();
      return;
    }
    starting = true;
    notice = null;
    _changed();
    try {
      var baseline = currentGrams!;
      var baselineReadingAt = scale.lastReading;
      if (demo) {
        demoWeight = 0;
        _demoReading = 0;
        baseline = 0;
      } else if (scale.info.capabilities.tare) {
        await scale.tare();
        if (_disposed) return;
        if (scale.error != null) throw StateError(scale.error!);
        final zero = await _waitForZero(scale);
        baseline = zero.grams;
        baselineReadingAt = zero.at;
      }
      if (_disposed) return;
      if (!demo && !scale.fresh) {
        throw StateError(strings.startReadingMissing);
      }
      reference = reference?.scaled(measuredDose, brew.ratio);
      brew.start(rawGrams: baseline, dose: measuredDose, ratio: brew.ratio);
      if (!demo && baselineReadingAt != scale.lastReading) {
        brew.ingestScaleReading(scale.reading!);
      }
      _lastSample = scale.lastReading;
      savedId = null;
      notice = null;
      _alerted = false;
      _keepAwake(true);
    } catch (e) {
      notice = strings.startTareError(e);
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
    _scaleFlow.reset();
    _dosePreparation.reset();
    _confirmedDose = null;
    _weighingDose = false;
    _preparingAgain = false;
    _doseBaseline = null;
    demoWeight = 20;
    _demoReading = 0;
    demoLifted = false;
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
    _clearEspressoDoseZero();
    _resetEspressoCup();
    demo = !demo;
    reset();
  }

  void toggleDemoPour() {
    demoAuto = !demoAuto;
    _changed();
  }

  void toggleDemoLift() {
    if (!demo || brew.phase != BrewPhase.pouring) return;
    demoLifted = !demoLifted;
    _changed();
  }

  void setDemoWeight(double value) {
    demoAuto = false;
    demoWeight = value;
    if (setup && !starting && !taring) {
      _observeScaleFlow(value, DateTime.now());
    }
    _changed();
  }

  Future<void> loadRecipe(BrewRecipe recipe) async {
    if (brewingActive || starting || taring) return;
    final error = BrewSession.validate(
      recipe.dose,
      recipe.ratio,
      maxWater: _scale?.info.capacityGrams,
      localizations: strings,
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
    if (!canChangeScale) throw StateError(strings.scaleChangeBusy);
    if (_scale?.info.id == modelId) return;
    final registration = scaleRegistry.find(modelId);
    if (registration == null) throw ArgumentError(strings.unsupportedScale);
    changingScale = true;
    _changed();
    CoffeeScale? next;
    try {
      next = registration.create()..localizations = () => strings;
      await _scale?.disconnect();
      if (_disposed) return;
      if (!await preferences.setString(selectedScaleKey, modelId)) {
        throw StateError(strings.scaleSaveError);
      }
      if (_disposed) return;
      _scale?.removeListener(_onScale);
      _scale?.dispose();
      _scale = next;
      next = null;
      _scale!.addListener(_onScale);
      _dosePreparation.reset();
      _weighingDose = false;
      _preparingAgain = false;
      _doseBaseline = null;
      _confirmedDose = null;
      _clearEspressoDoseZero();
      _resetEspressoCup();
      _lastSample = null;
      _scaleFlow.reset();
      notice = null;
    } finally {
      next?.dispose();
      changingScale = false;
      _changed();
    }
  }

  Future<void> upsertRecipe(BrewRecipe recipe) async {
    if (libraryBusy) throw StateError(strings.recipeSaveBusy);
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

  Future<void> saveFinished(
    String name, {
    BrewNotes notes = const BrewNotes(),
  }) async {
    if (!canSave) throw StateError(strings.noNewBrew);
    final recipe = brew.toRecipe(name, isDemo: demo, notes: notes);
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
    _scale?.removeListener(_onScale);
    _scale?.dispose();
    _keepAwake(false);
    super.dispose();
  }
}
