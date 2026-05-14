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
    final events = <_EventCandidate>[];
    events.addAll(await _loadAcceptedEvents(patientId));
    events.addAll(await _loadCreatedEvents(patientId));

    final now = DateTime.now();
    final upcoming = events.where((event) => !event.startsAt.isBefore(now));
    if (upcoming.isEmpty) {
      return null;
    }

    final nearest = upcoming.reduce(
      (a, b) => a.startsAt.isBefore(b.startsAt) ? a : b,
    );

    return HomeReminder(
      type: HomeReminderType.event,
      title: 'Событие ${nearbyDatePhrase(nearest.startsAt)}',
      subtitle: '${nearest.title}, ${formatReminderDateTime(nearest.startsAt)}',
      dateTime: nearest.startsAt,
    );
  }

  Future<List<_EventCandidate>> _loadAcceptedEvents(Object patientId) async {
    try {
      final data = await _supabase
          .from('event_requests')
          .select('events(*)')
          .eq('patient_id', patientId)
          .eq('request_status', 'accepted')
          .timeout(const Duration(seconds: 10));

      return [
        for (final row in data)
          ..._eventCandidatesFromJoinedValue(row['events']),
      ];
    } catch (error, stackTrace) {
      debugPrint('Home accepted event reminders load error: $error');
      debugPrintStack(stackTrace: stackTrace);
      return const [];
    }
  }

  Future<List<_EventCandidate>> _loadCreatedEvents(Object patientId) async {
    for (final column in const [
      'patient_id',
      'creator_patient_id',
      'created_by_patient_id',
      'owner_patient_id',
    ]) {
      try {
        final data = await _supabase
            .from('events')
            .select('*')
            .eq(column, patientId)
            .timeout(const Duration(seconds: 10));

        final events = [
          for (final row in data)
            if (_eventCandidateFromMap(Map<String, dynamic>.from(row)) != null)
              _eventCandidateFromMap(Map<String, dynamic>.from(row))!,
        ];
        if (events.isNotEmpty) {
          return events;
        }
      } catch (error, stackTrace) {
        debugPrint('Home created event query failed for $column: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
    }

    return const [];
  }
}

enum HomeReminderType { consultation, event }

class HomeReminder {
  const HomeReminder({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.dateTime,
  });

  final HomeReminderType type;
  final String title;
  final String subtitle;
  final DateTime dateTime;
}

class _EventCandidate {
  const _EventCandidate({required this.title, required this.startsAt});

  final String title;
  final DateTime startsAt;
}

List<_EventCandidate> _eventCandidatesFromJoinedValue(Object? value) {
  if (value is Map<String, dynamic>) {
    final candidate = _eventCandidateFromMap(value);
    return candidate == null ? const [] : [candidate];
  }

  if (value is List) {
    return [
      for (final item in value)
        if (item is Map<String, dynamic> &&
            _eventCandidateFromMap(item) != null)
          _eventCandidateFromMap(item)!,
    ];
  }

  return const [];
}

_EventCandidate? _eventCandidateFromMap(Map<String, dynamic> json) {
  final startsAt = _asDateTime(json['starts_at']);
  if (startsAt == null) {
    return null;
  }

  return _EventCandidate(
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
