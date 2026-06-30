import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/models/attendance_record.dart';
import '../../data/models/gang.dart';
import '../../services/database_helper.dart';
import 'history_detail_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final ScrollController _scrollController = ScrollController();
  final int _pageSize = 20;

  List<AttendanceRecord> _records = [];
  List<Gang> _gangs = [];
  bool _isLoading = false;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _loadGangs();
    _loadRecords();
    _scrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadGangs() async {
    final db = await DatabaseHelper.instance.database;
    final gangMaps = await db.query('gangs');
    _gangs = gangMaps.map((g) => Gang.fromMap(g)).toList();
  }

  String _getGangCode(int? gangId) {
    if (gangId == null) return '-';
    try {
      return _gangs.firstWhere((g) => g.id == gangId).gangCode ?? '-';
    } catch (_) {
      return '-';
    }
  }

  void _scrollListener() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      _loadRecords();
    }
  }

  Future<void> _loadRecords() async {
    if (_isLoading || !_hasMore) return;
    setState(() => _isLoading = true);

    final db = await DatabaseHelper.instance.database;
    final offset = _records.length;
    final result = await db.query(
      'attendance_records',
      orderBy: 'date DESC',
      limit: _pageSize,
      offset: offset,
    );

    if (result.isEmpty) {
      _hasMore = false;
    } else {
      _records.addAll(result.map((r) => AttendanceRecord.fromMap(r)).toList());
    }

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _refresh() async {
    setState(() {
      _records.clear();
      _hasMore = true;
    });
    await _loadRecords();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Riwayat Absensi"),
      ),
      body: _records.isEmpty && !_isLoading
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history_toggle_off, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text("Belum ada riwayat absensi"),
          ],
        ),
      )
          : RefreshIndicator(
        onRefresh: _refresh,
        child: ListView.builder(
          controller: _scrollController,
          itemCount: _records.length + (_hasMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == _records.length) {
              return const Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final record = _records[index];
            return _buildRecordCard(record);
          },
        ),
      ),
    );
  }

  Widget _buildRecordCard(AttendanceRecord record) {
    final dateFormat = DateFormat('dd MMM yyyy, HH:mm');
    final dateStr = dateFormat.format(record.date);
    final isCheckIn = record.type == 'in';
    final gangCode = _getGangCode(record.gangId);

    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (record.syncStatus) {
      case SyncStatus.synced:
        statusColor = Colors.green;
        statusText = "Tersinkron";
        statusIcon = Icons.cloud_done;
        break;
      case SyncStatus.pending:
        statusColor = Colors.orange;
        statusText = "Antrian";
        statusIcon = Icons.cloud_queue;
        break;
      case SyncStatus.conflict:
        statusColor = Colors.red;
        statusText = "Konflik";
        statusIcon = Icons.error_outline;
        break;
      default:
        statusColor = Colors.grey;
        statusText = "Memproses...";
        statusIcon = Icons.sync;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => HistoryDetailScreen(record: record),
            ),
          );
          if (result == true) _refresh(); // Refresh list if edited or deleted
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        isCheckIn ? Icons.fingerprint : Icons.exit_to_app,
                        color: isCheckIn ? Colors.green : Colors.red,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isCheckIn ? "Absensi Masuk" : "Absensi Pulang",
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ],
                  ),
                  Chip(
                    avatar: Icon(statusIcon, size: 16, color: statusColor),
                    label: Text(statusText, style: TextStyle(color: statusColor, fontSize: 12)),
                    backgroundColor: statusColor.withOpacity(0.1),
                    side: BorderSide.none,
                    padding: EdgeInsets.zero,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                  const SizedBox(width: 6),
                  Text(dateStr, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.groups, size: 14, color: Colors.grey),
                  const SizedBox(width: 6),
                  Text("Gang $gangCode", style: const TextStyle(color: Colors.grey, fontSize: 13)),
                  const SizedBox(width: 16),
                  const Icon(Icons.people, size: 14, color: Colors.grey),
                  const SizedBox(width: 6),
                  Text("${record.presentWorkerIds.length} Pekerja", style: const TextStyle(color: Colors.grey, fontSize: 13)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}