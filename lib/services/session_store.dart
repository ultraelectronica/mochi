import 'package:shared_preferences/shared_preferences.dart';

class SessionStore {
  SessionStore._();

  static final SessionStore instance = SessionStore._();
  static const String _sessionTokenKey = 'mochi.session_token';

  SharedPreferences? _prefs;
  String _sessionToken = '';

  String get sessionToken => _sessionToken;
  bool get hasSession => _sessionToken.isNotEmpty;

  Future<void> load() async {
    _prefs ??= await SharedPreferences.getInstance();
    _sessionToken = _prefs?.getString(_sessionTokenKey)?.trim() ?? '';
  }

  Future<void> setSessionToken(String token) async {
    _prefs ??= await SharedPreferences.getInstance();
    _sessionToken = token.trim();
    await _prefs!.setString(_sessionTokenKey, _sessionToken);
  }

  Future<void> clearSessionToken() async {
    _prefs ??= await SharedPreferences.getInstance();
    _sessionToken = '';
    await _prefs!.remove(_sessionTokenKey);
  }
}
