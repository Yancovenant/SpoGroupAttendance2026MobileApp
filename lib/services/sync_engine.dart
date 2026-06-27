// import 'package:connectivity_plus/connectivity_plus.dart';
// import 'package:dio/dio.dart';
// import 'package:isar/isar.dart';
// import '../data/models/attendance_record.dart';
//
// class SyncEngine {
//   final Isar _db;
//   final Dio _dio;
//
//   SyncEngine(this._db, this._dio) {
//     // Listen to connectivity changes to auto-trigger sync
//     Connectivity().onConnectivityChanged.listen((result) {
//       if (result != ConnectivityResult.none) {
//         processQueue();
//       }
//     });
//   }
//
//   Future<void> processQueue() async {
//     final pendingRecords = await _db.attendanceRecords
//         .filter()
//         .syncStatusEqualTo(SyncStatus.pending)
//         .findAll();
//
//     for (var record in pendingRecords) {
//       record.syncStatus = SyncStatus.syncing;
//       await _db.writeTxn(() async => await _db.attendanceRecords.put(record));
//
//       try {
//         // Push to Server API
//         final response = await _dio.post('/api/attendance/sync', data: {
//           'record_id': record.recordId,
//           'gang_code': record.gangCode,
//           'date': record.date.toIso8601String(),
//           'workers': record.presentWorkerIds,
//           'gps': {'lat': record.latitude, 'lng': record.longitude},
//           // Photo upload logic handled by Dio FormData
//         });
//
//         // Handle Conflicts returned by Server
//         if (response.data['conflicts'] != null && (response.data['conflicts'] as List).isNotEmpty) {
//           record.conflictWorkerIds = List<String>.from(response.data['conflicts']);
//           record.syncStatus = SyncStatus.conflict;
//         } else {
//           record.syncStatus = SyncStatus.synced;
//         }
//       } catch (e) {
//         record.syncStatus = SyncStatus.pending; // Retry later
//       }
//
//       await _db.writeTxn(() async => await _db.attendanceRecords.put(record));
//     }
//   }
// }