import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'brew_controller.dart';
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
  Future<void> _settings() => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder:
        (_) => BrewSettingsSheet(
          ratio: c.brew.ratio,
          scaling: c.reference != null,
          onSave: c.configureRatio,
        ),
  );
  Future<void> _library() => Navigator.push(
    context,
    MaterialPageRoute<void>(builder: (_) => RecipeLibrary(controller: c)),
  );
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

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: c,
    builder: (context, _) {
      final scale = c.scale;
      if (scale == null) {
        return ScaleSelectionScreen(controller: c, firstRun: true);
      }
      final brew = c.brew;
      if (c.diagnostics.recording) {
        final sequence = c.diagnostics.sequence;
        final raw = scale.reading?.grams;
        final water = brew.water;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          c.diagnostics.frame(sequence, raw: raw, water: water);
        });
      }
      return Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          toolbarHeight: 64,
          titleSpacing: 20,
          scrolledUnderElevation: 0,
          backgroundColor: paper,
          title: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Row(
                key: const Key('brew-header'),
                children: [
                  const BrandMark(),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'dot pour',
                      style: TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.7,
                      ),
                    ),
                  ),
                  if (c.demo)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        'DEMO',
                        style: TextStyle(
                          fontSize: 10,
                          letterSpacing: 1.5,
                          color: copper,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    )
                  else
                    TextButton.icon(
                      onPressed:
                          scale.busy ||
                                  c.starting ||
                                  (brew.active && !scale.connected)
                              ? null
                              : () async {
                                if (scale.connected) {
                                  await showScaleStatus(context, c);
                                } else {
                                  await showDevicePicker(context, scale);
                                }
                              },
                      icon: Icon(
                        scale.connected
                            ? Icons.bluetooth_connected
                            : Icons.bluetooth,
                        size: 17,
                      ),
                      label: Text(
                        scale.connected ? '연결됨' : '연결',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  IconButton(
                    tooltip: '내 레시피',
                    onPressed: c.starting ? null : _library,
                    icon: const Icon(Icons.menu_book_outlined, size: 23),
                  ),
                ],
              ),
            ),
          ),
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (c.setup)
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: c.canStart ? c.start : null,
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: Text(c.starting ? '영점 확인 중…' : '추출 시작'),
                        ),
                      )
                    else if (brew.active)
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _finish,
                          icon: const Icon(Icons.stop_rounded),
                          label: const Text('추출 마치기'),
                        ),
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
                            child: FilledButton.icon(
                              onPressed: c.canSave ? _save : null,
                              icon: Icon(
                                c.savedId != null
                                    ? Icons.check
                                    : Icons.bookmark_add_outlined,
                                size: 19,
                              ),
                              label: Text(
                                c.savedId != null ? '저장 완료' : '레시피로 저장',
                              ),
                            ),
                          ),
                        ],
                      ),
                    if (!brew.active)
                      SizedBox(
                        height: 34,
                        child: Row(
                          children: [
                            if (c.demoAvailable)
                              Expanded(
                                flex: 3,
                                child: TextButton(
                                  onPressed:
                                      c.canChangeScale ? c.toggleDemo : null,
                                  child: Text(
                                    c.demo ? '실제 저울로 전환' : '저울 없이 데모로 체험',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: muted,
                                    ),
                                  ),
                                ),
                              ),
                            Expanded(
                              flex: 2,
                              child: TextButton.icon(
                                key: const Key('change-scale'),
                                onPressed:
                                    c.canChangeScale ? _selectScale : null,
                                icon: const Icon(
                                  Icons.tune_rounded,
                                  size: 14,
                                  color: muted,
                                ),
                                label: Text(
                                  '${scale.info.shortName} · 변경',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: muted,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        body: SafeArea(
          bottom: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: SingleChildScrollView(
                key: const Key('brew-scroll'),
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    InkWell(
                      onTap: c.setup && !c.starting ? _settings : null,
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(14, 8, 10, 8),
                        decoration: BoxDecoration(
                          color: mint,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.coffee_outlined,
                              size: 17,
                              color: ink,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                c.setup
                                    ? '원두 : 물   1:${number(brew.ratio)}'
                                    : '원두 ${number(brew.dose)}g   ·   1:${number(brew.ratio)}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            if (c.setup)
                              const Row(
                                children: [
                                  Text('설정', style: TextStyle(fontSize: 11)),
                                  SizedBox(width: 4),
                                  Icon(Icons.tune_rounded, size: 17),
                                ],
                              )
                            else
                              const Icon(
                                Icons.lock_outline_rounded,
                                size: 14,
                                color: muted,
                              ),
                          ],
                        ),
                      ),
                    ),
                    if (c.reference != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.bookmark_outline,
                              size: 16,
                              color: copper,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                c.reference!.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: copper,
                                ),
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
                      ),
                    const SizedBox(height: 14),
                    if (c.setup)
                      WeighingPanel(controller: c)
                    else ...[
                      if (const bool.fromEnvironment('DOT_POUR_BLE_COMPARISON')) ...[
                        Text(
                          !scale.fresh
                              ? '실시간 저울값 · 수신 대기'
                              : scale.reading!.overloaded
                              ? '실시간 저울값 · 용량 초과'
                              : '실시간 저울값  ${scale.reading!.grams.toStringAsFixed(1)} g',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      BrewMetrics(
                        water: brew.water,
                        target: brew.target,
                        percent: brew.percent,
                        flow: brew.flow,
                      ),
                      const SizedBox(height: 12),
                      BrewTimer(
                        seconds: brew.seconds,
                        phase: brew.phase,
                        reached: brew.reached,
                        holdingMeasurement: brew.holdingMeasurement,
                      ),
                      const SizedBox(height: 14),
                      BrewChart(
                        points: brew.points,
                        reference: c.reference,
                        target: brew.target,
                        seconds: brew.seconds,
                        height:
                            MediaQuery.sizeOf(context).width < 500 ? 160 : 212,
                      ),
                    ],
                    if (c.guide != null) ...[
                      const SizedBox(height: 14),
                      _guide(),
                    ],
                    if (c.demo && brew.active) ...[
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          const Icon(
                            Icons.science_outlined,
                            size: 17,
                            color: copper,
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              '데모: 부은 물',
                              style: TextStyle(fontSize: 12, color: muted),
                            ),
                          ),
                          TextButton(
                            onPressed: c.toggleDemoPour,
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
                        onChanged: c.setDemoWeight,
                      ),
                    ],
                    if (c.notice != null || (!c.demo && scale.error != null))
                      Container(
                        margin: const EdgeInsets.only(top: 12),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xfff4e7d9),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          c.notice ?? scale.error!,
                          style: const TextStyle(fontSize: 12, height: 1.5),
                        ),
                      ),
                    if (!c.demo && scale.connected)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                scale.reading?.overloaded == true
                                    ? '저울 용량 초과'
                                    : !scale.fresh
                                    ? '무게 수신 대기 중…'
                                    : '저울 ${number(scale.reading!.grams)}g${scale.battery == null ? '' : '  ·  배터리 ${scale.battery}%'}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: muted,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (c.setup)
                      const Padding(
                        padding: EdgeInsets.only(top: 18),
                        child: Text(
                          '서버·드리퍼 TARE → 원두 계량 → 추출 시작\n원두량으로 목표 물의 무게를 계산하고 0g부터 기록합니다.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: muted,
                            fontSize: 11,
                            height: 1.6,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
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
