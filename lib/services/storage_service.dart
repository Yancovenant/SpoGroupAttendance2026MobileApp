import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class StorageService {
  static const _storage = FlutterSecureStorage();

  // Keys
  static const _serverUrl = 'server_url';
  static const _useSSL = 'use_ssl';
  static const _authToken = 'auth_token';
  static const _accessToken = 'access_token';
  static const _userId = 'user_id';
  static const _isConfigured = 'is_configured';

  // Server Configuration
  static Future<void> saveServerConfig(String url, bool useSSL) async {
    await _storage.write(key: _serverUrl, value: url);
    await _storage.write(key: _useSSL, value: useSSL.toString());
    await _storage.write(key: _isConfigured, value: 'true');
  }

  static Future<String?> getServerUrl() async {
    return await _storage.read(key: _serverUrl);
  }

  static Future<bool> getUseSSL() async {
    final val = await _storage.read(key: _useSSL);
    return val == 'true';
  }

  static Future<bool> isConfigured() async {
    final val = await _storage.read(key: _isConfigured);
    return val == 'true';
  }

  // Auth Tokens
  static Future<void> saveAuthTokens({
    required String token,
    required String accessToken,
    required int userId,
  }) async {
    await _storage.write(key: _authToken, value: token);
    await _storage.write(key: _accessToken, value: accessToken);
    await _storage.write(key: _userId, value: userId.toString());
  }

  static Future<Map<String, dynamic>?> getAuthTokens() async {
    final token = await _storage.read(key: _authToken);
    final accessToken = await _storage.read(key: _accessToken);
    final userId = await _storage.read(key: _userId);

    if (token == null || accessToken == null || userId == null) return null;

    return {
      'token': token,
      'access_token': accessToken,
      'user_id': int.parse(userId),
    };
  }

  static Future<void> clearAuth() async {
    await _storage.delete(key: _authToken);
    await _storage.delete(key: _accessToken);
    await _storage.delete(key: _userId);
  }
}