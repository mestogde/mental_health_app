import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'reference_data_service.dart';
import 'session_service.dart';

class ContentProgressService {
  ContentProgressService._();

  static final ContentProgressService instance = ContentProgressService._();

  static const _readMaterialsKey = 'read_material_ids';
  static const _completedTestsKey = 'completed_test_ids';

  final _supabase = Supabase.instance.client;

  Future<Set<String>> getReadMaterialIds() => loadReadMaterialIds();

  Future<Set<String>> loadReadMaterialIds() async {
    final prefs = await SharedPreferences.getInstance();
    return _normalizeIds(prefs.getStringList(_readMaterialsKey));
  }

  Future<Set<String>> getCompletedTestIds() => loadCompletedTestIds();

  Future<Set<String>> loadCompletedTestIds() async {
    final prefs = await SharedPreferences.getInstance();
    return _normalizeIds(prefs.getStringList(_completedTestsKey));
  }

  Future<bool> isMaterialRead(String materialId) async {
    final ids = await loadReadMaterialIds();
    return ids.contains(materialId);
  }

  Future<bool> isTestCompleted(String testId) async {
    final ids = await loadCompletedTestIds();
    return ids.contains(testId);
  }

  Future<void> markMaterialRead(String materialId) async {
    final normalizedId = materialId.trim();
    await _storeLocalId(_readMaterialsKey, normalizedId);
    await _attemptSupabaseMaterialViewInsert(normalizedId);
  }

  Future<void> markTestCompleted(String testId) async {
    final normalizedId = testId.trim();
    await _storeLocalId(_completedTestsKey, normalizedId);
  }

  Future<void> _storeLocalId(String key, String id) async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList(key)?.toSet() ?? <String>{};
    ids.add(id.trim());
    await prefs.setStringList(key, ids.toList());
  }

  Set<String> _normalizeIds(List<String>? ids) {
    if (ids == null || ids.isEmpty) {
      return <String>{};
    }

    return ids.map((id) => id.trim()).where((id) => id.isNotEmpty).toSet();
  }

  Future<void> _attemptSupabaseMaterialViewInsert(String materialId) async {
    try {
      final patientId = await _resolveCurrentPatientId();
      if (patientId == null) {
        return;
      }

      final payload = {
        'patient_id': patientId,
        'material_id': materialId,
        'read_status_id': await ReferenceDataService.instance.getId(
          table: ReferenceTables.materialReadStatuses,
          idColumn: 'read_status_id',
          systemValue: 'completed',
        ),
        'last_viewed_at': DateTime.now().toIso8601String(),
      };

      debugPrint('Material view insert payload: $payload');
      await _supabase.from('material_views').insert(payload);
    } catch (error, stackTrace) {
      debugPrint('Material view insert error: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<Object?> _resolveCurrentPatientId() async {
    try {
      final externalId = await SessionService().getCurrentPatientExternalId();
      final data = await _supabase
          .from('patients')
          .select('patient_id')
          .eq('external_patient_id', externalId)
          .limit(1);

      if (data.isEmpty) {
        return null;
      }

      return data.first['patient_id'];
    } catch (error, stackTrace) {
      debugPrint('Resolve patient id error: $error');
      debugPrintStack(stackTrace: stackTrace);
      return null;
    }
  }
}
