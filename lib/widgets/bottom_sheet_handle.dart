import 'package:flutter/material.dart';
import 'package:yugo/theme/app_theme.dart';

class BottomSheetHandle extends StatelessWidget {
  const BottomSheetHandle({super.key, this.color});

  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 3,
      decoration: BoxDecoration(
        color: color ?? AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}


