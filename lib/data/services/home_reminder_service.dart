import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'session_service.dart';

class HomeReminderService {
  HomeReminderService({
    SupabaseClient? supabase,
    SessionService? sessionService,
  }) : _supabase = supabase ?? Supabase.instance.client,
       _sessionService = sessionService ?? SessionService();

  final SupabaseClient _supabase;
  final SessionService _sessionService;

  Future<List<HomeReminder>> loadReminders() async {
    final patientId = await _loadCurrentPatientId();
    final reminders = <HomeReminder>[];

    final consultation = await _loadNearestConsultation(patientId);
    if (consultation != null) {
      reminders.add(consultation);
    }

    final event = await _loadNearestEvent(patientId);
    if (event != null) {
      reminders.add(event);
    }

    reminders.sort((a, b) => a.dateTime.compareTo(b.dateTime));
    return reminders;
  }

  Future<Object> _loadCurrentPatientId() async {
    final externalId = await _sessionService.getCurrentPatientExternalId();
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

  Future<HomeReminder?> _loadNearestConsultation(Object patientId) async {
    try {
      final now = DateTime.now();
      final data = await _supabase
          .from('consultations')
          .select('*')
          .eq('patient_id', patientId)
          .gte('scheduled_at', now.toIso8601String())
          .order('scheduled_at')
          .limit(1)
          .timeout(const Duration(seconds: 10));

      if (data.isEmpty) {
        return null;
      }

      final date = _asDateTime(data.first['scheduled_at']);
      if (date == null) {
        return null;
      }

      return HomeReminder(
        type: HomeReminderType.consultation,
        eventId: null,
        creatorPatientId: null,
        currentPatientId: patientId,
        isOwnEvent: false,
        title: 'Консультация ${nearbyDatePhrase(date)}',
        subtitle: formatReminderDateTime(date),
        dateTime: date,
      );
    } catch (error, stackTrace) {
      debugPrint('Home consultation reminder load error: $error');
      debugPrintStack(stackTrace: stackTrace);
      return null;
    }
  }

  Future<HomeReminder?> _loadNearestEvent(Object patientId) async {
    try {
      final now = DateTime.now();
      final events = <_EventCandidate>[
        ...await _loadApprovedCreatedEvents(patientId, now),
        ...await _loadAcceptedParticipationEvents(patientId, now),
      ];

      final uniqueEvents = <String, _EventCandidate>{};
      for (final event in events) {
        if (event.id != null && event.id!.isNotEmpty) {
          uniqueEvents.putIfAbsent(event.id!, () => event);
        } else {
          uniqueEvents.putIfAbsent(
            '${event.title}_${event.startsAt.toIso8601String()}',
            () => event,
          );
        }
      }

      final upcoming =
          uniqueEvents.values
              .where((event) => !event.startsAt.isBefore(now))
              .toList()
            ..sort((a, b) => a.startsAt.compareTo(b.startsAt));

      if (upcoming.isEmpty) {
        return null;
      }

      final nearest = upcoming.first;

      return HomeReminder(
        type: HomeReminderType.event,
        eventId: nearest.id,
        creatorPatientId: nearest.creatorPatientId,
        currentPatientId: patientId,
        isOwnEvent: nearest.isOwnEvent,
        title: 'Событие ${nearbyDatePhrase(nearest.startsAt)}',
        subtitle:
            '${nearest.title}, ${formatReminderDateTime(nearest.startsAt)}',
        dateTime: nearest.startsAt,
      );
    } catch (error, stackTrace) {
      debugPrint('Home event reminder load error: $error');
      debugPrintStack(stackTrace: stackTrace);
      return null;
    }
  }

  Future<List<_EventCandidate>> _loadAcceptedParticipationEvents(
    Object patientId,
    DateTime now,
  ) async {
    try {
      final data = await _supabase
          .from('event_requests')
          .select(
            'request_status, events(event_id, title, starts_at, event_status, creator_patient_id)',
          )
          .eq('patient_id', patientId)
          .eq('request_status', 'accepted')
          .timeout(const Duration(seconds: 10));

      final events = <_EventCandidate>[];
      for (final row in data) {
        if (!_isAcceptedStatus(row['request_status'])) {
          continue;
        }
        final candidates = _eventCandidatesFromJoinedValue(row['events']);
        for (final candidate in candidates) {
          if (!candidate.startsAt.isBefore(now)) {
            events.add(candidate);
          }
        }
      }
      return events;
    } catch (error, stackTrace) {
      debugPrint('Home accepted event reminders load error: $error');
      debugPrintStack(stackTrace: stackTrace);
      return const [];
    }
  }

  Future<List<_EventCandidate>> _loadApprovedCreatedEvents(
    Object patientId,
    DateTime now,
  ) async {
    try {
      final data = await _supabase
          .from('events')
          .select(
            'event_id, title, starts_at, event_status, creator_patient_id',
          )
          .eq('creator_patient_id', patientId)
          .gte('starts_at', now.toIso8601String())
          .timeout(const Duration(seconds: 10));

      return [
        for (final row in data)
          if (_eventCandidateFromMap(
                    Map<String, dynamic>.from(row),
                    isOwnEvent: true,
                  ) !=
                  null &&
              _isApprovedStatus(row['event_status']))
            _eventCandidateFromMap(
              Map<String, dynamic>.from(row),
              isOwnEvent: true,
            )!,
      ];
    } catch (error, stackTrace) {
      debugPrint('Home created event load error: $error');
      debugPrintStack(stackTrace: stackTrace);
      return const [];
    }
  }
}

enum HomeReminderType { consultation, event }

class HomeReminder {
  const HomeReminder({
    required this.type,
    required this.eventId,
    required this.creatorPatientId,
    required this.currentPatientId,
    required this.isOwnEvent,
    required this.title,
    required this.subtitle,
    required this.dateTime,
  });

  final HomeReminderType type;
  final String? eventId;
  final Object? creatorPatientId;
  final Object? currentPatientId;
  final bool isOwnEvent;
  final String title;
  final String subtitle;
  final DateTime dateTime;
}

class _EventCandidate {
  const _EventCandidate({
    required this.id,
    required this.creatorPatientId,
    required this.isOwnEvent,
    required this.title,
    required this.startsAt,
  });

  final String? id;
  final Object? creatorPatientId;
  final bool isOwnEvent;
  final String title;
  final DateTime startsAt;
}

List<_EventCandidate> _eventCandidatesFromJoinedValue(Object? value) {
  if (value is Map<String, dynamic>) {
    final candidate = _eventCandidateFromMap(value, isOwnEvent: false);
    return candidate == null ? const [] : [candidate];
  }

  if (value is List) {
    return [
      for (final item in value)
        if (item is Map<String, dynamic> &&
            _eventCandidateFromMap(item, isOwnEvent: false) != null)
          _eventCandidateFromMap(item, isOwnEvent: false)!,
    ];
  }

  return const [];
}

_EventCandidate? _eventCandidateFromMap(
  Map<String, dynamic> json, {
  required bool isOwnEvent,
}) {
  final startsAt = _asDateTime(json['starts_at']);
  if (startsAt == null) {
    return null;
  }

  return _EventCandidate(
    id: _asString(json['event_id'] ?? json['id'], fallback: '').isEmpty
        ? null
        : _asString(json['event_id'] ?? json['id'], fallback: ''),
    creatorPatientId:
        json['creator_patient_id'] ??
        json['patient_id'] ??
        json['owner_patient_id'],
    isOwnEvent: isOwnEvent,
    title: _asString(
      json['title'] ?? json['event_name'] ?? json['name'],
      fallback: 'Событие',
    ),
    startsAt: startsAt,
  );
}

String nearbyDatePhrase(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final target = DateTime(date.year, date.month, date.day);
  final days = target.difference(today).inDays;

  if (days <= 0) {
    return 'сегодня';
  }

  if (days == 1) {
    return 'завтра';
  }

  return 'через $days ${_dayWord(days)}';
}

String formatReminderDateTime(DateTime date) {
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

String _dayWord(int days) {
  final mod10 = days % 10;
  final mod100 = days % 100;
  if (mod10 == 1 && mod100 != 11) {
    return 'день';
  }
  if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) {
    return 'дня';
  }
  return 'дней';
}

DateTime? _asDateTime(Object? value) {
  final text = value?.toString();
  if (text == null || text.isEmpty) {
    return null;
  }
  return DateTime.tryParse(text);
}

String _asString(Object? value, {required String fallback}) {
  final text = value?.toString().trim();
  if (text == null || text.isEmpty) {
    return fallback;
  }
  return text;
}

bool _isApprovedStatus(Object? status) {
  final lower = status?.toString().toLowerCase() ?? '';
  return lower.contains('approved') ||
      lower.contains('published') ||
      lower.contains('active') ||
      lower.contains('одобр') ||
      lower.contains('провер');
}

bool _isAcceptedStatus(Object? status) {
  final lower = status?.toString().toLowerCase() ?? '';
  return lower.contains('accepted') ||
      lower.contains('confirmed') ||
      lower.contains('approved') ||
      lower.contains('принят') ||
      lower.contains('подтверж');
}
