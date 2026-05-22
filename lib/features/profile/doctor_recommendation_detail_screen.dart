import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/navigation/no_transition_page_route.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/guest_bottom_navigation.dart';
import '../calendar/activity_calendar_screen.dart';
import '../guest/guest_home_screen.dart';
import '../events/events_screen.dart';
import 'doctor_recommendations_screen.dart';
import 'profile_screen.dart';

class DoctorRecommendationDetailScreen extends StatefulWidget {
  const DoctorRecommendationDetailScreen({
    super.key,
    required this.recommendationId,
  });

  final String recommendationId;

  @override
  State<DoctorRecommendationDetailScreen> createState() =>
      _DoctorRecommendationDetailScreenState();
}

class _DoctorRecommendationDetailScreenState
    extends State<DoctorRecommendationDetailScreen> {
  final _supabase = Supabase.instance.client;

  bool _isLoading = true;
  String? _errorText;
  DoctorRecommendation? _recommendation;

  @override
  void initState() {
    super.initState();
    _loadRecommendation();
  }

  Future<void> _loadRecommendation() async {
    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      final data = await _supabase
          .from('recommendations')
          .select(
            'recommendation_id, recommendation_text, received_at, recommendation_status',
          )
          .eq('recommendation_id', widget.recommendationId)
          .limit(1)
          .timeout(const Duration(seconds: 10));

      if (!mounted) {
        return;
      }

      if (data.isEmpty) {
        setState(() {
          _errorText = 'Рекомендация не найдена.';
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _recommendation = DoctorRecommendation.fromJson(
          Map<String, dynamic>.from(data.first),
        );
        _isLoading = false;
      });
    } catch (error, stackTrace) {
      debugPrint('Recommendation detail load error: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) {
        return;
      }

      setState(() {
        _errorText = 'Не удалось загрузить рекомендацию.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final recommendation = _recommendation;

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
            child: RefreshIndicator(
              onRefresh: _loadRecommendation,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(11, 8, 0, 126),
                children: [
                  const _BackButtonText(),
                  const SizedBox(height: 25),
                  Padding(
                    padding: const EdgeInsets.only(left: 12, right: 24),
                    child: Text(
                      recommendation == null
                          ? 'Рекомендация'
                          : 'Рекомендация ${formatDate(recommendation.receivedAt)}',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontSize: 24, fontWeight: FontWeight.w500),
                    ),
                  ),
                  const SizedBox(height: 50),
                  _buildContent(context),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(
        height: 300,
        child: Center(
          child: CircularProgressIndicator(color: AppColors.pinkAccent),
        ),
      );
    }

    if (_errorText != null) {
      return _MessageText(text: _errorText!);
    }

    final recommendation = _recommendation;
    if (recommendation == null) {
      return const _MessageText(text: 'Рекомендация не найдена.');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 24, right: 24),
          child: Text(
            recommendation.title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontSize: 17,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
        const SizedBox(height: 13),
        const Divider(height: 1, color: Color(0xFFBDBDBD)),
        const SizedBox(height: 13),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 25),
          child: Text(
            recommendation.text,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              height: 1.45,
              fontSize: 13,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      ],
    );
  }
}

class _BackButtonText extends StatelessWidget {
  const _BackButtonText();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            '← Назад',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: const Color(0xFF777777),
              fontSize: 13,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}

class _TopGlow extends StatelessWidget {
  const _TopGlow();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Align(
        alignment: Alignment.topCenter,
        child: Container(
          height: 185,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.yellowAccent.withValues(alpha: 0.78),
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

class _MessageText extends StatelessWidget {
  const _MessageText({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 80),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: Theme.of(
          context,
        ).textTheme.bodyLarge?.copyWith(color: const Color(0xFF777777)),
      ),
    );
  }
}

void _handleExtendedNavigation(BuildContext context, int index) {
  if (index == 0) {
    Navigator.of(context).pushAndRemoveUntil(
      noTransitionPageRoute<void>(
        builder: (context) => const GuestHomeScreen(),
      ),
      (route) => false,
    );
    return;
  }

  if (index == 1) {
    Navigator.of(context).pushReplacement(
      noTransitionPageRoute<void>(builder: (context) => const EventsScreen()),
    );
    return;
  }

  if (index == 2) {
    Navigator.of(context).pushReplacement(
      noTransitionPageRoute<void>(
        builder: (context) => const ActivityCalendarScreen(),
      ),
    );
    return;
  }

  Navigator.of(context).pushReplacement(
    noTransitionPageRoute<void>(builder: (context) => const ProfileScreen()),
  );
}
