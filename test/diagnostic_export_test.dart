import 'dart:convert';
import 'package:dot_pour/brew_diagnostics.dart';
import 'package:dot_pour/diagnostic_export.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:share_plus_platform_interface/share_plus_platform_interface.dart';

class FileShareCapture extends SharePlatform {
  String? content, name;
  @override
  Future<ShareResult> shareXFiles(
    List<XFile> files, {
    String? subject,
    String? text,
    Rect? sharePositionOrigin,
    List<String>? fileNameOverrides,
  }) async {
    content = await files.single.readAsString();
    name = fileNameOverrides!.single;
    expect(files.single.mimeType, 'application/json');
    expect(sharePositionOrigin!.width, greaterThan(0));
    return const ShareResult('', ShareResultStatus.dismissed);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const saveChannel = MethodChannel('dot_pour/diagnostic_export');
  final report = DiagnosticReport(
    full: '{"events":[{"raw_g":160}]}',
    summary: 'short diagnostic summary',
  );
  tearDown(() {
    messenger.setMockMethodCallHandler(SystemChannels.platform, null);
    messenger.setMockMethodCallHandler(saveChannel, null);
  });

  test(
    'a successful write with an empty clipboard is not a copy success',
    () async {
      messenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (_) async => null,
      );
      expect(await DiagnosticExporter.copySummary(report), false);
    },
  );

  test('old or truncated clipboard text is not a copy success', () async {
    messenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async =>
          call.method == 'Clipboard.getData'
              ? {'text': 'short diagnostic'}
              : null,
    );
    expect(await DiagnosticExporter.copySummary(report), false);
  });

  test(
    'copy succeeds only after exact readback of the short summary',
    () async {
      String? clipboard;
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          clipboard = call.arguments['text'] as String;
        }
        if (call.method == 'Clipboard.getData') return {'text': clipboard};
        return null;
      });
      expect(await DiagnosticExporter.copySummary(report), true);
      expect(clipboard, report.summary);
      expect(clipboard, isNot(report.full));
    },
  );

  test('clipboard platform failures remain recoverable', () async {
    messenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (_) async => throw PlatformException(code: 'denied'),
    );
    expect(await DiagnosticExporter.copySummary(report), false);
  });

  test(
    'save sends the complete JSON; picker cancellation is not success',
    () async {
      messenger.setMockMethodCallHandler(saveChannel, (call) async {
        expect(call.method, 'save');
        expect(call.arguments['content'], report.full);
        expect(call.arguments['fileName'], endsWith('.json'));
        return false;
      });
      expect(await DiagnosticExporter.saveAndroid(report), false);
      messenger.setMockMethodCallHandler(saveChannel, (_) async => true);
      expect(await DiagnosticExporter.saveAndroid(report), true);
    },
  );

  test(
    'a full 1200-event capture is shared intact as a named JSON attachment',
    () async {
      var now = Duration.zero;
      final diagnostic = BrewDiagnostics(now: () => now)..start();
      for (var i = 0; i < 1500; i++) {
        now += const Duration(milliseconds: 100);
        diagnostic.input(
          raw: i.toDouble(),
          water: i.toDouble(),
          flow: 1,
          holding: false,
          overloaded: false,
          phase: 'pouring',
        );
      }
      diagnostic.stop();
      final complete = DiagnosticReport(
        full: diagnostic.export(version: 'test', platform: 'android'),
        summary: diagnostic.summary(version: 'test', platform: 'android'),
      );
      expect(complete.full.length, greaterThan(100000));
      expect(complete.summary.length, lessThan(4000));
      final original = SharePlatform.instance;
      final share = FileShareCapture();
      SharePlatform.instance = share;
      try {
        final result = await DiagnosticExporter.share(
          complete,
          const Rect.fromLTWH(0, 0, 100, 100),
        );
        expect(result.status, ShareResultStatus.dismissed);
        expect(share.content, complete.full);
        expect(share.name, complete.fileName);
        expect(
          jsonDecode(share.content!)['events'].length,
          BrewDiagnostics.capacity,
        );
      } finally {
        SharePlatform.instance = original;
      }
    },
  );
}
