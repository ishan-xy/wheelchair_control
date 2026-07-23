import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/typography.dart';
import '../core/widgets/glass_card.dart';
import '../core/widgets/primary_button.dart';
import '../providers/app_state.dart';
import '../services/wheelchair_commands.dart';
import '../widgets/joystick_widget.dart';

enum DriveMode {
  indoor('Indoor', 'Slow, precise', Icons.home_outlined, 90),
  outdoor('Outdoor', 'Balanced power', Icons.tune_rounded, 160);

  final String label;
  final String subtitle;
  final IconData icon;
  final int maxPwm;

  const DriveMode(this.label, this.subtitle, this.icon, this.maxPwm);
}

class ControlScreen extends StatefulWidget {
  const ControlScreen({super.key});

  @override
  State<ControlScreen> createState() => _ControlScreenState();
}

class _ControlScreenState extends State<ControlScreen> {
  DriveMode _mode = DriveMode.outdoor;
  Timer? _sendTimer;
  double _rawX = 0;
  double _rawY = 0;

  double get _x => (_rawX * context.read<AppState>().sensitivity)
      .clamp(-1.0, 1.0)
      .toDouble();
  double get _y => (_rawY * context.read<AppState>().sensitivity)
      .clamp(-1.0, 1.0)
      .toDouble();

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  }

  @override
  void dispose() {
    _sendTimer?.cancel();
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  void _onMove(double x, double y) {
    setState(() {
      _rawX = x;
      _rawY = y;
    });
    _sendTimer ??= Timer.periodic(const Duration(milliseconds: 50), (_) {
      unawaited(context
          .read<AppState>()
          .sendCommand(WheelchairCommands.joystick(_x, _y)));
    });
  }

  void _stop() {
    _sendTimer?.cancel();
    _sendTimer = null;
    setState(() {
      _rawX = 0;
      _rawY = 0;
    });
    unawaited(context
        .read<AppState>()
        .sendCommand(WheelchairCommands.stop, reliable: true));
  }

  void _selectMode(DriveMode mode) {
    setState(() => _mode = mode);
    unawaited(context
        .read<AppState>()
        .sendCommand(WheelchairCommands.maxPwm(mode.maxPwm), reliable: true));
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Container(
      decoration: BoxDecoration(gradient: AppColors.appBackground),
      child: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxHeight < 720;
            return Padding(
              padding: EdgeInsets.fromLTRB(18, compact ? 22 : 34, 18, 96),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('CONTROL',
                                style: AppTypography.overline),
                            const SizedBox(height: 6),
                            Text('Drive VAYA',
                                style: compact
                                    ? Theme.of(context).textTheme.headlineMedium
                                    : Theme.of(context)
                                        .textTheme
                                        .headlineLarge),
                          ],
                        ),
                      ),
                      _StatusPill(text: state.isConnected ? 'Ready' : 'Idle'),
                    ],
                  ),
                  SizedBox(height: compact ? 14 : 20),
                  Row(
                    children: [
                      for (final mode in DriveMode.values) ...[
                        Expanded(
                            child: _ModeCard(
                                compact: compact,
                                mode: mode,
                                selected: _mode == mode,
                                onTap: () => _selectMode(mode))),
                        if (mode != DriveMode.values.last)
                          const SizedBox(width: 10),
                      ],
                    ],
                  ),
                  SizedBox(height: compact ? 12 : 18),
                  Expanded(
                    child: GlassCard(
                      padding: EdgeInsets.fromLTRB(
                          16, compact ? 14 : 18, 16, compact ? 12 : 16),
                      child: Column(
                        children: [
                          const Text('JOYSTICK', style: AppTypography.overline),
                          SizedBox(height: compact ? 6 : 12),
                          Expanded(
                            child: JoystickWidget(
                                onMove: _onMove, onRelease: _stop),
                          ),
                          Row(
                            children: [
                              const Text('Speed',
                                  style: TextStyle(
                                      color: AppColors.textMuted,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800)),
                              const Spacer(),
                              Text('${(state.sensitivity * 100).round()}%',
                                  style: const TextStyle(
                                      color: AppColors.text,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800)),
                            ],
                          ),
                          Slider(
                            value: state.sensitivity,
                            min: 0.1,
                            max: 1.0,
                            divisions: 9,
                            onChanged: state.setSensitivity,
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: compact ? 10 : 14),
                  PrimaryButton(
                      label: 'Emergency Stop',
                      icon: Icons.error_outline_rounded,
                      danger: true,
                      onPressed: _stop),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String text;

  const _StatusPill({required this.text});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.accent.withValues(alpha: 0.13),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Text(text,
            style: const TextStyle(
                color: AppColors.accent, fontWeight: FontWeight.w800)),
      );
}

class _ModeCard extends StatelessWidget {
  final DriveMode mode;
  final bool selected;
  final VoidCallback onTap;
  final bool compact;

  const _ModeCard(
      {required this.mode,
      required this.selected,
      required this.onTap,
      this.compact = false});

  @override
  Widget build(BuildContext context) => AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          gradient: selected ? AppColors.primaryGradient : null,
          color: selected ? null : AppColors.glassSoft,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
              color: selected ? Colors.transparent : AppColors.border),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.all(compact ? 12 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(mode.icon,
                    color: selected ? Colors.black : AppColors.text,
                    size: compact ? 22 : 26),
                SizedBox(height: compact ? 10 : 14),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    mode.label,
                    style: TextStyle(
                      color: selected ? Colors.black : AppColors.text,
                      fontSize: compact ? 17 : 19,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    mode.subtitle,
                    style: TextStyle(
                        color: selected
                            ? Colors.black.withValues(alpha: 0.76)
                            : AppColors.textMuted,
                        fontSize: compact ? 12 : 14),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}
