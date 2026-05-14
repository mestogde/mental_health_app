import 'package:shared_preferences/shared_preferences.dart';

class SessionService {
  static const demoPatientExternalId = 'P-1001';
  static const demoPin = '5555';
  static const _hasExtendedAccessKey = 'hasExtendedAccess';
  static const _userPinKey = 'userPin';
  static const _currentPatientExternalIdKey = 'currentPatientExternalId';

  Future<void> activateDemoPatientSession({required String pin}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hasExtendedAccessKey, true);
    await prefs.setString(_userPinKey, pin);
    await prefs.setString(_currentPatientExternalIdKey, demoPatientExternalId);
  }

  Future<bool> hasExtendedAccess() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_hasExtendedAccessKey) ?? false;
  }

  Future<String> getCurrentPatientExternalId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_currentPatientExternalIdKey) ??
        demoPatientExternalId;
  }

  Future<bool> verifyPin(String pin) async {
    final isDemoLogin = await loginDemoPatientByPin(pin);
    if (isDemoLogin) {
      return true;
    }

    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userPinKey) == pin;
  }

  Future<bool> loginDemoPatientByPin(String pin) async {
    if (pin != demoPin) {
      return false;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hasExtendedAccessKey, true);
    await prefs.setString(_currentPatientExternalIdKey, demoPatientExternalId);
    return true;
  }

  Future<void> updatePin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userPinKey, pin);
    await prefs.setBool(_hasExtendedAccessKey, true);
    await prefs.setString(_currentPatientExternalIdKey, demoPatientExternalId);
  }
}
