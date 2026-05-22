import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/app_theme.dart';
import '../../core/navigation/no_transition_page_route.dart';
import '../../core/widgets/guest_bottom_navigation.dart';
import '../../data/services/session_service.dart';
import '../events/create_event_screen.dart';
import '../guest/guest_home_screen.dart';
import '../events/events_screen.dart';
import '../profile/profile_screen.dart';

class ActivityCalendarScreen extends StatefulWidget {
  const ActivityCalendarScreen({super.key});

  @override
  State<ActivityCalendarScreen> createState() => _ActivityCalendarScreenState();
}

class _ActivityCalendarScreenState extends State<ActivityCalendarScreen> {
  final _supabase = Supabase.instance.client;

  late DateTime _displayedMonth;
  late DateTime _selectedDate;
  Set<String> _activeDateKeys = const {};
  bool _isLoadingActivity = true;
  bool _hasActivityError = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _displayedMonth = DateTime(now.year, now.month);
    _selectedDate = DateTime(now.year, now.month, now.day);
    _loadActivityDates();
  }

  Future<void> _loadActivityDates() async {
    setState(() {
      _isLoadingActivity = true;
      _hasActivityError = false;
    });

    try {
      final patientId = await _loadCurrentPatientId().timeout(
        const Duration(seconds: 10),
      );
      final keys = <String>{};
      var hasActivityError = false;

      hasActivityError |= !await _collectDateKeys(
        keys,
        table: 'state_notes',
        column: 'note_created_at',
        patientId: patientId,
      );
      hasActivityError |= !await _collectDateKeys(
        keys,
        table: 'test_attempts',
        column: 'completed_at',
        patientId: patientId,
        skipNull: true,
      );
      hasActivityError |= !await _collectDateKeys(
        keys,
        table: 'material_views',
        column: 'last_viewed_at',
        patientId: patientId,
      );
      hasActivityError |= !await _collectDateKeys(
        keys,
        table: 'consultations',
        column: 'scheduled_at',
        patientId: patientId,
      );
      hasActivityError |= !await _collectAcceptedEventDateKeys(keys, patientId);

      if (!mounted) {
        return;
      }

      setState(() {
        _activeDateKeys = keys;
        _hasActivityError = hasActivityError;
        _isLoadingActivity = false;
      });
    } catch (error, stackTrace) {
      debugPrint('Calendar activity load error: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) {
        return;
      }

      setState(() {
        _activeDateKeys = const {};
        _hasActivityError = true;
        _isLoadingActivity = false;
      });
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

    if (data.isEmpty) {
      throw StateError('Patient not found for external id: $externalId');
    }

    final patientId = data.first['patient_id'];
    if (patientId == null) {
      throw StateError('Patient row has no patient_id');
    }

    return patientId;
  }

  Future<bool> _collectDateKeys(
    Set<String> keys, {
    required String table,
    required String column,
    required Object patientId,
    bool skipNull = false,
  }) async {
    try {
      var query = _supabase
          .from(table)
          .select(column)
          .eq('patient_id', patientId);

      if (skipNull) {
        query = query.not(column, 'is', null);
      }

      final data = await query.timeout(const Duration(seconds: 10));
      for (final row in data) {
        _addDateKey(keys, row[column]);
      }
      return true;
    } catch (error, stackTrace) {
      debugPrint('Calendar activity query error ($table.$column): $error');
      debugPrintStack(stackTrace: stackTrace);
      return false;
    }
  }

  Future<bool> _collectAcceptedEventDateKeys(
    Set<String> keys,
    Object patientId,
  ) async {
    try {
      final data = await _supabase
          .from('event_requests')
          .select('events(starts_at)')
          .eq('patient_id', patientId)
          .eq('request_status', 'accepted')
          .timeout(const Duration(seconds: 10));

      for (final row in data) {
        final eventData = row['events'];
        if (eventData is Map<String, dynamic>) {
          _addDateKey(keys, eventData['starts_at']);
        } else if (eventData is List && eventData.isNotEmpty) {
          final firstEvent = eventData.first;
          if (firstEvent is Map<String, dynamic>) {
            _addDateKey(keys, firstEvent['starts_at']);
          }
        }
      }
      return true;
    } catch (error, stackTrace) {
      debugPrint('Calendar accepted events query error: $error');
      debugPrintStack(stackTrace: stackTrace);
      return false;
    }
  }

  void _addDateKey(Set<String> keys, Object? rawValue) {
    final text = rawValue?.toString();
    if (text == null || text.isEmpty) {
      return;
    }

    final date = DateTime.tryParse(text);
    if (date == null) {
      return;
    }

    keys.add(_dateKey(date));
  }

  void _changeMonth(int delta) {
    setState(() {
      _displayedMonth = DateTime(
        _displayedMonth.year,
        _displayedMonth.month + delta,
      );
    });
  }

  void _changeYear(int year) {
    setState(() {
      _displayedMonth = DateTime(year, _displayedMonth.month);
    });
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
              padding: const EdgeInsets.fromLTRB(22, 58, 22, 112),
              children: [
                Text(
                  'Календарь событий',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontSize: 25,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 22),
                _CalendarCard(
                  displayedMonth: _displayedMonth,
                  selectedDate: _selectedDate,
                  activeDateKeys: _activeDateKeys,
                  isLoadingActivity: _isLoadingActivity,
                  hasActivityError: _hasActivityError,
                  onMonthChanged: _changeMonth,
                  onYearChanged: _changeYear,
                  onDateSelected: (date) => setState(() {
                    _selectedDate = date;
                    _displayedMonth = DateTime(date.year, date.month);
                  }),
                ),
                const SizedBox(height: 3),
                Divider(color: AppColors.textDark.withValues(alpha: 0.28)),
                const SizedBox(height: 2),
                Text(
                  'Создать событие',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontSize: 24,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                _CreateEventCard(
                  onTap: () async {
                    final created = await Navigator.of(context).push<bool>(
                      MaterialPageRoute<bool>(
                        builder: (context) => const CreateEventScreen(),
                      ),
                    );
                    if (created == true && mounted) {
                      await _loadActivityDates();
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CalendarCard extends StatelessWidget {
  const _CalendarCard({
    required this.displayedMonth,
    required this.selectedDate,
    required this.activeDateKeys,
    required this.isLoadingActivity,
    required this.hasActivityError,
    required this.onMonthChanged,
    required this.onYearChanged,
    required this.onDateSelected,
  });

  final DateTime displayedMonth;
  final DateTime selectedDate;
  final Set<String> activeDateKeys;
  final bool isLoadingActivity;
  final bool hasActivityError;
  final ValueChanged<int> onMonthChanged;
  final ValueChanged<int> onYearChanged;
  final ValueChanged<DateTime> onDateSelected;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.56)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 11),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Отмечены дни вашей активности',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF8A8A8A),
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _selectedDateLabel(selectedDate),
                          style: Theme.of(
                            context,
                          ).textTheme.titleMedium?.copyWith(fontSize: 17),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Divider(
              height: 1,
              color: AppColors.textDark.withValues(alpha: 0.3),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 6),
              child: Column(
                children: [
                  Row(
                    children: [
                      _YearDropdown(
                        displayedMonth: displayedMonth,
                        onYearChanged: onYearChanged,
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => onMonthChanged(-1),
                        icon: const Icon(Icons.chevron_left),
                        color: const Color(0xFF4B4653),
                        visualDensity: VisualDensity.compact,
                        constraints: const BoxConstraints.tightFor(
                          width: 34,
                          height: 34,
                        ),
                      ),
                      IconButton(
                        onPressed: () => onMonthChanged(1),
                        icon: const Icon(Icons.chevron_right),
                        color: const Color(0xFF4B4653),
                        visualDensity: VisualDensity.compact,
                        constraints: const BoxConstraints.tightFor(
                          width: 34,
                          height: 34,
                        ),
                      ),
                    ],
                  ),
                  const _WeekdayRow(),
                  const SizedBox(height: 2),
                  _CalendarGrid(
                    displayedMonth: displayedMonth,
                    selectedDate: selectedDate,
                    activeDateKeys: activeDateKeys,
                    onDateSelected: onDateSelected,
                  ),
                  if (isLoadingActivity || hasActivityError) ...[
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        isLoadingActivity
                            ? 'Загружаем активные даты...'
                            : 'Активные даты временно недоступны.',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: const Color(0xFF777777),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeekdayRow extends StatelessWidget {
  const _WeekdayRow();

  @override
  Widget build(BuildContext context) {
    const days = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

    return Row(
      children: [
        for (final day in days)
          Expanded(
            child: Center(
              child: Text(
                day,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppColors.textDark,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _YearDropdown extends StatelessWidget {
  const _YearDropdown({
    required this.displayedMonth,
    required this.onYearChanged,
  });

  final DateTime displayedMonth;
  final ValueChanged<int> onYearChanged;

  @override
  Widget build(BuildContext context) {
    final currentYear = DateTime.now().year;
    final years = [
      for (var year = currentYear - 3; year <= currentYear + 3; year++) year,
    ];

    return PopupMenuButton<int>(
      initialValue: displayedMonth.year,
      onSelected: onYearChanged,
      itemBuilder: (context) => [
        for (final year in years)
          PopupMenuItem<int>(value: year, child: Text(year.toString())),
      ],
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            monthYearLabel(displayedMonth),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: const Color(0xFF5A5260),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.arrow_drop_down, size: 19),
        ],
      ),
    );
  }
}

class _CalendarGrid extends StatelessWidget {
  const _CalendarGrid({
    required this.displayedMonth,
    required this.selectedDate,
    required this.activeDateKeys,
    required this.onDateSelected,
  });

  final DateTime displayedMonth;
  final DateTime selectedDate;
  final Set<String> activeDateKeys;
  final ValueChanged<DateTime> onDateSelected;

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(displayedMonth.year, displayedMonth.month);
    final daysInMonth = DateUtils.getDaysInMonth(
      displayedMonth.year,
      displayedMonth.month,
    );
    final leadingEmptyCells = firstDay.weekday % 7;
    final totalCells = ((leadingEmptyCells + daysInMonth + 6) ~/ 7) * 7;
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: totalCells,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisExtent: 35,
      ),
      itemBuilder: (context, index) {
        final dayNumber = index - leadingEmptyCells + 1;
        if (dayNumber < 1 || dayNumber > daysInMonth) {
          return const SizedBox.shrink();
        }

        final date = DateTime(
          displayedMonth.year,
          displayedMonth.month,
          dayNumber,
        );
        final isToday = DateUtils.isSameDay(date, todayDate);
        final isSelected = DateUtils.isSameDay(date, selectedDate);
        final isActive = activeDateKeys.contains(_dateKey(date));

        return _CalendarDayCell(
          date: date,
          isToday: isToday,
          isSelected: isSelected,
          isActive: isActive,
          onTap: () => onDateSelected(date),
        );
      },
    );
  }
}

class _CalendarDayCell extends StatelessWidget {
  const _CalendarDayCell({
    required this.date,
    required this.isToday,
    required this.isSelected,
    required this.isActive,
    required this.onTap,
  });

  final DateTime date;
  final bool isToday;
  final bool isSelected;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final backgroundColor = isToday
        ? const Color(0xFF888888)
        : isActive
        ? AppColors.yellowAccent
        : Colors.transparent;
    final borderColor = isSelected && !isToday
        ? AppColors.textDark
        : isActive
        ? AppColors.textDark.withValues(alpha: 0.75)
        : Colors.transparent;
    final textColor = isToday ? Colors.white : AppColors.textDark;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: backgroundColor,
            shape: BoxShape.circle,
            border: Border.all(color: borderColor),
          ),
          child: Center(
            child: Text(
              date.day.toString(),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: textColor,
                fontWeight: isToday || isActive || isSelected
                    ? FontWeight.w500
                    : FontWeight.w400,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CreateEventCard extends StatelessWidget {
  const _CreateEventCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(31),
          border: Border.all(color: Colors.white.withValues(alpha: 0.6)),
        ),
        child: const SizedBox(
          height: 86,
          child: Center(
            child: Icon(Icons.add, size: 34, color: AppColors.textDark),
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
    return;
  }

  Navigator.of(context).pushReplacement(
    noTransitionPageRoute<void>(builder: (context) => const ProfileScreen()),
  );
}

String _selectedDateLabel(DateTime date) {
  const weekdays = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
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

  return '${weekdays[date.weekday - 1]}, ${months[date.month - 1]} ${date.day}';
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

String _dateKey(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}
