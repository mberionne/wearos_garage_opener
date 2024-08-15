import 'package:shared_preferences/shared_preferences.dart';

class Settings {
  static const String deviceIdKey = 'device_id';
  static const String accessTokenKey = 'access_token';
  static const String durationKey = 'duration';
  static const int defaultDuration = 3;

  Settings._(); // Private constructor to prevent external instantiation.

  static final Settings _instance = Settings._();

  factory Settings() {
    return _instance;
  }

  late final SharedPreferences _prefs;
  String _deviceId = "";
  String _accessToken = "";
  int _duration = 3;

  Future init() async {
    _prefs = await SharedPreferences.getInstance();
    _deviceId = _prefs.getString(deviceIdKey) ?? '';
    _accessToken = _prefs.getString(accessTokenKey) ?? '';
    _duration = int.tryParse(
            _prefs.getString('duration') ?? defaultDuration.toString()) ??
        defaultDuration;
  }

  String getDeviceId() => _deviceId;

  String getAccessToken() => _accessToken;

  int getDuration() => _duration;

  void setDeviceId(String value) {
    _deviceId = value;
    _prefs.setString(deviceIdKey, value);
  }

  void setAccessToken(String value) {
    _accessToken = value;
    _prefs.setString(accessTokenKey, value);
  }

  void setDuration(int value) {
    _duration = value;
    _prefs.setString(durationKey, value.toString());
  }
}
