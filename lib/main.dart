import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'brew_session.dart';
import 'dot_scale.dart';

const ink = Color(0xff202b27);
const paper = Color(0xfff6f3eb);
const accent = Color(0xffd6f18c);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(DotPourApp(preferences: await SharedPreferences.getInstance()));
}

class DotPourApp extends StatelessWidget {
  final SharedPreferences preferences;
  const DotPourApp({super.key, required this.preferences});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Dot Pour',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: paper,
      colorScheme: ColorScheme.fromSeed(seedColor: ink, surface: paper),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    ),
    home: BrewScreen(preferences: preferences),
  );
}

class BrewScreen extends StatefulWidget {
  final SharedPreferences preferences;
  const BrewScreen({super.key, required this.preferences});
  @override
  State<BrewScreen> createState() => _BrewScreenState();
}

class _BrewScreenState extends State<BrewScreen> {
  final _scale = DotScale();
  final _brew = BrewSession();
  final _form = GlobalKey<FormState>();
  late final TextEditingController _dose;
  late final TextEditingController _ratio;
  late final Timer _ticker;
  DateTime? _lastSample;
  bool _demo = false, _demoPouring = false, _alerted = false;
  double _demoWeight = 0;
  String? _notice;

  @override
  void initState() {
    super.initState();
    final dose = widget.preferences.getDouble('dose') ?? 20;
    final ratio = widget.preferences.getDouble('ratio') ?? 16;
    if (BrewSession.validate(dose, ratio) == null) {
      _brew.dose = dose;
      _brew.ratio = ratio;
    }
    _dose = TextEditingController(text: _number(_brew.dose));
    _ratio = TextEditingController(text: _number(_brew.ratio));
    _scale.addListener(_onScale);
    _ticker = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (_demo && _brew.active) {
        if (_demoPouring) _demoWeight += 0.6;
        _brew.update(_demoWeight);
        _targetAlert();
      } else if (!_demo && _brew.active && !_scale.fresh) {
        _interrupt('무게 데이터가 멈췄습니다. 연결을 확인하고 새 추출을 시작해 주세요.');
      }
      if (mounted) setState(() {});
    });
  }

  String _number(double n) =>
      n == n.roundToDouble() ? n.toInt().toString() : '$n';
  double _parse(String text) =>
      double.tryParse(text.trim().replaceAll(',', '.')) ?? double.nan;
  bool get _setup => _brew.phase == BrewPhase.setup;
  bool get _usable => _demo || (_scale.fresh && !_scale.reading!.overloaded);

  void _onScale() {
    if (!mounted || _demo) return;
    if (_brew.active) {
      if (!_scale.connected || !_scale.gramsConfirmed) {
        _interrupt('연결이 끊겨 추출을 중단했습니다. 다시 연결한 뒤 새로 시작해 주세요.');
      } else if (_scale.reading?.overloaded == true) {
        _interrupt('저울 용량을 초과했습니다. 추출을 중단했습니다.');
      } else if (_scale.fresh && _lastSample != _scale.lastReading) {
        _lastSample = _scale.lastReading;
        if (_brew.vesselRemoved(_scale.reading!.grams)) {
          _interrupt('시작 무게보다 2g 이상 줄었습니다. 용기 위치나 영점을 확인해 주세요.');
        } else {
          _brew.update(_scale.reading!.grams);
          _targetAlert();
        }
      }
    }
    setState(() {});
  }

  void _keepAwake(bool enabled) {
    unawaited(
      WakelockPlus.toggle(enable: enabled).catchError((Object error) {
        debugPrint('Screen wake lock unavailable: $error');
      }),
    );
  }

  void _targetAlert() {
    if (_brew.reached && !_alerted) {
      _alerted = true;
      unawaited(HapticFeedback.mediumImpact());
      unawaited(SystemSound.play(SystemSoundType.click));
    }
  }

  void _interrupt(String message) {
    _brew.interrupt();
    _demoPouring = false;
    _notice = message;
    _keepAwake(false);
  }

  void _start() {
    if (!_form.currentState!.validate() || !_usable || _scale.busy) return;
    final dose = _parse(_dose.text), ratio = _parse(_ratio.text);
    _brew.start(
      rawGrams: _demo ? _demoWeight : _scale.reading!.grams,
      dose: dose,
      ratio: ratio,
    );
    _lastSample = _scale.lastReading;
    _notice = null;
    _alerted = false;
    _keepAwake(true);
    unawaited(widget.preferences.setDouble('dose', dose));
    unawaited(widget.preferences.setDouble('ratio', ratio));
    setState(() {});
  }

  void _reset() {
    _brew.reset();
    _demoWeight = 0;
    _demoPouring = false;
    _notice = null;
    _keepAwake(false);
    setState(() {});
  }

  Future<void> _toggleDemo() async {
    if (_brew.active || _scale.busy) return;
    await _scale.disconnect();
    if (!mounted) return;
    _demo = !_demo;
    _reset();
  }

  void _editRecipe() {
    final dose = _parse(_dose.text), ratio = _parse(_ratio.text);
    if (BrewSession.validate(dose, ratio) == null) {
      _brew.dose = dose;
      _brew.ratio = ratio;
    }
    setState(() {});
  }

  Future<void> _devices() async {
    if (_demo || _brew.active || _scale.busy) return;
    var showAll = false;
    unawaited(_scale.scan());
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setSheetState) => AnimatedBuilder(
                  animation: _scale,
                  builder: (context, _) {
                    final devices =
                        _scale.devices.values
                            .where((d) => showAll || DotScale.likelyDot(d))
                            .toList()
                          ..sort((a, b) => b.rssi.compareTo(a.rssi));
                    return SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                        child: SizedBox(
                          height: MediaQuery.sizeOf(context).height * 0.65,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '도트 연결',
                                style:
                                    Theme.of(context).textTheme.headlineSmall,
                              ),
                              const SizedBox(height: 8),
                              const Text('도트를 켜고, 연결 중인 TIMEMORE 앱을 종료해 주세요.'),
                              if (_scale.scanning || _scale.busy) ...[
                                const SizedBox(height: 16),
                                const LinearProgressIndicator(),
                              ],
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('모든 BLE 기기 보기'),
                                subtitle: const Text('이름이 바뀐 도트가 검색되지 않을 때'),
                                value: showAll,
                                onChanged:
                                    (value) =>
                                        setSheetState(() => showAll = value),
                              ),
                              if (_scale.error case final error?)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Text(
                                    error,
                                    style: const TextStyle(color: Colors.red),
                                  ),
                                ),
                              Expanded(
                                child:
                                    devices.isEmpty
                                        ? Center(
                                          child: Text(
                                            _scale.scanning
                                                ? '근처 도트를 찾고 있습니다…'
                                                : '검색된 기기가 없습니다. 전원과 권한을 확인해 주세요.',
                                            textAlign: TextAlign.center,
                                          ),
                                        )
                                        : ListView.builder(
                                          itemCount: devices.length,
                                          itemBuilder: (context, index) {
                                            final device = devices[index];
                                            return ListTile(
                                              contentPadding: EdgeInsets.zero,
                                              leading: const Icon(
                                                Icons.bluetooth,
                                              ),
                                              title: Text(
                                                device.advertisement.name ??
                                                    '이름 없는 BLE 기기',
                                              ),
                                              subtitle: Text(
                                                '${device.peripheral.uuid}\n${device.rssi} dBm',
                                              ),
                                              trailing: const Icon(
                                                Icons.chevron_right,
                                              ),
                                              enabled: !_scale.busy,
                                              onTap: () async {
                                                await _scale.connect(device);
                                                if (context.mounted &&
                                                    _scale.connected) {
                                                  Navigator.pop(context);
                                                }
                                              },
                                            );
                                          },
                                        ),
                              ),
                              OutlinedButton.icon(
                                onPressed:
                                    _scale.busy || _scale.scanning
                                        ? null
                                        : _scale.scan,
                                icon: const Icon(Icons.refresh),
                                label: const Text('다시 검색'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
          ),
    );
    await _scale.stopScan();
  }

  @override
  Widget build(BuildContext context) {
    final phase = switch (_brew.phase) {
      BrewPhase.setup => '나만의 비율로, 한 잔',
      BrewPhase.ready => '물을 부으면 시작해요',
      BrewPhase.pouring => _brew.reached ? '목표 물량에 도달했어요' : '천천히, 원하는 만큼',
      BrewPhase.finished => '오늘의 한 잔',
      BrewPhase.interrupted => '추출이 중단되었어요',
    };
    final seconds = _brew.elapsed.inSeconds;
    final timer =
        '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Row(
                  children: [
                    const Icon(Icons.circle, size: 16, color: ink),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'dot pour',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -1,
                          ),
                        ),
                      ),
                    ),
                    if (_demo)
                      const Chip(
                        label: Text('DEMO'),
                        avatar: Icon(Icons.science_outlined, size: 16),
                      )
                    else
                      TextButton.icon(
                        onPressed:
                            _brew.active || _scale.busy
                                ? null
                                : (_scale.connected
                                    ? () => _scale.disconnect()
                                    : _devices),
                        icon: Icon(
                          _scale.connected
                              ? Icons.bluetooth_connected
                              : Icons.bluetooth,
                        ),
                        label: Text(_scale.connected ? '연결 해제' : '도트 연결'),
                      ),
                  ],
                ),
                const SizedBox(height: 22),
                Text(
                  phase,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _demo
                      ? '가상 저울로 진행률을 미리 확인해 보세요.'
                      : _scale.connected
                      ? '${_scale.deviceName} · ${_scale.battery == null ? '배터리 확인 중' : '배터리 ${_scale.battery}%'}'
                      : 'TIMEMORE Black Mirror Dot과 함께하는 브루잉',
                  style: const TextStyle(color: Color(0xff626c65)),
                ),
                const SizedBox(height: 24),
                Form(
                  key: _form,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _dose,
                          enabled: _setup,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: '원두량',
                            suffixText: 'g',
                          ),
                          validator:
                              (_) => BrewSession.validate(
                                _parse(_dose.text),
                                _parse(_ratio.text),
                              ),
                          onChanged: (_) => _editRecipe(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _ratio,
                          enabled: _setup,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: '원두 : 물',
                            prefixText: '1 : ',
                          ),
                          validator:
                              (_) =>
                                  BrewSession.validate(
                                            _parse(_dose.text),
                                            _parse(_ratio.text),
                                          ) ==
                                          null
                                      ? null
                                      : '입력값을 확인해 주세요.',
                          onChanged: (_) => _editRecipe(),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children:
                      [15, 16, 16.7, 17, 18]
                          .map(
                            (ratio) => ChoiceChip(
                              label: Text('1:$ratio'),
                              selected: _parse(_ratio.text) == ratio,
                              onSelected:
                                  _setup
                                      ? (_) {
                                        _ratio.text = '$ratio';
                                        _editRecipe();
                                      }
                                      : null,
                            ),
                          )
                          .toList(),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: ink,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            _brew.phase == BrewPhase.finished
                                ? '최종 진행률'
                                : '목표 물량 대비',
                            style: const TextStyle(color: Colors.white70),
                          ),
                          const Spacer(),
                          Text(
                            timer,
                            style: const TextStyle(
                              color: accent,
                              fontSize: 20,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Semantics(
                        label: '진행률 ${_brew.percent.toStringAsFixed(1)} 퍼센트',
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '${_brew.percent.toStringAsFixed(1)}%',
                            style: const TextStyle(
                              color: accent,
                              fontSize: 84,
                              height: 1.15,
                              letterSpacing: -5,
                              fontWeight: FontWeight.w600,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: (_brew.percent / 100).clamp(0, 1),
                          minHeight: 8,
                          backgroundColor: Colors.white12,
                          color: accent,
                        ),
                      ),
                      const SizedBox(height: 22),
                      Wrap(
                        spacing: 28,
                        runSpacing: 16,
                        children: [
                          _metric(
                            '부은 물',
                            '${_brew.water.toStringAsFixed(1)} g',
                          ),
                          _metric('목표 물량', '${_number(_brew.target)} g'),
                          _metric(
                            _brew.extra > 0 ? '초과 물량' : '남은 물',
                            '${(_brew.extra > 0 ? _brew.extra : _brew.remaining).toStringAsFixed(1)} g',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (_notice != null || (!_demo && _scale.error != null))
                  _message(_notice ?? _scale.error!),
                if (!_demo && _scale.connected)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _scale.reading?.overloaded == true
                                ? '저울 용량 초과'
                                : !_scale.fresh
                                ? '무게 수신 대기 중…'
                                : '현재 저울  ${_scale.reading!.grams.toStringAsFixed(1)} g',
                            style: const TextStyle(color: Color(0xff626c65)),
                          ),
                        ),
                        TextButton(
                          onPressed:
                              _setup && !_scale.busy ? _scale.tare : null,
                          child: const Text('영점 맞추기'),
                        ),
                      ],
                    ),
                  ),
                if (_demo && _brew.active) ...[
                  Row(
                    children: [
                      const Icon(Icons.science_outlined),
                      const SizedBox(width: 8),
                      const Expanded(child: Text('데모 물량 조절')),
                      TextButton(
                        onPressed:
                            () => setState(() => _demoPouring = !_demoPouring),
                        child: Text(_demoPouring ? '붓기 멈춤' : '자동으로 붓기'),
                      ),
                    ],
                  ),
                  Slider(
                    value: _demoWeight.clamp(0, _brew.target * 1.25),
                    max: _brew.target * 1.25,
                    onChanged:
                        (value) => setState(() {
                          _demoPouring = false;
                          _demoWeight = value;
                        }),
                  ),
                ],
                if (_setup)
                  FilledButton.icon(
                    onPressed: _usable && !_scale.busy ? _start : null,
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('추출 시작'),
                  )
                else if (_brew.active)
                  OutlinedButton.icon(
                    onPressed: () {
                      _brew.finish();
                      _demoPouring = false;
                      _keepAwake(false);
                      setState(() {});
                    },
                    icon: const Icon(Icons.stop_rounded),
                    label: const Text('추출 마치기'),
                  )
                else
                  FilledButton.icon(
                    onPressed: _reset,
                    icon: const Icon(Icons.refresh),
                    label: const Text('새 추출'),
                  ),
                const SizedBox(height: 14),
                Text(
                  _setup
                      ? '서버·드리퍼·원두를 모두 올린 뒤 시작하세요.\n시작 시점의 무게를 0%로 잡고, 첫 물줄기에 타이머가 켜집니다.'
                      : '서버와 드리퍼를 저울 위에 그대로 두세요.\n목표에 도달한 뒤에도 물량과 시간은 계속 표시됩니다.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.7,
                    color: Color(0xff626c65),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: _brew.active || _scale.busy ? null : _toggleDemo,
                  child: Text(_demo ? '데모 종료 · 실제 도트 연결' : '저울 없이 데모로 체험'),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _metric(String label, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(color: Colors.white60, fontSize: 12)),
      const SizedBox(height: 6),
      Text(
        value,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
      ),
    ],
  );
  Widget _message(String text) => Container(
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xffffe6ce),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Text(text),
  );
  @override
  void dispose() {
    _ticker.cancel();
    _scale.removeListener(_onScale);
    _scale.dispose();
    _dose.dispose();
    _ratio.dispose();
    _keepAwake(false);
    super.dispose();
  }
}
