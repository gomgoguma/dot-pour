import 'package:flutter/material.dart';
import '../l10n/language.dart';
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
  String? version;
  bool versionUnavailable = false;

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
      if (mounted) setState(() => versionUnavailable = true);
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, _) {
      final c = widget.controller;
      final scale = c.scale;
      final displayVersion =
          version ??
          (versionUnavailable
              ? context.l10n.unavailable
              : context.l10n.checking);
      if (scale == null) return const SizedBox.shrink();
      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionLabel(context.l10n.scaleConnection),
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
                    ? (scale.battery == null
                        ? context.l10n.connected
                        : context.l10n.connectedWithBattery(scale.battery!))
                    : context.l10n.disconnected,
              ),
              const SizedBox(height: 8),
              Text(
                'Dot Pour $displayVersion',
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
                child: Text(context.l10n.disconnect),
              ),
            ],
          ),
        ),
      );
    },
  );
}
