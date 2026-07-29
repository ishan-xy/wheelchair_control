import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_colors.dart';
import '../core/widgets/battery_indicator.dart';
import '../models/wheelchair_runtime.dart';
import '../providers/app_state.dart';
import '../widgets/joystick_widget.dart';

enum DriveMode {
  indoor('Indoor'),
  outdoor('Outdoor');

  final String label;

  const DriveMode(this.label);
}

class ControlScreen extends StatefulWidget {
  const ControlScreen({super.key});

  @override
  State<ControlScreen> createState() => _ControlScreenState();
}

class _ControlScreenState extends State<ControlScreen>
    with WidgetsBindingObserver {
  DriveMode _mode = DriveMode.indoor;
  Timer? _sendTimer;
  double _rawX = 0;
  double _rawY = 0;
  bool _stopping = false;
  bool _orientationConfigured = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_orientationConfigured) return;
    _orientationConfigured = true;
    final isPhone = MediaQuery.sizeOf(context).shortestSide < 600;
    unawaited(
      SystemChrome.setPreferredOrientations(
        isPhone ? [DeviceOrientation.portraitUp] : DeviceOrientation.values,
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _stop(silent: true);
  }

  @override
  void dispose() {
    _sendTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    unawaited(SystemChrome.setPreferredOrientations(DeviceOrientation.values));
    super.dispose();
  }

  void _onMove(double x, double y) {
    final state = context.read<AppState>();
    if (!state.canDrive) return;
    _rawX = x;
    _rawY = y;
    _sendTimer ??= Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (!state.canDrive) {
        _stop(silent: true);
        return;
      }
      final sensitivity = state.sensitivity;
      final commandX = (_rawX * sensitivity).clamp(-1.0, 1.0);
      final commandY = (_rawY * sensitivity).clamp(-1.0, 1.0);
      unawaited(state.sendMovement(commandX, commandY));
    });
  }

  Future<void> _stop({bool silent = false}) async {
    _sendTimer?.cancel();
    _sendTimer = null;
    _rawX = 0;
    _rawY = 0;
    if (_stopping) return;
    final state = context.read<AppState>();
    if (!state.isConnected) return;
    _stopping = true;
    bool delivered;
    try {
      delivered = await state.stopWheelchair();
    } finally {
      _stopping = false;
    }
    if (!mounted || silent) return;
    final confirmed = state.motionStatus == WheelchairMotionStatus.stopped;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          confirmed
              ? 'Wheelchair reports stopped.'
              : delivered
                  ? 'Stop command sent. Confirm the wheelchair has stopped.'
                  : 'Stop command could not be delivered. Use the physical stop.',
        ),
        backgroundColor: delivered ? AppColors.surfaceHigh : AppColors.danger,
      ),
    );
  }

  Future<void> _emergencyStop() async {
    final state = context.read<AppState>();
    final confirmed = await state.emergencyStop();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          confirmed
              ? 'Emergency stop confirmed by the wheelchair.'
              : 'Emergency stop was not confirmed. Use the physical stop now.',
        ),
        backgroundColor: confirmed ? AppColors.surfaceHigh : AppColors.danger,
      ),
    );
  }

  void _requestEmergencyAssistance() {
    context.read<AppState>().requestEmergencyAssistance();
  }

  Future<void> _selectMode(DriveMode mode) async {
    final state = context.read<AppState>();
    if (!state.canDrive) return;
    final confirmed =
        await state.setDriveMode(indoor: mode == DriveMode.indoor);
    if (!mounted) return;
    if (confirmed) {
      setState(() => _mode = mode);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('The wheelchair did not confirm the mode.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return SafeArea(
      bottom: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxHeight < 640;
              final textScale = MediaQuery.textScalerOf(context).scale(1);
              final accessibleCompact = textScale > 1.25;
              final narrow = constraints.maxWidth < 360 || accessibleCompact;
              return Padding(
                // Matches the Status and Settings screen heading grid while
                // retaining compact vertical space for the fixed control UI.
                padding: EdgeInsets.fromLTRB(20, compact ? 4 : 20, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _ControlHeader(
                      state: state,
                      compact: compact,
                      onEmergencyAssistance: _requestEmergencyAssistance,
                      showEmergencyAssistance: true,
                    ),
                    SizedBox(height: compact ? 4 : 12),
                    if (!state.canDrive) ...[
                      _SafetyWarning(
                        state: state,
                        short: accessibleCompact,
                      ),
                      SizedBox(height: compact ? 4 : 12),
                    ],
                    SegmentedButton<DriveMode>(
                      segments: [
                        for (final mode in DriveMode.values)
                          ButtonSegment(
                            value: mode,
                            label: Text(mode.label),
                            icon: narrow
                                ? null
                                : Icon(
                                    mode == DriveMode.indoor
                                        ? Icons.home_outlined
                                        : Icons.park_outlined,
                                  ),
                          ),
                      ],
                      selected: {_mode},
                      onSelectionChanged: state.canDrive
                          ? (selection) =>
                              unawaited(_selectMode(selection.first))
                          : null,
                      showSelectedIcon: false,
                    ),
                    SizedBox(height: compact ? 6 : 12),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        padding: EdgeInsets.fromLTRB(
                          12,
                          compact ? 8 : 12,
                          12,
                          compact ? 6 : 10,
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                if (!accessibleCompact)
                                  Expanded(
                                    child: Text(
                                      state.canDrive
                                          ? 'Hold and move to drive'
                                          : state.isCharging
                                              ? 'Charging: movement controls are disabled'
                                              : state.isConnected
                                                  ? 'Movement controls are unavailable'
                                                  : 'Connect to enable movement',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: AppColors.textMuted,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  )
                                else
                                  const Spacer(),
                                SizedBox(width: accessibleCompact ? 0 : 8),
                                BatteryIndicator(
                                  percent: state.batteryStatus ==
                                          TelemetryStatus.unavailable
                                      ? null
                                      : state.battery,
                                  delayed: state.batteryStatus ==
                                      TelemetryStatus.stale,
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Expanded(
                              child: JoystickWidget(
                                enabled: state.canDrive,
                                onMove: _onMove,
                                onRelease: () => _stop(silent: true),
                              ),
                            ),
                            Row(
                              children: [
                                const Expanded(
                                  child: Text(
                                    'Joystick sensitivity',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style:
                                        TextStyle(fontWeight: FontWeight.w700),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${(state.sensitivity * 100).round()}%',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                            Slider(
                              value: state.sensitivity,
                              min: 0.1,
                              max: 1,
                              divisions: 9,
                              label:
                                  '${(state.sensitivity * 100).round()} percent',
                              onChanged:
                                  state.canDrive ? state.setSensitivity : null,
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: compact ? 8 : 12),
                    SizedBox(
                      height: compact ? 54 : 62,
                      child: FilledButton.icon(
                        onPressed: state.isConnected && state.protocolReady
                            ? _emergencyStop
                            : null,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.danger,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: AppColors.surfaceHigh,
                          disabledForegroundColor: AppColors.textDim,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.stop_circle_outlined),
                        label: const Text(
                          'EMERGENCY STOP',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ControlHeader extends StatelessWidget {
  final AppState state;
  final bool compact;
  final VoidCallback onEmergencyAssistance;
  final bool showEmergencyAssistance;

  const _ControlHeader({
    required this.state,
    required this.compact,
    required this.onEmergencyAssistance,
    required this.showEmergencyAssistance,
  });

  @override
  Widget build(BuildContext context) {
    final connected = state.isConnected;
    final statusColor = connected ? AppColors.success : AppColors.warning;
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final stackStatus = compact || textScale > 1.25;
    final title = Text(
      stackStatus ? 'Control' : 'Wheelchair control',
      style: stackStatus
          ? Theme.of(context).textTheme.titleLarge
          : Theme.of(context).textTheme.headlineMedium,
    );
    final motion = Text(
      state.motionStatus.label,
      style: TextStyle(color: statusColor, fontWeight: FontWeight.w700),
    );
    final connection = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          connected ? Icons.link_rounded : Icons.link_off_rounded,
          size: 18,
          color: statusColor,
        ),
        const SizedBox(width: 6),
        Text(
          state.connectionStatus.label,
          style: TextStyle(color: statusColor, fontWeight: FontWeight.w800),
        ),
      ],
    );
    if (stackStatus) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: title),
              if (showEmergencyAssistance)
                _EmergencyAssistanceButton(
                  onPressed: onEmergencyAssistance,
                ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(child: motion),
              const SizedBox(width: 8),
              connection,
            ],
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              title,
              const SizedBox(height: 4),
              motion,
            ],
          ),
        ),
        if (showEmergencyAssistance)
          _EmergencyAssistanceButton(onPressed: onEmergencyAssistance),
        connection,
      ],
    );
  }
}

class _EmergencyAssistanceButton extends StatelessWidget {
  const _EmergencyAssistanceButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: 'Emergency assistance',
        onPressed: onPressed,
        color: AppColors.danger,
        icon: const Icon(Icons.sos_rounded),
      );
}

class _SafetyWarning extends StatelessWidget {
  final AppState state;
  final bool short;

  const _SafetyWarning({required this.state, this.short = false});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.warning.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.warning.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppColors.warning),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                state.emergencyStopActive
                    ? 'Emergency stop is active. Use the physical reset procedure.'
                    : state.isCharging
                        ? 'Charging is connected. Movement controls are disabled.'
                        : state.sosActive
                            ? 'SOS button was pressed. Check on the child.'
                            : state.isLocked
                                ? short
                                    ? 'Wheelchair is locked.'
                                    : 'Wheelchair is locked. Use Status to unlock it when it is safe to drive.'
                                : state.faultCode == 'COMMAND_TIMEOUT'
                                    ? 'Control signal was interrupted. Release the joystick while control is restored.'
                                    : state.faultCode != 'NONE'
                                        ? 'Wheelchair fault: movement is locked.'
                                        : short
                                            ? 'Movement is locked.'
                                            : 'Movement controls are locked until the safety connection is ready.',
              ),
            ),
          ],
        ),
      );
}
