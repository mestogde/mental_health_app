import 'package:supabase_flutter/supabase_flutter.dart';

const materialsSelectFields =
    'material_id, title, category, short_description, reading_time_minutes, '
    'image_url, published_at, access_level_id, access_levels(system_value, level_name)';

const testsSelectFields =
    'test_id, test_name, external_test_id, description, estimated_time_minutes, '
    'image_url, access_level_id, access_levels(system_value, level_name), '
    'test_type_id, test_types(system_value, type_name)';

const eventsSelectFields =
    'event_id, creator_patient_id, title, description, location, starts_at, '
    'participant_limit, created_at, updated_at, event_format_id, '
    'event_formats(system_value, format_name), event_category_id, '
    'event_categories(system_value, category_name), event_status_id, '
    'event_statuses(system_value, status_name)';

const eventRequestsSelectFields =
    'event_request_id, event_id, patient_id, request_text, request_created_at, '
    'decision_date, created_at, updated_at, request_status_id, '
    'request_statuses(system_value, status_name)';

const consultationsSelectFields =
    'consultation_id, external_consultation_id, patient_id, specialist_id, '
    'scheduled_at, record_created_at, note, created_at, updated_at, '
    'consultation_type_id, consultation_types(system_value, type_name), '
    'consultation_status_id, consultation_statuses(system_value, status_name)';

class ReferenceTables {
  static const accessLevels = 'access_levels';
  static const accessStatuses = 'access_statuses';
  static const consultationTypes = 'consultation_types';
  static const consultationStatuses = 'consultation_statuses';
  static const testTypes = 'test_types';
  static const materialReadStatuses = 'material_read_statuses';
  static const testAttemptStatuses = 'test_attempt_statuses';
  static const eventFormats = 'event_formats';
  static const eventCategories = 'event_categories';
  static const eventStatuses = 'event_statuses';
  static const moderationTypes = 'moderation_types';
  static const moderationDecisions = 'moderation_decisions';
  static const requestStatuses = 'request_statuses';
}

class ReferenceDataService {
  ReferenceDataService._();

  static final ReferenceDataService instance = ReferenceDataService._();

  final _supabase = Supabase.instance.client;
  final Map<String, Future<String?>> _idCache = {};

  Future<String> getId({
    required String table,
    required String idColumn,
    required String systemValue,
  }) async {
    final id = await tryGetId(
      table: table,
      idColumn: idColumn,
      systemValue: systemValue,
    );
    if (id == null || id.isEmpty) {
      throw StateError(
        'Reference row not found: table=$table system_value=$systemValue',
      );
    }
    return id;
  }

  Future<String?> tryGetId({
    required String table,
    required String idColumn,
    required String systemValue,
  }) {
    final normalizedSystemValue = systemValue.trim().toLowerCase();
    final cacheKey = '$table:$normalizedSystemValue';
    return _idCache.putIfAbsent(cacheKey, () async {
      final row = await _supabase
          .from(table)
          .select(idColumn)
          .eq('system_value', normalizedSystemValue)
          .maybeSingle();

      final id = row?[idColumn]?.toString().trim();
      if (id == null || id.isEmpty) {
        return null;
      }
      return id;
    });
  }
}

Map<String, dynamic>? referenceMap(Object? value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.map(
      (key, nestedValue) => MapEntry(key.toString(), nestedValue),
    );
  }
  if (value is List &&
      value.isNotEmpty &&
      value.first is Map<String, dynamic>) {
    return Map<String, dynamic>.from(value.first as Map<String, dynamic>);
  }
  if (value is List && value.isNotEmpty && value.first is Map) {
    final first = value.first as Map;
    return first.map(
      (key, nestedValue) => MapEntry(key.toString(), nestedValue),
    );
  }
  return null;
}

String referenceSystemValue(
  Map<String, dynamic> json, {
  required String relationKey,
  String legacyKey = '',
  String fallback = '',
}) {
  final related = referenceMap(json[relationKey]);
  final relatedValue = related?['system_value']?.toString().trim();
  if (relatedValue != null && relatedValue.isNotEmpty) {
    return relatedValue;
  }

  if (legacyKey.isNotEmpty) {
    final legacyValue = json[legacyKey]?.toString().trim();
    if (legacyValue != null && legacyValue.isNotEmpty) {
      return legacyValue;
    }
  }

  return fallback;
}

String referenceLabel(
  Map<String, dynamic> json, {
  required String relationKey,
  required String labelKey,
  String legacyKey = '',
  String fallback = '',
}) {
  final related = referenceMap(json[relationKey]);
  final relatedLabel = related?[labelKey]?.toString().trim();
  if (relatedLabel != null && relatedLabel.isNotEmpty) {
    return relatedLabel;
  }

  if (legacyKey.isNotEmpty) {
    final legacyLabel = json[legacyKey]?.toString().trim();
    if (legacyLabel != null && legacyLabel.isNotEmpty) {
      return legacyLabel;
    }
  }

  return fallback;
}

String normalizeAccessLevel(String? value) {
  final normalized = value?.trim().toLowerCase() ?? '';
  return switch (normalized) {
    'guest' => 'guest',
    'extended' || 'patient' => 'patient',
    _ => normalized.isEmpty ? 'guest' : normalized,
  };
}

bool isGuestAccessLevel(String? value) {
  return normalizeAccessLevel(value) == 'guest';
}
