import 'dart:convert';

enum SyncStatus { pending, syncing, synced, conflict }

class AttendanceRecord {
  final int? id;
  final String recordId;
  final DateTime date;
  final int userId;
  final int gangId;
  final String type;
  final String? groupPhotoPath;
  final double? latitude;
  final double? longitude;
  final List<String> presentWorkerIds;
  final SyncStatus syncStatus;
  final List<String> conflictWorkerIds;

  AttendanceRecord({
    this.id, required this.recordId, required this.date, required this.userId,
    required this.gangId, required this.type, this.groupPhotoPath, this.latitude, this.longitude,
    this.presentWorkerIds = const [], this.syncStatus = SyncStatus.pending,
    this.conflictWorkerIds = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id, 'record_id': recordId, 'date': date.toIso8601String(),
      'user_id': userId, 'gang_id': gangId, 'type': type, 'group_photo_path': groupPhotoPath,
      'latitude': latitude, 'longitude': longitude,
      'present_worker_ids': jsonEncode(presentWorkerIds),
      'sync_status': syncStatus.index,
      'conflict_worker_ids': jsonEncode(conflictWorkerIds),
    };
  }

  factory AttendanceRecord.fromMap(Map<String, dynamic> map) {
    return AttendanceRecord(
      id: map['id'] as int?, recordId: map['record_id'] as String,
      date: DateTime.parse(map['date'] as String), userId: map['user_id'] as int,
      gangId: map['gang_id'] as int, type: map['type'] as String? ?? 'in',
      groupPhotoPath: map['group_photo_path'] as String?,
      latitude: (map['latitude'] as num?)?.toDouble(), longitude: (map['longitude'] as num?)?.toDouble(),
      presentWorkerIds: List<String>.from(jsonDecode(map['present_worker_ids'] ?? '[]')),
      syncStatus: SyncStatus.values[map['sync_status'] ?? 0],
      conflictWorkerIds: List<String>.from(jsonDecode(map['conflict_worker_ids'] ?? '[]')),
    );
  }
}