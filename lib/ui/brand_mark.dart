import 'package:flutter/material.dart';
import '../l10n/language.dart';

class BrandMark extends StatelessWidget {
  final double size;
  const BrandMark({super.key, this.size = 32});
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(size * 0.23),
    child: Image.asset(
      'assets/brand/dot-pour-drops.png',
      width: size,
      height: size,
      filterQuality: FilterQuality.high,
      semanticLabel: context.l10n.logoDescription,
    ),
  );
}
