import 'dart:async';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'brew_controller.dart';
import 'brew_session.dart';
import 'l10n/language.dart';
import 'ui/brew_chart.dart';
import 'ui/brew_metrics.dart';
import 'ui/brand_mark.dart';
import 'ui/brew_settings.dart';
import 'ui/device_picker.dart';
import 'ui/espresso_panel.dart';
import 'ui/recipe_library.dart';
import 'ui/scale_selection.dart';
import 'ui/scale_status.dart';
import 'ui/style.dart';
import 'ui/weighing_panel.dart';
import 'ui/basic_scale.dart';
import 'ui/save_recipe_dialog.dart';
import 'ui/language_picker.dart';

enum _HomeMode { scale, pourOver, espresso }

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(DotPourApp(preferences: await SharedPreferences.getInstance()));
}

class DotPourApp extends StatefulWidget {
  final SharedPreferences preferences;
  final BrewController? controller;
  const DotPourApp({super.key, required this.preferences, this.controller});

  @override
  State<DotPourApp> createState() => _DotPourAppState();
}

class _DotPourAppState extends State<DotPourApp> {
  late AppLanguage? _language = AppLanguage.saved(widget.preferences);
  late final _deviceLanguage = AppLanguage.forDevice(
    WidgetsBinding.instance.platformDispatcher.locales,
  );

  Future<bool> _applyLanguage(AppLanguage language) async {
    try {
      if (!await widget.preferences.setString(
        AppLanguage.preferenceKey,
        language.code,
      )) {
        return false;
      }
    } catch (_) {
      return false;
    }
    if (mounted) setState(() => _language = language);
    return true;
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Dot Pour',
    debugShowCheckedModeBanner: false,
    theme: pourTheme(),
    locale: (_language ?? _deviceLanguage).locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home:
        _language == null
            ? LanguagePicker(
              initialLanguage: _deviceLanguage,
              firstRun: true,
              onApply: _applyLanguage,
            )
            : BrewScreen(
              preferences: widget.preferences,
              controller: widget.controller,
              language: _language!,
              onApplyLanguage: _applyLanguage,
            ),
  );
}

class BrewScreen extends StatefulWidget {
  final SharedPreferences preferences;
  final BrewController? controller;
  final AppLanguage language;
  final Future<bool> Function(AppLanguage) onApplyLanguage;
  const BrewScreen({
    super.key,
    required this.preferences,
    this.controller,
    required this.language,
    required this.onApplyLanguage,
  });
  @override
  State<BrewScreen> createState() => _BrewScreenState();
}

class _BrewScreenState extends State<BrewScreen> {
  late final c = widget.controller ?? BrewController(widget.preferences);
  late final _version = PackageInfo.fromPlatform();
  bool _ratioInputValid = true;

  @override
  void initState() {
    super.initState();
    c.setScaleMode(_mode == _HomeMode.scale);
  }

  void _onRatioValidityChanged(bool valid) {
    if (mounted && _ratioInputValid != valid) {
      setState(() => _ratioInputValid = valid);
    }
  }

  Future<void> _selectScale() => Navigator.push(
    context,
    MaterialPageRoute<void>(
      builder: (_) => ScaleSelectionScreen(controller: c),
    ),
  );
  Future<void> _selectLanguage() => Navigator.push(
    context,
    MaterialPageRoute<void>(
      builder:
          (_) => LanguagePicker(
            initialLanguage: widget.language,
            firstRun: false,
            onApply: widget.onApplyLanguage,
          ),
    ),
  );
  Future<void> _save() async {
    if (!c.canSave) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => SaveRecipeDialog(controller: c),
    );
  }

  int _page = 0;
  late _HomeMode _mode = c.setup ? _HomeMode.scale : _HomeMode.pourOver;

  void _openBrewing() {
    if (_mode == _HomeMode.espresso) c.clearEspressoWeighing();
    c.setScaleMode(false);
    setState(() {
      _page = 0;
      _mode = _HomeMode.pourOver;
      _ratioInputValid = true;
    });
  }

  Future<void> _connection() async {
    final scale = c.scale!;
    if (scale.connected) {
      await showScaleStatus(context, c);
    } else {
      await showDevicePicker(context, scale);
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: c,
    builder: (context, _) {
      final scale = c.scale;
      if (scale == null) {
        return ScaleSelectionScreen(controller: c, firstRun: true);
      }
      return Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          toolbarHeight: 52,
          titleSpacing: 20,
          scrolledUnderElevation: 0,
          title: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Row(
                key: const Key('brew-header'),
                children: [
                  const BrandMark(size: 27),
                  const SizedBox(width: 9),
                  const Expanded(
                    child: Text(
                      'dot pour',
                      style: TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.8,
                      ),
                    ),
                  ),
                  if (c.demo)
                    const Text(
                      'DEMO',
                      style: TextStyle(
                        fontSize: 10,
                        letterSpacing: 1.5,
                        color: copper,
                      ),
                    )
                  else
                    TextButton.icon(
                      onPressed:
                          scale.busy ||
                                  c.starting ||
                                  c.taring ||
                                  (c.brewingActive && !scale.connected)
                              ? null
                              : _connection,
                      style: TextButton.styleFrom(
                        foregroundColor: ink,
                        backgroundColor: mint,
                        minimumSize: const Size(0, 36),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        shape: const StadiumBorder(
                          side: BorderSide(color: line),
                        ),
                      ),
                      icon: Icon(
                        scale.connected
                            ? Icons.bluetooth_connected
                            : Icons.bluetooth,
                        size: 18,
                        color: copper,
                      ),
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            scale.connected
                                ? context.l10n.connected
                                : context.l10n.connect,
                            style: const TextStyle(fontSize: 12),
                          ),
                          if (scale.connected && scale.battery != null) ...[
                            const SizedBox(width: 7),
                            Text(
                              '${scale.battery}%',
                              key: const Key('scale-battery'),
                              semanticsLabel: context.l10n.scaleBattery(
                                scale.battery!,
                              ),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: ink,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          bottom:
              _page == 0 && c.setup && !c.espresso.active
                  ? PreferredSize(
                    preferredSize: const Size.fromHeight(44),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 608),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Row(
                            children: [
                              Expanded(
                                child: _modeTab(
                                  context.l10n.scaleTab,
                                  _HomeMode.scale,
                                ),
                              ),
                              Expanded(
                                child: _modeTab(
                                  context.l10n.pourOverTab,
                                  _HomeMode.pourOver,
                                ),
                              ),
                              Expanded(
                                child: _modeTab(
                                  context.l10n.espressoTab,
                                  _HomeMode.espresso,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  )
                  : null,
        ),
        body: switch (_page) {
          1 => RecipeLibrary(controller: c, onRecipeLoaded: _openBrewing),
          2 => _settings(),
          _ => switch (_mode) {
            _HomeMode.scale => BasicScale(controller: c),
            _HomeMode.pourOver => _brewing(),
            _HomeMode.espresso => EspressoPanel(controller: c),
          },
        },
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_page == 0 && _mode != _HomeMode.scale)
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 608),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                    child:
                        _mode == _HomeMode.espresso
                            ? EspressoActions(controller: c)
                            : _brewActions(),
                  ),
                ),
              ),
            const Divider(height: 1),
            NavigationBar(
              selectedIndex: _page,
              onDestinationSelected: (page) {
                if (c.starting || c.taring) return;
                FocusScope.of(context).unfocus();
                setState(() {
                  _page = page;
                  _ratioInputValid = true;
                });
              },
              destinations: [
                NavigationDestination(
                  icon: Icon(Icons.water_drop_outlined, size: 22),
                  selectedIcon: Icon(Icons.water_drop, size: 22),
                  label: context.l10n.brewingTab,
                ),
                NavigationDestination(
                  icon: Icon(Icons.menu_book_outlined, size: 22),
                  selectedIcon: Icon(Icons.menu_book_rounded, size: 22),
                  label: context.l10n.recipesTab,
                ),
                NavigationDestination(
                  icon: Icon(Icons.tune_rounded, size: 22),
                  label: context.l10n.settings,
                ),
              ],
            ),
          ],
        ),
      );
    },
  );

  Widget _modeTab(String label, _HomeMode mode) {
    final selected = _mode == mode;
    return Semantics(
      selected: selected,
      child: InkWell(
        key: ValueKey('home-mode-${mode.name}'),
        onTap:
            c.brewingActive || c.starting || c.taring
                ? null
                : () {
                  FocusScope.of(context).unfocus();
                  if (_mode == _HomeMode.espresso && mode != _mode) {
                    c.clearEspressoWeighing();
                  }
                  c.setScaleMode(mode == _HomeMode.scale);
                  setState(() {
                    _mode = mode;
                    _ratioInputValid = true;
                  });
                },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: selected ? copper : line,
                width: selected ? 2.5 : 1,
              ),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 16,
              color: selected ? ink : muted,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _brewActions() {
    final brew = c.brew;
    final dose = c.setupDose;
    final showConditions =
        dose != null && c.validateDose(dose) == null && _ratioInputValid;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (c.setup)
          FilledButton(
            key: const Key('start-brew'),
            onPressed:
                c.canStart && _ratioInputValid
                    ? () {
                      FocusScope.of(context).unfocus();
                      c.start();
                    }
                    : null,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.play_arrow_rounded, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      c.starting
                          ? context.l10n.checkingZero
                          : context.l10n.startBrew,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  c.starting
                      ? context.l10n.zeroingScale
                      : showConditions
                      ? context.l10n.brewStartDetails(
                        number(dose),
                        number(brew.ratio),
                        number(dose * brew.ratio),
                      )
                      : !_ratioInputValid
                      ? context.l10n.checkRatio
                      : context.l10n.checkDose,
                  key: const Key('brew-start-conditions'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          )
        else if (brew.active)
          FilledButton.icon(
            onPressed: c.finish,
            icon: const Icon(Icons.stop_rounded, size: 18),
            label: Text(context.l10n.finishBrew),
          )
        else
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: c.reset,
                  child: Text(context.l10n.newBrew),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: c.canSave ? _save : null,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  child: Text(
                    c.savedId != null
                        ? context.l10n.saved
                        : context.l10n.saveAsRecipe,
                  ),
                ),
              ),
            ],
          ),
        if (c.demoAvailable && c.setup)
          TextButton(
            onPressed: c.canChangeScale ? c.toggleDemo : null,
            child: Text(
              c.demo ? context.l10n.switchToScale : context.l10n.tryDemo,
              style: const TextStyle(fontSize: 11, color: muted),
            ),
          ),
      ],
    );
  }

  Widget _brewing() {
    final brew = c.brew;
    final scale = c.scale!;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 608),
        child: SingleChildScrollView(
          key: const Key('brew-scroll'),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (c.reference != null)
                Row(
                  children: [
                    const Icon(Icons.bookmark_outline, size: 15, color: copper),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        c.reference!.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: copper),
                      ),
                    ),
                    if (c.setup)
                      IconButton(
                        tooltip: context.l10n.clearRecipe,
                        onPressed: c.clearRecipe,
                        icon: const Icon(Icons.close, size: 16),
                      ),
                  ],
                ),
              if (c.setup) ...[
                WeighingPanel(controller: c),
                const SizedBox(height: 12),
                BrewRatioInput(
                  ratio: brew.ratio,
                  target:
                      c.setupDose == null ? null : c.setupDose! * brew.ratio,
                  enabled: !c.starting && !c.taring,
                  onChanged: c.configureRatio,
                  onValidityChanged: _onRatioValidityChanged,
                ),
              ] else ...[
                SurfaceCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 3,
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: [
                                _brewChip(
                                  context.l10n.doseChip(number(brew.dose)),
                                ),
                                _brewChip(
                                  context.l10n.ratioChip(number(brew.ratio)),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            flex: 2,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Align(
                                alignment: Alignment.topRight,
                                child: Text(
                                  !c.demo &&
                                          scale.fresh &&
                                          scale.reading?.overloaded == true
                                      ? context.l10n.scaleOverload
                                      : context.l10n.liveScaleChip(
                                        c.currentGrams?.toStringAsFixed(1) ??
                                            '—',
                                      ),
                                  key: const Key('brew-live-weight'),
                                  textAlign: TextAlign.end,
                                  style: const TextStyle(
                                    color: muted,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w400,
                                    fontFeatures: [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      BrewMetrics(
                        water: brew.water,
                        target: brew.target,
                        percent: brew.percent,
                        flow: brew.flow,
                        seconds: brew.seconds,
                        phase: brew.phase,
                        reached: brew.reached,
                        holdingMeasurement:
                            brew.active && brew.holdingMeasurement,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SurfaceCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SectionLabel(
                        context.l10n.brewFlow,
                        trailing: Icon(
                          Icons.show_chart_rounded,
                          color: copper,
                          size: 21,
                        ),
                      ),
                      BrewChart(
                        points: brew.points,
                        reference: c.reference,
                        target: brew.target,
                        seconds: brew.seconds,
                        height:
                            MediaQuery.sizeOf(context).height < 780
                                ? 96
                                : MediaQuery.sizeOf(context).height < 820
                                ? 110
                                : 135,
                      ),
                    ],
                  ),
                ),
              ],
              if (!c.setup && c.guide != null) ...[
                const SizedBox(height: 20),
                _guide(),
              ],
              if (c.demo && brew.active) ...[
                const SizedBox(height: 20),
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      context.l10n.demo,
                      style: TextStyle(fontSize: 11, color: muted),
                    ),
                    if (brew.phase == BrewPhase.pouring)
                      TextButton(
                        onPressed: c.toggleDemoLift,
                        child: Text(
                          c.demoLifted
                              ? context.l10n.replaceEquipment
                              : context.l10n.liftEquipment,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    TextButton(
                      onPressed: c.demoLifted ? null : c.toggleDemoPour,
                      child: Text(
                        c.demoAuto
                            ? context.l10n.stopPour
                            : c.reference != null
                            ? context.l10n.followRecipe
                            : context.l10n.autoPour,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
                Slider(
                  key: const Key('demo-water'),
                  value: c.demoWeight.clamp(0, brew.target * 1.25),
                  max: brew.target * 1.25,
                  onChanged: c.demoLifted ? null : c.setDemoWeight,
                ),
              ],
              if (c.notice != null || (!c.demo && scale.error != null))
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(
                    c.notice ?? scale.error!,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.6,
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _brewChip(String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: mint,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      text,
      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
    ),
  );

  Widget _settings() => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 608),
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            context.l10n.settings,
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 28),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.bluetooth, size: 22),
            title: Text(context.l10n.scaleConnection),
            subtitle: Text(
              c.demo
                  ? context.l10n.demoActive
                  : c.scale!.connected
                  ? context.l10n.connected
                  : context.l10n.notConnected,
            ),
            trailing: const Icon(Icons.chevron_right, size: 20),
            onTap:
                c.demo ||
                        c.scale!.busy ||
                        c.starting ||
                        c.taring ||
                        (c.brewingActive && !c.scale!.connected)
                    ? null
                    : _connection,
          ),
          const Divider(),
          ListTile(
            key: const Key('change-scale'),
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.scale_outlined, size: 22),
            title: Text(context.l10n.scaleModel),
            subtitle: Text(c.scale!.info.name),
            trailing: const Icon(Icons.chevron_right, size: 20),
            onTap: c.canChangeScale ? _selectScale : null,
          ),
          if (c.demoAvailable) ...[
            const Divider(),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(context.l10n.demoMode),
              subtitle: Text(context.l10n.demoDescription),
              value: c.demo,
              onChanged: c.canChangeScale ? (_) => c.toggleDemo() : null,
            ),
          ],
          const Divider(),
          ListTile(
            key: const Key('change-language'),
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.language_rounded, size: 22),
            title: Text(context.l10n.language),
            subtitle: Text(widget.language.nameInLanguage),
            trailing: const Icon(Icons.chevron_right, size: 20),
            onTap: _selectLanguage,
          ),
          const Divider(),
          const SizedBox(height: 16),
          FutureBuilder<PackageInfo>(
            future: _version,
            builder:
                (context, snapshot) => Text(
                  snapshot.hasData
                      ? 'Dot Pour ${snapshot.data!.version}'
                      : 'Dot Pour',
                  style: const TextStyle(fontSize: 12, color: muted),
                ),
          ),
        ],
      ),
    ),
  );

  Widget _guide() {
    final guide = c.guide!;
    final title =
        guide.recipe.steps.isEmpty
            ? context.l10n.followCurve
            : guide.step == null
            ? context.l10n.pouringDone
            : guide.waiting
            ? context.l10n.nextPourIn(
              guide.stepIndex + 1,
              number(guide.step!.start - guide.seconds, 0),
            )
            : context.l10n.pourNumber(guide.stepIndex + 1);
    final difference = guide.difference;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xffefede4),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.route_outlined, size: 18, color: copper),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
              if (guide.recipe.steps.isNotEmpty)
                Text(
                  '${guide.poursDone ? guide.recipe.steps.length : guide.stepIndex + 1}/${guide.recipe.steps.length}',
                  style: const TextStyle(fontSize: 11, color: muted),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (guide.step != null)
            Text(
              context.l10n.guidePourTarget(
                number(guide.stepTarget),
                number(guide.targetFlow),
              ),
              style: const TextStyle(fontSize: 13),
            ),
          if (guide.step == null)
            Text(
              context.l10n.recipeEndsAt(clockText(guide.recipe.duration)),
              style: const TextStyle(fontSize: 13),
            ),
          const SizedBox(height: 6),
          Text(
            context.l10n.guideDifference(
              number(guide.expected),
              difference >= 0 ? '+' : '',
              number(difference),
            ),
            style: const TextStyle(fontSize: 11, color: muted),
          ),
          if (guide.recipe.steps.isNotEmpty) ...[
            const SizedBox(height: 14),
            Row(
              children: List.generate(
                guide.recipe.steps.length,
                (index) => Expanded(
                  child: Container(
                    height: 4,
                    margin: EdgeInsets.only(
                      right: index == guide.recipe.steps.length - 1 ? 0 : 4,
                    ),
                    decoration: BoxDecoration(
                      color:
                          index < guide.stepIndex
                              ? ink
                              : index == guide.stepIndex
                              ? copper
                              : line,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }
}
