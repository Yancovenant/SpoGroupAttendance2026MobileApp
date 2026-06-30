import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';
import 'dart:async';
import 'package:uuid/uuid.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/themes/spo_theme.dart';
import '../../data/models/employee.dart';
import '../../data/models/attendance_record.dart';
import '../../services/database_helper.dart';
import '../../services/api_service.dart';
import '../../services/storage_service.dart';
import '../dashboard/dashboard_main.dart';

class AttendanceScreen extends ConsumerStatefulWidget {
  final int gangId;
  final String gangCode;
  final bool isCheckIn;

  const AttendanceScreen({
    super.key,
    required this.gangId,
    required this.gangCode,
    required this.isCheckIn,
  });

  @override
  ConsumerState<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends ConsumerState<AttendanceScreen> {
  // Clock & Date
  Timer? _timer;
  String _currentTime = '';
  String _currentDate = '';

  // Pagination
  final ScrollController _scrollController = ScrollController();
  final int _pageSize = 20;
  bool _isLoadingMore = false;

  // State
  File? _groupPhoto;
  bool _isTakingPhoto = false;

  String? _gpsLocation;
  bool _isFetchingGps = true;

  List<Employee> _allWorkers = [];
  List<Employee> _filteredWorkers = [];
  List<Employee> _displayedWorkers = [];
  String _searchQuery = '';
  List<int> _selectedWorkerIds = [];

  bool _isSaving = false;
  bool _isPushing = false;

  final _api = ApiService();
  final _uuid = const Uuid();

  @override
  void initState() {
    super.initState();
    _updateTime();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _updateTime());
    _scrollController.addListener(_scrollListener);

    _loadWorkers();
    _getLocation(); // 🚀 Auto-fetch GPS immediately on load
  }

  void _updateTime() {
    final now = DateTime.now();
    if (mounted) {
      setState(() {
        _currentTime = DateFormat('HH:mm:ss').format(now);
        _currentDate = DateFormat('EEEE, dd MMMM yyyy').format(now);
      });
    }
  }

  void _scrollListener() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      _loadMoreWorkers();
    }
  }

  void _resetPagination() {
    _displayedWorkers = _filteredWorkers.take(_pageSize).toList();
    if (mounted) setState(() {});
  }

  void _loadMoreWorkers() {
    if (_isLoadingMore || _displayedWorkers.length >= _filteredWorkers.length) return;
    setState(() => _isLoadingMore = true);

    final start = _displayedWorkers.length;
    final end = (start + _pageSize).clamp(0, _filteredWorkers.length);

    _displayedWorkers.addAll(_filteredWorkers.sublist(start, end));
    if (mounted) setState(() => _isLoadingMore = false);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadWorkers() async {
    final db = await DatabaseHelper.instance.database;
    final workers = await db.query(
      'employees',
      where: 'gang_id = ? AND is_active = 1',
      whereArgs: [widget.gangId],
      orderBy: 'name ASC',
    );

    _allWorkers = workers.map((e) => Employee.fromMap(e)).toList();

    if (!widget.isCheckIn) {
      final today = DateTime.now().toUtc().toIso8601String().substring(0, 10);
      final inRecords = await db.query(
        'attendance_records',
        where: 'date LIKE ? AND gang_id = ? AND type = ?',
        whereArgs: ['$today%', widget.gangId, 'in'],
        orderBy: 'date DESC',
        limit: 1,
      );
      if (inRecords.isNotEmpty) {
        final inRecord = AttendanceRecord.fromMap(inRecords.first);
        final checkedInIds = inRecord.presentWorkerIds;
        _allWorkers = _allWorkers.where((w) => checkedInIds.contains((w.id ?? 0).toString())).toList();
        _selectedWorkerIds = _allWorkers.map((w) => w.id ?? 0).toList();
      } else {
        _allWorkers = [];
      }
    }

    _filteredWorkers = List.from(_allWorkers);
    _resetPagination();
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredWorkers = List.from(_allWorkers);
      } else {
        _filteredWorkers = _allWorkers
            .where((w) => w.name.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
      _resetPagination();
    });
  }

  Future<void> _takePhoto() async {
    if (_isTakingPhoto) return;
    var status = await Permission.camera.status;
    if (!status.isGranted) {
      status = await Permission.camera.request();
      if (!status.isGranted) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Izin Kamera ditolak."), backgroundColor: Colors.red));
        return;
      }
    }

    setState(() => _isTakingPhoto = true);
    try {
      final pickedFile = await ImagePicker().pickImage(
        source: ImageSource.camera,
        imageQuality: 50,
        maxWidth: 1280,
        preferredCameraDevice: CameraDevice.rear, // Rear camera is better for group photos
      );

      if (pickedFile != null) {
        final appDir = await getApplicationDocumentsDirectory();
        final photoDir = Directory('${appDir.path}/spo_attendance_photos');
        if (!await photoDir.exists()) {
          await photoDir.create(recursive: true);
        }
        final fileName = '${_uuid.v4()}.jpg';
        final savedPath = '${photoDir.path}/$fileName';
        final savedFile = await File(pickedFile.path).copy(savedPath);
        setState(() {
          _groupPhoto = savedFile;
          _isTakingPhoto = false;
        });
      } else {
        setState(() => _isTakingPhoto = false);
      }
    } catch (e) {
      setState(() => _isTakingPhoto = false);
    }
  }

  Future<void> _getLocation() async {
    setState(() => _isFetchingGps = true);

    var status = await Permission.location.status;
    if (!status.isGranted) {
      status = await Permission.location.request();
      if (!status.isGranted) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Izin Lokasi ditolak."), backgroundColor: Colors.red));
        setState(() => _isFetchingGps = false);
        return;
      }
    }

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) throw Exception('GPS Perangkat Mati');

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) throw Exception('Izin GPS Ditolak');
      }

      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);

      if (mounted) {
        setState(() {
          _gpsLocation = '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}';
          _isFetchingGps = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("GPS Error: ${e.toString()}"), backgroundColor: Colors.red));
        setState(() => _isFetchingGps = false);
      }
    }
  }

  Future<void> _saveAttendance() async {
    if (_isSaving || _isPushing) return;

    if (_groupPhoto == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Foto kelompok WAJIB diambil"), backgroundColor: Colors.red));
      return;
    }
    if (_gpsLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("GPS WAJIB diaktifkan"), backgroundColor: Colors.red));
      return;
    }
    if (_selectedWorkerIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Pilih minimal 1 pekerja"), backgroundColor: Colors.red));
      return;
    }

    setState(() => _isSaving = true);
    try {
      final tokens = await StorageService.getAuthTokens();
      final userId = tokens?['user_id'] ?? 0;

      final attendance = AttendanceRecord(
        recordId: _uuid.v4(),
        date: DateTime.now(),
        userId: userId,
        gangId: widget.gangId,
        type: widget.isCheckIn ? 'in' : 'out',
        groupPhotoPath: _groupPhoto?.path,
        latitude: double.tryParse(_gpsLocation!.split(', ')[0]),
        longitude: double.tryParse(_gpsLocation!.split(', ')[1]),
        presentWorkerIds: _selectedWorkerIds.map((id) => id.toString()).toList(),
        syncStatus: SyncStatus.pending,
        conflictWorkerIds: [],
      );

      final db = await DatabaseHelper.instance.database;
      await db.insert('attendance_records', attendance.toMap());

      setState(() => _isPushing = true);
      final pushResult = await _api.pushAttendance(attendance);

      if (pushResult['success'] == true) {
        await db.update('attendance_records', {'sync_status': SyncStatus.synced.index}, where: 'record_id = ?', whereArgs: [attendance.recordId]);

        // 🚀 CLEANUP: Delete local photo to save phone storage since it's safely on the server
        if (attendance.groupPhotoPath != null) {
          try {
            final file = File(attendance.groupPhotoPath!);
            if (await file.exists()) await file.delete();
          } catch (_) {}
        }

        if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Tersimpan & Tersinkron!"), backgroundColor: SPOColors.accentGreen));
      } else {
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Tersimpan Lokal. Sync gagal (akan dicoba nanti)."), backgroundColor: Colors.orange));
      }

      if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const DashboardScreen()));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() { _isSaving = false; _isPushing = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    // 🎨 DYNAMIC THEME: Primary (Green) for Check-In, Tertiary (Red) for Check-Out
    final Color accentColor = widget.isCheckIn
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.tertiary;

    final bool stateButtonReady = !_isSaving && !_isPushing && _groupPhoto != null && _gpsLocation != null && _selectedWorkerIds.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: accentColor,
        foregroundColor: Colors.white,
        leading: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
        title: Text("Absensi ${widget.isCheckIn ? "Masuk" : "Pulang"} - ${widget.gangCode}"),
      ),
      body: CustomScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(),
        slivers: [
          // 1. HEADER (Clock & Date)
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              color: accentColor.withOpacity(0.05),
              child: Column(
                children: [
                  Text(
                    _currentTime,
                    style: Theme.of(context).textTheme.displaySmall!.copyWith(fontWeight: FontWeight.bold, color: accentColor),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _currentDate,
                    style: Theme.of(context).textTheme.titleMedium!.copyWith(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
                  ),
                ],
              ),
            ),
          ),

          // 2. PHOTO & GPS STATUS
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Photo Section
                  Text("Foto Kelompok (Wajib)", style: Theme.of(context).textTheme.titleMedium!.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _isTakingPhoto ? null : _takePhoto,
                    child: Container(
                      height: 200,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.black12,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _groupPhoto == null ? Colors.redAccent : accentColor, width: 2),
                        image: _groupPhoto != null ? DecorationImage(image: FileImage(_groupPhoto!), fit: BoxFit.cover) : null,
                      ),
                      child: _groupPhoto == null
                          ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(_isTakingPhoto ? Icons.hourglass_empty : Icons.camera_alt, size: 48, color: Colors.grey),
                            const SizedBox(height: 8),
                            Text(_isTakingPhoto ? "Mengambil..." : "Tap untuk ambil foto", style: const TextStyle(color: Colors.grey)),
                          ],
                        ),
                      )
                          : null,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // GPS Auto-Fetch Status
                  Row(
                    children: [
                      Icon(_isFetchingGps ? Icons.gps_not_fixed : Icons.gps_fixed, color: _isFetchingGps ? Colors.orange : SPOColors.accentGreen),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _isFetchingGps ? "Mencari sinyal GPS..." : "GPS Terkunci: $_gpsLocation",
                          style: TextStyle(color: _isFetchingGps ? Colors.orange : SPOColors.accentGreen, fontWeight: FontWeight.w600),
                        ),
                      ),
                      if (_isFetchingGps) const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // 3. SEARCH BAR
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: TextField(
                decoration: InputDecoration(
                  hintText: "Cari nama pekerja...",
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  filled: true,
                ),
                onChanged: _onSearchChanged,
              ),
            ),
          ),

          // 4. WORKER LIST HEADER
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Daftar Pekerja (${_filteredWorkers.length})", style: Theme.of(context).textTheme.titleMedium!.copyWith(fontWeight: FontWeight.bold)),
                  Text("Dipilih: ${_selectedWorkerIds.length}", style: TextStyle(color: accentColor, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),

          // 5. PAGINATED WORKER LIST (SliverList)
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                    (context, index) {
                  if (index == _displayedWorkers.length) {
                    return _isLoadingMore
                        ? const Padding(padding: EdgeInsets.all(16.0), child: Center(child: CircularProgressIndicator()))
                        : const SizedBox.shrink();
                  }

                  final worker = _displayedWorkers[index];
                  final isSelected = _selectedWorkerIds.contains(worker.id ?? 0);

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        if (isSelected) _selectedWorkerIds.remove(worker.id ?? 0);
                        else _selectedWorkerIds.add(worker.id ?? 0);
                      });
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isSelected ? accentColor.withOpacity(0.1) : Theme.of(context).colorScheme.surface.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isSelected ? accentColor : Colors.grey.withOpacity(0.2)),
                      ),
                      child: Row(
                        children: [
                          Icon(isSelected ? Icons.check_circle : Icons.circle_outlined, color: isSelected ? accentColor : Colors.grey),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              worker.name,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontSize: 16,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
                childCount: _displayedWorkers.length + (_isLoadingMore ? 1 : 0),
              ),
            ),
          ),

          // Bottom padding so list doesn't hide behind the bottom button
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),

      // 🚀 FIXED BOTTOM BUTTON
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: FilledButton(
            onPressed: stateButtonReady ? _saveAttendance : null,
            style: FilledButton.styleFrom(
              backgroundColor: accentColor,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: _isSaving || _isPushing
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(
              "Simpan Absen ${widget.isCheckIn ? 'Masuk' : 'Pulang'} (${_selectedWorkerIds.length})",
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  }
}