import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/guest_bottom_navigation.dart';
import '../../data/services/session_service.dart';
import '../events/create_event_placeholder_screen.dart';
import '../guest/guest_home_screen.dart';
import '../materials/articles_list_screen.dart';
import 'profile_screen.dart';

class DoctorRecommendationsScreen extends StatefulWidget {
  const DoctorRecommendationsScreen({super.key});

  @override
  State<DoctorRecommendationsScreen> createState() =>
      _DoctorRecommendationsScreenState();
}

class _DoctorRecommendationsScreenState
    extends State<DoctorRecommendationsScreen> {
  final _supabase = Supabase.instance.client;

  bool _isLoading = true;
  String? _errorText;
  List<DoctorRecommendation> _recommendations = const [];

  @override
  void initState() {
    super.initState();
    _loadRecommendations();
  }

  Future<void> _loadRecommendations() async {
    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      final recommendations = await _fetchRecommendations().timeout(
        const Duration(seconds: 10),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _recommendations = recommendations;
        _isLoading = false;
      });
    } catch (error, stackTrace) {
      debugPrint('Doctor recommendations load error: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) {
        return;
      }

      setState(() {
        _errorText = 'Не удалось загрузить рекомендации.';
        _isLoading = false;
      });
    }
  }

  Future<List<DoctorRecommendation>> _fetchRecommendations() async {
    final patientId = await _loadCurrentPatientId();
    final data = await _supabase
        .from('recommendations')
        .select(
          'recommendation_id, recommendation_text, received_at, recommendation_status',
        )
        .eq('patient_id', patientId)
        .order('received_at', ascending: false);

    return data
        .map(
          (row) =>
              DoctorRecommendation.fromJson(Map<String, dynamic>.from(row)),
        )
        .toList();
  }

  Future<Object> _loadCurrentPatientId() async {
    final externalId = await SessionService().getCurrentPatientExternalId();
    final data = await _supabase
        .from('patients')
        .select('patient_id')
        .eq('external_patient_id', externalId)
        .limit(1);

    if (data.isEmpty) {
      throw StateError('Patient not found for external id: $externalId');
    }

    final patientId = data.first['patient_id'];
    if (patientId == null) {
      throw StateError('Patient row has no patient_id');
    }

    return patientId;
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
            child: RefreshIndicator(
              onRefresh: _loadRecommendations,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(11, 8, 0, 126),
                children: [
                  const _BackButtonText(),
                  const SizedBox(height: 25),
                  Padding(
                    padding: const EdgeInsets.only(left: 12, right: 24),
                    child: Text(
                      'Рекомендации врача',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontSize: 24, fontWeight: FontWeight.w500),
                    ),
                  ),
                  const SizedBox(height: 45),
                  _buildContent(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const SizedBox(
        height: 280,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorText != null) {
      return _MessageText(text: _errorText!);
    }

    if (_recommendations.isEmpty) {
      return const _MessageText(text: 'Пока нет рекомендаций врача.');
    }

    final grouped = groupByMonth(_recommendations, (item) => item.receivedAt);

    return Column(
      children: [
        for (final group in grouped.entries) ...[
          _MonthPill(label: group.key),
          const SizedBox(height: 16),
          for (var index = 0; index < group.value.length; index++) ...[
            _RecommendationRow(recommendation: group.value[index]),
            if (index < group.value.length - 1)
              const Divider(height: 20, color: Color(0xFFBDBDBD)),
          ],
          const SizedBox(height: 20),
        ],
      ],
    );
  }
}

class _RecommendationRow extends StatelessWidget {
  const _RecommendationRow({required this.recommendation});

  final DoctorRecommendation recommendation;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 20, right: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            recommendation.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${formatDate(recommendation.receivedAt)} ${recommendation.preview}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: const Color(0xFF777777),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class DoctorRecommendation {
  const DoctorRecommendation({
    required this.id,
    required this.text,
    required this.receivedAt,
    required this.status,
  });

  final String id;
  final String text;
  final DateTime receivedAt;
  final String status;

  String get title {
    final firstLine = text.split(RegExp(r'[\n.!?]')).first.trim();
    if (firstLine.isEmpty) {
      return 'Рекомендация врача';
    }

    return firstLine;
  }

  String get preview {
    if (text.length <= 120) {
      return text;
    }

    return '${text.substring(0, 120)}...';
  }

  factory DoctorRecommendation.fromJson(Map<String, dynamic> json) {
    return DoctorRecommendation(
      id: asString(json['recommendation_id']),
      text: asString(json['recommendation_text'], fallback: 'Рекомендация'),
      receivedAt: asDateTime(json['received_at']),
      status: asString(json['recommendation_status']),
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
          padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
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
          height: 190,
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

class _MonthPill extends StatelessWidget {
  const _MonthPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.76),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withValues(alpha: 0.72)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 19, vertical: 5),
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontSize: 17,
              fontWeight: FontWeight.w400,
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

Map<String, List<T>> groupByMonth<T>(
  List<T> items,
  DateTime Function(T item) dateOf,
) {
  final grouped = <String, List<T>>{};
  for (final item in items) {
    final key = monthYearLabel(dateOf(item));
    grouped.putIfAbsent(key, () => []).add(item);
  }

  return grouped;
}

String monthYearLabel(DateTime date) {
  const months = [
    'Январь',
    'Февраль',
    'Март',
    'Апрель',
    'Май',
    'Июнь',
    'Июль',
    'Август',
    'Сентябрь',
    'Октябрь',
    'Ноябрь',
    'Декабрь',
  ];

  return '${months[date.month - 1]} ${date.year}';
}

String formatDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day.$month.${date.year}';
}

String asString(Object? value, {String fallback = ''}) {
  final text = value?.toString().trim();
  if (text == null || text.isEmpty) {
    return fallback;
  }

  return text;
}

DateTime asDateTime(Object? value) {
  return DateTime.tryParse(value?.toString() ?? '') ?? DateTime.now();
}
