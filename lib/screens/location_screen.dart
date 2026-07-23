import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/typography.dart';
import '../core/widgets/glass_card.dart';

class LocationScreen extends StatelessWidget {
  const LocationScreen({super.key});

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(gradient: AppColors.appBackground),
        child: SafeArea(
          bottom: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 86, 22, 124),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('LEARNING CENTER', style: AppTypography.overline),
                const SizedBox(height: 10),
                Text('Master your VAYA',
                    style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 34),
                GlassCard(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF0D6587), Color(0xFF112025)],
                  ),
                  padding: const EdgeInsets.all(28),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SmallBadge('Featured'),
                      SizedBox(height: 32),
                      Text('Your first ride',
                          style: TextStyle(
                              color: AppColors.text,
                              fontSize: 27,
                              fontWeight: FontWeight.w800)),
                      SizedBox(height: 16),
                      Text(
                          'A 3-minute walkthrough of everything you need to know.',
                          style: TextStyle(
                              color: AppColors.textMuted, fontSize: 17)),
                      SizedBox(height: 26),
                      _TutorialButton(),
                    ],
                  ),
                ),
                const SizedBox(height: 26),
                const _LessonCard(
                  icon: Icons.sports_esports_outlined,
                  title: 'Driving',
                  lessons: [
                    'Joystick operation',
                    'Driving modes',
                    'Turning tips'
                  ],
                ),
                const SizedBox(height: 22),
                const _LessonCard(
                  icon: Icons.bolt_rounded,
                  title: 'Charging',
                  lessons: [
                    'How to charge',
                    'Battery care',
                    'Long-term storage'
                  ],
                ),
                const SizedBox(height: 22),
                const _LessonCard(
                  icon: Icons.shield_outlined,
                  title: 'Safety',
                  lessons: [
                    'Ramps & slopes',
                    'Emergency stop',
                    'Caregiver handoff'
                  ],
                ),
              ],
            ),
          ),
        ),
      );
}

class _SmallBadge extends StatelessWidget {
  final String label;

  const _SmallBadge(this.label);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(label,
            style: const TextStyle(
                color: AppColors.text, fontWeight: FontWeight.w800)),
      );
}

class _TutorialButton extends StatelessWidget {
  const _TutorialButton();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(22),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.play_circle_outline_rounded, color: AppColors.text),
            SizedBox(width: 10),
            Text('Watch tutorial',
                style: TextStyle(
                    color: AppColors.text, fontWeight: FontWeight.w800)),
          ],
        ),
      );
}

class _LessonCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<String> lessons;

  const _LessonCard(
      {required this.icon, required this.title, required this.lessons});

  @override
  Widget build(BuildContext context) => GlassCard(
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 62,
                  height: 62,
                  decoration: const BoxDecoration(
                      color: AppColors.accent, shape: BoxShape.circle),
                  child: Icon(icon, color: Colors.black, size: 31),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              color: AppColors.text,
                              fontSize: 22,
                              fontWeight: FontWeight.w800)),
                      const SizedBox(height: 6),
                      Text('${lessons.length} lessons',
                          style: const TextStyle(
                              color: AppColors.textMuted, fontSize: 16)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 26),
            for (var i = 0; i < lessons.length; i++) ...[
              _LessonRow(label: lessons[i]),
              if (i != lessons.length - 1)
                Divider(
                    color: Colors.white.withValues(alpha: 0.06), height: 24),
            ],
          ],
        ),
      );
}

class _LessonRow extends StatelessWidget {
  final String label;

  const _LessonRow({required this.label});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
              child: Text(label,
                  style: const TextStyle(
                      color: AppColors.text,
                      fontSize: 19,
                      fontWeight: FontWeight.w500))),
          const Icon(Icons.chevron_right_rounded,
              color: AppColors.textMuted, size: 28),
        ],
      );
}
