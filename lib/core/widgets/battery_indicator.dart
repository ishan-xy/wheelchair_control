import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class BatteryIndicator extends StatelessWidget {
  final int? percent;
  final bool delayed;

  const BatteryIndicator({
    super.key,
    required this.percent,
    this.delayed = false,
  });

  @override
  Widget build(BuildContext context) {
    final value = percent?.clamp(0, 100);
    final available = value != null;
    final color = _colorFor(value, delayed);
    final label = available ? '$value%' : 'Unavailable';
    final semanticLabel = available
        ? 'Wheelchair battery $value percent${delayed ? ', delayed' : ''}'
        : 'Wheelchair battery information unavailable';

    return Semantics(
      label: semanticLabel,
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CustomPaint(
              size: const Size(25, 14),
              painter: _BatteryIconPainter(
                fraction: available ? value / 100 : 0,
                color: color,
                unavailable: !available,
              ),
            ),
            const SizedBox(width: 7),
            Text(
              label,
              maxLines: 1,
              style: TextStyle(
                color: available ? AppColors.text : AppColors.textMuted,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 7),
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          ],
        ),
      ),
    );
  }

  Color _colorFor(int? value, bool delayed) {
    if (value == null) return AppColors.textDim;
    if (delayed) return AppColors.warning;
    if (value <= 15) return AppColors.danger;
    if (value <= 30) return AppColors.warning;
    return AppColors.success;
  }
}

class _BatteryIconPainter extends CustomPainter {
  final double fraction;
  final Color color;
  final bool unavailable;

  const _BatteryIconPainter({
    required this.fraction,
    required this.color,
    required this.unavailable,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(1, 1, size.width - 5, size.height - 2),
      const Radius.circular(2),
    );
    final outline = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRRect(body, outline);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
            size.width - 3, size.height * 0.34, 2, size.height * 0.32),
        const Radius.circular(1),
      ),
      Paint()..color = color,
    );

    if (!unavailable && fraction > 0) {
      final inner = Rect.fromLTWH(
        3,
        3,
        (size.width - 9) * fraction.clamp(0, 1),
        size.height - 6,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(inner, const Radius.circular(1)),
        Paint()..color = color,
      );
    }

    if (unavailable) {
      canvas.drawLine(
        const Offset(2, 13),
        Offset(size.width - 4, 1),
        Paint()
          ..color = AppColors.textMuted
          ..strokeWidth = 1.8
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_BatteryIconPainter oldDelegate) =>
      oldDelegate.fraction != fraction ||
      oldDelegate.color != color ||
      oldDelegate.unavailable != unavailable;
}
