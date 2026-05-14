import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/guest_bottom_navigation.dart';
import '../../data/services/session_service.dart';
import '../notes/new_state_note_screen.dart';
import '../notes/state_note_detail_screen.dart';
import '../calendar/activity_calendar_screen.dart';
import '../guest/guest_home_screen.dart';
import '../events/events_screen.dart';
import 'profile_screen.dart';

class StateNotesScreen extends StatefulWidget {
  const StateNotesScreen({super.key});

  @override
  State<StateNotesScreen> createState() => _StateNotesScreenState();
}

class _StateNotesScreenState extends State<StateNotesScreen> {
  final _supabase = Supabase.instance.client;

  bool _isLoading = true;
  String? _errorText;
  List<StateNoteItem> _notes = const [];

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  Future<void> _loadNotes() async {
    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      final notes = await _fetchNotes().timeout(const Duration(seconds: 10));

      if (!mounted) {
        return;
      }

      setState(() {
        _notes = notes;
        _isLoading = false;
      });
    } catch (error, stackTrace) {
      debugPrint('State notes load error: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) {
        return;
      }

      setState(() {
        _errorText = 'Не удалось загрузить заметки о состоянии.';
        _isLoading = false;
      });
    }
  }

  Future<List<StateNoteItem>> _fetchNotes() async {
    final patientId = await _loadCurrentPatientId();
    final data = await _supabase
        .from('state_notes')
        .select(
          'state_note_id, title, note_created_at, anxiety_level, mood_level, social_comfort_level, comment',
        )
        .eq('patient_id', patientId)
        .order('note_created_at', ascending: false);

    return data
        .map((row) => StateNoteItem.fromJson(Map<String, dynamic>.from(row)))
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
              onRefresh: _loadNotes,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(11, 8, 20, 160),
                children: [
                  const _BackButtonText(),
                  const SizedBox(height: 25),
                  Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: Text(
                      'Мои заметки о состоянии',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontSize: 24, fontWeight: FontWeight.w500),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: Text(
                      'Фиксируйте свое состояние, чтобы отслеживать изменения со временем',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF777777),
                        height: 1.35,
                      ),
                    ),
                  ),
                  const SizedBox(height: 17),
                  _buildContent(),
                ],
              ),
            ),
          ),
          Positioned(
            left: 13,
            right: 20,
            bottom: MediaQuery.paddingOf(context).bottom + 103,
            child: FilledButton.icon(
              onPressed: () async {
                final wasSaved = await Navigator.of(context).push<bool>(
                  MaterialPageRoute<bool>(
                    builder: (context) => const NewStateNoteScreen(),
                  ),
                );
                if (wasSaved == true) {
                  await _loadNotes();
                }
              },
              icon: const Icon(Icons.add, size: 30),
              label: const Text('Добавить заметку'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.yellowAccent,
                foregroundColor: AppColors.textDark,
                minimumSize: const Size.fromHeight(58),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(29),
                ),
                textStyle: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontSize: 17,
                  fontWeight: FontWeight.w500,
                ),
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

    if (_notes.isEmpty) {
      return const _MessageText(text: 'Пока нет заметок о состоянии.');
    }

    final grouped = groupByMonth(_notes, (item) => item.createdAt);

    return Column(
      children: [
        for (final group in grouped.entries) ...[
          _MonthPill(label: group.key),
          const SizedBox(height: 20),
          for (final note in group.value) ...[
            _NoteCard(note: note, onDeleted: _loadNotes),
            const SizedBox(height: 22),
          ],
        ],
      ],
    );
  }
}

class _NoteCard extends StatelessWidget {
  const _NoteCard({required this.note, required this.onDeleted});

  final StateNoteItem note;
  final Future<void> Function() onDeleted;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final wasDeleted = await Navigator.of(context).push<bool>(
          MaterialPageRoute<bool>(
            builder: (context) => StateNoteDetailScreen(stateNoteId: note.id),
          ),
        );
        if (wasDeleted == true && context.mounted) {
          await onDeleted();
          if (context.mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Заметка удалена')));
          }
        }
      },
      behavior: HitTestBehavior.opaque,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.72)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _MoodCircle(level: note.moodLevel),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          note.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(
                            context,
                          ).textTheme.titleMedium?.copyWith(fontSize: 17),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          formatDate(note.createdAt),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: const Color(0xFF777777),
                                fontSize: 12,
                              ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Color(0xFF777777)),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: _MetricBlock(
                      icon: Icons.bolt_outlined,
                      color: AppColors.pinkAccent,
                      label: 'Тревожность',
                      value: note.anxietyLevel,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _MetricBlock(
                      icon: Icons.show_chart,
                      color: AppColors.yellowAccent,
                      label: 'Настроение',
                      value: note.moodLevel,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _MetricBlock(
                      icon: Icons.groups_2_outlined,
                      color: AppColors.blueAccent,
                      label: 'Комфорт в общении',
                      value: note.socialComfortLevel,
                    ),
                  ),
                ],
              ),
              if (note.comment.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(
                  note.comment,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    height: 1.35,
                    color: AppColors.textDark,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MoodCircle extends StatelessWidget {
  const _MoodCircle({required this.level});

  final int level;

  @override
  Widget build(BuildContext context) {
    final color = level >= 7
        ? AppColors.greenStatus
        : level >= 4
        ? AppColors.yellowAccent
        : AppColors.blueAccent;

    return DecoratedBox(
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: const SizedBox.square(
        dimension: 36,
        child: Icon(Icons.sentiment_satisfied_alt_outlined, size: 24),
      ),
    );
  }
}

class _MetricBlock extends StatelessWidget {
  const _MetricBlock({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color color;
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final foregroundColor = Color.lerp(color, AppColors.textDark, 0.55)!;

    return SizedBox(
      height: 42,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.42),
              borderRadius: BorderRadius.circular(6),
            ),
            child: SizedBox.square(
              dimension: 22,
              child: Icon(icon, size: 14, color: foregroundColor),
            ),
          ),
          const SizedBox(width: 5),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: const Color(0xFF777777),
                    fontSize: 9.5,
                    height: 1.08,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$value/10',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: foregroundColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    height: 1,
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

class StateNoteItem {
  const StateNoteItem({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.anxietyLevel,
    required this.moodLevel,
    required this.socialComfortLevel,
    required this.comment,
  });

  final String id;
  final String title;
  final DateTime createdAt;
  final int anxietyLevel;
  final int moodLevel;
  final int socialComfortLevel;
  final String comment;

  factory StateNoteItem.fromJson(Map<String, dynamic> json) {
    return StateNoteItem(
      id: asString(json['state_note_id']),
      title: asString(json['title'], fallback: 'Заметка о состоянии'),
      createdAt: asDateTime(json['note_created_at']),
      anxietyLevel: asInt(json['anxiety_level']),
      moodLevel: asInt(json['mood_level']),
      socialComfortLevel: asInt(json['social_comfort_level']),
      comment: asString(json['comment']),
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

int asInt(Object? value) {
  if (value is int) {
    return value;
  }

  return int.tryParse(value?.toString() ?? '') ?? 0;
}

DateTime asDateTime(Object? value) {
  return DateTime.tryParse(value?.toString() ?? '') ?? DateTime.now();
}
