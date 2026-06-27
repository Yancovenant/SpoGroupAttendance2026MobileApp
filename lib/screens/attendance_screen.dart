import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sqflite/sqflite.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../core/themes/spo_theme.dart';
import '../services/database_helper.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../data/models/user.dart';
import '../data/models/employee.dart';
import '../data/models/gang.dart';
import '../data/models/attendance_record.dart';
import 'dashboard_screen.dart';
import 'package:permission_handler/permission_handler.dart';

class AttendanceScreen extends ConsumerStatefulWidget {
  final int gangId;
  final String gangCode;

  const AttendanceScreen({super.key, required this.gangId, required this.gangCode});

  @override
  ConsumerState<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends ConsumerState<AttendanceScreen> {
  final _api = ApiService();
  final _uuid = const Uuid();

  // State variables
  bool _isCheckIn = true;
  String? _gpsLocation;
  File? _groupPhoto;
  List<int> _selectedWorkerIds = [];
  List<Employee> _workers = [];
  String _searchQuery = '';
  bool _isLoading = false;
  bool _isGettingLocation = false;
  bool _isTakingPhoto = false;
  bool _isSaving = false;
  bool _isPushing = false;

  @override
  void initState() {
    super.initState();
    _loadAttendanceData();
    _loadWorkers();
  }

  Future<void> _loadAttendanceData() async {
    final db = await DatabaseHelper.instance.database;
    final today = DateTime.now().toUtc().toIso8601String().substring(0, 10);

    final inRecord = await db.query('attendance_records', where: 'date LIKE ? AND type = ? AND gang_id = ?', whereArgs: ['$today%', 'in', widget.gangId]);
    final outRecord = await db.query('attendance_records', where: 'date LIKE ? AND type = ? AND gang_id = ?', whereArgs: ['$today%', 'out', widget.gangId]);

    // Determine if we need to create "in" or "out"
    if (inRecord.isEmpty && outRecord.isEmpty) {
      setState(() => _isCheckIn = true);
    } else if (inRecord.isNotEmpty && outRecord.isEmpty) {
      setState(() => _isCheckIn = false);
    } else {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text("Attendance already completed for today!"),
                backgroundColor: SPOColors.conflictRed,
                behavior: SnackBarBehavior.floating,
            )
        );
        Navigator.pop(context);
      }
    }
  }

  Future<void> _loadWorkers() async {
    final db = await DatabaseHelper.instance.database;

    // Get only workers from the same gang
    final workers = await db.query(
      'employees',
      where: 'gang_id = ? AND is_active = 1',
      whereArgs: [widget.gangId],
      orderBy: 'name ASC',
    );

    setState(() {
      _workers = workers.map((e) => Employee.fromMap(e)).toList();
    });
  }

  Future<void> _getLocation() async {
    if (_isGettingLocation) return;

    var status = await Permission.location.status;
    if (!status.isGranted) {
      status = await Permission.location.request();
      if (!status.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Izin Lokasi ditolak. Harap izinkan di Pengaturan."),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return; // Stop execution if permission is denied
      }
    }

    setState(() => _isGettingLocation = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Fetching GPS location..."),
        backgroundColor: SPOColors.accentGreen,
        behavior: SnackBarBehavior.floating,
      ),
    );

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) throw Exception('Location services are disabled.');

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) throw Exception('Location permissions are denied');
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _gpsLocation = '${position.latitude}, ${position.longitude}';
        _isGettingLocation = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("GPS location captured successfully!"),
          backgroundColor: SPOColors.accentGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      setState(() => _isGettingLocation = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to get location: ${e.toString()}"),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _takePhoto() async {
    if (_isTakingPhoto) return;

    var status = await Permission.camera.status;
    if (!status.isGranted) {
      status = await Permission.camera.request();
      if (!status.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Izin Kamera ditolak. Harap izinkan di Pengaturan."),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return; // Stop execution if permission is denied
      }
    }

    setState(() => _isTakingPhoto = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Preparing camera..."),
        backgroundColor: SPOColors.accentGreen,
        behavior: SnackBarBehavior.floating,
      ),
    );

    try {
      final pickedFile = await ImagePicker().pickImage(
        source: ImageSource.camera,
        imageQuality: 50,
        maxWidth: 1280,
      );

      if (pickedFile != null) {
        setState(() {
          _groupPhoto = File(pickedFile.path);
          _isTakingPhoto = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Group photo captured successfully!"),
            backgroundColor: SPOColors.accentGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        setState(() => _isTakingPhoto = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Photo capture cancelled"),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      setState(() => _isTakingPhoto = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to capture photo: ${e.toString()}"),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _saveAttendance() async {
    if (_isLoading || _isSaving) return;
    if (_groupPhoto == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please take a group photo first"),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (_gpsLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please capture GPS location first"),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (_selectedWorkerIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please select at least one worker"),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Saving attendance data..."),
        backgroundColor: SPOColors.accentGreen,
        behavior: SnackBarBehavior.floating,
      ),
    );

    try {
      // Get current user ID
      final tokens = await StorageService.getAuthTokens();
      final userId = tokens?['user_id'] ?? 0;

      // Prepare attendance data
      final attendance = AttendanceRecord(
        recordId: _uuid.v4(),
        date: DateTime.now(),
        userId: userId,
        gangId: widget.gangId,
        type: _isCheckIn ? 'in' : 'out',
        groupPhotoPath: _groupPhoto?.path,
        latitude: double.tryParse(_gpsLocation!.split(', ')[0]),
        longitude: double.tryParse(_gpsLocation!.split(', ')[1]),
        presentWorkerIds: _selectedWorkerIds.map((id) => id.toString()).toList(),
        syncStatus: SyncStatus.pending,
        conflictWorkerIds: [],
      );

      // Save to local database
      final db = await DatabaseHelper.instance.database;
      await db.insert('attendance_records', attendance.toMap());

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Attendance saved locally!"),
          backgroundColor: SPOColors.accentGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );

      // Try to push data to server
      setState(() => _isPushing = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Attempting to sync with server..."),
          backgroundColor: SPOColors.accentGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );

      final pushResult = await _api.pushAttendance(attendance);
      if (pushResult['success'] == true) {
        // Update local record to synced
        final db = await DatabaseHelper.instance.database;
        await db.update(
          'attendance_records',
          {'sync_status': SyncStatus.synced.index},
          where: 'record_id = ?',
          whereArgs: [attendance.recordId],
        );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Attendance synced with server!"),
            backgroundColor: SPOColors.accentGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Sync failed: ${pushResult['message']}"),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      // Return to dashboard
      setState(() => _isPushing = false);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const DashboardScreen()),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error saving attendance: ${e.toString()}"),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = Theme.of(context).colorScheme.onSurface;
    final subtextColor = Theme.of(context).colorScheme.onSurface.withOpacity(0.6);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          // Background Gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [SPOColors.primaryGreen.withOpacity(0.3), SPOColors.darkBg]
                    : [SPOColors.primaryGreen.withOpacity(0.05), SPOColors.lightBg],
              ),
            ),
          ),
          Positioned(top: -100, right: -100, child: _buildOrb(SPOColors.accentGreen, 300, isDark)),
          Positioned(bottom: 50, left: -100, child: _buildOrb(SPOColors.limeGreen, 400, isDark)),

          // Main Content
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _buildHeader(isDark, textColor, subtextColor)),
              SliverToBoxAdapter(child: _buildPhotoSection()),
              SliverToBoxAdapter(child: _buildGpsSection()),
              SliverToBoxAdapter(child: _buildWorkerSearch()),
              SliverToBoxAdapter(child: _buildWorkerList()),
              SliverToBoxAdapter(child: _buildSaveButton()),
              const SliverToBoxAdapter(child: SizedBox(height: 40)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isDark, Color textColor, Color subtextColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Absensi ${_isCheckIn ? "Masuk" : "Pulang"}", style: TextStyle(color: textColor, fontSize: 24, fontWeight: FontWeight.bold)),
                  Text("Gang ${widget.gangCode}", style: TextStyle(color: subtextColor, fontSize: 16)),
                  Text("Hari Ini", style: TextStyle(color: subtextColor, fontSize: 14)),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (isDark ? Colors.white : Colors.black).withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white24),
                ),
                child: Icon(Icons.notifications_none, color: textColor, size: 24),
              )
            ],
          ),
          const SizedBox(height: 20),
          Text(
            "Harap lakukan absensi harian untuk ${_isCheckIn ? "masuk" : "pulang"} sesuai aturan perusahaan",
            style: TextStyle(color: subtextColor, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Foto Kelompok", style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Container(
            height: 200,
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.2)),
            ),
            child: _groupPhoto != null
                ? Image.file(_groupPhoto!, fit: BoxFit.cover)
                : const Center(
              child: Text("Foto akan muncul di sini", style: TextStyle(color: Colors.white54)),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  _groupPhoto == null
                      ? "Harap ambil foto kelompok untuk memulai absensi"
                      : "Foto kelompok sudah diambil",
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
                ),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _groupPhoto == null ? SPOColors.accentGreen : SPOColors.conflictRed,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: Icon(_isTakingPhoto ? Icons.hourglass_empty : Icons.camera_alt_outlined),
                label: Text(_isTakingPhoto ? "Mengambil..." : "Ambil Foto"),
                onPressed: _isTakingPhoto ? null : _takePhoto,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGpsSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Lokasi GPS", style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Container(
            height: 80,
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.2)),
            ),
            child: _gpsLocation != null
                ? Center(
              child: Text(
                _gpsLocation!,
                style: TextStyle(color: Colors.white, fontSize: 16),
                textAlign: TextAlign.center,
              ),
            )
                : const Center(
              child: Text("Lokasi akan muncul di sini", style: TextStyle(color: Colors.white54)),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  _gpsLocation == null
                      ? "Harap ambil lokasi GPS untuk memulai absensi"
                      : "Lokasi GPS sudah diambil",
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
                ),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _gpsLocation == null ? SPOColors.accentGreen : SPOColors.conflictRed,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: Icon(_isGettingLocation ? Icons.hourglass_empty : Icons.location_on_outlined),
                label: Text(_isGettingLocation ? "Mengambil..." : "Ambil Lokasi"),
                onPressed: _isGettingLocation ? null : _getLocation,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWorkerSearch() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: TextField(
        decoration: InputDecoration(
          hintText: "Cari pekerja...",
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: SPOColors.limeGreen)),
          filled: true,
          fillColor: Theme.of(context).colorScheme.surface.withOpacity(0.1),
        ),
        onChanged: (value) => setState(() => _searchQuery = value),
      ),
    );
  }

  Widget _buildWorkerList() {
    final filteredWorkers = _workers.where((w) => w.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Daftar Pekerja (${filteredWorkers.length})", style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          // ✅ Fixed Syntax Error using Ternary Operator
          filteredWorkers.isEmpty
              ? const Center(child: Padding(padding: EdgeInsets.all(20.0), child: Text("Tidak ada pekerja ditemukan", style: TextStyle(color: Colors.grey))))
              : ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filteredWorkers.length,
            itemBuilder: (context, index) {
              final worker = filteredWorkers[index];
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
                    color: isSelected ? SPOColors.limeGreen.withOpacity(0.1) : Theme.of(context).colorScheme.surface.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isSelected ? SPOColors.limeGreen : Colors.grey.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(isSelected ? Icons.check_circle : Icons.circle_outlined, color: isSelected ? SPOColors.limeGreen : Colors.grey),
                      const SizedBox(width: 12),
                      Expanded(child: Text(worker.name, style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.w500))),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: SizedBox(
        height: 60,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: SPOColors.limeGreen,
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            disabledBackgroundColor: SPOColors.limeGreen.withOpacity(0.5),
          ),
          onPressed: _isSaving || _isPushing ? null : _saveAttendance,
          child: _isSaving || _isPushing
              ? const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
          )
              : const Text("Simpan Absensi", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  Widget _buildOrb(Color color, double size, bool isDark) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color.withOpacity(isDark ? 0.2 : 0.05)),
      child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80), child: Container()),
    );
  }
}