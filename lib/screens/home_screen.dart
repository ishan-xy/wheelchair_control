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
      bottom: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
            children: [
              Text(
                'Wheelchair status',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 6),
              const Text(
                'Live information from VAYA One',
                style: TextStyle(color: AppColors.textMuted),
              ),
              const SizedBox(height: 20),
              _ConnectionPanel(state: state),
              const SizedBox(height: 12),
              if (state.sosNeedsAcknowledgement) ...[
                _SosAcknowledgementPanel(state: state),
                const SizedBox(height: 12),
              ],
              _WheelchairLockPanel(state: state),
              const SizedBox(height: 12),
              _DriveReadinessPanel(state: state),
              if (state.errorMessage != null) ...[
                const SizedBox(height: 12),
                _WarningPanel(message: state.errorMessage!),
              ],
              const SizedBox(height: 20),
              Text(
                'Current state',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              _StatusRow(
                label: 'Movement',
                value: state.motionStatus.label,
                icon: state.motionStatus == WheelchairMotionStatus.moving
                    ? Icons.directions_rounded
                    : Icons.stop_circle_outlined,
                emphasized: state.motionStatus == WheelchairMotionStatus.moving,
              ),
              const SizedBox(height: 10),
              _TelemetryRow(
                label: 'Battery',
                icon: Icons.battery_5_bar_rounded,
                value: state.batteryStatus == TelemetryStatus.current
                    ? '${state.battery}%'
                    : state.batteryStatus == TelemetryStatus.stale
                        ? '${state.battery}% · delayed'
                        : 'Information unavailable',
                status: state.batteryStatus,
              ),
              const SizedBox(height: 10),
              _TelemetryRow(
                label: 'Controller speed',
                icon: Icons.speed_rounded,
                value: state.speedStatus == TelemetryStatus.current
                    ? '${state.currentSpeed}'
                    : state.speedStatus == TelemetryStatus.stale
                        ? '${state.currentSpeed} · delayed'
                        : 'Information unavailable',
                status: state.speedStatus,
              ),
              const SizedBox(height: 20),
              const _SafetyNotice(),
            ],
          ),
        ),
      ),
    );
  }
}

class _SosAcknowledgementPanel extends StatelessWidget {
  const _SosAcknowledgementPanel({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.danger.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.danger.withValues(alpha: 0.7)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.sos_rounded, color: AppColors.danger),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'SOS needs acknowledgement',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'The wheelchair SOS button was pressed. Confirm the child is safe before acknowledging this alert.',
              style: TextStyle(color: AppColors.textMuted),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: state.acknowledgeSosAlert,
              icon: const Icon(Icons.check_rounded),
              label: const Text('Acknowledge alert'),
            ),
          ],
        ),
      );
}

class _DriveReadinessPanel extends StatelessWidget {
  const _DriveReadinessPanel({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final complete = state.isDriveChecklistComplete;
    final color = complete ? AppColors.success : AppColors.warning;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.65)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                complete
                    ? Icons.verified_user_outlined
                    : Icons.fact_check_outlined,
                color: color,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  complete ? 'Ready to drive' : 'Pre-drive check',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...state.driveReadiness.map(
            (check) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(
                    check.ready
                        ? Icons.check_circle_outline
                        : Icons.info_outline,
                    color: check.ready ? AppColors.success : AppColors.warning,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(check.label)),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      check.detail,
                      textAlign: TextAlign.end,
                      style: const TextStyle(color: AppColors.textMuted),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WheelchairLockPanel extends StatelessWidget {
  const _WheelchairLockPanel({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final locked = state.isLocked;
    final restConfirmed = state.isWheelchairAtRest;
    final statusColor = locked ? AppColors.warning : AppColors.success;
    final action = locked ? 'Unlock wheelchair' : 'Lock wheelchair';
    final explanation = locked
        ? 'Movement controls remain disabled until you unlock the wheelchair.'
        : 'Locking disables movement controls. The wheelchair must already be stopped.';
    final unavailableReason = !state.isConnected
        ? 'Connect to change the lock state.'
        : !restConfirmed
            ? 'Stop the wheelchair completely before changing the lock state.'
            : null;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withValues(alpha: 0.65)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                locked ? Icons.lock_rounded : Icons.lock_open_rounded,
                color: statusColor,
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Wheelchair lock',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              Text(
                locked ? 'Locked' : 'Unlocked',
                style:
                    TextStyle(color: statusColor, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(explanation, style: const TextStyle(color: AppColors.textMuted)),
          if (unavailableReason != null) ...[
            const SizedBox(height: 6),
            Text(
              unavailableReason,
              style: const TextStyle(color: AppColors.warning),
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              onPressed: state.canChangeWheelchairLock
                  ? () => _changeLock(context, state, !locked)
                  : null,
              icon: state.isUpdatingWheelchairLock
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(locked ? Icons.lock_open_rounded : Icons.lock_rounded),
              label: Text(action),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _changeLock(
    BuildContext context,
    AppState state,
    bool lock,
  ) async {
    final changed = await state.setWheelchairLocked(lock);
    if (!context.mounted) return;
    final message = changed
        ? lock
            ? 'Wheelchair locked. Movement controls are disabled.'
            : 'Wheelchair unlocked. Movement controls are available.'
        : 'The wheelchair did not confirm the lock state. Keep it stopped and try again.';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            color: AppColors.text,
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: changed ? AppColors.surfaceHigh : AppColors.warning,
      ),
    );
  }
}

class _ConnectionPanel extends StatelessWidget {
  final AppState state;

  const _ConnectionPanel({required this.state});

  @override
  Widget build(BuildContext context) {
    final connected = state.isConnected;
    final color = connected ? AppColors.success : AppColors.warning;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              connected ? Icons.link_rounded : Icons.link_off_rounded,
              color: color,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  state.connectionStatus.label,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  connected
                      ? (state.connectedDeviceName.isEmpty
                          ? 'VAYA One'
                          : state.connectedDeviceName)
                      : state.isReconnecting
                          ? 'Trying to restore communication'
                          : 'Movement controls are unavailable',
                  style: const TextStyle(color: AppColors.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final bool emphasized;

  const _StatusRow({
    required this.label,
    required this.value,
    required this.icon,
    this.emphasized = false,
  });

  @override
  Widget build(BuildContext context) => _BaseRow(
        icon: icon,
        label: label,
        value: value,
        color: emphasized ? AppColors.warning : AppColors.text,
      );
}

class _TelemetryRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final TelemetryStatus status;

  const _TelemetryRow({
    required this.label,
    required this.value,
    required this.icon,
    required this.status,
  });

  @override
  Widget build(BuildContext context) => _BaseRow(
        icon: icon,
        label: label,
        value: value,
        color: status == TelemetryStatus.current
            ? AppColors.text
            : status == TelemetryStatus.stale
                ? AppColors.warning
                : AppColors.textMuted,
      );
}

class _BaseRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _BaseRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 14),
            Expanded(
              child: Text(label,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                value,
                textAlign: TextAlign.end,
                style: TextStyle(color: color, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      );
}

class _WarningPanel extends StatelessWidget {
  final String message;

  const _WarningPanel({required this.message});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.warning.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.warning.withValues(alpha: 0.45)),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppColors.warning),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
      );
}

class _SafetyNotice extends StatelessWidget {
  const _SafetyNotice();

  @override
  Widget build(BuildContext context) => const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded,
              color: AppColors.textMuted, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'If the app loses connection while driving, use the wheelchair’s physical stop control.',
              style: TextStyle(color: AppColors.textMuted, height: 1.4),
            ),
          ),
        ],
      );
}
