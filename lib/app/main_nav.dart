import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../screens/control_screen.dart';
import '../screens/home_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/location_screen.dart';

class MainNav extends StatefulWidget {
  const MainNav({super.key});

  @override
  State<MainNav> createState() => MainNavState();
}

class MainNavState extends State<MainNav> {
  int _index = 0;

  static MainNavState? of(BuildContext context) =>
      context.findAncestorStateOfType<MainNavState>();

  static const _screens = [
    HomeScreen(),
    ControlScreen(),
    LocationScreen(),
    SettingsScreen(),
  ];

  void setIndex(int value) => setState(() => _index = value);

  @override
  Widget build(BuildContext context) => Scaffold(
        extendBody: true,
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: KeyedSubtree(key: ValueKey(_index), child: _screens[_index]),
        ),
        bottomNavigationBar: _VayaBottomNav(index: _index, onChanged: setIndex),
      );
}

class _VayaBottomNav extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChanged;

  const _VayaBottomNav({required this.index, required this.onChanged});

  static const _items = [
    (Icons.home_outlined, Icons.home_rounded, 'Home'),
    (Icons.sports_esports_outlined, Icons.sports_esports_rounded, 'Control'),
    (Icons.school_outlined, Icons.school_rounded, 'Learn'),
    (Icons.person_outline_rounded, Icons.person_rounded, 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(18, 0, 18, bottom + 14),
      child: Container(
        height: 76,
        decoration: BoxDecoration(
          color: AppColors.surfaceHigh.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(36),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 28,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: Row(
          children: [
            for (var i = 0; i < _items.length; i++)
              Expanded(
                child: _NavItem(
                  icon: index == i ? _items[i].$2 : _items[i].$1,
                  label: _items[i].$3,
                  selected: index == i,
                  onTap: () => onChanged(i),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(32),
        onTap: onTap,
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: 34,
              height: 5,
              margin: const EdgeInsets.only(top: 8),
              decoration: BoxDecoration(
                color: selected ? AppColors.accent : Colors.transparent,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon,
                        color:
                            selected ? AppColors.accent : AppColors.textMuted,
                        size: 28),
                    const SizedBox(height: 4),
                    Text(
                      label,
                      style: TextStyle(
                        color:
                            selected ? AppColors.accent : AppColors.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
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
