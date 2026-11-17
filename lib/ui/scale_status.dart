import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../brew_controller.dart';
import 'style.dart';

Future<void> showScaleStatus(BuildContext context, BrewController controller) =>
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
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
      final scale = c.scale;
      if (scale == null) return const SizedBox.shrink();
      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
              const SizedBox(height: 24),
              OutlinedButton(
                onPressed:
                    c.brew.active ||
                            c.starting ||
                            c.taring ||
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
      );
    },
  );
}
