import 'package:flutter/material.dart';

const ink = Color(0xff35312e);
const paper = Color(0xfff8f5f0);
const muted = Color(0xff827a72);
const line = Color(0xffe6dfd6);
const copper = Color(0xffae5d42);
const mint = Color(0xffeee7dd);

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
  splashFactory: InkSparkle.splashFactory,
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
  navigationBarTheme: NavigationBarThemeData(
    backgroundColor: paper,
    surfaceTintColor: Colors.transparent,
    indicatorColor: mint,
    height: 68,
    labelTextStyle: WidgetStateProperty.resolveWith(
      (states) => TextStyle(
        fontSize: 11,
        color: states.contains(WidgetState.selected) ? ink : muted,
        fontWeight:
            states.contains(WidgetState.selected)
                ? FontWeight.w600
                : FontWeight.w400,
      ),
    ),
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
