import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app/main_nav.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/typography.dart';
import '../core/widgets/animated_vehicle.dart';
import '../core/widgets/battery_indicator.dart';
import '../core/widgets/glass_card.dart';
import '../providers/app_state.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final battery = state.isConnected && state.battery > 0 ? state.battery : 84;

    return Container(
      decoration: const BoxDecoration(gradient: AppColors.appBackground),
      child: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 118),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _HomeHeader(connected: state.isConnected),
              const SizedBox(height: 24),
              _VehicleHero(connected: state.isConnected, battery: battery),
              const SizedBox(height: 22),
              _QuickActions(onControl: () => MainNavState.of(context)?.setIndex(1)),
              const SizedBox(height: 22),
              _BatteryCard(percent: battery),
              const SizedBox(height: 22),
              const _ActivityCard(),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  final bool connected;

  const _HomeHeader({required this.connected});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Good morning', style: TextStyle(color: AppColors.textMuted, fontSize: 16)),
                    const SizedBox(height: 8),
                    Text('Alex', style: Theme.of(context).textTheme.headlineMedium),
                  ],
                ),
              ),
              _CircleIcon(icon: Icons.notifications_none_rounded, onTap: () {}),
              const SizedBox(width: 12),
              _CircleIcon(icon: Icons.tune_rounded, onTap: () => MainNavState.of(context)?.setIndex(3)),
            ],
          ),
          const SizedBox(height: 26),
          AnimatedContainer(
            duration: const Duration(milliseconds: 240),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: (connected ? AppColors.success : AppColors.textMuted).withOpacity(0.14),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: connected ? AppColors.success : AppColors.textMuted,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  connected ? 'VAYA One · Connected' : 'VAYA One · Standby',
                  style: TextStyle(
                    color: connected ? AppColors.success : AppColors.textMuted,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
}

class _CircleIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CircleIcon({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: AppColors.glassSoft,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.border),
          ),
          child: Icon(icon, color: AppColors.text, size: 25),
        ),
      );
}

class _VehicleHero extends StatelessWidget {
  final bool connected;
  final int battery;

  const _VehicleHero({required this.connected, required this.battery});

  @override
  Widget build(BuildContext context) => GlassCard(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 30),
        gradient: AppColors.cardGradient,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('YOUR VAYA', style: AppTypography.overline),
                      SizedBox(height: 14),
                      Text('VAYA One', style: TextStyle(color: AppColors.text, fontSize: 30, fontWeight: FontWeight.w800)),
                      SizedBox(height: 6),
                      Text('Titanium · 2026', style: TextStyle(color: AppColors.textMuted, fontSize: 17)),
                    ],
                  ),
                ),
                _StatusPill(label: connected ? 'Ready' : 'Idle'),
              ],
            ),
            Center(child: AnimatedVehicle(size: MediaQuery.sizeOf(context).width * 0.64, compact: true)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _MetricPill(icon: Icons.battery_5_bar_rounded, label: 'BATTERY', value: '$battery%')),
                const SizedBox(width: 10),
                const Expanded(child: _MetricPill(icon: Icons.location_on_outlined, label: 'RANGE', value: '24 km')),
                const SizedBox(width: 10),
                const Expanded(child: _MetricPill(icon: Icons.schedule_rounded, label: 'TIME', value: '5h 20m')),
              ],
            ),
          ],
        ),
      );
}

class _StatusPill extends StatelessWidget {
  final String label;

  const _StatusPill({required this.label});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: AppColors.accent.withOpacity(0.14),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Text(label, style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.w800)),
      );
}

class _MetricPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _MetricPill({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.035),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppColors.textMuted, size: 15),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value, style: const TextStyle(color: AppColors.text, fontSize: 24, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      );
}

class _QuickActions extends StatelessWidget {
  final VoidCallback onControl;

  const _QuickActions({required this.onControl});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(child: _ActionButton(icon: Icons.bolt_rounded, label: 'Drive', onTap: onControl)),
          const SizedBox(width: 12),
          Expanded(child: _ActionButton(icon: Icons.battery_5_bar_rounded, label: 'Battery', onTap: () {})),
          const SizedBox(width: 12),
          Expanded(child: _ActionButton(icon: Icons.monitor_heart_outlined, label: 'Comfort', onTap: () {})),
          const SizedBox(width: 12),
          Expanded(child: _ActionButton(icon: Icons.shield_outlined, label: 'SOS', danger: true, onTap: () {})),
        ],
      );
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool danger;
  final VoidCallback onTap;

  const _ActionButton({required this.icon, required this.label, required this.onTap, this.danger = false});

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppColors.danger : AppColors.accent;
    return GlassCard(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: color.withOpacity(0.17), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 12),
          FittedBox(child: Text(label, style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w800))),
        ],
      ),
    );
  }
}

class _BatteryCard extends StatelessWidget {
  final int percent;

  const _BatteryCard({required this.percent});

  @override
  Widget build(BuildContext context) => GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.battery_5_bar_rounded, color: AppColors.accent, size: 20),
                SizedBox(width: 10),
                Text('Battery', style: TextStyle(color: AppColors.text, fontSize: 20, fontWeight: FontWeight.w800)),
                Spacer(),
                Text('Charging capable', style: TextStyle(color: AppColors.textMuted)),
              ],
            ),
            const SizedBox(height: 28),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('$percent', style: const TextStyle(color: AppColors.text, fontSize: 56, fontWeight: FontWeight.w800, height: 0.9)),
                const Text('%', style: TextStyle(color: AppColors.textMuted, fontSize: 24, fontWeight: FontWeight.w800)),
                const Spacer(),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Health', style: TextStyle(color: AppColors.textMuted, fontSize: 16)),
                    SizedBox(height: 4),
                    Text('Excellent', style: TextStyle(color: AppColors.success, fontSize: 17, fontWeight: FontWeight.w800)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text('Estimated 24 km remaining', style: TextStyle(color: AppColors.textMuted, fontSize: 16)),
            const SizedBox(height: 24),
            BatteryIndicator(percent: percent),
          ],
        ),
      );
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard();

  @override
  Widget build(BuildContext context) => GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Text("Today's activity", style: TextStyle(color: AppColors.text, fontSize: 20, fontWeight: FontWeight.w800)),
                Spacer(),
                Text('View all', style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w800)),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: const [
                Expanded(child: _ActivityMetric(value: '6.2km', label: 'DISTANCE')),
                SizedBox(width: 10),
                Expanded(child: _ActivityMetric(value: '3', label: 'RIDES')),
                SizedBox(width: 10),
                Expanded(child: _ActivityMetric(value: '1h 48m', label: 'ACTIVE')),
              ],
            ),
          ],
        ),
      );
}

class _ActivityMetric extends StatelessWidget {
  final String value;
  final String label;

  const _ActivityMetric({required this.value, required this.label});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          children: [
            FittedBox(child: Text(value, style: const TextStyle(color: AppColors.text, fontSize: 25, fontWeight: FontWeight.w800))),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w700)),
          ],
        ),
      );
}
