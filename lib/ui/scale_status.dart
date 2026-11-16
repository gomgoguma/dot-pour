import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../brew_controller.dart';
import 'style.dart';

Future<void> showScaleStatus(BuildContext context, BrewController controller) =>
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => ScaleStatusSheet(controller: controller),
    );

class ScaleStatusSheet extends StatefulWidget {
  final BrewController controller;
  const ScaleStatusSheet({super.key, required this.controller});
  @override
  State<ScaleStatusSheet> createState() => _ScaleStatusSheetState();
}

class _ScaleStatusSheetState extends State<ScaleStatusSheet> {
  String version = '확인 중';
  bool copied = false;
  bool copying = false;

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() => version = '${info.version}+${info.buildNumber}');
      }
    } catch (_) {
      if (mounted) setState(() => version = '확인 불가');
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, _) {
      final c = widget.controller;
      final scale = c.scale!;
      final diagnostic = c.diagnostics;
      return SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * .85,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SectionLabel('저울 연결'),
                Text(
                  scale.info.name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  scale.connected
                      ? '연결됨${scale.battery == null ? '' : ' · 배터리 ${scale.battery}%'}'
                      : '연결 해제됨',
                ),
                const SizedBox(height: 8),
                Text(
                  'Dot Pour $version',
                  style: const TextStyle(color: muted, fontSize: 12),
                ),
                const SizedBox(height: 16),
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: const Text('반응속도 진단'),
                  children: [
                    const Text(
                      '필요할 때만 기록합니다. 시작 후 이 창을 닫고 평소처럼 계량하거나 추출해 보세요. 다시 열어 중지한 뒤 기록을 복사할 수 있습니다.',
                      style: TextStyle(fontSize: 12, height: 1.5),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _Value(
                            '저울 수신값',
                            scale.reading == null
                                ? '—'
                                : '${number(scale.reading!.grams)}g',
                          ),
                        ),
                        Expanded(
                          child: _Value('추출 물량', '${number(c.brew.water)}g'),
                        ),
                      ],
                    ),
                    if (diagnostic.recording) ...[
                      const SizedBox(height: 8),
                      Text(
                        '기록 중 · ${diagnostic.count}건${diagnostic.intervalMs == null ? '' : ' · 최근 수신 간격 ${diagnostic.intervalMs!.round()}ms'}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      Text(
                        c.brew.holdingMeasurement ? '중량 변화 제외 중' : '측정 반영 중',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                    const SizedBox(height: 12),
                    FilledButton.tonal(
                      onPressed:
                          copying
                              ? null
                              : () => setState(() {
                                copied = false;
                                if (diagnostic.recording) {
                                  diagnostic.stop();
                                } else {
                                  diagnostic.start();
                                }
                              }),
                      child: Text(
                        diagnostic.recording ? '기록 중지' : '새 진단 기록 시작',
                      ),
                    ),
                    if (diagnostic.recording)
                      OutlinedButton(
                        onPressed:
                            () => setState(
                              () => diagnostic.mark('physical-action'),
                            ),
                        child: const Text('물건을 올리거나 내린 시점 표시'),
                      ),
                    TextButton.icon(
                      onPressed:
                          diagnostic.count == 0 ||
                                  diagnostic.recording ||
                                  copying
                              ? null
                              : () async {
                                setState(() => copying = true);
                                try {
                                  final connection =
                                      await scale.connectionDiagnostics();
                                  await Clipboard.setData(
                                    ClipboardData(
                                      text: diagnostic.export(
                                        version: version,
                                        platform: Platform.operatingSystem,
                                        connection: connection,
                                      ),
                                    ),
                                  );
                                  if (mounted) setState(() => copied = true);
                                } finally {
                                  if (mounted) setState(() => copying = false);
                                }
                              },
                      icon: Icon(copied ? Icons.check : Icons.copy, size: 18),
                      label: Text(copied ? '복사했어요' : '진단 기록 복사'),
                    ),
                    const Text(
                      '최근 최대 1,200건을 앱 메모리에만 보관하며 자동 전송하지 않습니다. 수신 간격은 실제 무게 변화부터의 지연 시간과 다릅니다.',
                      style: TextStyle(fontSize: 11, color: muted, height: 1.5),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed:
                      c.brew.active ||
                              c.starting ||
                              scale.busy ||
                              !scale.connected
                          ? null
                          : () async {
                            await scale.disconnect();
                            if (context.mounted) Navigator.pop(context);
                          },
                  child: const Text('연결 해제'),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _Value extends StatelessWidget {
  final String label, value;
  const _Value(this.label, this.value);
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(fontSize: 12, color: muted)),
      Text(
        value,
        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
      ),
    ],
  );
}
