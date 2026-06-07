import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/navigation/no_transition_page_route.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/guest_bottom_navigation.dart';
import '../../data/services/reference_data_service.dart';
import '../calendar/activity_calendar_screen.dart';
import '../guest/guest_home_screen.dart';
import '../profile/profile_screen.dart';
import 'event_detail_models.dart';

class EventRequestsScreen extends StatefulWidget {
  const EventRequestsScreen({super.key, required this.eventId});

  final String eventId;

  @override
  State<EventRequestsScreen> createState() => _EventRequestsScreenState();
}

class _EventRequestsScreenState extends State<EventRequestsScreen> {
  final _supabase = Supabase.instance.client;

  bool _isLoading = true;
  String? _errorText;
  String? _updatingRequestKey;
  bool _hasChanged = false;
  EventDetailItem? _event;
  List<_RequestWithPatient> _requests = const [];

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      final eventData = await _supabase
          .from('events')
          .select(eventsSelectFields)
          .eq('event_id', widget.eventId)
          .limit(1)
          .timeout(const Duration(seconds: 10));

      if (eventData.isEmpty) {
        throw StateError('Event not found: ${widget.eventId}');
      }

      final event = EventDetailItem.fromJson(
        Map<String, dynamic>.from(eventData.first),
      );
      final requestRows = await _supabase
          .from('event_requests')
          .select(eventRequestsSelectFields)
          .eq('event_id', widget.eventId)
          .timeout(const Duration(seconds: 10));

      final requests = <_RequestWithPatient>[];
      for (final row in requestRows) {
        final request = EventRequestDetail.fromJson(
          Map<String, dynamic>.from(row),
        );
        requests.add(
          _RequestWithPatient(
            request: request,
            patient: await _loadPatientProfile(request.patientId),
          ),
        );
      }
      requests.sort(_compareRequests);

      if (!mounted) {
        return;
      }
      setState(() {
        _event = event;
        _requests = requests;
        _isLoading = false;
      });
    } catch (error, stackTrace) {
      debugPrint('Event requests load error: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) {
        return;
      }
      setState(() {
        _errorText = 'Не удалось загрузить запросы';
        _isLoading = false;
      });
    }
  }

  Future<EventPatientProfile?> _loadPatientProfile(Object? patientId) async {
    if (patientId == null) {
      return null;
    }
    try {
      final data = await _supabase
          .from('patients')
          .select('patient_id, full_name, birth_date')
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
      debugPrint('Event request patient load error: $error');
      debugPrintStack(stackTrace: stackTrace);
      return null;
    }
  }

  int _compareRequests(_RequestWithPatient a, _RequestWithPatient b) {
    final priorityComparison = _requestPriority(
      a.request,
    ).compareTo(_requestPriority(b.request));
    if (priorityComparison != 0) {
      return priorityComparison;
    }
    final aDate = a.request.createdAt ?? DateTime(0);
    final bDate = b.request.createdAt ?? DateTime(0);
    return bDate.compareTo(aDate);
  }

  int _requestPriority(EventRequestDetail request) {
    if (request.isPending) {
      return 0;
    }
    if (request.isAccepted) {
      return 1;
    }
    return 2;
  }

  Future<void> _updateRequestStatus(
    EventRequestDetail request,
    String status,
  ) async {
    final patientId = request.patientId;
    if (patientId == null || _updatingRequestKey != null) {
      return;
    }

    final key = '${request.eventId}_${patientId}_$status';
    setState(() {
      _updatingRequestKey = key;
    });

    try {
      final statusId = await ReferenceDataService.instance.getId(
        table: ReferenceTables.requestStatuses,
        idColumn: 'request_status_id',
        systemValue: status,
      );
      await _supabase
          .from('event_requests')
          .update({'request_status_id': statusId})
          .eq('event_id', request.eventId)
          .eq('patient_id', patientId)
          .timeout(const Duration(seconds: 10));

      if (!mounted) {
        return;
      }
      _hasChanged = true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            status == 'accepted' ? 'Заявка принята' : 'Заявка отклонена',
          ),
        ),
      );
      setState(() {
        _updatingRequestKey = null;
      });
      await _loadRequests();
    } catch (error, stackTrace) {
      debugPrint('Event request status update error: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) {
        return;
      }
      setState(() {
        _updatingRequestKey = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось изменить статус заявки')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop || !Navigator.of(context).canPop()) {
          return;
        }
        Navigator.of(context).pop(_hasChanged);
      },
      child: Scaffold(
        extendBody: true,
        backgroundColor: AppColors.background,
        bottomNavigationBar: GuestBottomNavigation(
          selectedIndex: 1,
          onItemTap: (index) => _handleExtendedNavigation(context, index),
        ),
        body: SafeArea(
          bottom: false,
          child: RefreshIndicator(
            onRefresh: _loadRequests,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(22, 8, 22, 132),
              children: [
                _BackButtonText(hasChanged: _hasChanged),
                const SizedBox(height: 26),
                Text(
                  'Запросы на участие',
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
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
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
    final event = _event;
    if (event == null) {
      return const _MessageText(text: 'Событие не найдено');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _EventSummaryCard(event: event),
        const SizedBox(height: 18),
        if (_requests.isEmpty)
          const _MessageText(text: 'Запросов на участие пока нет')
        else
          for (final item in _requests) ...[
            _RequestCard(
              item: item,
              isUpdating:
                  _updatingRequestKey?.startsWith(
                    '${item.request.eventId}_${item.request.patientId}_',
                  ) ??
                  false,
              onAccept: () => _updateRequestStatus(item.request, 'accepted'),
              onReject: () => _updateRequestStatus(item.request, 'rejected'),
            ),
            const SizedBox(height: 10),
          ],
      ],
    );
  }
}

class _RequestWithPatient {
  const _RequestWithPatient({required this.request, required this.patient});

  final EventRequestDetail request;
  final EventPatientProfile? patient;
}

class _EventSummaryCard extends StatelessWidget {
  const _EventSummaryCard({required this.event});

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
        ],
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.item,
    required this.isUpdating,
    required this.onAccept,
    required this.onReject,
  });

  final _RequestWithPatient item;
  final bool isUpdating;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final request = item.request;
    return _SoftCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _AvatarPlaceholder(),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.patient?.displayName ?? 'Участник',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    if (!request.isPending)
                      _StatusChip(
                        text: request.isAccepted ? 'Принято' : 'Отклонено',
                        color: request.isAccepted
                            ? AppColors.greenStatus
                            : const Color(0xFFD9D9D9),
                      ),
                  ],
                ),
                if (request.text.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    request.text,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF777777),
                      height: 1.35,
                    ),
                  ),
                ],
                if (request.isPending) ...[
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _RequestActionButton(
                          label: 'Отклонить',
                          backgroundColor: const Color(0xFFD9D9D9),
                          onPressed: isUpdating ? null : onReject,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _RequestActionButton(
                          label: 'Принять',
                          backgroundColor: AppColors.pinkAccent,
                          onPressed: isUpdating ? null : onAccept,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RequestActionButton extends StatelessWidget {
  const _RequestActionButton({
    required this.label,
    required this.backgroundColor,
    required this.onPressed,
  });

  final String label;
  final Color backgroundColor;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: backgroundColor,
        foregroundColor: AppColors.textDark,
        minimumSize: const Size.fromHeight(42),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(21)),
        textStyle: Theme.of(
          context,
        ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w500),
      ),
      child: Text(label),
    );
  }
}

class _AvatarPlaceholder extends StatelessWidget {
  const _AvatarPlaceholder();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.pinkAccent.withValues(alpha: 0.62),
        shape: BoxShape.circle,
      ),
      child: const SizedBox.square(
        dimension: 42,
        child: Icon(Icons.person_outline, size: 22, color: AppColors.textDark),
      ),
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
  const _BackButtonText({required this.hasChanged});

  final bool hasChanged;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: GestureDetector(
        onTap: () => Navigator.of(context).pop(hasChanged),
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
      height: 220,
      child: Center(
        child: Text(text, style: const TextStyle(color: Color(0xFF777777))),
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
