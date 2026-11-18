import 'dart:async';

import 'package:flutter/material.dart';
import '../l10n/language.dart';
import '../scales/scale.dart';
import 'style.dart';

Future<void> showDevicePicker(BuildContext context, CoffeeScale scale) async {
  unawaited(scale.scan());
  try {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder:
          (context) => AnimatedBuilder(
            animation: scale,
            builder: (context, _) {
              final devices =
                  scale.devices.where((device) => device.recommended).toList()
                    ..sort((a, b) => b.rssi.compareTo(a.rssi));
              return SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
                  child: SizedBox(
                    height: MediaQuery.sizeOf(context).height * 0.65,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SectionLabel(
                          context.l10n.connectModel(scale.info.shortName),
                        ),
                        Text(
                          context.l10n.scaleScanHint,
                          style: TextStyle(color: muted),
                        ),
                        if (scale.scanning || scale.busy) ...[
                          const SizedBox(height: 16),
                          const LinearProgressIndicator(),
                          const SizedBox(height: 8),
                          Text(
                            scale.discoveryStatus,
                            style: const TextStyle(color: muted, fontSize: 12),
                          ),
                        ],
                        const SizedBox(height: 8),
                        if (scale.error != null)
                          Text(
                            scale.error!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        Expanded(
                          child:
                              devices.isEmpty
                                  ? Center(
                                    child: Text(
                                      scale.scanning || scale.busy
                                          ? context.l10n.searchingScale
                                          : context.l10n.noModelFound(
                                            scale.info.shortName,
                                          ),
                                      textAlign: TextAlign.center,
                                    ),
                                  )
                                  : ListView.builder(
                                    itemCount: devices.length,
                                    itemBuilder: (context, index) {
                                      final device = devices[index];
                                      return ListTile(
                                        contentPadding: EdgeInsets.zero,
                                        leading: const Icon(Icons.bluetooth),
                                        title: Text(device.name),
                                        enabled: !scale.busy,
                                        onTap: () async {
                                          await scale.connect(device);
                                          if (context.mounted &&
                                              scale.connected) {
                                            Navigator.pop(context);
                                          }
                                        },
                                      );
                                    },
                                  ),
                        ),
                        OutlinedButton.icon(
                          onPressed:
                              scale.busy || scale.scanning ? null : scale.scan,
                          icon: const Icon(Icons.refresh),
                          label: Text(context.l10n.scanAgain),
                        ),
                        if (scale.canOpenSettings)
                          TextButton(
                            onPressed: scale.openSettings,
                            child: Text(context.l10n.openPermissions),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
    );
  } finally {
    await scale.stopScan();
  }
}
