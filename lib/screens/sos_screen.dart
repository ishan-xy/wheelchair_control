import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app/app_theme.dart';
import '../providers/app_state.dart';
import '../services/wheelchair_commands.dart';
import '../widgets/app_card.dart';
import '../widgets/screen_header.dart';

class SosScreen extends StatefulWidget {
  const SosScreen({super.key});

  @override
  State<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat(reverse: true);
    _pulse = Tween(begin: 1.0, end: 1.06).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ScreenHeader(
                  title: 'Emergency',
                  subtitle: 'Quick access to emergency services',
                  titleColor: AppColors.danger,
                ),
                const SizedBox(height: 32),
                Center(
                  child: ScaleTransition(
                    scale: _pulse,
                    child: _SosButton(onTap: () => _sendSos(context)),
                  ),
                ),
                const SizedBox(height: 36),
                const Text('Emergency Actions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 12),
                for (final action in _actions) _EmergencyActionTile(action: action),
              ],
            ),
          ),
        ),
      );

  void _sendSos(BuildContext context) {
    unawaited(context.read<AppState>().sendCommand(WheelchairCommands.stop, reliable: true));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('SOS Alert Sent!'),
        backgroundColor: AppColors.danger,
      ),
    );
  }
}

const _actions = [
  _EmergencyAction(Icons.phone, 'Call Emergency Contact', 'Connect to caregiver'),
  _EmergencyAction(Icons.location_on, 'Share Location', 'Send GPS coordinates'),
  _EmergencyAction(Icons.notifications_active, 'Trigger Alarm', 'Sound local alert'),
];

class _SosButton extends StatelessWidget {
  final VoidCallback onTap;

  const _SosButton({required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 200,
          height: 200,
          decoration: BoxDecoration(
            color: AppColors.danger,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.danger.withValues(alpha: 0.35),
                blurRadius: 24,
                spreadRadius: 8,
              ),
            ],
          ),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.notifications, color: Colors.white, size: 52),
              SizedBox(height: 8),
              Text('SOS', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
              Text('Send Emergency Alert', style: TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
        ),
      );
}

class _EmergencyActionTile extends StatelessWidget {
  final _EmergencyAction action;

  const _EmergencyActionTile({required this.action});

  @override
  Widget build(BuildContext context) => AppCard(
        margin: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(action.icon, color: AppColors.primary),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(action.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(action.subtitle, style: const TextStyle(color: Colors.grey, fontSize: 13)),
              ],
            ),
          ],
        ),
      );
}

class _EmergencyAction {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmergencyAction(this.icon, this.title, this.subtitle);
}
