import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/guest_bottom_navigation.dart';
import '../../data/services/session_service.dart';
import '../guest/guest_home_screen.dart';
import '../events/events_screen.dart';
import '../profile/profile_screen.dart';

class CreateEventScreen extends StatefulWidget {
  const CreateEventScreen({super.key});

  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  final _supabase = Supabase.instance.client;
  final _titleController = TextEditingController();
  final _locationController = TextEditingController();
  final _descriptionController = TextEditingController();

  bool _isSaving = false;
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  String _participantCount = '2 человека';
  String? _format;
  String? _category;

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3),
    );

    if (pickedDate == null || !mounted) {
      return;
    }

    setState(() {
      _selectedDate = pickedDate;
    });
  }

  Future<void> _pickTime() async {
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );

    if (pickedTime == null || !mounted) {
      return;
    }

    setState(() {
      _selectedTime = pickedTime;
    });
  }

  Future<void> _saveEvent() async {
    final isMissingRequiredField =
        _titleController.text.trim().isEmpty ||
        _selectedDate == null ||
        _selectedTime == null ||
        _locationController.text.trim().isEmpty ||
        _participantCount.isEmpty ||
        _format == null ||
        _category == null ||
        _descriptionController.text.trim().isEmpty;

    if (isMissingRequiredField) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Заполните все поля события')),
      );
      return;
    }

    if (_isSaving) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final patientId = await _loadCurrentPatientId();
      final startsAt = _combinedStartsAt();
      final now = DateTime.now().toIso8601String();
      final eventPayload = {
        'creator_patient_id': patientId,
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'event_format': _format,
        'category': _category,
        'location': _locationController.text.trim(),
        'starts_at': startsAt.toIso8601String(),
        'participant_limit': _participantLimitValue(),
        'event_status': 'pending',
        'created_at': now,
        'updated_at': now,
      };

      final insertedEvents = await _supabase
          .from('events')
          .insert(eventPayload)
          .select('event_id, event_status, creator_patient_id')
          .timeout(const Duration(seconds: 10));
      final insertedEvent = insertedEvents.isEmpty
          ? <String, dynamic>{}
          : Map<String, dynamic>.from(insertedEvents.first);
      debugPrint(
        'Created event id=${insertedEvent['event_id']} '
        'status=${insertedEvent['event_status']} '
        'creator_patient_id=${insertedEvent['creator_patient_id']}',
      );

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Событие отправлено на проверку')),
      );
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (context) => const EventsScreen()),
      );
    } catch (error, stackTrace) {
      debugPrint('Create event insert error: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) {
        return;
      }
      setState(() {
        _isSaving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось сохранить событие')),
      );
    }
  }

  Future<Object> _loadCurrentPatientId() async {
    final externalId = await SessionService().getCurrentPatientExternalId();
    final data = await _supabase
        .from('patients')
        .select('patient_id')
        .eq('external_patient_id', externalId)
        .limit(1)
        .timeout(const Duration(seconds: 10));

    if (data.isEmpty || data.first['patient_id'] == null) {
      throw StateError('Patient not found for external id: $externalId');
    }
    return data.first['patient_id'];
  }

  DateTime _combinedStartsAt() {
    final date = _selectedDate!;
    final time = _selectedTime!;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  int _participantLimitValue() {
    return int.tryParse(_participantCount.split(' ').first) ?? 2;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: AppColors.background,
      bottomNavigationBar: GuestBottomNavigation(
        selectedIndex: 2,
        onItemTap: (index) => _handleExtendedNavigation(context, index),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/calendar_bg.png',
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFFFE8A8),
                    AppColors.background,
                    Color(0xFFF1D4D4),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(22, 8, 22, 184),
              children: [
                const _BackButtonText(),
                const SizedBox(height: 26),
                Text(
                  'Создание события',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontSize: 25,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 22),
                _LabeledField(
                  label: 'Название события',
                  child: _TextInput(
                    controller: _titleController,
                    hint: 'Например: Сходить в кино',
                  ),
                ),
                const SizedBox(height: 14),
                _LabeledField(
                  label: 'Дата и время',
                  child: Row(
                    children: [
                      Expanded(
                        child: _PickerField(
                          text: _selectedDate == null
                              ? 'Дата'
                              : _formatDate(_selectedDate!),
                          onTap: _pickDate,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _PickerField(
                          text: _selectedTime == null
                              ? 'Время'
                              : _formatTime(_selectedTime!),
                          onTap: _pickTime,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _LabeledField(
                  label: 'Местоположение',
                  child: _TextInput(
                    controller: _locationController,
                    hint: 'Адрес или онлайн',
                  ),
                ),
                const SizedBox(height: 14),
                _LabeledField(
                  label: 'Количество участников',
                  child: _DropdownField(
                    value: _participantCount,
                    items: const [
                      '2 человека',
                      '3 человека',
                      '4 человека',
                      '5 человек',
                    ],
                    onChanged: (value) =>
                        setState(() => _participantCount = value!),
                  ),
                ),
                const SizedBox(height: 14),
                _LabeledField(
                  label: 'Формат',
                  child: _DropdownField(
                    value: _format,
                    hint: 'Выберите формат',
                    items: const ['Онлайн', 'Офлайн'],
                    onChanged: (value) => setState(() => _format = value),
                  ),
                ),
                const SizedBox(height: 14),
                _LabeledField(
                  label: 'Категория',
                  child: _CategoryDropdownField(
                    value: _category,
                    hint: 'Выберите категорию',
                    onChanged: (value) => setState(() => _category = value),
                  ),
                ),
                const SizedBox(height: 14),
                _LabeledField(
                  label: 'Описание события',
                  child: _TextInput(
                    controller: _descriptionController,
                    hint: 'Коротко расскажите, как будет проходить мероприятие',
                    minLines: 4,
                    maxLines: 5,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 22,
            right: 22,
            bottom: MediaQuery.paddingOf(context).bottom + 103,
            child: FilledButton(
              onPressed: _isSaving ? null : _saveEvent,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.pinkAccent,
                foregroundColor: AppColors.textDark,
                minimumSize: const Size.fromHeight(62),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(31),
                ),
                textStyle: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontSize: 17,
                  fontWeight: FontWeight.w500,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 14),
          child: Text(
            label,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
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
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 13),
      decoration: _fieldDecoration(hint),
    );
  }
}

class _PickerField extends StatelessWidget {
  const _PickerField({required this.text, required this.onTap});

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isPlaceholder = text == 'Дата' || text == 'Время';

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: DecoratedBox(
        decoration: _fieldBoxDecoration(),
        child: SizedBox(
          height: 50,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                text,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontSize: 13,
                  color: isPlaceholder
                      ? const Color(0xFFA7A7A7)
                      : AppColors.textDark,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DropdownField extends StatelessWidget {
  const _DropdownField({
    required this.value,
    required this.items,
    required this.onChanged,
    this.hint,
  });

  final String? value;
  final List<String> items;
  final ValueChanged<String?> onChanged;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      hint: hint == null
          ? null
          : Text(hint!, style: const TextStyle(fontSize: 13)),
      items: [
        for (final item in items)
          DropdownMenuItem<String>(value: item, child: Text(item)),
      ],
      onChanged: onChanged,
      decoration: _fieldDecoration(null),
      style: Theme.of(
        context,
      ).textTheme.bodyMedium?.copyWith(color: AppColors.textDark, fontSize: 13),
      icon: const Icon(Icons.keyboard_arrow_down),
      borderRadius: BorderRadius.circular(18),
      dropdownColor: AppColors.surface,
    );
  }
}

class _CategoryDropdownField extends StatelessWidget {
  const _CategoryDropdownField({
    required this.value,
    required this.onChanged,
    this.hint,
  });

  final String? value;
  final ValueChanged<String?> onChanged;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    const items = ['Прогулка', 'Развлечение', 'Игра'];

    return DropdownButtonFormField<String>(
      initialValue: value,
      hint: hint == null
          ? null
          : Text(hint!, style: const TextStyle(fontSize: 13)),
      selectedItemBuilder: (context) => [
        for (final item in items) _CategoryOption(label: item),
      ],
      items: [
        for (final item in items)
          DropdownMenuItem<String>(
            value: item,
            child: _CategoryOption(label: item),
          ),
      ],
      onChanged: onChanged,
      decoration: _fieldDecoration(null),
      style: Theme.of(
        context,
      ).textTheme.bodyMedium?.copyWith(color: AppColors.textDark, fontSize: 13),
      icon: const Icon(Icons.keyboard_arrow_down),
      borderRadius: BorderRadius.circular(18),
      dropdownColor: AppColors.surface,
    );
  }
}

class _CategoryOption extends StatelessWidget {
  const _CategoryOption({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.pinkAccent.withValues(alpha: 0.66),
            borderRadius: BorderRadius.circular(7),
          ),
          child: SizedBox.square(
            dimension: 28,
            child: Icon(
              _categoryIcon(label),
              size: 17,
              color: AppColors.textDark,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textDark,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }
}

InputDecoration _fieldDecoration(String? hint) {
  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: Color(0xFFA7A7A7), fontSize: 13),
    filled: true,
    fillColor: Colors.white.withValues(alpha: 0.74),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(22),
      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.78)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(22),
      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.78)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(22),
      borderSide: const BorderSide(color: AppColors.pinkAccent),
    ),
  );
}

BoxDecoration _fieldBoxDecoration() {
  return BoxDecoration(
    color: Colors.white.withValues(alpha: 0.74),
    borderRadius: BorderRadius.circular(22),
    border: Border.all(color: Colors.white.withValues(alpha: 0.78)),
  );
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
    Navigator.of(context).pop();
    return;
  }

  Navigator.of(context).pushReplacement(
    MaterialPageRoute<void>(builder: (context) => const ProfileScreen()),
  );
}

String _formatDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day.$month.${date.year}';
}

String _formatTime(TimeOfDay time) {
  final hour = time.hour.toString().padLeft(2, '0');
  final minute = time.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

IconData _categoryIcon(String category) {
  return switch (category) {
    'Прогулка' => Icons.landscape_outlined,
    'Развлечение' => Icons.local_activity_outlined,
    'Игра' => Icons.sports_esports_outlined,
    _ => Icons.category_outlined,
  };
}
