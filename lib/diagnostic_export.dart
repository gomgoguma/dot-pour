import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

class DiagnosticReport {
  final String full, summary, fileName;
  DiagnosticReport({
    required this.full,
    required this.summary,
    DateTime? createdAt,
  }) : fileName =
           'dot-pour-diagnostic-${(createdAt ?? DateTime.now()).toUtc().toIso8601String().replaceAll(':', '-')}.json';
}

class DiagnosticExporter {
  /// Read back only the text just written, while the app still has focus.
  /// A successful write request alone is not a verified clipboard write.
  static Future<bool> copySummary(DiagnosticReport report) async {
    try {
      await Clipboard.setData(
        ClipboardData(text: report.summary),
      ).timeout(const Duration(seconds: 2));
      final actual = await Clipboard.getData(
        Clipboard.kTextPlain,
      ).timeout(const Duration(seconds: 2));
      return actual?.text == report.summary;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    } on TimeoutException {
      return false;
    }
  }

  /// Android's document picker chooses the location; no broad storage access.
  /// True means the complete file has been written and closed. False is cancel.
  static Future<bool> saveAndroid(DiagnosticReport report) async =>
      await const MethodChannel(
        'dot_pour/diagnostic_export',
      ).invokeMethod<bool>('save', {
        'fileName': report.fileName,
        'content': report.full,
      }) ??
      false;

  static Future<ShareResult> share(
    DiagnosticReport report,
    Rect origin,
  ) => Share.shareXFiles(
    [XFile.fromData(utf8.encode(report.full), mimeType: 'application/json')],
    fileNameOverrides: [report.fileName],
    subject: 'Dot Pour 진단 기록',
    sharePositionOrigin: origin,
  );
}
