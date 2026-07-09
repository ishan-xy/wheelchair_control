import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool danger;

  const PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          gradient: danger ? null : AppColors.primaryGradient,
          color: danger ? AppColors.danger.withOpacity(0.18) : null,
          borderRadius: BorderRadius.circular(28),
          border: danger ? Border.all(color: AppColors.danger.withOpacity(0.65)) : null,
          boxShadow: danger
              ? null
              : [
                  BoxShadow(
                    color: AppColors.accent.withOpacity(0.16),
                    blurRadius: 22,
                    offset: const Offset(0, 10),
                  ),
                ],
        ),
        child: FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(58),
            backgroundColor: Colors.transparent,
            disabledBackgroundColor: Colors.white.withOpacity(0.08),
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, color: danger ? AppColors.danger : Colors.black, size: 22),
                const SizedBox(width: 12),
              ],
              Text(
                label,
                style: TextStyle(
                  color: danger ? AppColors.danger : Colors.black,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      );
}
