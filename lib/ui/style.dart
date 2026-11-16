import 'package:flutter/material.dart';

const ink = Color(0xff233e36);
const paper = Color(0xfff7f5ef);
const muted = Color(0xff7a8079);
const line = Color(0xffe5e8df);
const copper = Color(0xffb78154);
const mint = Color(0xffe8efe6);

String number(double value, [int decimals = 1]) =>
    value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toStringAsFixed(decimals);
String clockText(double seconds) {
  final value = seconds.floor().clamp(0, 864000);
  return '${(value ~/ 60).toString().padLeft(2, '0')}:${(value % 60).toString().padLeft(2, '0')}';
}

double parseNumber(String text) =>
    double.tryParse(text.trim().replaceAll(',', '.')) ?? double.nan;

ThemeData pourTheme() => ThemeData(
  useMaterial3: true,
  scaffoldBackgroundColor: paper,
  colorScheme: ColorScheme.fromSeed(
    seedColor: ink,
    primary: ink,
    surface: paper,
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: paper,
    foregroundColor: ink,
    surfaceTintColor: Colors.transparent,
    centerTitle: false,
  ),
  textTheme: const TextTheme(
    bodyMedium: TextStyle(color: ink),
    bodyLarge: TextStyle(color: ink),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: line),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: line),
    ),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      minimumSize: const Size(0, 50),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      minimumSize: const Size(0, 46),
      side: const BorderSide(color: line),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  ),
  chipTheme: ChipThemeData(
    side: BorderSide.none,
    backgroundColor: Colors.white,
    selectedColor: mint,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  ),
  dividerTheme: const DividerThemeData(color: line, thickness: 1),
);

class SectionLabel extends StatelessWidget {
  final String title;
  final Widget? trailing;
  const SectionLabel(this.title, {super.key, this.trailing});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
        ),
        if (trailing != null) trailing!,
      ],
    ),
  );
}
