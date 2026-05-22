import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/app_theme.dart';
import '../../core/navigation/no_transition_page_route.dart';
import '../../core/widgets/guest_bottom_navigation.dart';
import '../../data/services/session_service.dart';
import '../calendar/activity_calendar_screen.dart';
import '../guest/guest_home_screen.dart';
import '../events/events_screen.dart';
import '../profile/profile_screen.dart';

class NewStateNoteScreen extends StatefulWidget {
  const NewStateNoteScreen({super.key});

  @override
  State<NewStateNoteScreen> createState() => _NewStateNoteScreenState();
}

class _NewStateNoteScreenState extends State<NewStateNoteScreen> {
  final _supabase = Supabase.instance.client;
  final _titleController = TextEditingController();
  final _commentController = TextEditingController();

  int? _anxietyLevel;
  int? _moodLevel;
  int? _socialComfortLevel;
  bool _isSaving = false;
  String? _validationText;

  @override
  void dispose() {
    _titleController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _saveNote() async {
    final title = _titleController.text.trim();
    if (title.isEmpty ||
        _anxietyLevel == null ||
        _moodLevel == null ||
        _socialComfortLevel == null) {
      setState(() {
        _validationText = 'Заполните название и все оценки состояния';
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _validationText = null;
    });

    try {
      final patientId = await _loadCurrentPatientId();
      await _supabase
          .from('state_notes')
          .insert({
            'patient_id': patientId,
            'title': title,
            'note_created_at': DateTime.now().toIso8601String(),
            'anxiety_level': _anxietyLevel,
            'mood_level': _moodLevel,
            'social_comfort_level': _socialComfortLevel,
            'comment': _commentController.text.trim(),
          })
          .timeout(const Duration(seconds: 10));

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(true);
    } catch (error, stackTrace) {
      debugPrint('State note insert error: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) {
        return;
      }

      setState(() {
        _validationText = 'Не удалось сохранить заметку. Попробуйте ещё раз.';
        _isSaving = false;
      });
    }
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
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 190),
              children: [
                const _BackButtonText(),
                const SizedBox(height: 25),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 11),
                  child: Text(
                    'Новая заметка о состоянии',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontSize: 24,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 11),
                  child: Text(
                    'Зафиксируйте, как вы себя чувствуете сейчас или после конкретной ситуации',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF777777),
                      height: 1.28,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                _LabeledField(
                  label: 'Название заметки',
                  child: _TextInput(
                    controller: _titleController,
                    hint: 'например: Встреча с другом',
                  ),
                ),
                const SizedBox(height: 17),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 11),
                  child: Text(
                    'Оцените своё состояние',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontSize: 17,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                _RatingRow(
                  icon: Icons.bolt_outlined,
                  label: 'Тревожность',
                  leftHint: 'Спокойно',
                  rightHint: 'Очень тревожно',
                  accent: AppColors.pinkAccent,
                  value: _anxietyLevel,
                  onChanged: (value) => setState(() => _anxietyLevel = value),
                ),
                _RatingRow(
                  icon: Icons.show_chart,
                  label: 'Настроение',
                  leftHint: 'Плохо',
                  rightHint: 'Отлично',
                  accent: AppColors.yellowAccent,
                  value: _moodLevel,
                  onChanged: (value) => setState(() => _moodLevel = value),
                ),
                _RatingRow(
                  icon: Icons.groups_2_outlined,
                  label: 'Комфорт в общении',
                  leftHint: 'Совсем не комфортно',
                  rightHint: 'Полностью комфортно',
                  accent: AppColors.blueAccent,
                  value: _socialComfortLevel,
                  onChanged: (value) =>
                      setState(() => _socialComfortLevel = value),
                ),
                const SizedBox(height: 13),
                _LabeledField(
                  label: 'Комментарий (необязательно)',
                  child: _TextInput(
                    controller: _commentController,
                    hint: 'Опишите ситуацию, свои мысли и ощущения в теле',
                    minLines: 4,
                    maxLines: 5,
                  ),
                ),
                if (_validationText != null) ...[
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 11),
                    child: Text(
                      _validationText!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.pinkAccent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Positioned(
            left: 22,
            right: 22,
            bottom: MediaQuery.paddingOf(context).bottom + 103,
            child: FilledButton(
              onPressed: _isSaving ? null : _saveNote,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.yellowAccent,
                foregroundColor: AppColors.textDark,
                disabledBackgroundColor: AppColors.yellowAccent.withValues(
                  alpha: 0.58,
                ),
                minimumSize: const Size.fromHeight(62),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(31),
                ),
              ),
              child: Text(_isSaving ? 'Сохранение...' : 'Сохранить'),
            ),
          ),
        ],
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontSize: 17,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 9),
          child,
        ],
      ),
    );
  }
}

class _TextInput extends StatelessWidget {
  const _TextInput({
    required this.controller,
    required this.hint,
    this.minLines = 1,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String hint;
  final int minLines;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      minLines: minLines,
      maxLines: maxLines,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFFA7A7A7)),
        filled: true,
        fillColor: AppColors.surface.withValues(alpha: 0.86),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 13,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: const BorderSide(color: Color(0xFFC6C6C6)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: const BorderSide(color: Color(0xFFC6C6C6)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: const BorderSide(color: AppColors.yellowAccent),
        ),
      ),
    );
  }
}

class _RatingRow extends StatelessWidget {
  const _RatingRow({
    required this.icon,
    required this.label,
    required this.leftHint,
    required this.rightHint,
    required this.accent,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final String leftHint;
  final String rightHint;
  final Color accent;
  final int? value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final foregroundColor = Color.lerp(accent, AppColors.textDark, 0.52)!;

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 13),
      child: Column(
        children: [
          Row(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.34),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: SizedBox.square(
                  dimension: 29,
                  child: Icon(icon, size: 18, color: foregroundColor),
                ),
              ),
              const SizedBox(width: 9),
              Text(
                label,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var index = 1; index <= 10; index++)
                GestureDetector(
                  onTap: () => onChanged(index),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: value == index ? accent : const Color(0xFFD9D9D9),
                      shape: BoxShape.circle,
                      border: value == index
                          ? Border.all(color: foregroundColor, width: 1)
                          : null,
                    ),
                    child: SizedBox.square(
                      dimension: 27,
                      child: Center(
                        child: Text(
                          index.toString(),
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                color: AppColors.textDark,
                                fontWeight: value == index
                                    ? FontWeight.w800
                                    : FontWeight.w500,
                              ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 7),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                leftHint,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: const Color(0xFFA0A0A0),
                ),
              ),
              Text(
                rightHint,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: const Color(0xFFA0A0A0),
                ),
              ),
            ],
          ),
        ],
      ),
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
