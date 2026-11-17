import 'dart:async';
import 'package:flutter/material.dart';
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
                        SectionLabel('${scale.info.shortName} 연결'),
                        const Text(
                          '저울을 켜고, 연결 중인 다른 앱을 종료해 주세요.',
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
                                          ? '저울을 찾는 중…'
                                          : '${scale.info.shortName} 저울을 찾지 못했습니다.\n저울을 켜고 다시 검색해 주세요.',
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
                          label: const Text('다시 검색'),
                        ),
                        if (scale.canOpenSettings)
                          TextButton(
                            onPressed: scale.openSettings,
                            child: const Text('앱 권한 설정 열기'),
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
