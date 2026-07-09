import 'package:flutter/material.dart';
import '../app/app_theme.dart';

class ScreenHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color titleColor;

  const ScreenHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.titleColor = AppColors.title,
  });

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: titleColor,
            ),
          ),
          Text(
            subtitle,
            style: const TextStyle(color: Colors.grey, fontSize: 14),
          ),
        ],
      );
}
