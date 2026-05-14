import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/guest_bottom_navigation.dart';
import '../../data/services/session_service.dart';
import '../calendar/activity_calendar_screen.dart';
import '../guest/guest_home_screen.dart';
import '../profile/profile_screen.dart';
import 'event_detail_models.dart';
import 'event_requests_screen.dart';

class EventOwnerDetailScreen extends StatefulWidget {
  const EventOwnerDetailScreen({super.key, required this.eventId});

  final String eventId;

  @override
  State<EventOwnerDetailScreen> createState() => _EventOwnerDetailScreenState();
}

class _EventOwnerDetailScreenState extends State<EventOwnerDetailScreen> {
  final _supabase = Supabase.instance.client;

  bool _isLoading = true;
  String? _errorText;
  EventDetailItem? _event;
  EventPatientProfile? _organizer;
  List<EventRequestDetail> _requests = const [];

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      final currentPatientId = await _loadCurrentPatientId();
      final eventData = await _supabase
          .from('events')
          .select('*')
          .eq('event_id', widget.eventId)
          .limit(1)
          .timeout(const Duration(seconds: 10));

      if (eventData.isEmpty) {
        throw StateError('Event not found: ${widget.eventId}');
      }

      final event = EventDetailItem.fromJson(
        Map<String, dynamic>.from(eventData.first),
      );
      final organizer = await _loadPatientProfile(
        event.creatorPatientId ?? currentPatientId,
      );
      final requests = await _loadRequests();

      if (!mounted) {
        return;
      }

      setState(() {
        _event = event;
        _organizer = organizer;
        _requests = requests;
        _isLoading = false;
      });
    } catch (error, stackTrace) {
      debugPrint('Owner event detail load error: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) {
        return;
      }
      setState(() {
        _errorText = 'Не удалось загрузить событие';
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

    if (data.isEmpty || data.first['patient_id'] == null) {
      throw StateError('Patient not found for external id: $externalId');
    }
    return data.first['patient_id'];
  }

  Future<EventPatientProfile?> _loadPatientProfile(Object? patientId) async {
    if (patientId == null) {
      return null;
    }
    try {
      final data = await _supabase
          .from('patients')
          .select('*')
          .eq('patient_id', patientId)
          .limit(1)
          .timeout(const Duration(seconds: 10));
      if (data.isEmpty) {
        return null;
      }
      return EventPatientProfile.fromJson(
        Map<String, dynamic>.from(data.first),
      );
    } catch (error, stackTrace) {
      debugPrint('Owner event patient load error: $error');
      debugPrintStack(stackTrace: stackTrace);
      return null;
    }
  }

  Future<List<EventRequestDetail>> _loadRequests() async {
    final data = await _supabase
        .from('event_requests')
        .select('*')
        .eq('event_id', widget.eventId)
        .timeout(const Duration(seconds: 10));

    return [
      for (final row in data)
        EventRequestDetail.fromJson(Map<String, dynamic>.from(row)),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: AppColors.background,
      bottomNavigationBar: GuestBottomNavigation(
        selectedIndex: 1,
        onItemTap: (index) => _handleExtendedNavigation(context, index),
      ),
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: RefreshIndicator(
              onRefresh: _loadDetails,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(22, 8, 22, 188),
                children: [
                  const _BackButtonText(),
                  const SizedBox(height: 26),
                  Text(
                    'Событие',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontSize: 25,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 22),
                  _buildContent(context),
                ],
              ),
            ),
          ),
          Positioned(
            left: 22,
            right: 22,
            bottom: MediaQuery.paddingOf(context).bottom + 103,
            child: FilledButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Удаление события будет реализовано позже'),
                  ),
                );
              },
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFD9D9D9),
                foregroundColor: AppColors.textDark,
                minimumSize: const Size.fromHeight(58),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(29),
                ),
                textStyle: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w500),
              ),
              child: const Text('Удалить'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(
        height: 360,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_errorText != null) {
      return _MessageText(text: _errorText!);
    }
    final event = _event;
    if (event == null) {
      return const _MessageText(text: 'Событие не найдено');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _EventDetailCard(event: event),
        const SizedBox(height: 14),
        _InfoCard(
          rows: [
            _InfoRow(label: 'Формат', value: event.normalizedFormat),
            _InfoRow(
              label: 'Организатор',
              value: _organizer?.displayNameWithAge ?? 'Не указан',
            ),
          ],
        ),
        const SizedBox(height: 22),
        Text(
          'Запросы на участие',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 10),
        if (_requests.isEmpty)
          Text(
            'Запросов на участие пока нет',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: const Color(0xFF777777)),
          )
        else
          _RequestsSummaryRow(
            count: _requests.length,
            onTap: () async {
              final changed = await Navigator.of(context).push<bool>(
                MaterialPageRoute<bool>(
                  builder: (context) =>
                      EventRequestsScreen(eventId: widget.eventId),
                ),
              );
              if (changed == true) {
                await _loadDetails();
              }
            },
          ),
      ],
    );
  }
}

class _EventDetailCard extends StatelessWidget {
  const _EventDetailCard({required this.event});
  final EventDetailItem event;

  @override
  Widget build(BuildContext context) {
    return _SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: _StatusChip(
              text: eventStatusText(event),
              color: event.isApproved
                  ? AppColors.greenStatus
                  : const Color(0xFFD9D9D9),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _CategoryIcon(category: event.category),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  event.title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _DetailMeta(icon: Icons.place_outlined, text: event.location),
          const SizedBox(height: 8),
          _DetailMeta(
            icon: Icons.schedule,
            text: formatEventDateTime(event.startsAt),
          ),
          const SizedBox(height: 8),
          _DetailMeta(
            icon: Icons.people_alt_outlined,
            text: participantText(event.participantLimit),
          ),
          if (event.description.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              event.description,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(height: 1.4),
            ),
          ],
        ],
      ),
    );
  }
}

class _RequestsSummaryRow extends StatelessWidget {
  const _RequestsSummaryRow({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: _SoftCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          children: [
            Expanded(
              child: Text(
                '$count ${newRequestWord(count)}',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w500),
              ),
            ),
            const Icon(Icons.chevron_right, size: 22, color: Color(0xFF777777)),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.rows});
  final List<_InfoRow> rows;
  @override
  Widget build(BuildContext context) {
    return _SoftCard(
      child: Column(
        children: [
          for (var index = 0; index < rows.length; index++) ...[
            rows[index],
            if (index < rows.length - 1)
              const Divider(height: 20, color: Color(0xFFCFCFCF)),
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 104,
          child: Text(label, style: const TextStyle(color: Color(0xFF777777))),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontSize: 14),
          ),
        ),
      ],
    );
  }
}

class _SoftCard extends StatelessWidget {
  const _SoftCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.72)),
      ),
      child: Padding(padding: padding, child: child),
    );
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
        dimension: 40,
        child: Icon(
          eventCategoryIcon(category),
          size: 23,
          color: AppColors.textDark,
        ),
      ),
    );
  }
}

class _DetailMeta extends StatelessWidget {
  const _DetailMeta({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF777777)),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            text,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: const Color(0xFF777777)),
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

class _MessageText extends StatelessWidget {
  const _MessageText({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 360,
      child: Center(
        child: Text(text, style: const TextStyle(color: Color(0xFF777777))),
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
