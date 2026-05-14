import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/guest_bottom_navigation.dart';
import '../guest/guest_home_screen.dart';
import '../materials/articles_list_screen.dart';
import '../profile/profile_screen.dart';

class CreateEventPlaceholderScreen extends StatelessWidget {
  const CreateEventPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _ExtendedPlaceholderScreen(
      title: 'Создание события',
      selectedIndex: 2,
      onItemTap: (index) => _handleExtendedNavigation(context, index),
    );
  }
}

class EventsPlaceholderScreen extends StatelessWidget {
  const EventsPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _ExtendedPlaceholderScreen(
      title: 'События',
      selectedIndex: 2,
      onItemTap: (index) => _handleExtendedNavigation(context, index),
    );
  }
}

class _ExtendedPlaceholderScreen extends StatelessWidget {
  const _ExtendedPlaceholderScreen({
    required this.title,
    required this.selectedIndex,
    required this.onItemTap,
  });

  final String title;
  final int selectedIndex;
  final ValueChanged<int> onItemTap;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: AppColors.background,
      bottomNavigationBar: GuestBottomNavigation(
        selectedIndex: selectedIndex,
        onItemTap: onItemTap,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 56, 24, 120),
          child: Align(
            alignment: Alignment.topLeft,
            child: Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontSize: 28,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

void _handleExtendedNavigation(BuildContext context, int index) {
  if (index == 0) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (context) => const GuestHomeScreen()),
      (route) => false,
    );
    return;
  }

  if (index == 1) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (context) => const ArticlesListScreen(isExtendedAccess: true),
      ),
    );
    return;
  }

  if (index == 2) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (context) => const CreateEventPlaceholderScreen(),
      ),
    );
    return;
  }

  Navigator.of(context).pushReplacement(
    MaterialPageRoute<void>(builder: (context) => const ProfileScreen()),
  );
}
