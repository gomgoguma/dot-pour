import 'package:flutter/material.dart';

const ink = Color(0xff211f1c);
const paper = Color(0xfff7f5f0);
const muted = Color(0xff78736b);
const line = Color(0xffe5e0d7);
const controlLine = Color(0xffd8d0c4);
const copper = Color(0xffd96b43);
const copperText = Color(0xffb95330);
const mint = Color(0xfff2eee6);
const softCopper = Color(0xfffcf2ec);

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
  fontFamily: 'Pretendard',
  splashFactory: InkSparkle.splashFactory,
  scaffoldBackgroundColor: paper,
  colorScheme: ColorScheme.fromSeed(
    seedColor: ink,
    primary: ink,
    surface: paper,
  ),
  appBarTheme: const AppBarTheme(
    toolbarHeight: 52,
    backgroundColor: paper,
    foregroundColor: ink,
    surfaceTintColor: Colors.transparent,
    centerTitle: false,
  ),
  textTheme: const TextTheme(
    bodyMedium: TextStyle(color: ink, letterSpacing: -.2),
    bodyLarge: TextStyle(color: ink, letterSpacing: -.2),
    labelLarge: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      letterSpacing: -.2,
    ),
  ),
  navigationBarTheme: NavigationBarThemeData(
    backgroundColor: paper,
    surfaceTintColor: Colors.transparent,
    indicatorColor: mint,
    height: 64,
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
      borderSide: const BorderSide(color: controlLine),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: controlLine),
    ),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      minimumSize: const Size(0, 50),
      backgroundColor: ink,
      foregroundColor: Colors.white,
      disabledBackgroundColor: const Color(0xffe9e5de),
      disabledForegroundColor: const Color(0xff928c83),
      side: BorderSide.none,
      shadowColor: const Color(0x30211f1c),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ).copyWith(
      elevation: WidgetStateProperty.resolveWith(
        (states) =>
            states.contains(WidgetState.disabled) ||
                    states.contains(WidgetState.pressed)
                ? 0
                : 1,
      ),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      minimumSize: const Size(0, 46),
      side: const BorderSide(color: controlLine),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
  ),
  switchTheme: SwitchThemeData(
    thumbColor: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.selected) ? Colors.white : muted,
    ),
    trackColor: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.selected) ? copper : mint,
    ),
    trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
  ),
  dialogTheme: DialogTheme(
    backgroundColor: paper,
    surfaceTintColor: Colors.transparent,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(24),
      side: const BorderSide(color: line),
    ),
  ),
  chipTheme: ChipThemeData(
    side: const BorderSide(color: line),
    backgroundColor: Colors.white,
    selectedColor: mint,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  ),
  dividerTheme: const DividerThemeData(color: line, thickness: 1),
);

class SurfaceCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  const SurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: line),
      boxShadow: const [
        BoxShadow(
          color: Color(0x08372b1e),
          blurRadius: 18,
          spreadRadius: -2,
          offset: Offset(0, 4),
        ),
        BoxShadow(
          color: Color(0x04372b1e),
          blurRadius: 3,
          offset: Offset(0, 1),
        ),
      ],
    ),
    child: child,
  );
}

ButtonStyle secondaryButtonStyle() => FilledButton.styleFrom(
  backgroundColor: mint,
  foregroundColor: ink,
  elevation: 0,
  side: const BorderSide(color: controlLine),
);

ButtonStyle circleControlStyle() => IconButton.styleFrom(
  backgroundColor: Colors.white,
  foregroundColor: ink,
  side: const BorderSide(color: controlLine),
  shape: const CircleBorder(),
  fixedSize: const Size(40, 40),
  padding: const EdgeInsets.all(8),
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
