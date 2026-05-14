import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/guest_bottom_navigation.dart';
import '../../data/services/session_service.dart';
import '../calendar/activity_calendar_screen.dart';
import '../guest/guest_home_screen.dart';
import '../events/events_screen.dart';
import 'doctor_recommendations_screen.dart';
import 'state_notes_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _supabase = Supabase.instance.client;
  String _fullName = 'Елизавета';
  int _readArticlesCount = 5;
  int _completedMeetingsCount = 3;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final patientExternalId = await SessionService()
          .getCurrentPatientExternalId();
      debugPrint('Profile patient external id: $patientExternalId');

      final patient = await _loadPatient(patientExternalId);
      debugPrint(
        'Loaded profile patient: patient_id=${patient.id}, full_name=${patient.fullName}',
      );

      final results = await Future.wait([
        _loadCompletedMaterialsCount(patient.id),
        _loadAcceptedEventsCount(patient.id),
      ]).timeout(const Duration(seconds: 10));

      if (!mounted) {
        return;
      }

      setState(() {
        _fullName = patient.fullName;
        _readArticlesCount = results[0];
        _completedMeetingsCount = results[1];
      });
    } catch (error, stackTrace) {
      debugPrint('Profile stats load error: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<_ProfilePatient> _loadPatient(String patientExternalId) async {
    try {
      final data = await _supabase
          .from('patients')
          .select('patient_id, full_name')
          .eq('external_patient_id', patientExternalId)
          .limit(1);

      debugPrint('Loaded profile patient raw response: $data');

      if (data.isEmpty) {
        debugPrint(
          'Profile patient query returned no rows for external id: $patientExternalId',
        );
        throw StateError('Profile patient not found');
      }

      final row = Map<String, dynamic>.from(data.first);
      final patientId = row['patient_id'];
      final fullName = row['full_name']?.toString().trim();

      if (patientId == null || fullName == null || fullName.isEmpty) {
        debugPrint('Profile patient row is incomplete: $row');
        throw StateError('Profile patient row is incomplete');
      }

      return _ProfilePatient(id: patientId, fullName: fullName);
    } catch (error, stackTrace) {
      debugPrint('Profile patient load error: $error');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<int> _loadCompletedMaterialsCount(Object patientId) async {
    final data = await _supabase
        .from('material_views')
        .select('patient_id')
        .eq('patient_id', patientId)
        .eq('reading_status', 'completed');

    final count = data.length;
    debugPrint('Completed materials count for patient_id=$patientId: $count');
    return count;
  }

  Future<int> _loadAcceptedEventsCount(Object patientId) async {
    final data = await _supabase
        .from('event_requests')
        .select('patient_id')
        .eq('patient_id', patientId)
        .eq('request_status', 'accepted');

    final count = data.length;
    debugPrint('Accepted events count for patient_id=$patientId: $count');
    return count;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: AppColors.background,
      bottomNavigationBar: GuestBottomNavigation(
        selectedIndex: 3,
        onItemTap: (index) => _handleExtendedNavigation(context, index),
      ),
      body: Stack(
        children: [
          const _TopGlow(),
          SafeArea(
            bottom: false,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(22, 39, 22, 126),
              children: [
                const Align(
                  alignment: Alignment.centerRight,
                  child: Icon(Icons.settings_outlined, size: 28),
                ),
                const SizedBox(height: 5),
                const _Avatar(),
                const SizedBox(height: 16),
                Text(
                  _fullName,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontSize: 34,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 39),
                _StatisticsCard(
                  readArticlesCount: _readArticlesCount,
                  completedMeetingsCount: _completedMeetingsCount,
                ),
                const SizedBox(height: 26),
                const _ProfileMenuCard(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfilePatient {
  const _ProfilePatient({required this.id, required this.fullName});

  final Object id;
  final String fullName;
}

class _TopGlow extends StatelessWidget {
  const _TopGlow();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Align(
        alignment: Alignment.topCenter,
        child: Container(
          height: 236,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.yellowAccent.withValues(alpha: 0.74),
                AppColors.yellowAccent.withValues(alpha: 0.28),
                AppColors.background.withValues(alpha: 0),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.blueAccent.withValues(alpha: 0.75),
              AppColors.pinkAccent.withValues(alpha: 0.85),
            ],
          ),
        ),
        child: const SizedBox.square(
          dimension: 128,
          child: Icon(
            Icons.person_outline,
            size: 70,
            color: AppColors.textDark,
          ),
        ),
      ),
    );
  }
}

class _StatisticsCard extends StatelessWidget {
  const _StatisticsCard({
    required this.readArticlesCount,
    required this.completedMeetingsCount,
  });

  final int readArticlesCount;
  final int completedMeetingsCount;

  @override
  Widget build(BuildContext context) {
    return _SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Персональная статистика',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontSize: 17,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              Text(
                'Последние 30 дней',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF777777),
                ),
              ),
              const SizedBox(width: 3),
              const Icon(Icons.keyboard_arrow_down, size: 17),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFBDBDBD)),
          const SizedBox(height: 13),
          IntrinsicHeight(
            child: Row(
              children: [
                Expanded(
                  child: _StatColumn(
                    icon: Icons.article_outlined,
                    label: 'прочитанные статьи',
                    value: readArticlesCount,
                  ),
                ),
                const VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: Color(0xFFBDBDBD),
                ),
                Expanded(
                  child: _StatColumn(
                    icon: Icons.people_alt_outlined,
                    label: 'завершённые встречи',
                    value: completedMeetingsCount,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  const _StatColumn({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 24, color: AppColors.textDark),
        const SizedBox(height: 7),
        Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 13),
        ),
        const SizedBox(height: 6),
        Text(
          value.toString(),
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _ProfileMenuCard extends StatelessWidget {
  const _ProfileMenuCard();

  @override
  Widget build(BuildContext context) {
    return _SoftCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _MenuRow(
            icon: Icons.medical_services_outlined,
            label: 'Рекомендации врача',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) => const DoctorRecommendationsScreen(),
                ),
              );
            },
          ),
          const Divider(height: 1, indent: 20, color: Color(0xFFD0D0D0)),
          _MenuRow(
            icon: Icons.sentiment_satisfied_alt_outlined,
            label: 'Мои заметки о состоянии',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) => const StateNotesScreen(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 26),
            const SizedBox(width: 13),
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontSize: 17,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFF777777)),
          ],
        ),
      ),
    );
  }
}

class _SoftCard extends StatelessWidget {
  const _SoftCard({
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(20, 16, 20, 22),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.72)),
      ),
      child: Padding(padding: padding, child: child),
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
    return;
  }

  Navigator.of(context).pushReplacement(
    MaterialPageRoute<void>(builder: (context) => const ProfileScreen()),
  );
}
