import 'dart:async';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'brew_controller.dart';
import 'brew_session.dart';
import 'ui/brew_chart.dart';
import 'ui/brew_metrics.dart';
import 'ui/brand_mark.dart';
import 'ui/brew_settings.dart';
import 'ui/device_picker.dart';
import 'ui/recipe_library.dart';
import 'ui/scale_selection.dart';
import 'ui/scale_status.dart';
import 'ui/style.dart';
import 'ui/weighing_panel.dart';
import 'ui/basic_scale.dart';
import 'ui/save_recipe_dialog.dart';

enum _HomeMode { scale, pourOver, espresso }

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(DotPourApp(preferences: await SharedPreferences.getInstance()));
}

class DotPourApp extends StatelessWidget {
  final SharedPreferences preferences;
  final BrewController? controller;
  const DotPourApp({super.key, required this.preferences, this.controller});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Dot Pour',
    debugShowCheckedModeBanner: false,
    theme: pourTheme(),
    home: BrewScreen(preferences: preferences, controller: controller),
  );
}

class BrewScreen extends StatefulWidget {
  final SharedPreferences preferences;
  final BrewController? controller;
  const BrewScreen({super.key, required this.preferences, this.controller});
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
                                  (c.brew.active && !scale.connected)
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
                            scale.connected ? '연결됨' : '연결',
                            style: const TextStyle(fontSize: 12),
                          ),
                          if (scale.connected && scale.battery != null) ...[
                            const SizedBox(width: 7),
                            Text(
                              '${scale.battery}%',
                              key: const Key('scale-battery'),
                              semanticsLabel: '저울 배터리 ${scale.battery}%',
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
              _page == 0 && c.setup
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
                                child: _modeTab('Scale', _HomeMode.scale),
                              ),
                              Expanded(
                                child: _modeTab(
                                  'Pour over',
                                  _HomeMode.pourOver,
                                ),
                              ),
                              Expanded(
                                child: _modeTab('Espresso', _HomeMode.espresso),
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
            _HomeMode.espresso => _espressoPlaceholder(),
          },
        },
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_page == 0 && _mode == _HomeMode.pourOver)
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 608),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                    child: _brewActions(),
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
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.water_drop_outlined, size: 22),
                  selectedIcon: Icon(Icons.water_drop, size: 22),
                  label: '브루잉',
                ),
                NavigationDestination(
                  icon: Icon(Icons.menu_book_outlined, size: 22),
                  selectedIcon: Icon(Icons.menu_book_rounded, size: 22),
                  label: '레시피',
                ),
                NavigationDestination(
                  icon: Icon(Icons.tune_rounded, size: 22),
                  label: '설정',
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
            c.brew.active || c.starting || c.taring
                ? null
                : () {
                  FocusScope.of(context).unfocus();
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

  Widget _espressoPlaceholder() => const Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.local_cafe_outlined, size: 40, color: copper),
        SizedBox(height: 20),
        Text(
          'Espresso',
          style: TextStyle(fontSize: 27, fontWeight: FontWeight.w500),
        ),
        SizedBox(height: 8),
        Text('준비 중', style: TextStyle(color: muted, fontSize: 13)),
      ],
    ),
  );

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
                    Text(c.starting ? '영점 확인 중…' : '추출 시작'),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  c.starting
                      ? '저울의 영점을 맞추고 있어요'
                      : showConditions
                      ? '원두 ${number(dose)}g · 1:${number(brew.ratio)} · 물 ${number(dose * brew.ratio)}g'
                      : !_ratioInputValid
                      ? '비율을 확인해 주세요'
                      : '원두량을 확인해 주세요',
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
            label: const Text('추출 마치기'),
          )
        else
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: c.reset,
                  child: const Text('새 추출'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: c.canSave ? _save : null,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  child: Text(c.savedId != null ? '저장 완료' : '레시피로 저장'),
                ),
              ),
            ],
          ),
        if (c.demoAvailable && c.setup)
          TextButton(
            onPressed: c.canChangeScale ? c.toggleDemo : null,
            child: Text(
              c.demo ? '실제 저울로 전환' : '저울 없이 데모로 체험',
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
                        tooltip: '레시피 해제',
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
                                _brewChip('원두 ${number(brew.dose)}g'),
                                _brewChip('비율 1:${number(brew.ratio)}'),
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
                                      ? '저울 용량 초과'
                                      : '저울 ${c.currentGrams?.toStringAsFixed(1) ?? '—'} g',
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
                      const SectionLabel(
                        '추출 흐름',
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
                    const Text(
                      '데모',
                      style: TextStyle(fontSize: 11, color: muted),
                    ),
                    if (brew.phase == BrewPhase.pouring)
                      TextButton(
                        onPressed: c.toggleDemoLift,
                        child: Text(
                          c.demoLifted ? '기구 놓기' : '기구 들기',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    TextButton(
                      onPressed: c.demoLifted ? null : c.toggleDemoPour,
                      child: Text(
                        c.demoAuto
                            ? '붓기 멈춤'
                            : c.reference != null
                            ? '가이드 따라 붓기'
                            : '자동으로 붓기',
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
          const Text(
            '설정',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 28),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.bluetooth, size: 22),
            title: const Text('저울 연결'),
            subtitle: Text(
              c.demo
                  ? '데모 사용 중'
                  : c.scale!.connected
                  ? '연결됨'
                  : '연결 안 됨',
            ),
            trailing: const Icon(Icons.chevron_right, size: 20),
            onTap:
                c.demo ||
                        c.scale!.busy ||
                        c.starting ||
                        c.taring ||
                        (c.brew.active && !c.scale!.connected)
                    ? null
                    : _connection,
          ),
          const Divider(),
          ListTile(
            key: const Key('change-scale'),
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.scale_outlined, size: 22),
            title: const Text('저울 모델'),
            subtitle: Text(c.scale!.info.name),
            trailing: const Icon(Icons.chevron_right, size: 20),
            onTap: c.canChangeScale ? _selectScale : null,
          ),
          if (c.demoAvailable) ...[
            const Divider(),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('데모 모드'),
              subtitle: const Text('저울 없이 브루잉 체험'),
              value: c.demo,
              onChanged: c.canChangeScale ? (_) => c.toggleDemo() : null,
            ),
          ],
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
            ? '기록된 곡선을 따라 부어 주세요'
            : guide.step == null
            ? '물 붓기 완료 · 추출 대기'
            : guide.waiting
            ? '${guide.stepIndex + 1}차까지 ${number(guide.step!.start - guide.seconds, 0)}초'
            : '${guide.stepIndex + 1}차 붓기';
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
              '누적 ${number(guide.stepTarget)}g까지 · ${number(guide.targetFlow)}g/s로 붓기',
              style: const TextStyle(fontSize: 13),
            ),
          if (guide.step == null)
            Text(
              '레시피 종료 ${clockText(guide.recipe.duration)}',
              style: const TextStyle(fontSize: 13),
            ),
          const SizedBox(height: 6),
          Text(
            '지금 기준 ${number(guide.expected)}g  ·  ${difference >= 0 ? '+' : ''}${number(difference)}g 차이',
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
