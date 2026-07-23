import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app/main_nav.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/typography.dart';
import '../core/widgets/animated_vehicle.dart';
import '../core/widgets/glass_card.dart';
import '../core/widgets/primary_button.dart';
import '../providers/app_state.dart';
import '../services/bluetooth_service.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _step = 0;
  bool _preparing = false;
  bool _permissionBusy = false;

  void _next() => setState(() => _step = (_step + 1).clamp(0, 4));
  void _back() => setState(() => _step = (_step - 1).clamp(0, 4));

  Future<void> _startOnboarding() async {
    final state = context.read<AppState>();
    final hasPermissions = await state.hasRequiredPermissions();
    if (!mounted) return;
    if (!hasPermissions) {
      setState(() => _step = 1);
      return;
    }
    await state.startScan();
    if (mounted) setState(() => _step = 2);
  }

  Future<void> _allowAndScan() async {
    if (_permissionBusy) return;
    setState(() => _permissionBusy = true);
    final state = context.read<AppState>();
    final ok = await state.requestPermissions();
    if (!mounted) return;
    if (!ok) {
      setState(() => _permissionBusy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(state.errorMessage ??
              'Bluetooth and Location permissions are required.'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }
    setState(() {
      _permissionBusy = false;
      _step = 2;
    });
    unawaited(state.startScan());
  }

  Future<void> _connect(BleDevice device) async {
    final ok = await context.read<AppState>().connectTo(device);
    if (ok && mounted) _next();
  }

  Future<void> _prepare() async {
    setState(() => _preparing = true);
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    if (mounted) _next();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 320),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: switch (_step) {
        0 => _WelcomeScreen(onNext: _startOnboarding),
        1 => _PermissionsScreen(
            onBack: _back, onContinue: _allowAndScan, busy: _permissionBusy),
        2 => _PairingScreen(onBack: _back, onConnect: _connect, state: state),
        3 => _PreparingScreen(
            onBack: _back, onContinue: _prepare, preparing: _preparing),
        _ => _SetupCompleteScreen(onEnter: () {
            Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const MainNav()));
          }),
      },
    );
  }
}

class _OnboardingShell extends StatelessWidget {
  final Widget child;
  final VoidCallback? onBack;

  const _OnboardingShell({required this.child, this.onBack});

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        child: Container(
          key: ValueKey(child.runtimeType),
          decoration: BoxDecoration(gradient: AppColors.appBackground),
          child: SafeArea(
            child: Stack(
              children: [
                Positioned.fill(child: child),
                if (onBack != null)
                  Positioned(
                    top: 38,
                    left: 26,
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: onBack,
                      child: Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          color: AppColors.glassSoft,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.border),
                        ),
                        child: const Icon(Icons.chevron_left_rounded,
                            color: AppColors.text, size: 34),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
}

class _WelcomeScreen extends StatelessWidget {
  final VoidCallback onNext;

  const _WelcomeScreen({required this.onNext});

  @override
  Widget build(BuildContext context) => _OnboardingShell(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxHeight < 720;
            final vehicleSize = compact ? 250.0 : 320.0;
            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(28, compact ? 36 : 58, 28, 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - (compact ? 60 : 82)),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _Dot(),
                        SizedBox(width: 16),
                        Text('VAYA', style: AppTypography.overline),
                        SizedBox(width: 16),
                        _Dot(),
                      ],
                    ),
                    SizedBox(height: compact ? 22 : 44),
                    AnimatedVehicle(size: vehicleSize),
                    SizedBox(height: compact ? 18 : 34),
                    Column(
                      children: [
                        Text('VAYA',
                            style: TextStyle(
                                color: AppColors.accent,
                                fontSize: compact ? 46 : 54,
                                fontWeight: FontWeight.w900)),
                        SizedBox(height: compact ? 12 : 18),
                        const Text('FREEDOM IN MOTION',
                            style: AppTypography.overline),
                        SizedBox(height: compact ? 28 : 44),
                        SizedBox(
                            width: 260,
                            child: PrimaryButton(
                                label: 'Get Started',
                                icon: Icons.arrow_forward_rounded,
                                onPressed: onNext)),
                        SizedBox(height: compact ? 18 : 30),
                        const Text('v1.0 · VAYA One Companion',
                            style: TextStyle(color: AppColors.textMuted)),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
}

class _PermissionsScreen extends StatelessWidget {
  final VoidCallback onBack;
  final VoidCallback onContinue;
  final bool busy;

  const _PermissionsScreen({
    required this.onBack,
    required this.onContinue,
    required this.busy,
  });

  @override
  Widget build(BuildContext context) => _OnboardingShell(
        onBack: onBack,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxHeight < 720;
            return Padding(
              padding: EdgeInsets.fromLTRB(24, compact ? 72 : 84, 24, 22),
              child: Column(
                children: [
                  const _BluetoothTitle(),
                  SizedBox(height: compact ? 16 : 24),
                  AnimatedVehicle(size: compact ? 132 : 170, compact: true),
                  SizedBox(height: compact ? 12 : 18),
                  Text('Permissions',
                      style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 8),
                  const Text('VAYA Connect needs these to find and connect.',
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(color: AppColors.textMuted, fontSize: 15)),
                  SizedBox(height: compact ? 18 : 24),
                  const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('REQUIRED', style: AppTypography.overline)),
                  const SizedBox(height: 12),
                  const _PermissionTile(
                      compact: true,
                      icon: Icons.bluetooth_rounded,
                      title: 'Bluetooth',
                      subtitle: 'Connect to your VAYA One.'),
                  const SizedBox(height: 10),
                  const _PermissionTile(
                      compact: true,
                      icon: Icons.location_on_outlined,
                      title: 'Location',
                      subtitle: 'Required by Bluetooth scanning.'),
                  const Spacer(),
                  PrimaryButton(
                      label: busy ? 'Checking...' : 'Allow & Continue',
                      onPressed: busy ? null : onContinue),
                ],
              ),
            );
          },
        ),
      );
}

class _PairingScreen extends StatelessWidget {
  final VoidCallback onBack;
  final AppState state;
  final ValueChanged<BleDevice> onConnect;

  const _PairingScreen(
      {required this.onBack, required this.state, required this.onConnect});

  @override
  Widget build(BuildContext context) {
    final found =
        state.discoveredDevices.isNotEmpty || state.pairedDevices.isNotEmpty;
    final devices = state.discoveredDevices.isNotEmpty
        ? state.discoveredDevices
        : state.pairedDevices;

    return _OnboardingShell(
      onBack: onBack,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxHeight < 720;
          return Padding(
            padding: EdgeInsets.fromLTRB(24, compact ? 72 : 84, 24, 22),
            child: Column(
              children: [
                const _BluetoothTitle(),
                SizedBox(height: compact ? 14 : 22),
                AnimatedVehicle(size: compact ? 132 : 168, compact: true),
                SizedBox(height: compact ? 10 : 16),
                Text(found ? 'Device found' : 'Searching nearby',
                    style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 6),
                Text(
                  found ? 'Ready to pair.' : 'Keep VAYA One powered on.',
                  textAlign: TextAlign.center,
                  style:
                      const TextStyle(color: AppColors.textMuted, fontSize: 15),
                ),
                SizedBox(height: compact ? 16 : 22),
                Row(
                  children: [
                    const Expanded(
                        child: Text('NEARBY DEVICES',
                            style: AppTypography.overline)),
                    TextButton.icon(
                      onPressed: () => unawaited(state.startScan()),
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Scan'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (state.errorMessage != null) ...[
                  _InlineError(message: state.errorMessage!),
                  const SizedBox(height: 10),
                ],
                Expanded(
                  child: devices.isEmpty
                      ? GlassCard(
                          padding: const EdgeInsets.all(18),
                          child: Center(
                            child: Text(
                              state.errorMessage != null
                                  ? 'Turn on Bluetooth, then tap Scan.'
                                  : state.isScanning
                                      ? 'Scanning...'
                                      : 'No VAYA One found yet.',
                              style:
                                  const TextStyle(color: AppColors.textMuted),
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: EdgeInsets.zero,
                          itemCount: devices.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) => _PairingDeviceCard(
                            compact: true,
                            device: devices[index],
                            busy: state.isConnecting,
                            onConnect: () => onConnect(devices[index]),
                          ),
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  final String message;

  const _InlineError({required this.message});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.danger.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.danger.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline_rounded,
                color: AppColors.danger, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.danger, fontSize: 12),
              ),
            ),
          ],
        ),
      );
}

class _PreparingScreen extends StatelessWidget {
  final VoidCallback onBack;
  final VoidCallback onContinue;
  final bool preparing;

  const _PreparingScreen(
      {required this.onBack,
      required this.onContinue,
      required this.preparing});

  @override
  Widget build(BuildContext context) => _OnboardingShell(
        onBack: onBack,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxHeight < 720;
            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(28, compact ? 74 : 90, 28, 34),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - (compact ? 108 : 124)),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('SETUP', style: AppTypography.overline),
                    Column(
                      children: [
                        SizedBox(height: compact ? 28 : 48),
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: preparing ? 1 : 0.45),
                          duration: const Duration(milliseconds: 1000),
                          builder: (context, value, child) => SizedBox(
                            width: compact ? 104 : 132,
                            height: compact ? 104 : 132,
                            child: CircularProgressIndicator(
                                value: value,
                                strokeWidth: 3,
                                color: AppColors.accent),
                          ),
                        ),
                        SizedBox(height: compact ? 30 : 48),
                        Text('Preparing your VAYA One',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineMedium),
                        const SizedBox(height: 14),
                        const Text('Verifying secure connection...',
                            style: TextStyle(
                                color: AppColors.textMuted, fontSize: 18)),
                        SizedBox(height: compact ? 28 : 44),
                        const _SetupStep(
                            done: true, text: 'Bluetooth connected'),
                        const SizedBox(height: 12),
                        const _SetupStep(done: true, text: 'Device detected'),
                        const SizedBox(height: 12),
                        _SetupStep(
                            done: preparing,
                            text: 'Serial number verified',
                            number: 3),
                        const SizedBox(height: 12),
                        _SetupStep(
                            done: preparing,
                            text: 'Hardware authenticated',
                            number: 4),
                      ],
                    ),
                    Padding(
                      padding: EdgeInsets.only(top: compact ? 22 : 34),
                      child: PrimaryButton(
                          label: preparing ? 'Preparing...' : 'Continue',
                          onPressed: preparing ? null : onContinue),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
}

class _SetupCompleteScreen extends StatelessWidget {
  final VoidCallback onEnter;

  const _SetupCompleteScreen({required this.onEnter});

  @override
  Widget build(BuildContext context) => _OnboardingShell(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxHeight < 720;
            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(28, compact ? 54 : 76, 28, 34),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - (compact ? 88 : 110)),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('SETUP', style: AppTypography.overline),
                    Column(
                      children: [
                        SizedBox(height: compact ? 30 : 52),
                        Container(
                          width: compact ? 78 : 96,
                          height: compact ? 78 : 96,
                          decoration: BoxDecoration(
                              gradient: AppColors.primaryGradient,
                              shape: BoxShape.circle),
                          child: Icon(Icons.check_rounded,
                              color: Colors.black, size: compact ? 40 : 48),
                        ),
                        SizedBox(height: compact ? 24 : 34),
                        Text("You're all set",
                            style: Theme.of(context).textTheme.headlineMedium),
                        const SizedBox(height: 12),
                        const Text('Just a few final touches for your safety.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: AppColors.textMuted, fontSize: 18)),
                        SizedBox(height: compact ? 28 : 42),
                        const _PermissionTile(
                            icon: Icons.lock_outline_rounded,
                            title: 'PIN protection',
                            subtitle:
                                'Secure your controls with a 4-digit code.',
                            action: 'Set'),
                        const SizedBox(height: 14),
                        const _PermissionTile(
                            icon: Icons.fingerprint_rounded,
                            title: 'Biometric unlock',
                            subtitle: 'Face ID or fingerprint sign-in.',
                            action: 'Enable'),
                        const SizedBox(height: 14),
                        const _PermissionTile(
                            icon: Icons.phone_outlined,
                            title: 'Emergency contacts',
                            subtitle: 'Choose who to call when you need help.',
                            action: 'Add'),
                      ],
                    ),
                    Padding(
                      padding: EdgeInsets.only(top: compact ? 24 : 34),
                      child: PrimaryButton(
                          label: 'Enter VAYA Connect', onPressed: onEnter),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
}

class _BluetoothTitle extends StatelessWidget {
  const _BluetoothTitle();

  @override
  Widget build(BuildContext context) => const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bluetooth_rounded, color: AppColors.accent),
          SizedBox(width: 14),
          Text('PAIRING', style: AppTypography.overline),
        ],
      );
}

class _Dot extends StatelessWidget {
  const _Dot();

  @override
  Widget build(BuildContext context) => Container(
        width: 10,
        height: 10,
        decoration: const BoxDecoration(
            color: AppColors.accent, shape: BoxShape.circle),
      );
}

class _PermissionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? action;
  final bool compact;

  const _PermissionTile(
      {required this.icon,
      required this.title,
      required this.subtitle,
      this.action,
      this.compact = false});

  @override
  Widget build(BuildContext context) => GlassCard(
        padding: EdgeInsets.all(compact ? 14 : 22),
        borderRadius: BorderRadius.circular(compact ? 22 : 32),
        child: Row(
          children: [
            Container(
              width: compact ? 44 : 62,
              height: compact ? 44 : 62,
              decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.14),
                  shape: BoxShape.circle),
              child:
                  Icon(icon, color: AppColors.accent, size: compact ? 24 : 31),
            ),
            SizedBox(width: compact ? 12 : 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          color: AppColors.text,
                          fontSize: compact ? 16 : 19,
                          fontWeight: FontWeight.w800)),
                  SizedBox(height: compact ? 2 : 5),
                  Text(subtitle,
                      maxLines: compact ? 1 : null,
                      overflow: compact ? TextOverflow.ellipsis : null,
                      style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: compact ? 13 : 15)),
                ],
              ),
            ),
            if (action != null)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(20)),
                child: Text(action!,
                    style: const TextStyle(
                        color: AppColors.accent, fontWeight: FontWeight.w800)),
              ),
          ],
        ),
      );
}

class _PairingDeviceCard extends StatelessWidget {
  final BleDevice device;
  final bool busy;
  final VoidCallback onConnect;
  final bool compact;

  const _PairingDeviceCard(
      {required this.device,
      required this.busy,
      required this.onConnect,
      this.compact = false});

  @override
  Widget build(BuildContext context) => GlassCard(
        padding: EdgeInsets.all(compact ? 14 : 22),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: compact ? 42 : 56,
                  height: compact ? 42 : 56,
                  decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      shape: BoxShape.circle),
                  child: const Icon(Icons.check_circle_outline_rounded,
                      color: Colors.black),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(device.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: AppColors.text,
                              fontSize: compact ? 18 : 22,
                              fontWeight: FontWeight.w800)),
                      const SizedBox(height: 5),
                      Text('Serial · ${device.address}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppColors.textMuted)),
                    ],
                  ),
                ),
                if (!compact)
                  const Text('Excellent',
                      style: TextStyle(
                          color: AppColors.accent,
                          fontWeight: FontWeight.w800)),
              ],
            ),
            SizedBox(height: compact ? 12 : 22),
            PrimaryButton(
                label: busy ? 'Connecting...' : 'Connect',
                onPressed: busy ? null : onConnect),
          ],
        ),
      );
}

class _SetupStep extends StatelessWidget {
  final bool done;
  final String text;
  final int? number;

  const _SetupStep({required this.done, required this.text, this.number});

  @override
  Widget build(BuildContext context) => GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
        borderRadius: BorderRadius.circular(28),
        color: done ? AppColors.glass : AppColors.glass.withValues(alpha: 0.45),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                  color: done
                      ? AppColors.accent
                      : Colors.white.withValues(alpha: 0.04),
                  shape: BoxShape.circle),
              child: done
                  ? const Icon(Icons.check_rounded, color: Colors.black)
                  : Center(
                      child: Text('${number ?? ''}',
                          style: const TextStyle(color: AppColors.textDim))),
            ),
            const SizedBox(width: 18),
            Text(
              text,
              style: TextStyle(
                color: done ? AppColors.text : AppColors.textDim,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      );
}
