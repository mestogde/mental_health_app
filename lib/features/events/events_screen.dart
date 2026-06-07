import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/app_theme.dart';
import '../../core/navigation/no_transition_page_route.dart';
import '../../core/widgets/guest_bottom_navigation.dart';
import '../../data/services/reference_data_service.dart';
import '../../data/services/session_service.dart';
import '../calendar/activity_calendar_screen.dart';
import 'event_foreign_detail_screen.dart';
import 'event_owner_detail_screen.dart';
import '../guest/guest_home_screen.dart';
import '../profile/profile_screen.dart';

enum _EventsTab { mine, foreign }

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  final _supabase = Supabase.instance.client;
  final _searchController = TextEditingController();

  bool _isLoading = true;
  String? _errorText;
  Object? _currentPatientId;
  _EventsTab _selectedTab = _EventsTab.mine;
  String _formatFilter = 'Все';
  List<EventItem> _events = const [];
  List<EventRequestItem> _requests = const [];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
    _loadEvents();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadEvents() async {
    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      final patientId = await _loadCurrentPatientId();
      final rows = await _supabase
          .from('events')
          .select(eventsSelectFields)
          .timeout(const Duration(seconds: 10));
      final requestRows = await _supabase
          .from('event_requests')
          .select(eventRequestsSelectFields)
          .timeout(const Duration(seconds: 10));

      if (!mounted) {
        return;
      }

      final loadedEvents = [
        for (final row in rows)
          EventItem.fromJson(Map<String, dynamic>.from(row)),
      ];
      final loadedRequests = [
        for (final row in requestRows)
          EventRequestItem.fromJson(Map<String, dynamic>.from(row)),
      ];
      final ownEventsCount = loadedEvents
          .where(
            (event) =>
                event.creatorPatientId?.toString() == patientId.toString(),
          )
          .length;
      debugPrint(
        'Events loaded: total=${loadedEvents.length}, '
        'own=$ownEventsCount, current_patient_id=$patientId',
      );

      setState(() {
        _currentPatientId = patientId;
        _events = loadedEvents;
        _requests = loadedRequests;
        _isLoading = false;
      });
    } catch (error, stackTrace) {
      debugPrint('Events load error: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) {
        return;
      }

      setState(() {
        _errorText = 'Не удалось загрузить события';
        _isLoading = false;
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

  @override
  Widget build(BuildContext context) {
    debugPrint(
      'Building EventsScreen background=${AppColors.background} '
      'selectedTab=$_selectedTab',
    );
    return Scaffold(
      extendBody: true,
      backgroundColor: AppColors.background,
      bottomNavigationBar: GuestBottomNavigation(
        selectedIndex: 1,
        onItemTap: (index) => _handleExtendedNavigation(context, index),
      ),
      body: SafeArea(
        bottom: false,
        child: ScrollConfiguration(
          behavior: const _NoGlowScrollBehavior(),
          child: RefreshIndicator(
            color: AppColors.pinkAccent,
            backgroundColor: AppColors.surface,
            onRefresh: _loadEvents,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 132),
              children: [
                _SearchField(controller: _searchController),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _SegmentedTabs(
                        selectedTab: _selectedTab,
                        onChanged: (tab) => setState(() => _selectedTab = tab),
                      ),
                    ),
                    const SizedBox(width: 12),
                    _FormatFilter(
                      value: _formatFilter,
                      onChanged: (value) => setState(() {
                        _formatFilter = value ?? 'Все';
                      }),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _buildContent(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const SizedBox(
        height: 360,
        child: Center(
          child: CircularProgressIndicator(color: AppColors.pinkAccent),
        ),
      );
    }

    if (_errorText != null) {
      return _MessageText(text: _errorText!);
    }

    final events = _visibleEvents();
    if (events.isEmpty) {
      return _MessageText(
        text: _selectedTab == _EventsTab.mine
            ? 'Вы ещё не создали события'
            : 'Пока нет доступных событий',
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.72)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          children: [
            for (var index = 0; index < events.length; index++) ...[
              _EventRow(
                event: events[index],
                request: _requestFor(events[index].id),
                requestsCount: _requestsCountFor(events[index].id),
                isMine: _selectedTab == _EventsTab.mine,
              ),
              if (index < events.length - 1)
                const Divider(
                  height: 1,
                  thickness: 0.8,
                  indent: 58,
                  color: Color(0xFFCFCFCF),
                ),
            ],
          ],
        ),
      ),
    );
  }

  List<EventItem> _visibleEvents() {
    final patientId = _currentPatientId?.toString();
    final query = _searchController.text.trim().toLowerCase();

    final filtered = _events.where((event) {
      final creatorId = event.creatorPatientId?.toString();
      final belongsToCurrentPatient = creatorId == patientId;
      if (_selectedTab == _EventsTab.mine && !belongsToCurrentPatient) {
        return false;
      }
      if (_selectedTab == _EventsTab.foreign && belongsToCurrentPatient) {
        return false;
      }
      if (_formatFilter != 'Все' && event.normalizedFormat != _formatFilter) {
        return false;
      }
      return true;
    }).toList();

    filtered.sort((a, b) {
      final aMatches = _matchesSearch(a, query) ? 0 : 1;
      final bMatches = _matchesSearch(b, query) ? 0 : 1;
      if (aMatches != bMatches) {
        return aMatches.compareTo(bMatches);
      }

      if (_selectedTab == _EventsTab.mine) {
        final aPriority = _ownPriority(a);
        final bPriority = _ownPriority(b);
        if (aPriority != bPriority) {
          return aPriority.compareTo(bPriority);
        }
      }

      if (_selectedTab == _EventsTab.foreign) {
        final aPriority = _foreignPriority(a);
        final bPriority = _foreignPriority(b);
        if (aPriority != bPriority) {
          return aPriority.compareTo(bPriority);
        }
      }

      final aDate = a.startsAt ?? a.createdAt ?? DateTime(9999);
      final bDate = b.startsAt ?? b.createdAt ?? DateTime(9999);
      final dateComparison = aDate.compareTo(bDate);
      if (dateComparison != 0) {
        return dateComparison;
      }

      return (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0));
    });

    return filtered;
  }

  bool _matchesSearch(EventItem event, String query) {
    if (query.isEmpty) {
      return true;
    }

    return [
      event.title,
      event.description,
      event.location,
      event.category,
      event.format,
    ].any((value) => value.toLowerCase().contains(query));
  }

  int _foreignPriority(EventItem event) {
    final request = _requestFor(event.id);
    if (request == null) {
      return 2;
    }
    if (request.isAccepted) {
      return 0;
    }
    if (request.isPending) {
      return 1;
    }
    return 2;
  }

  int _ownPriority(EventItem event) {
    final lower = event.status.toLowerCase();
    if (event.isApproved) {
      return 0;
    }
    if (lower.contains('pending') ||
        lower.contains('moderation') ||
        lower.contains('ожида') ||
        lower.contains('провер')) {
      return 1;
    }
    if (lower.contains('rejected') ||
        lower.contains('declined') ||
        lower.contains('отклон')) {
      return 2;
    }
    return 3;
  }

  EventRequestItem? _requestFor(String eventId) {
    final currentPatientId = _currentPatientId?.toString();
    for (final request in _requests) {
      if (request.eventId == eventId &&
          request.patientId?.toString() == currentPatientId) {
        return request;
      }
    }
    return null;
  }

  int _requestsCountFor(String eventId) {
    return _requests.where((request) => request.eventId == eventId).length;
  }
}

class _NoGlowScrollBehavior extends MaterialScrollBehavior {
  const _NoGlowScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        hintText: 'Поиск по ключевым словам',
        hintStyle: const TextStyle(color: Color(0xFF8C8C8C), fontSize: 14),
        prefixIcon: const Icon(Icons.search, color: Color(0xFF777777)),
        filled: true,
        fillColor: AppColors.surface.withValues(alpha: 0.92),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 13,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.72)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.72)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.pinkAccent),
        ),
      ),
    );
  }
}

class _SegmentedTabs extends StatelessWidget {
  const _SegmentedTabs({required this.selectedTab, required this.onChanged});

  final _EventsTab selectedTab;
  final ValueChanged<_EventsTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: Row(
          children: [
            _SegmentButton(
              label: 'Мои',
              isSelected: selectedTab == _EventsTab.mine,
              onTap: () => onChanged(_EventsTab.mine),
            ),
            _SegmentButton(
              label: 'Чужие',
              isSelected: selectedTab == _EventsTab.foreign,
              onTap: () => onChanged(_EventsTab.foreign),
            ),
          ],
        ),
      ),
    );
  }
}

class _SegmentButton extends StatelessWidget {
  const _SegmentButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? AppColors.textDark : Colors.transparent,
            borderRadius: BorderRadius.circular(15),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: isSelected ? Colors.white : AppColors.textDark,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _FormatFilter extends StatelessWidget {
  const _FormatFilter({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(18),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          borderRadius: BorderRadius.circular(18),
          padding: const EdgeInsets.only(left: 14, right: 9),
          items: const [
            DropdownMenuItem(value: 'Все', child: Text('Формат')),
            DropdownMenuItem(value: 'Онлайн', child: Text('Онлайн')),
            DropdownMenuItem(value: 'Офлайн', child: Text('Офлайн')),
          ],
          onChanged: onChanged,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: AppColors.textDark,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          icon: const Icon(Icons.keyboard_arrow_down, size: 18),
        ),
      ),
    );
  }
}

class _EventRow extends StatelessWidget {
  const _EventRow({
    required this.event,
    required this.request,
    required this.requestsCount,
    required this.isMine,
  });

  final EventItem event;
  final EventRequestItem? request;
  final int requestsCount;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final chips = isMine ? _myChips() : _foreignChips();

    return InkWell(
      onTap: () async {
        final wasChanged = await Navigator.of(context).push<bool>(
          MaterialPageRoute<bool>(
            builder: (context) => isMine
                ? EventOwnerDetailScreen(eventId: event.id)
                : EventForeignDetailScreen(eventId: event.id),
          ),
        );
        if (wasChanged == true && context.mounted) {
          final state = context.findAncestorStateOfType<_EventsScreenState>();
          await state?._loadEvents();
        }
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(13, 13, 8, 13),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CategoryIcon(category: event.category),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontSize: 16,
                      height: 1.12,
                    ),
                  ),
                  if (chips.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Wrap(
                        alignment: WrapAlignment.end,
                        spacing: 5,
                        runSpacing: 5,
                        children: chips,
                      ),
                    ),
                  ],
                  const SizedBox(height: 7),
                  _EventMetaText(
                    icon: Icons.place_outlined,
                    text: event.location,
                  ),
                  const SizedBox(height: 5),
                  _EventMetaText(
                    icon: Icons.schedule,
                    text: formatEventDateTime(event.startsAt),
                  ),
                  const SizedBox(height: 5),
                  _EventMetaText(
                    icon: Icons.people_alt_outlined,
                    text: participantText(event.participantLimit),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _foreignChips() {
    if (request == null) {
      return const [];
    }
    if (request!.isAccepted) {
      return const [
        _StatusChip(text: 'Вы участвуете', color: AppColors.greenStatus),
      ];
    }
    if (request!.isPending) {
      return const [
        _StatusChip(text: 'Запрос отправлен', color: Color(0xFFD9D9D9)),
      ];
    }
    return const [];
  }

  List<Widget> _myChips() {
    final chips = <Widget>[
      _StatusChip(
        text: event.isApproved ? 'Прошло проверку' : 'Ожидает проверку',
        color: event.isApproved
            ? AppColors.greenStatus
            : const Color(0xFFD9D9D9),
      ),
    ];
    if (requestsCount > 0) {
      chips.add(
        _StatusChip(
          text: '$requestsCount ${requestWord(requestsCount)} на участие',
          color: Colors.white,
        ),
      );
    }
    return chips;
  }
}

class _CategoryIcon extends StatelessWidget {
  const _CategoryIcon({required this.category});

  final String category;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.pinkAccent.withValues(alpha: 0.68),
        borderRadius: BorderRadius.circular(8),
      ),
      child: SizedBox.square(
        dimension: 36,
        child: Icon(
          categoryIcon(category),
          size: 21,
          color: AppColors.textDark,
        ),
      ),
    );
  }
}

class _EventMetaText extends StatelessWidget {
  const _EventMetaText({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: const Color(0xFF777777)),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: const Color(0xFF777777),
              fontSize: 12,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: Text(
          text,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: AppColors.textDark,
            fontSize: 10,
            height: 1,
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
    return SizedBox(
      height: 360,
      child: Center(
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(color: const Color(0xFF777777)),
        ),
      ),
    );
  }
}

class EventItem {
  const EventItem({
    required this.id,
    required this.creatorPatientId,
    required this.title,
    required this.description,
    required this.format,
    required this.category,
    required this.location,
    required this.startsAt,
    required this.participantLimit,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final Object? creatorPatientId;
  final String title;
  final String description;
  final String format;
  final String category;
  final String location;
  final DateTime? startsAt;
  final int? participantLimit;
  final String status;
  final DateTime? createdAt;

  String get normalizedFormat {
    final lower = format.toLowerCase();
    if (lower.contains('online') || lower.contains('онлайн')) {
      return 'Онлайн';
    }
    if (lower.contains('offline') ||
        lower.contains('офлайн') ||
        lower.contains('очный')) {
      return 'Офлайн';
    }
    return format;
  }

  bool get isApproved {
    final lower = status.toLowerCase();
    return lower.contains('approved') ||
        lower.contains('published') ||
        lower.contains('active') ||
        lower.contains('одобр') ||
        lower.contains('провер');
  }

  factory EventItem.fromJson(Map<String, dynamic> json) {
    return EventItem(
      id: asString(json['event_id'] ?? json['id']),
      creatorPatientId:
          json['creator_patient_id'] ??
          json['patient_id'] ??
          json['owner_patient_id'] ??
          json['created_by_patient_id'],
      title: asString(
        json['title'] ?? json['event_name'] ?? json['name'],
        fallback: 'Событие',
      ),
      description: asString(json['description']),
      format: referenceLabel(
        json,
        relationKey: 'event_formats',
        labelKey: 'format_name',
        fallback: 'Не указан',
      ),
      category: referenceLabel(
        json,
        relationKey: 'event_categories',
        labelKey: 'category_name',
        fallback: 'Развлечение',
      ),
      location: asString(json['location'], fallback: 'Место не указано'),
      startsAt: asDateTime(json['starts_at']),
      participantLimit: asInt(json['participant_limit']),
      status: referenceSystemValue(
        json,
        relationKey: 'event_statuses',
        fallback: asString(json['status']),
      ),
      createdAt: asDateTime(json['created_at']),
    );
  }
}

class EventRequestItem {
  const EventRequestItem({
    required this.eventId,
    required this.patientId,
    required this.status,
  });

  final String eventId;
  final Object? patientId;
  final String status;

  bool get isAccepted {
    final lower = status.toLowerCase();
    return lower.contains('accepted') ||
        lower.contains('confirmed') ||
        lower.contains('approved') ||
        lower.contains('принят') ||
        lower.contains('подтверж');
  }

  bool get isPending {
    final lower = status.toLowerCase();
    return lower.contains('sent') ||
        lower.contains('pending') ||
        lower.contains('requested') ||
        lower.contains('ожида') ||
        lower.contains('отправ');
  }

  factory EventRequestItem.fromJson(Map<String, dynamic> json) {
    return EventRequestItem(
      eventId: asString(json['event_id']),
      patientId: json['patient_id'],
      status: referenceSystemValue(
        json,
        relationKey: 'request_statuses',
        fallback: asString(json['status']),
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

IconData categoryIcon(String category) {
  final lower = category.toLowerCase();
  if (lower.contains('прогул') || lower.contains('walk')) {
    return Icons.landscape_outlined;
  }
  if (lower.contains('игр') || lower.contains('game')) {
    return Icons.sports_esports_outlined;
  }
  return Icons.local_activity_outlined;
}

String formatEventDateTime(DateTime? date) {
  if (date == null) {
    return 'Дата не указана';
  }

  const weekdays = ['ПН', 'ВТ', 'СР', 'ЧТ', 'ПТ', 'СБ', 'ВС'];
  const months = [
    'января',
    'февраля',
    'марта',
    'апреля',
    'мая',
    'июня',
    'июля',
    'августа',
    'сентября',
    'октября',
    'ноября',
    'декабря',
  ];
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '${weekdays[date.weekday - 1]}, ${date.day} ${months[date.month - 1]}, $hour:$minute';
}

String participantText(int? limit) {
  if (limit == null || limit <= 0) {
    return 'Участники не указаны';
  }
  return '$limit ${personWord(limit)}';
}

String personWord(int count) {
  final mod10 = count % 10;
  final mod100 = count % 100;
  if (mod10 == 1 && mod100 != 11) {
    return 'человек';
  }
  return 'человека';
}

String requestWord(int count) {
  final mod10 = count % 10;
  final mod100 = count % 100;
  if (mod10 == 1 && mod100 != 11) {
    return 'запрос';
  }
  if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) {
    return 'запроса';
  }
  return 'запросов';
}

String asString(Object? value, {String fallback = ''}) {
  final text = value?.toString().trim();
  if (text == null || text.isEmpty) {
    return fallback;
  }
  return text;
}

int? asInt(Object? value) {
  if (value is int) {
    return value;
  }
  return int.tryParse(value?.toString() ?? '');
}

DateTime? asDateTime(Object? value) {
  final text = value?.toString();
  if (text == null || text.isEmpty) {
    return null;
  }
  return DateTime.tryParse(text);
}
