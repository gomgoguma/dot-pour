import 'package:flutter/material.dart';

class BrandMark extends StatelessWidget {
  final double size;
  const BrandMark({super.key, this.size = 32});
  @override
  Widget build(BuildContext context) => Image.asset(
    'assets/brand/dot-pour-drop.png',
    width: size,
    height: size,
    filterQuality: FilterQuality.high,
    semanticLabel: 'Dot Pour 물방울 로고',
  );
}
