import 'dart:io';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';
import '../brew_controller.dart';
import '../diagnostic_export.dart';
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

enum _ExportAction { copy, save, share, view }

class _ScaleStatusSheetState extends State<ScaleStatusSheet> {
  String version = '확인 중';
  bool copied = false;
  bool exporting = false;
  String? exportMessage;
  bool exportFailed = false;

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

  Future<void> _export(_ExportAction action) async {
    if (exporting) return;
    final box = context.findRenderObject() as RenderBox?;
    final origin =
        box == null
            ? const Rect.fromLTWH(0, 0, 1, 1)
            : box.localToGlobal(Offset.zero) & box.size;
    setState(() {
      exporting = true;
      copied = false;
      exportMessage = null;
      exportFailed = false;
    });
    try {
      final c = widget.controller;
      final connection = await c.scale!.connectionDiagnostics();
      final report = DiagnosticReport(
        full: c.diagnostics.export(
          version: version,
          platform: Platform.operatingSystem,
          connection: connection,
        ),
        summary: c.diagnostics.summary(
          version: version,
          platform: Platform.operatingSystem,
          connection: connection,
        ),
      );
      if (!mounted) return;
      switch (action) {
        case _ExportAction.copy:
          final verified = await DiagnosticExporter.copySummary(report);
          if (mounted) {
            setState(() {
              copied = verified;
              exportFailed = !verified;
              exportMessage =
                  verified
                      ? '클립보드 복사 확인 완료.'
                      : '복사를 확인하지 못했습니다. 파일 저장 또는 공유를 이용하세요.';
            });
          }
        case _ExportAction.save:
          final saved = await DiagnosticExporter.saveAndroid(report);
          if (mounted) {
            setState(
              () =>
                  exportMessage =
                      saved
                          ? '파일 저장 완료: ${report.fileName}'
                          : '저장 취소. 기록은 유지됩니다.',
            );
          }
        case _ExportAction.share:
          final result = await DiagnosticExporter.share(report, origin);
          if (mounted) {
            setState(
              () =>
                  exportMessage = switch (result.status) {
                    ShareResultStatus.success => '선택한 앱으로 파일을 전달했습니다.',
                    ShareResultStatus.dismissed => '공유 취소. 기록은 유지됩니다.',
                    ShareResultStatus.unavailable => '공유 결과는 선택한 앱에서 확인해 주세요.',
                  },
            );
          }
        case _ExportAction.view:
          await showDialog<void>(
            context: context,
            builder:
                (context) => AlertDialog(
                  title: const Text('진단 요약'),
                  content: SizedBox(
                    width: 500,
                    child: SingleChildScrollView(
                      child: SelectableText(
                        report.summary,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('닫기'),
                    ),
                  ],
                ),
          );
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          exportFailed = true;
          exportMessage = '내보내기 실패. 기록은 유지됩니다. 다른 방법을 선택하세요.';
        });
      }
    } finally {
      if (mounted) setState(() => exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, _) {
      final c = widget.controller;
      final scale = c.scale!;
      final diagnostic = c.diagnostics;
      final canExport =
          diagnostic.count > 0 && !diagnostic.recording && !exporting;
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
                      '기록 시작 후 계량·추출을 진행하세요. 기록을 중지하면 전체 파일 저장·공유 또는 요약 복사가 가능합니다.',
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
                          child: _Value('부은 물', '${number(c.brew.water)}g'),
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
                          exporting
                              ? null
                              : () => setState(() {
                                copied = false;
                                exportMessage = null;
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
                    if (Platform.isAndroid)
                      OutlinedButton.icon(
                        key: const Key('save-diagnostic-file'),
                        onPressed:
                            canExport
                                ? () => _export(_ExportAction.save)
                                : null,
                        icon: const Icon(Icons.save_alt, size: 18),
                        label: const Text('진단 파일 저장'),
                      ),
                    OutlinedButton.icon(
                      key: const Key('share-diagnostic-file'),
                      onPressed:
                          canExport ? () => _export(_ExportAction.share) : null,
                      icon: const Icon(Icons.share_outlined, size: 18),
                      label: const Text('진단 파일 공유'),
                    ),
                    Wrap(
                      alignment: WrapAlignment.center,
                      children: [
                        TextButton.icon(
                          key: const Key('copy-diagnostic-summary'),
                          onPressed:
                              canExport
                                  ? () => _export(_ExportAction.copy)
                                  : null,
                          icon: Icon(
                            copied ? Icons.check : Icons.copy,
                            size: 18,
                          ),
                          label: Text(copied ? '요약 복사 확인됨' : '요약 복사'),
                        ),
                        TextButton(
                          onPressed:
                              canExport
                                  ? () => _export(_ExportAction.view)
                                  : null,
                          child: const Text('요약 보기'),
                        ),
                      ],
                    ),
                    if (exporting) const LinearProgressIndicator(),
                    if (exportMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          exportMessage!,
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.5,
                            color: exportFailed ? Colors.red : ink,
                          ),
                        ),
                      ),
                    const Text(
                      '최근 최대 1,200건을 보관하며 자동 전송하지 않습니다. 전체 기록은 .json 파일에 포함됩니다. 수신 간격은 실제 무게 변화부터의 지연 시간과 다릅니다.',
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
