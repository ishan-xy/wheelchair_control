import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/typography.dart';
import '../core/widgets/glass_card.dart';
import '../providers/app_state.dart';
import '../services/bluetooth_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) unawaited(context.read<AppState>().loadPairedDevices());
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Container(
      decoration: BoxDecoration(gradient: AppColors.appBackground),
      child: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 86, 22, 124),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('ACCOUNT', style: AppTypography.overline),
              const SizedBox(height: 10),
              Text('Profile',
                  style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 34),
              const _ProfileCard(),
              const SizedBox(height: 24),
              _DeviceSection(state: state),
              const SizedBox(height: 18),
              const _ProfileTile(
                  icon: Icons.group_outlined,
                  title: 'Caregiver Mode',
                  subtitle: 'Share status with loved ones'),
              const SizedBox(height: 14),
              const _ProfileTile(
                  icon: Icons.monitor_heart_outlined,
                  title: 'Comfort & Posture',
                  subtitle: 'Monitor sitting habits'),
              const SizedBox(height: 14),
              const _ProfileTile(
                  icon: Icons.shield_outlined,
                  title: 'Emergency',
                  subtitle: 'Contacts & instant SOS',
                  danger: true),
              const SizedBox(height: 14),
              const _ProfileTile(
                  icon: Icons.headset_mic_outlined,
                  title: 'VAYA Support',
                  subtitle: 'Troubleshooting & service'),
              const SizedBox(height: 28),
              GlassCard(
                padding:
                    const EdgeInsets.symmetric(horizontal: 26, vertical: 20),
                borderRadius: BorderRadius.circular(26),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.logout_rounded, color: AppColors.textMuted),
                    SizedBox(width: 12),
                    Text('Sign out',
                        style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 18,
                            fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              const Center(
                  child: Text('VAYA Connect · v1.0.0',
                      style: TextStyle(color: AppColors.textDim))),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard();

  @override
  Widget build(BuildContext context) => GlassCard(
        gradient: AppColors.cardGradient,
        child: Row(
          children: [
            Stack(
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      shape: BoxShape.circle),
                  child: const Center(
                      child: Text('A',
                          style: TextStyle(
                              color: Colors.black,
                              fontSize: 30,
                              fontWeight: FontWeight.w900))),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: AppColors.success,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.background, width: 3),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 22),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Alex Rivera',
                      style: TextStyle(
                          color: AppColors.text,
                          fontSize: 23,
                          fontWeight: FontWeight.w800)),
                  SizedBox(height: 6),
                  Text('VAYA One · VY-00192',
                      style:
                          TextStyle(color: AppColors.textMuted, fontSize: 16)),
                ],
              ),
            ),
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  shape: BoxShape.circle),
              child: const Icon(Icons.tune_rounded, color: AppColors.text),
            ),
          ],
        ),
      );
}

class _DeviceSection extends StatelessWidget {
  final AppState state;

  const _DeviceSection({required this.state});

  @override
  Widget build(BuildContext context) {
    final devices = [...state.pairedDevices, ...state.discoveredDevices];
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bluetooth_rounded, color: AppColors.accent),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('VAYA One pairing',
                    style: TextStyle(
                        color: AppColors.text,
                        fontSize: 20,
                        fontWeight: FontWeight.w800)),
              ),
              TextButton.icon(
                onPressed: state.isScanning
                    ? () => unawaited(state.stopScan())
                    : () => unawaited(state.startScan()),
                icon: Icon(
                    state.isScanning
                        ? Icons.stop_rounded
                        : Icons.refresh_rounded,
                    size: 18),
                label: Text(state.isScanning ? 'Stop' : 'Scan'),
              ),
            ],
          ),
          if (state.errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(state.errorMessage!,
                style: const TextStyle(color: AppColors.danger)),
          ],
          const SizedBox(height: 14),
          if (state.isScanning) const LinearProgressIndicator(minHeight: 2),
          if (devices.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 18),
              child: Text('Scan nearby devices to connect your VAYA One.',
                  style: TextStyle(color: AppColors.textMuted)),
            )
          else
            for (final device in devices)
              _DeviceRow(device: device, state: state),
        ],
      ),
    );
  }
}

class _DeviceRow extends StatelessWidget {
  final BleDevice device;
  final AppState state;

  const _DeviceRow({required this.device, required this.state});

  @override
  Widget build(BuildContext context) {
    final connected =
        state.isConnected && state.connectedDeviceAddress == device.address;
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => connected
            ? unawaited(state.disconnect())
            : unawaited(state.connectTo(device)),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Row(
            children: [
              Icon(
                  connected
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: connected ? AppColors.success : AppColors.textMuted),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(device.label,
                        style: const TextStyle(
                            color: AppColors.text,
                            fontSize: 17,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(device.address,
                        style: const TextStyle(
                            color: AppColors.textMuted, fontSize: 12)),
                  ],
                ),
              ),
              Text(connected ? 'Connected' : 'Connect',
                  style: TextStyle(
                      color: connected ? AppColors.success : AppColors.accent,
                      fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool danger;

  const _ProfileTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppColors.danger : AppColors.accent;
    return GlassCard(
      padding: const EdgeInsets.all(22),
      borderRadius: BorderRadius.circular(28),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.16), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 29),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: AppColors.text,
                        fontSize: 20,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 5),
                Text(subtitle,
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 15)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded,
              color: AppColors.textMuted, size: 30),
        ],
      ),
    );
  }
}
