import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/guest_bottom_navigation.dart';
import '../calendar/activity_calendar_screen.dart';
import '../guest/guest_home_screen.dart';
import '../events/events_screen.dart';

class ProfilePlaceholderScreen extends StatelessWidget {
  const ProfilePlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: AppColors.background,
      bottomNavigationBar: GuestBottomNavigation(
        selectedIndex: 3,
        onItemTap: (index) => _handleExtendedNavigation(context, index),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 56, 24, 120),
          child: Align(
            alignment: Alignment.topLeft,
            child: Text(
              'Профиль',
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
      MaterialPageRoute<void>(builder: (context) => const EventsScreen()),
    );
    return;
  }

  if (index == 2) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (context) => const ActivityCalendarScreen(),
      ),
    );
  }
}
