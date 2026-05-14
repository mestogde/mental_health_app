import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class GuestBottomNavigation extends StatelessWidget {
  const GuestBottomNavigation({
    super.key,
    this.selectedIndex = 0,
    this.onItemTap,
  });

  final int selectedIndex;
  final ValueChanged<int>? onItemTap;

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.paddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(22, 0, 22, bottomPadding + 40),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.7)),
            ),
            child: SizedBox(
              height: 49,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _BottomNavItem(
                    icon: Icons.home_outlined,
                    isSelected: selectedIndex == 0,
                    onTap: () => onItemTap?.call(0),
                  ),
                  _BottomNavItem(
                    icon: Icons.layers_outlined,
                    isSelected: selectedIndex == 1,
                    onTap: () => onItemTap?.call(1),
                  ),
                  _BottomNavItem(
                    icon: Icons.add,
                    isSelected: selectedIndex == 2,
                    onTap: () => onItemTap?.call(2),
                  ),
                  _BottomNavItem(
                    icon: Icons.person_outline,
                    isSelected: selectedIndex == 3,
                    onTap: () => onItemTap?.call(3),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  const _BottomNavItem({
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final iconColor = isSelected ? Colors.white : AppColors.textDark;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 49,
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: isSelected ? 46 : 34,
            height: isSelected ? 30 : 34,
            decoration: BoxDecoration(
              color: isSelected ? AppColors.textDark : Colors.transparent,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, size: 21, color: iconColor),
          ),
        ),
      ),
    );
  }
}
