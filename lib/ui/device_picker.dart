import 'dart:async';
import 'package:flutter/material.dart';
import '../scales/scale.dart';
import 'style.dart';

Future<void> showDevicePicker(BuildContext context, CoffeeScale scale) async {
  var showAll = false;
  unawaited(scale.scan());
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder:
        (context) => StatefulBuilder(
          builder:
              (context, setSheetState) => AnimatedBuilder(
                animation: scale,
                builder: (context, _) {
                  final devices =
                      scale.devices
                          .where((d) => showAll || d.recommended)
                          .toList()
                        ..sort((a, b) => b.rssi.compareTo(a.rssi));
                  return SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
                      child: SizedBox(
                        height: MediaQuery.sizeOf(context).height * 0.65,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SectionLabel('${scale.info.shortName} 연결'),
                            const Text(
                              '저울을 켜고, 연결 중인 다른 앱을 종료해 주세요.',
                              style: TextStyle(color: muted),
                            ),
                            if (scale.scanning || scale.busy) ...[
                              const SizedBox(height: 16),
                              const LinearProgressIndicator(),
                            ],
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('모든 BLE 기기 보기'),
                              value: showAll,
                              onChanged:
                                  (value) =>
                                      setSheetState(() => showAll = value),
                            ),
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
                                          scale.scanning
                                              ? '근처 저울을 찾고 있어요…'
                                              : '전원과 블루투스 권한을 확인해 주세요.',
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
                                            title: Text(device.name),
                                            subtitle: Text(
                                              '${device.id}\n${device.rssi} dBm',
                                            ),
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
                                  scale.busy || scale.scanning
                                      ? null
                                      : scale.scan,
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
  await scale.stopScan();
}
