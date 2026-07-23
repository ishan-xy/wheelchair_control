import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

class JoystickWidget extends StatefulWidget {
  final void Function(double x, double y) onMove;
  final VoidCallback onRelease;

  const JoystickWidget({
    super.key,
    required this.onMove,
    required this.onRelease,
  });

  @override
  State<JoystickWidget> createState() => _JoystickWidgetState();
}

class _JoystickWidgetState extends State<JoystickWidget> {
  Offset _offset = Offset.zero;

  void _move(Offset localPosition, Size size) {
    final radius = _radiusFor(size);
    final center = Offset(size.width / 2, size.height / 2);
    var delta = localPosition - center;
    if (delta.distance > radius) delta = delta / delta.distance * radius;
    setState(() => _offset = delta);
    widget.onMove(delta.dx / radius, -delta.dy / radius);
  }

  void _release() {
    setState(() => _offset = Offset.zero);
    widget.onRelease();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          return GestureDetector(
            onPanStart: (details) => _move(details.localPosition, size),
            onPanUpdate: (details) => _move(details.localPosition, size),
            onPanEnd: (_) => _release(),
            onPanCancel: _release,
            child: CustomPaint(
              painter: _JoystickPainter(_offset),
              size: Size.infinite,
            ),
          );
        },
      );

  double _radiusFor(Size size) => math.max(
        64,
        math.min(110, math.min(size.width, size.height) / 2 - 18),
      );
}

class _JoystickPainter extends CustomPainter {
  final Offset offset;

  const _JoystickPainter(this.offset);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final trackRadius = math.max(
        64.0, math.min(110.0, math.min(size.width, size.height) / 2 - 18));
    final knobRadius = math.max(28.0, math.min(44.0, trackRadius * 0.38));
    final safeOffset = offset.distance > trackRadius
        ? offset / offset.distance * trackRadius
        : offset;
    final knob = center + safeOffset;
    final trackPaint = Paint()..color = AppColors.background;
    final borderPaint = Paint()
      ..color = AppColors.accent.withValues(alpha: 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final crossPaint = Paint()
      ..color = AppColors.accent.withValues(alpha: 0.12)
      ..strokeWidth = 1;

    canvas.drawCircle(center, trackRadius, trackPaint);
    canvas.drawCircle(center, trackRadius, borderPaint);
    canvas.drawCircle(center, trackRadius * 0.63,
        borderPaint..color = AppColors.accent.withValues(alpha: 0.12));
    canvas.drawLine(center + Offset(-trackRadius * 0.82, 0),
        center + Offset(trackRadius * 0.82, 0), crossPaint);
    canvas.drawLine(center + Offset(0, -trackRadius * 0.82),
        center + Offset(0, trackRadius * 0.82), crossPaint);

    for (final arrow in _Arrow.values) {
      _drawArrow(canvas, arrow.tip(center, trackRadius), arrow);
    }

    canvas.drawCircle(knob + const Offset(0, 8), knobRadius,
        Paint()..color = Colors.black.withValues(alpha: 0.28));
    canvas.drawCircle(knob, knobRadius, Paint()..color = AppColors.accent);
    canvas.drawCircle(knob, knobRadius * 0.55,
        Paint()..color = AppColors.accentDeep.withValues(alpha: 0.35));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromCenter(
              center: knob,
              width: knobRadius,
              height: math.max(7, knobRadius * 0.22)),
          const Radius.circular(8)),
      Paint()..color = Colors.white.withValues(alpha: 0.34),
    );
  }

  void _drawArrow(Canvas canvas, Offset tip, _Arrow arrow) {
    const size = 7.0;
    final path = Path();
    switch (arrow) {
      case _Arrow.up:
        path
          ..moveTo(tip.dx, tip.dy - size)
          ..lineTo(tip.dx - size, tip.dy + size)
          ..lineTo(tip.dx + size, tip.dy + size);
      case _Arrow.down:
        path
          ..moveTo(tip.dx, tip.dy + size)
          ..lineTo(tip.dx - size, tip.dy - size)
          ..lineTo(tip.dx + size, tip.dy - size);
      case _Arrow.left:
        path
          ..moveTo(tip.dx - size, tip.dy)
          ..lineTo(tip.dx + size, tip.dy - size)
          ..lineTo(tip.dx + size, tip.dy + size);
      case _Arrow.right:
        path
          ..moveTo(tip.dx + size, tip.dy)
          ..lineTo(tip.dx - size, tip.dy - size)
          ..lineTo(tip.dx - size, tip.dy + size);
    }
    canvas.drawPath(path..close(),
        Paint()..color = AppColors.accent.withValues(alpha: 0.82));
  }

  @override
  bool shouldRepaint(_JoystickPainter oldDelegate) =>
      oldDelegate.offset != offset;
}

enum _Arrow {
  up,
  down,
  left,
  right;

  Offset tip(Offset center, double radius) {
    const inset = 20.0;
    return switch (this) {
      _Arrow.up => center + Offset(0, -radius + inset),
      _Arrow.down => center + Offset(0, radius - inset),
      _Arrow.left => center + Offset(-radius + inset, 0),
      _Arrow.right => center + Offset(radius - inset, 0),
    };
  }
}
