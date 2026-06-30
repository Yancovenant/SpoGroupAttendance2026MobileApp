import 'dart:io';
import 'package:flutter/material.dart';
import '../../data/models/attendance_record.dart';
import '../../data/models/employee.dart';
import '../../services/database_helper.dart';

class HistoryDetailScreen extends StatefulWidget {
  final AttendanceRecord record;

  const HistoryDetailScreen({super.key, required this.record});

  @override
  State<HistoryDetailScreen> createState() => _HistoryDetailScreenState();
}

class _HistoryDetailScreenState extends State<HistoryDetailScreen> {
  List<Employee> _allWorkers = [];
  List<Employee> _displayedWorkers = [];
  List<String> _selectedWorkerIds = [];

  bool _isLoading = true;
  bool _isSaving = false;
  bool _hasChanges = false;

  // Pagination Controllers
  final ScrollController _scrollController = ScrollController();
  final int _pageSize = 30;
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _selectedWorkerIds = List.from(widget.record.presentWorkerIds);
    _scrollController.addListener(_scrollListener);
    _loadWorkers();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    // Trigger load more when 200px from the bottom
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      _loadMoreWorkers();
    }
  }

  void _loadMoreWorkers() {
    if (_isLoadingMore || _displayedWorkers.length >= _allWorkers.length) return;
    setState(() => _isLoadingMore = true);

    // Small delay to show the loading indicator smoothly
    Future.delayed(const Duration(milliseconds: 200), () {
      final start = _displayedWorkers.length;
      final end = (start + _pageSize).clamp(0, _allWorkers.length);
      _displayedWorkers.addAll(_allWorkers.sublist(start, end));
      if (mounted) setState(() => _isLoadingMore = false);
    });
  }

  Future<void> _loadWorkers() async {
    final db = await DatabaseHelper.instance.database;
    final workers = await db.query(
      'employees',
      where: 'gang_id = ?',
      whereArgs: [widget.record.gangId],
      orderBy: 'name ASC',
    );

    if (mounted) {
      _allWorkers = workers.map((e) => Employee.fromMap(e)).toList();
      // Load the first batch immediately
      _displayedWorkers = _allWorkers.take(_pageSize).toList();
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveChanges() async {
    setState(() => _isSaving = true);

    final updatedRecord = AttendanceRecord(
      id: widget.record.id,
      recordId: widget.record.recordId,
      date: widget.record.date,
      userId: widget.record.userId,
      gangId: widget.record.gangId,
      type: widget.record.type,
      groupPhotoPath: widget.record.groupPhotoPath,
      latitude: widget.record.latitude,
      longitude: widget.record.longitude,
      presentWorkerIds: _selectedWorkerIds,
      syncStatus: SyncStatus.pending, // Force re-sync
      conflictWorkerIds: widget.record.conflictWorkerIds,
    );

    final db = await DatabaseHelper.instance.database;
    await db.update(
      'attendance_records',
      updatedRecord.toMap(),
      where: 'id = ?',
      whereArgs: [updatedRecord.id],
    );

    if (mounted) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Perubahan disimpan & direset ke Antrian"), backgroundColor: Colors.green),
      );
      Navigator.pop(context, true);
    }
  }

  Future<void> _deleteRecord() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Hapus Riwayat?"),
        content: Text(
          widget.record.syncStatus == SyncStatus.synced
              ? "Data ini sudah tersinkron ke server. Menghapusnya di sini TIDAK akan menghapus data di server. Lanjutkan?"
              : "Data absensi ini akan dihapus permanen dari perangkat. Lanjutkan?",
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Batal")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Hapus", style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      final db = await DatabaseHelper.instance.database;
      await db.delete(
        'attendance_records',
        where: 'id = ?',
        whereArgs: [widget.record.id],
      );

      if (widget.record.groupPhotoPath != null) {
        try {
          final file = File(widget.record.groupPhotoPath!);
          if (await file.exists()) await file.delete();
        } catch (_) {}
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Riwayat dihapus"), backgroundColor: Colors.red),
        );
        Navigator.pop(context, true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.record.type == 'in' ? "Detail Absensi Masuk" : "Detail Absensi Pulang"),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            onPressed: _deleteRecord,
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(),
        slivers: [
          // 1. Info Card Header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      if (widget.record.groupPhotoPath != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(
                            File(widget.record.groupPhotoPath!),
                            height: 150,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("Status Sync:", style: TextStyle(color: Colors.grey[600])),
                          Text(
                            widget.record.syncStatus.name.toUpperCase(),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: widget.record.syncStatus == SyncStatus.synced ? Colors.green : Colors.orange,
                            ),
                          ),
                        ],
                      ),
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("GPS:", style: TextStyle(color: Colors.grey[600])),
                          Text("${widget.record.latitude?.toStringAsFixed(4) ?? '-'}, ${widget.record.longitude?.toStringAsFixed(4) ?? '-'}"),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 2. List Title
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Text(
                  "Daftar Pekerja (${_selectedWorkerIds.length} dipilih)",
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
              ),
            ),
          ),

          // 3. Paginated Worker List
          SliverList(
            delegate: SliverChildBuilderDelegate(
                  (context, index) {
                // Show loading indicator at the bottom when fetching more
                if (index == _displayedWorkers.length) {
                  return _isLoadingMore
                      ? const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Center(child: CircularProgressIndicator())
                  )
                      : const SizedBox.shrink();
                }

                final worker = _displayedWorkers[index];
                final empIdStr = (worker.id ?? 0).toString();
                final isSelected = _selectedWorkerIds.contains(empIdStr);

                return CheckboxListTile(
                  value: isSelected,
                  onChanged: (val) {
                    setState(() {
                      _hasChanges = true;
                      if (val == true) {
                        _selectedWorkerIds.add(empIdStr);
                      } else {
                        _selectedWorkerIds.remove(empIdStr);
                      }
                    });
                  },
                  title: Text(worker.name),
                  subtitle: Text(worker.externalId ?? ''),
                  activeColor: Theme.of(context).colorScheme.primary,
                  controlAffinity: ListTileControlAffinity.leading,
                );
              },
              childCount: _displayedWorkers.length + (_isLoadingMore ? 1 : 0),
            ),
          ),

          // Bottom padding so the last item isn't hidden behind the Save button
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton(
            onPressed: (_isSaving || !_hasChanges) ? null : _saveChanges,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
            ),
            child: _isSaving
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text("Simpan Perubahan"),
          ),
        ),
      ),
    );
  }
}