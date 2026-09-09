import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_colors.dart';
import '../models/wheelchair_runtime.dart';
import '../providers/app_state.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
            children: [
              Text('Wheelchair status',
                  style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 6),
              Text('Live information from VAYA One',
                  style: TextStyle(color: AppColors.textMuted)),
              const SizedBox(height: 20),
              _ConnectionPanel(state: state),
              if (state.sosNeedsAcknowledgement) ...[
                const SizedBox(height: 12),
                _SosAcknowledgementPanel(state: state),
              ],
              const SizedBox(height: 12),
              _DriveReadinessPanel(state: state),
              if (state.errorMessage != null) ...[
                const SizedBox(height: 12),
                _Notice(message: state.errorMessage!, color: AppColors.warning),
              ],
              const SizedBox(height: 20),
              Text('Current state',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              _StatusRow(
                label: 'Movement',
                value: state.motionStatus.label,
                icon: state.motionStatus == WheelchairMotionStatus.moving
                    ? Icons.directions_rounded
                    : Icons.stop_circle_outlined,
                color: state.motionStatus == WheelchairMotionStatus.moving
                    ? AppColors.warning
                    : AppColors.text,
              ),
              const SizedBox(height: 10),
              _StatusRow(
                label: 'Battery',
                value: state.batteryStatus == TelemetryStatus.current
                    ? '${state.battery}%'
                    : state.batteryStatus == TelemetryStatus.stale
                        ? '${state.battery}% · delayed'
                        : 'Information unavailable',
                icon: Icons.battery_5_bar_rounded,
                color: _telemetryColor(state.batteryStatus),
              ),
              const SizedBox(height: 10),
              _StatusRow(
                label: 'Controller speed',
                value: state.speedStatus == TelemetryStatus.current
                    ? '${state.currentSpeed}'
                    : state.speedStatus == TelemetryStatus.stale
                        ? '${state.currentSpeed} · delayed'
                        : 'Information unavailable',
                icon: Icons.speed_rounded,
                color: _telemetryColor(state.speedStatus),
              ),
              const SizedBox(height: 20),
              const _Notice(
                message:
                    'Controls stay locked until the wheelchair reports a safe connection and you unlock it from Control.',
                color: AppColors.accent,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _telemetryColor(TelemetryStatus status) => switch (status) {
        TelemetryStatus.current => AppColors.text,
        TelemetryStatus.stale => AppColors.warning,
        TelemetryStatus.unavailable => AppColors.textMuted,
      };
}

class _ConnectionPanel extends StatelessWidget {
  const _ConnectionPanel({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final connected = state.isConnected;
    final color = connected ? AppColors.success : AppColors.warning;
    return _Card(
      child: Row(children: [
        Icon(connected ? Icons.link_rounded : Icons.link_off_rounded,
            color: color, size: 30),
        const SizedBox(width: 14),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(state.connectionStatus.label,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(
              connected
                  ? (state.connectedDeviceName.isEmpty
                      ? 'VAYA One'
                      : state.connectedDeviceName)
                  : state.isReconnecting
                      ? 'Reconnecting automatically'
                      : 'Movement controls are unavailable',
              style: TextStyle(color: AppColors.textMuted),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _SosAcknowledgementPanel extends StatelessWidget {
  const _SosAcknowledgementPanel({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) => _Card(
        color: AppColors.danger.withValues(alpha: 0.12),
        border: AppColors.danger,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('SOS needs acknowledgement',
              style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text('Check on the child before acknowledging this alert.',
              style: TextStyle(color: AppColors.textMuted)),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: state.acknowledgeSosAlert,
            icon: const Icon(Icons.check_rounded),
            label: const Text('Acknowledge alert'),
          ),
        ]),
      );
}

class _DriveReadinessPanel extends StatelessWidget {
  const _DriveReadinessPanel({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) => _Card(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
              state.isDriveChecklistComplete
                  ? 'Ready to drive'
                  : 'Pre-drive check',
              style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          for (final check in state.driveReadiness)
            _StatusDetail(
              label: check.label,
              detail: check.detail,
              icon:
                  check.ready ? Icons.check_circle_outline : Icons.info_outline,
              color: check.ready ? AppColors.success : AppColors.warning,
            ),
        ]),
      );
}

class _StatusDetail extends StatelessWidget {
  const _StatusDetail({
    required this.label,
    required this.detail,
    required this.icon,
    required this.color,
  });

  final String label;
  final String detail;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final stacked = constraints.maxWidth < 460;
          final labelRow = Row(children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(label)),
          ]);
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: stacked
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                        labelRow,
                        Padding(
                          padding: const EdgeInsets.only(left: 26, top: 4),
                          child: Text(detail,
                              style: TextStyle(color: AppColors.textMuted)),
                        ),
                      ])
                : Row(children: [
                    Expanded(child: labelRow),
                    const SizedBox(width: 16),
                    SizedBox(
                      width: 260,
                      child: Text(detail,
                          textAlign: TextAlign.end,
                          style: TextStyle(color: AppColors.textMuted)),
                    ),
                  ]),
          );
        },
      );
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => _Card(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final stacked = constraints.maxWidth < 460 && value.length > 10;
            final labelRow = Row(children: [
              Icon(icon, color: color),
              const SizedBox(width: 14),
              Expanded(
                  child: Text(label,
                      style: const TextStyle(fontWeight: FontWeight.w700))),
            ]);
            final valueText = Text(value,
                textAlign: stacked ? TextAlign.start : TextAlign.end,
                style: TextStyle(color: color, fontWeight: FontWeight.w800));
            return stacked
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                        labelRow,
                        Padding(
                          padding: const EdgeInsets.only(left: 38, top: 6),
                          child: valueText,
                        ),
                      ])
                : Row(children: [
                    Expanded(child: labelRow),
                    const SizedBox(width: 12),
                    ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 260),
                        child: valueText),
                  ]);
          },
        ),
      );
}

class _Notice extends StatelessWidget {
  const _Notice({required this.message, required this.color});
  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) => _Card(
        color: color.withValues(alpha: 0.12),
        border: color,
        child: Row(children: [
          Icon(Icons.info_outline, color: color),
          const SizedBox(width: 10),
          Expanded(child: Text(message)),
        ]),
      );
}

class _Card extends StatelessWidget {
  const _Card({required this.child, this.color, this.border});
  final Widget child;
  final Color? color;
  final Color? border;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color ?? AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: border?.withValues(alpha: 0.65) ?? AppColors.border),
        ),
        child: child,
      );
}
