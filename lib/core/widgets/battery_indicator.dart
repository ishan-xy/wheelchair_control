import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class BatteryIndicator extends StatelessWidget {
  final int percent;
  final double height;

  const BatteryIndicator({
    super.key,
    required this.percent,
    this.height = 8,
  });

  @override
  Widget build(BuildContext context) {
    final value = percent.clamp(0, 100) / 100;
    final color = percent > 25 ? AppColors.accent : AppColors.danger;

    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: Stack(
        children: [
          Container(height: height, color: Colors.white.withOpacity(0.08)),
          FractionallySizedBox(
            widthFactor: value.toDouble(),
            child: Container(
              height: height,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [AppColors.accent, color == AppColors.danger ? color : AppColors.accentDeep]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
