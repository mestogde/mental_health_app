import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class EventDetailItem {
  const EventDetailItem({
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
    return format.isEmpty ? 'Не указан' : format;
  }

  bool get isApproved {
    final lower = status.toLowerCase();
    return lower.contains('approved') ||
        lower.contains('published') ||
        lower.contains('active') ||
        lower.contains('одобр') ||
        lower.contains('провер');
  }

  factory EventDetailItem.fromJson(Map<String, dynamic> json) {
    return EventDetailItem(
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
      format: asString(json['event_format'] ?? json['format']),
      category: asString(json['category'], fallback: 'Развлечение'),
      location: asString(json['location'], fallback: 'Место не указано'),
      startsAt: asDateTime(json['starts_at']),
      participantLimit: asInt(json['participant_limit']),
      status: asString(json['event_status'] ?? json['status']),
    );
  }
}

class EventRequestDetail {
  const EventRequestDetail({
    required this.eventId,
    required this.patientId,
    required this.status,
    required this.text,
    required this.createdAt,
  });

  final String eventId;
  final Object? patientId;
  final String status;
  final String text;
  final DateTime? createdAt;

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

  bool get isRejected {
    final lower = status.toLowerCase();
    return lower.contains('rejected') ||
        lower.contains('declined') ||
        lower.contains('отклон');
  }

  factory EventRequestDetail.fromJson(Map<String, dynamic> json) {
    return EventRequestDetail(
      eventId: asString(json['event_id']),
      patientId: json['patient_id'],
      status: asString(json['request_status'] ?? json['status']),
      text: asString(json['request_text']),
      createdAt: asDateTime(json['created_at']),
    );
  }
}

class EventPatientProfile {
  const EventPatientProfile({
    required this.id,
    required this.fullName,
    required this.age,
  });

  final Object? id;
  final String fullName;
  final int? age;

  String get displayName {
    if (age == null) {
      return fullName;
    }
    return '$fullName, $age';
  }

  String get displayNameWithAge {
    if (age == null) {
      return fullName;
    }
    return '$fullName, $age ${ageWord(age!)}';
  }

  factory EventPatientProfile.fromJson(Map<String, dynamic> json) {
    return EventPatientProfile(
      id: json['patient_id'],
      fullName: asString(
        json['full_name'] ?? json['name'],
        fallback: 'Участник',
      ),
      age: asInt(json['age']) ?? ageFromBirthDate(json['birth_date']),
    );
  }
}

IconData eventCategoryIcon(String category) {
  final lower = category.toLowerCase();
  if (lower.contains('прогул') || lower.contains('walk')) {
    return Icons.landscape_outlined;
  }
  if (lower.contains('игр') || lower.contains('game')) {
    return Icons.sports_esports_outlined;
  }
  return Icons.local_activity_outlined;
}

String eventStatusText(EventDetailItem event) {
  return event.isApproved ? 'Прошло проверку' : 'Ожидает проверку';
}

String requestStatusText(EventRequestDetail request) {
  if (request.isAccepted) {
    return 'Принято';
  }
  if (request.isPending) {
    return 'Запрос отправлен';
  }
  return 'Отклонено';
}

Color requestStatusColor(EventRequestDetail request) {
  if (request.isAccepted) {
    return AppColors.greenStatus;
  }
  return const Color(0xFFD9D9D9);
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

String ageWord(int count) {
  final mod10 = count % 10;
  final mod100 = count % 100;
  if (mod10 == 1 && mod100 != 11) {
    return 'год';
  }
  if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) {
    return 'года';
  }
  return 'лет';
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

String newRequestWord(int count) {
  final mod10 = count % 10;
  final mod100 = count % 100;
  if (mod10 == 1 && mod100 != 11) {
    return 'новый запрос';
  }
  if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) {
    return 'новых запроса';
  }
  return 'новых запросов';
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

int? ageFromBirthDate(Object? value) {
  final birthDate = asDateTime(value);
  if (birthDate == null) {
    return null;
  }
  final now = DateTime.now();
  var age = now.year - birthDate.year;
  if (now.month < birthDate.month ||
      (now.month == birthDate.month && now.day < birthDate.day)) {
    age--;
  }
  return age;
}
