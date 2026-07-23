import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class AnimatedVehicle extends StatefulWidget {
  final double size;
  final bool compact;

  const AnimatedVehicle({
    super.key,
    this.size = 280,
    this.compact = false,
  });

  @override
  State<AnimatedVehicle> createState() => _AnimatedVehicleState();
}

class _AnimatedVehicleState extends State<AnimatedVehicle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: const Duration(seconds: 4))
          ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    return SizedBox(
      width: size,
      height: size * (widget.compact ? 0.78 : 0.86),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final t = _controller.value;
          final bob = math.sin(t * math.pi * 2) * 4;
          return CustomPaint(
            painter: _VehicleStagePainter(t),
            child: Transform.translate(offset: Offset(0, bob), child: child),
          );
        },
        child: CustomPaint(painter: _VehiclePainter()),
      ),
    );
  }
}

class _VehicleStagePainter extends CustomPainter {
  final double t;

  const _VehicleStagePainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = AppColors.accent.withValues(alpha: 0.10);

    canvas.drawCircle(center,
        size.width * (0.34 + math.sin(t * math.pi * 2) * 0.015), ringPaint);
    canvas.drawCircle(center, size.width * 0.45,
        ringPaint..color = AppColors.accent.withValues(alpha: 0.06));

    final shadow = Paint()
      ..shader = RadialGradient(
        colors: [AppColors.accent.withValues(alpha: 0.18), Colors.transparent],
      ).createShader(Rect.fromCircle(
          center: Offset(center.dx, size.height * 0.78),
          radius: size.width * 0.22));
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(center.dx, size.height * 0.78),
          width: size.width * 0.54,
          height: size.height * 0.07),
      shadow,
    );
  }

  @override
  bool shouldRepaint(covariant _VehicleStagePainter oldDelegate) =>
      oldDelegate.t != t;
}

class _VehiclePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 280;
    final sy = size.height / 230;
    canvas.save();
    canvas.scale(sx, sy);

    final frame = Paint()
      ..color = const Color(0xFF62717B)
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final dark = Paint()..color = const Color(0xFF151A20);
    final panel = Paint()..color = const Color(0xFF1C232A);
    final edge = Paint()
      ..color = const Color(0xFF46515A)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final wheelCenter = const Offset(186, 132);
    canvas.drawCircle(wheelCenter, 52, Paint()..color = Colors.black);
    canvas.drawCircle(
        wheelCenter, 45, Paint()..color = const Color(0xFF1B2026));
    canvas.drawCircle(
        wheelCenter, 31, Paint()..color = const Color(0xFF11161B));
    for (var i = 0; i < 8; i++) {
      final a = i * math.pi / 4;
      canvas.drawLine(
        wheelCenter,
        wheelCenter + Offset(math.cos(a), math.sin(a)) * 34,
        Paint()
          ..color = const Color(0xFF343D47)
          ..strokeWidth = 3,
      );
    }
    canvas.drawCircle(wheelCenter, 17,
        Paint()..color = AppColors.accentDeep.withValues(alpha: 0.65));
    canvas.drawCircle(wheelCenter, 5, Paint()..color = Colors.black);

    final smallWheel = const Offset(95, 164);
    canvas.drawCircle(smallWheel, 29, Paint()..color = Colors.black);
    canvas.drawCircle(smallWheel, 22, Paint()..color = const Color(0xFF121820));
    canvas.drawCircle(smallWheel, 8, Paint()..color = AppColors.accentDeep);

    canvas.drawLine(const Offset(84, 149), const Offset(112, 152), frame);
    canvas.drawLine(const Offset(112, 152), const Offset(134, 104), frame);
    canvas.drawLine(const Offset(134, 104), const Offset(122, 133), frame);
    canvas.drawLine(const Offset(72, 134), const Offset(81, 89),
        frame..color = const Color(0xFFC7D3DC));
    canvas.drawLine(const Offset(143, 109), const Offset(174, 109), frame);

    final seat = RRect.fromRectAndRadius(
        const Rect.fromLTWH(92, 94, 108, 35), const Radius.circular(10));
    canvas.drawRRect(seat, panel);
    canvas.drawRRect(seat, edge);

    final back = RRect.fromRectAndRadius(
        const Rect.fromLTWH(98, 28, 82, 86), const Radius.circular(12));
    canvas.drawRRect(back, dark);
    canvas.drawRRect(back, edge);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(120, 31, 39, 8), const Radius.circular(5)),
      Paint()..color = AppColors.accentDeep,
    );

    canvas.drawLine(const Offset(163, 96), const Offset(184, 128),
        frame..color = const Color(0xFFD8E2E9));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(210, 70, 28, 28), const Radius.circular(6)),
      panel,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          const Rect.fromLTWH(210, 70, 28, 28), const Radius.circular(6)),
      edge,
    );
    canvas.drawCircle(
        const Offset(224, 77), 6, Paint()..color = AppColors.accentDeep);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
