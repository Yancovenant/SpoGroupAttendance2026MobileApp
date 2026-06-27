import 'package:dio/dio.dart';
import 'storage_service.dart';
import 'dart:convert';

import './database_helper.dart';
import '../data/models/attendance_record.dart';

import 'package:flutter/material.dart';

class ApiService {
  late Dio _dio;

  ApiService() {
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
    ));

    // Interceptor to inject tokens and handle headers
    _dio.interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) async {
          final serverUrl = await StorageService.getServerUrl();
          final tokens = await StorageService.getAuthTokens();

          if (serverUrl != null) {
            options.baseUrl = serverUrl;
          }

          if (tokens != null) {
            options.headers['Authorization'] = 'Bearer ${tokens['token']}';
            options.headers['X-Access-Token'] = tokens['access_token'];
            options.headers['X-User-Id'] = tokens['user_id'].toString();
          }

          handler.next(options);
        },
        onError: (DioException e, handler) async {
          // Handle 401 Unauthorized
          if (e.response?.statusCode == 401) {
            await StorageService.clearAuth();
          }
          handler.next(e);
        }
    ));
  }

  // Login endpoint
  Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      final response = await _dio.post('/auth/login', data: {
        'username': username,
        'password': password,
      });

      return {
        'success': true,
        'data': response.data,
      };
    } on DioException catch (e) {
      return {
        'success': false,
        'message': e.response?.data['message'] ?? 'Connection failed',
        'code': e.response?.data['code'] ?? 'NET_001',
      };
    }
  }

  // Pull attendance data
  Future<Map<String, dynamic>> pullData() async {
    try {
      debugPrint('[SPO_DEBUG] API: Sending GET request to /sync/pull...');
      final response = await _dio.get('/sync/pull');
      debugPrint('[SPO_DEBUG] API: Received response. Status: ${response.statusCode}');

      return {
        'success': true,
        'data': response.data,
      };
    } on DioException catch (e) {
      debugPrint('[SPO_DEBUG] API: DioException caught! Message: ${e.message}');
      debugPrint('[SPO_DEBUG] API: Response Data: ${e.response?.data}');
      return {
        'success': false,
        'message': e.response?.data['message'] ?? 'Failed to pull data',
      };
    } catch (e) {
      debugPrint('[SPO_DEBUG] API: Generic Exception caught! $e');
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }

  Future<Map<String, dynamic>> pushAttendance(AttendanceRecord record) async {
    try {
      debugPrint('[SPO_DEBUG] PUSH: 🚀 Starting pushAttendance for record ${record.recordId}');
      // 1. Fetch worker names for the entries payload
      final db = await DatabaseHelper.instance.database;
      final entries = <Map<String, dynamic>>[];

      for (var empIdStr in record.presentWorkerIds) {
        final empId = int.tryParse(empIdStr) ?? 0;
        final empRes = await db.query('employees', where: 'id = ?', whereArgs: [empId]);
        String name = 'Unknown';
        if (empRes.isNotEmpty) {
          name = empRes.first['name'] as String? ?? 'Unknown';
        }
        entries.add({'employee_id': empIdStr, 'name': name});
      }
      debugPrint('[SPO_DEBUG] PUSH: Fetched ${entries.length} worker entries.');

      // 2. Format exactly as PHP backend expects
      final attendancePayload = [{
        'attendance_data': {
          'true_id': record.recordId,
          'user_id': record.userId,
          'gang_id': record.gangId,
          'attendance_date': record.date.toIso8601String(),
          'type': record.type,
          'location': '${record.latitude}, ${record.longitude}',
          'entries': jsonEncode(entries), // Must be a JSON string
        }
      }];

      final jsonString = jsonEncode(attendancePayload);
      debugPrint('[SPO_DEBUG] PUSH: 📦 JSON Payload being sent:');
      debugPrint(jsonString);

      FormData formData = FormData.fromMap({
        'attendance_data': jsonString,
      });

      // 3. Attach Photo
      if (record.groupPhotoPath != null) {
        debugPrint('[SPO_DEBUG] PUSH: 📷 Attaching photo from ${record.groupPhotoPath}');
        formData.files.add(MapEntry(
          'photo_${record.recordId}',
          await MultipartFile.fromFile(record.groupPhotoPath!, filename: '${record.recordId}.jpg'),
        ));
      } else {
        debugPrint('[SPO_DEBUG] PUSH: ⚠️ No photo to attach.');
      }

      debugPrint('[SPO_DEBUG] PUSH: 🌐 Sending POST request to /sync/push...');
      final response = await _dio.post('/sync/push', data: formData);

      return {'success': true, 'data': response.data};
    } on DioException catch (e) {
      debugPrint('[SPO_DEBUG] PUSH: ❌ DioException caught!');
      debugPrint('[SPO_DEBUG] PUSH: Status Code: ${e.response?.statusCode}');
      debugPrint('[SPO_DEBUG] PUSH: Error Message: ${e.message}');

      debugPrint('[SPO_DEBUG] PUSH: 🛑 Server Response Data: ${e.response?.data}');
      return {
        'success': false,
        'message': e.response?.data['message'] ?? e.message ?? 'Sync failed',
        'errors': e.response?.data['errors'] ?? [],
        'conflicts': e.response?.data['conflicts'] ?? [],
      };
    } catch (e, stacktrace) {
      debugPrint('[SPO_DEBUG] PUSH: ❌ Generic Exception caught! $e');
      debugPrint('[SPO_DEBUG] PUSH: Stacktrace: $stacktrace');
      return {'success': false, 'message': e.toString()};
    }
  }

  // Refresh token
  Future<Map<String, dynamic>> refreshToken() async {
    try {
      final response = await _dio.post('/auth/refresh');

      return {
        'success': true,
        'data': response.data,
      };
    } on DioException catch (e) {
      return {
        'success': false,
        'message': e.response?.data['message'] ?? 'Token refresh failed',
      };
    }
  }
}