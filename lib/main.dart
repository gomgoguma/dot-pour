import 'dart:async';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'brew_controller.dart';
import 'brew_session.dart';
import 'ui/brew_chart.dart';
import 'ui/brew_timer.dart';
import 'ui/brew_metrics.dart';
import 'ui/brand_mark.dart';
import 'ui/brew_settings.dart';
import 'ui/device_picker.dart';
import 'ui/recipe_library.dart';
import 'ui/scale_selection.dart';
import 'ui/scale_status.dart';
import 'ui/style.dart';
import 'ui/weighing_panel.dart';

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
    final now = DateTime.now();
    final name = TextEditingController(text: '${now.month}월 ${now.day}일 추출');
    String? error;
    bool busy = false;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setDialogState) => AlertDialog(
                  title: const Text('레시피 저장'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${number(c.brew.water)}g · ${clockText(c.brew.seconds)}${c.demo ? ' · 데모 기록' : ''}',
                        style: const TextStyle(color: muted),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '추출 그래프와 붓기 단계를 저장합니다.',
                        style: TextStyle(
                          color: muted,
                          fontSize: 12,
                          height: 1.6,
                        ),
                      ),
                      const SizedBox(height: 18),
                      TextField(
                        key: const Key('save-recipe-name'),
                        controller: name,
                        autofocus: true,
                        maxLength: 60,
                        decoration: InputDecoration(
                          labelText: '레시피 이름',
                          errorText: error,
                        ),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: busy ? null : () => Navigator.pop(context),
                      child: const Text('나중에'),
                    ),
                    FilledButton(
                      onPressed:
                          busy
                              ? null
                              : () async {
                                if (name.text.trim().isEmpty) {
                                  setDialogState(() => error = '이름을 입력해 주세요.');
                                  return;
                                }
                                setDialogState(() => busy = true);
                                try {
                                  await c.saveFinished(name.text.trim());
                                  if (context.mounted) Navigator.pop(context);
                                } catch (e) {
                                  if (context.mounted) {
                                    setDialogState(() {
                                      error = '$e';
                                      busy = false;
                                    });
                                  }
                                }
                              },
                      child: Text(busy ? '저장 중…' : '저장'),
                    ),
                  ],
                ),
          ),
    );
    // Dialog route animations may still have references to its text field.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    name.dispose();
  }

  Future<void> _finish() async {
    c.finish();
    if (c.canSave) await _save();
  }

  int _page = 0;
  bool _espresso = false;

  void _openBrewing() {
    setState(() {
      _page = 0;
      _espresso = false;
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
          toolbarHeight: 64,
          titleSpacing: 24,
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
                        fontSize: 22,
                        fontWeight: FontWeight.w500,
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
                        foregroundColor: muted,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      icon: Icon(
                        scale.connected
                            ? Icons.bluetooth_connected
                            : Icons.bluetooth,
                        size: 16,
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
                    preferredSize: const Size.fromHeight(52),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 608),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Row(
                            children: [
                              Flexible(child: _modeTab('Pour over', false)),
                              const SizedBox(width: 26),
                              Flexible(child: _modeTab('Espresso', true)),
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
          _ => _espresso ? _espressoPlaceholder() : _brewing(),
        },
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_page == 0 && !_espresso)
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 608),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 10, 24, 8),
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

  Widget _modeTab(String label, bool espresso) {
    final selected = _espresso == espresso;
    return Semantics(
      selected: selected,
      child: TextButton(
        onPressed:
            c.brew.active || c.starting || c.taring
                ? null
                : () {
                  FocusScope.of(context).unfocus();
                  setState(() {
                    _espresso = espresso;
                    _ratioInputValid = true;
                  });
                },
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 12),
          foregroundColor: selected ? ink : muted,
          disabledForegroundColor: selected ? ink : muted,
          shape: const RoundedRectangleBorder(),
          side: BorderSide.none,
        ),
        child: Container(
          padding: const EdgeInsets.only(bottom: 9),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: selected ? copper : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 19,
                letterSpacing: -0.5,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (c.setup)
          FilledButton.icon(
            onPressed:
                c.canStart && _ratioInputValid
                    ? () {
                      FocusScope.of(context).unfocus();
                      c.start();
                    }
                    : null,
            icon: const Icon(Icons.play_arrow_rounded, size: 20),
            label: Text(c.starting ? '영점 확인 중…' : '추출 시작'),
          )
        else if (brew.active)
          FilledButton.icon(
            onPressed: _finish,
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
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 24),
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
                const Divider(height: 24),
                BrewRatioInput(
                  ratio: brew.ratio,
                  enabled: !c.starting && !c.taring,
                  onChanged: c.configureRatio,
                  onValidityChanged: _onRatioValidityChanged,
                ),
              ] else ...[
                Text(
                  '원두 ${number(brew.dose)}g  /  1:${number(brew.ratio)}',
                  style: const TextStyle(fontSize: 12, color: muted),
                ),
                BrewMetrics(
                  water: brew.water,
                  target: brew.target,
                  percent: brew.percent,
                  flow: brew.flow,
                  holdingMeasurement: brew.active && brew.holdingMeasurement,
                  liveWeight:
                      !c.demo &&
                              scale.fresh &&
                              scale.reading?.overloaded == true
                          ? '저울 용량 초과'
                          : '저울 ${c.currentGrams?.toStringAsFixed(1) ?? '—'} g',
                ),
                const Divider(height: 20),
                BrewTimer(
                  seconds: brew.seconds,
                  phase: brew.phase,
                  reached: brew.reached,
                ),
                const SizedBox(height: 10),
                BrewChart(
                  points: brew.points,
                  reference: c.reference,
                  target: brew.target,
                  seconds: brew.seconds,
                  height: MediaQuery.sizeOf(context).width < 500 ? 155 : 190,
                ),
              ],
              if (c.guide != null) ...[const SizedBox(height: 20), _guide()],
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
