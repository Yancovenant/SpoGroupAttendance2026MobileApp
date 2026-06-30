import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/models/gang.dart';
import '../../data/models/user.dart';
import '../../data/models/attendance_record.dart';

import '../../core/themes/spo_theme.dart';

import '../../services/storage_service.dart';
import '../../services/database_helper.dart';
import '../../services/api_service.dart';

import 'bottom_nav.dart';
import 'home_screen.dart';
import 'profile_screen.dart';
import 'notification_screen.dart';
import 'gang_selection_sheet.dart';
import '../attendance/attendance_main.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;

  /// On Load
  // Header
  Gang? _selectedGang;
  bool _isSupervisor = false;
  String _userName = "User";

  // Body
  final ApiService _api = ApiService();
  bool _isSyncing = false;
  bool _isPushing = false;

  // Bottom Nav
  bool _isCheckInDone = false;
  bool _isCheckOutDone = false;

  // Midnight Auto-Reset Logic
  Future<void> _checkTodayAttendanceStatus() async {
    if (_selectedGang == null) return;

    final db = await DatabaseHelper.instance.database;
    final today = DateTime.now().toUtc().toIso8601String().substring(0, 10);

    // Check specifically for 'in' record
    final inRecords = await db.query(
      'attendance_records',
      where: 'date LIKE ? AND gang_id = ? AND type = ?',
      whereArgs: ['$today%', _selectedGang!.id, 'in'],
    );

    // Check specifically for 'out' record
    final outRecords = await db.query(
      'attendance_records',
      where: 'date LIKE ? AND gang_id = ? AND type = ?',
      whereArgs: ['$today%', _selectedGang!.id, 'out'],
    );

    if (mounted) {
      setState(() {
        _isCheckInDone = inRecords.isNotEmpty;
        _isCheckOutDone = outRecords.isNotEmpty;
      });
    }
  }

  // For Supervisor Only
  List<Gang> _availableGangs = [];

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    final tokens = await StorageService.getAuthTokens();
    if (tokens == null) return;

    final db = await DatabaseHelper.instance.database;
    final userRes = await db
        .query('users', where: 'id = ?', whereArgs: [tokens['user_id']]);

    if (userRes.isNotEmpty) {
      final user = User.fromMap(userRes.first);
      _userName = user.username ?? "User";

      // Determine if Supervisor (e.g., username contains supervisor/admin or no specific gang assigned)
      _isSupervisor = user.id == 1;

      if (_isSupervisor) {
        final gangs = await db.query('gangs', orderBy: 'gang_code ASC');
        _availableGangs = gangs.map((g) => Gang.fromMap(g)).toList();

        // Load last selected gang from prefs
        final prefs = await SharedPreferences.getInstance();
        final savedGangId = prefs.getInt('selected_gang_id');
        if (savedGangId != null) {
          _selectedGang =
              _availableGangs.firstWhereOrNull((g) => g.id == savedGangId);
        }
        if (_selectedGang == null && _availableGangs.isNotEmpty) {
          _selectedGang = _availableGangs.first;
        }
      } else {
        // Regular Mandor
        if (user.gangId != null) {
          final gangRes = await db
              .query('gangs', where: 'id = ?', whereArgs: [user.gangId]);
          if (gangRes.isNotEmpty) _selectedGang = Gang.fromMap(gangRes.first);
        }
      }

      //   await _loadGangStats();
      await _checkTodayAttendanceStatus();

      if (mounted) setState(() {});
    }
  }

  Future<void> _pullData() async {
    HapticFeedback.mediumImpact();
    setState(() => _isSyncing = true);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Menarik data terbaru...'),
        backgroundColor: SPOColors.accentGreen,
        behavior: SnackBarBehavior.floating));

    final result = await _api.pullData();
    if (result['success'] == true && result['data']?['result'] != null) {
      await DatabaseHelper.instance.savePulledData(result['data']['result']);
      await _loadDashboardData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Data berhasil diperbarui!'),
            backgroundColor: SPOColors.accentGreen,
            behavior: SnackBarBehavior.floating));
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Gagal: ${result['message']}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating));
      }
    }
    if (mounted) setState(() => _isSyncing = false);
  }

  Future<void> _pushData() async {
    HapticFeedback.mediumImpact();
    setState(() => _isPushing = true);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Mengunggah antrian absensi...'),
        backgroundColor: SPOColors.accentGreen,
        behavior: SnackBarBehavior.floating));

    final db = await DatabaseHelper.instance.database;
    final pendingRecords = await db.query(
      'attendance_records',
      where: 'sync_status = ?',
      whereArgs: [SyncStatus.pending.index],
    );

    if (pendingRecords.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Tidak ada data antrian untuk diunggah.'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating));
        setState(() => _isPushing = false);
      }
      return;
    }

    int successCount = 0;
    int failCount = 0;

    for (var recordMap in pendingRecords) {
      final record = AttendanceRecord.fromMap(recordMap);
      final result = await _api.pushAttendance(record);

      if (result['success'] == true) {
        await db.update(
          'attendance_records',
          {'sync_status': SyncStatus.synced.index},
          where: 'record_id = ?',
          whereArgs: [record.recordId],
        );
        successCount++;
      } else {
        failCount++;
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Selesai: $successCount berhasil, $failCount gagal.'),
          backgroundColor: failCount > 0 ? Colors.orange : SPOColors.accentGreen,
          behavior: SnackBarBehavior.floating));
      setState(() => _isPushing = false);
    }
  }

  void _startAttendance() async {
    HapticFeedback.heavyImpact();
    if (_selectedGang == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Pilih Gang terlebih dahulu!'),
          backgroundColor: Colors.red));
      return;
    }
    if (_isCheckInDone && _isCheckOutDone) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Anda sudah melakukan absensi masuk dan pulang hari ini.'),
          backgroundColor: Colors.orange));
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AttendanceScreen(
          isCheckIn: !_isCheckInDone,
          gangId: _selectedGang!.id!,
          gangCode: _selectedGang!.gangCode ?? '',
        ),
      ),
    ).then((_) {
      _checkTodayAttendanceStatus();
    });
  }

  void _showGangSelectionSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => GangSelectionSheet(
        allGangs: _availableGangs,
        currentGang: _selectedGang,
        onSelected: (gang) async {
          setState(() => _selectedGang = gang);
          final prefs = await SharedPreferences.getInstance();
          await prefs.setInt('selected_gang_id', gang.id!);
          await _checkTodayAttendanceStatus();
          setState(() {});
        },
      ),
    );
  }

  void _handleNotificationTap() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationScreen()));
  }

  void _handleProfileAvatarTap() {
    setState(() {
      _currentIndex = 1; // Switch to Profile Tab
    });
  }

  void _handleNavTap(int index) {
    if (index == 1) {
      _startAttendance();
      return;
    }
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Setup Header Color
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      body: _currentIndex == 0
          ? HomeScreen(
        selectedGang: _selectedGang,
        userName: _userName,
        isSupervisor: _isSupervisor,
        isSyncing: _isSyncing,
        isPushing: _isPushing,
        onPullData: _pullData,
        onPushData: _pushData,
        onGangChipTap: _isSupervisor ? _showGangSelectionSheet : null,
        onNotificationTap: _handleNotificationTap,
        onProfileAvatarTap: _handleProfileAvatarTap,
      )
          : ProfileScreen(
        employeeName: _userName,
        employeeGangCode: _selectedGang?.gangCode ?? "-",
      ),
      bottomNavigationBar: BottomNav(
        currentIndex: _currentIndex,
        onTap: _handleNavTap,
        startAttendance: _startAttendance,
        isCheckInDone: _isCheckInDone,
        isCheckOutDone: _isCheckOutDone,
      ),
    );
  }
}

// Extension for firstWhereOrNull since it's not built-in without collection package
extension IterableExtension<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T) test) {
    for (var element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}
