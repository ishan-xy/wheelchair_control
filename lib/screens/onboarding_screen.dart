import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app/main_nav.dart';
import '../core/theme/app_colors.dart';
import '../providers/app_state.dart';
import '../services/bluetooth_service.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  bool _checkingPermissions = true;
  bool _hasPermissions = false;

  @override
  void initState() {
    super.initState();
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    final state = context.read<AppState>();
    if (state.isConnected) {
      _openApp();
      return;
    }
    final allowed = await state.hasRequiredPermissions();
    if (!mounted) return;
    setState(() {
      _checkingPermissions = false;
      _hasPermissions = allowed;
    });
    if (allowed) {
      await state.loadPairedDevices();
      if (mounted && state.discoveredDevices.isEmpty) {
        unawaited(state.startScan());
      }
    }
  }

  Future<void> _requestAndScan() async {
    setState(() => _checkingPermissions = true);
    final state = context.read<AppState>();
    final allowed = await state.requestPermissions();
    if (!mounted) return;
    setState(() {
      _checkingPermissions = false;
      _hasPermissions = allowed;
    });
    if (allowed) unawaited(state.startScan());
  }

  Future<void> _connect(BleDevice device) async {
    final connected = await context.read<AppState>().connectTo(device);
    if (connected && mounted) _openApp();
  }

  void _openApp() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainNav()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final devices = <BleDevice>{
      ...state.pairedDevices,
      ...state.discoveredDevices,
    }.toList();

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _BrandMark(),
                  const SizedBox(height: 28),
                  Text(
                    'Connect your VAYA One',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Keep the wheelchair powered on and nearby.',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 16),
                  ),
                  const SizedBox(height: 24),
                  if (_checkingPermissions)
                    const Expanded(
                      child: _CenteredState(
                        icon: Icons.bluetooth_searching_rounded,
                        title: 'Checking connection access',
                        showProgress: true,
                      ),
                    )
                  else if (!_hasPermissions)
                    Expanded(
                      child: _CenteredState(
                        icon: Icons.bluetooth_disabled_rounded,
                        title: 'Bluetooth access is required',
                        message:
                            'Allow access so VAYA Connect can find and connect to the wheelchair.',
                        actionLabel: 'Allow Bluetooth access',
                        onAction: _requestAndScan,
                      ),
                    )
                  else ...[
                    _ConnectionSummary(state: state),
                    if (!state.isConnecting &&
                        state.requiresSystemPairingReset) ...[
                      const SizedBox(height: 12),
                      _PairingResetNotice(
                        message: state.systemPairingResetMessage,
                      ),
                    ],
                    if (state.errorMessage != null &&
                        !state.isConnecting &&
                        !state.requiresSystemPairingReset) ...[
                      const SizedBox(height: 12),
                      _ErrorMessage(message: state.errorMessage!),
                    ],
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Text(
                          'Available wheelchairs',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: state.isScanning || state.isConnecting
                              ? null
                              : () => unawaited(state.startScan()),
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Try again'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: devices.isEmpty
                          ? _CenteredState(
                              icon: Icons.search_rounded,
                              title: state.isScanning
                                  ? 'Searching nearby'
                                  : 'No wheelchair found',
                              message: state.isScanning
                                  ? 'This usually takes a few seconds.'
                                  : 'Check that VAYA One is powered on, then try again.',
                              showProgress: state.isScanning,
                            )
                          : ListView.separated(
                              itemCount: devices.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (_, index) => _DeviceTile(
                                device: devices[index],
                                busy: state.isConnecting,
                                onConnect: () => _connect(devices[index]),
                              ),
                            ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) => const Row(
        children: [
          Icon(Icons.accessible_forward_rounded, color: AppColors.accent),
          SizedBox(width: 10),
          Text(
            'VAYA CONNECT',
            style: TextStyle(
              color: AppColors.text,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
        ],
      );
}

class _ConnectionSummary extends StatelessWidget {
  final AppState state;

  const _ConnectionSummary({required this.state});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(
              state.isConnecting
                  ? Icons.lock_clock_rounded
                  : state.isScanning
                      ? Icons.bluetooth_searching_rounded
                      : Icons.bluetooth_rounded,
              color: AppColors.accent,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                state.isConnecting
                    ? 'Waiting for secure pairing'
                    : state.isScanning
                        ? 'Searching for VAYA One'
                        : 'Ready to search',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            if (state.isScanning || state.isConnecting)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
      );
}

class _DeviceTile extends StatelessWidget {
  final BleDevice device;
  final bool busy;
  final VoidCallback onConnect;

  const _DeviceTile({
    required this.device,
    required this.busy,
    required this.onConnect,
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
            const Icon(Icons.airline_seat_recline_normal_rounded),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                device.name ?? 'VAYA One',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 12),
            FilledButton(
              onPressed: busy ? null : onConnect,
              child: Text(busy ? 'Connecting' : 'Connect'),
            ),
          ],
        ),
      );
}

class _CenteredState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final bool showProgress;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _CenteredState({
    required this.icon,
    required this.title,
    this.message,
    this.showProgress = false,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 40, color: AppColors.textMuted),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (message != null) ...[
                const SizedBox(height: 8),
                Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textMuted),
                ),
              ],
              if (showProgress) ...[
                const SizedBox(height: 20),
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ],
              if (actionLabel != null) ...[
                const SizedBox(height: 24),
                FilledButton(onPressed: onAction, child: Text(actionLabel!)),
              ],
            ],
          ),
        ),
      );
}

class _ErrorMessage extends StatelessWidget {
  final String message;

  const _ErrorMessage({required this.message});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.danger.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.danger.withValues(alpha: 0.45)),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: AppColors.danger),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
      );
}

class _PairingResetNotice extends StatelessWidget {
  const _PairingResetNotice({this.message});

  final String? message;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.warning.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.warning.withValues(alpha: 0.45),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.phonelink_erase_rounded,
              color: AppColors.warning,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message ??
                    'This iPhone has an old Bluetooth pairing for the '
                        'wheelchair. Open Settings > Bluetooth, tap VAYA One, '
                        'and choose Forget This Device before connecting again.',
              ),
            ),
          ],
        ),
      );
}
