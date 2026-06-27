import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import '../core/themes/spo_theme.dart';
import '../services/api_service.dart';
import '../services/database_helper.dart';
import '../services/storage_service.dart';
import '../data/models/user.dart';
import '../data/models/gang.dart';
import '../main.dart'; // For themeNotifier
import 'server_config_screen.dart';
import 'attendance_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final ApiService _api = ApiService();

  String _userName = "User";
  int _workerCount = 0;
  bool _isSyncing = false;
  bool _isPushing = false;

  // Supervisor & Check-in Logic
  bool _isSupervisor = false;
  List<Gang> _availableGangs = [];
  Gang? _selectedGang;
  bool _isCheckedInToday = false;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    final tokens = await StorageService.getAuthTokens();
    if (tokens == null) return;

    final db = await DatabaseHelper.instance.database;
    final userRes = await db.query('users', where: 'id = ?', whereArgs: [tokens['user_id']]);

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
          _selectedGang = _availableGangs.firstWhereOrNull((g) => g.id == savedGangId);
        }
        if (_selectedGang == null && _availableGangs.isNotEmpty) {
          _selectedGang = _availableGangs.first;
        }
      } else {
        // Regular Mandor
        if (user.gangId != null) {
          final gangRes = await db.query('gangs', where: 'id = ?', whereArgs: [user.gangId]);
          if (gangRes.isNotEmpty) _selectedGang = Gang.fromMap(gangRes.first);
        }
      }

      await _loadGangStats();
      await _checkTodayAttendanceStatus();

      if (mounted) setState(() {});
    }
  }

  Future<void> _loadGangStats() async {
    if (_selectedGang == null) return;
    final db = await DatabaseHelper.instance.database;
    final countRes = await db.rawQuery(
        'SELECT COUNT(*) as cnt FROM employees WHERE gang_id = ? AND is_active = 1',
        [_selectedGang!.id]
    );
    _workerCount = Sqflite.firstIntValue(countRes) ?? 0;
  }

  // Midnight Auto-Reset Logic
  Future<void> _checkTodayAttendanceStatus() async {
    if (_selectedGang == null) return;

    final db = await DatabaseHelper.instance.database;
    final today = DateTime.now().toUtc().toIso8601String().substring(0, 10);

    final todayRecords = await db.query(
      'attendance_records',
      where: 'date LIKE ? AND gang_id = ?',
      whereArgs: ['$today%', _selectedGang!.id],
    );

    bool isCheckedIn = todayRecords.isNotEmpty;

    if (mounted) {
      setState(() {
        _isCheckedInToday = isCheckedIn;
      });
    }

    // final prefs = await SharedPreferences.getInstance();
    // final lastCheckInStr = prefs.getString('last_checkin_${_selectedGang!.id}');
    //
    // bool isCheckedIn = false;
    // if (lastCheckInStr != null) {
    //   final lastCheckIn = DateTime.parse(lastCheckInStr);
    //   final now = DateTime.now();
    //   final startOfDay = DateTime(now.year, now.month, now.day);
    //   if (lastCheckIn.isAfter(startOfDay)) {
    //     isCheckedIn = true;
    //   }
    // }
    // _isCheckedInToday = isCheckedIn;
  }

  Future<void> _pullData() async {
    HapticFeedback.mediumImpact();
    setState(() => _isSyncing = true);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Menarik data terbaru...'), backgroundColor: SPOColors.accentGreen, behavior: SnackBarBehavior.floating));

    final result = await _api.pullData();
    if (result['success'] == true && result['data']?['result'] != null) {
      await DatabaseHelper.instance.savePulledData(result['data']['result']);
      await _loadDashboardData();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Data berhasil diperbarui!'), backgroundColor: SPOColors.accentGreen, behavior: SnackBarBehavior.floating));
    } else {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal: ${result['message']}'), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating));
    }
    if (mounted) setState(() => _isSyncing = false);
  }
  // Future<void> _pushData() async {
  //   HapticFeedback.mediumImpact();
  //   setState(() => _isPushing = true);
  //   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mengunggah data absensi ke server...'), backgroundColor: SPOColors.accentGreen, behavior: SnackBarBehavior.floating));
  //
  //   final result = await _api.pushAttendance();
  //   if (result['success'] == true && result['data']?['result'] != null) {
  //
  //
  //     if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Data berhasil di unggah ke server!'), backgroundColor: SPOColors.accentGreen, behavior: SnackBarBehavior.floating));
  //   } else {
  //     if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal: ${result['message']}'), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating));
  //   }
  //   if (mounted) setState(() => _isPushing = false);
  // }

  void _startAttendance() async {
    HapticFeedback.heavyImpact();
    if (_selectedGang == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pilih Gang terlebih dahulu!'), backgroundColor: Colors.red));
      return;
    }

    // Navigate to the full Attendance Flow (Camera, GPS, Checklist)
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AttendanceScreen(
          gangId: _selectedGang!.id!,
          gangCode: _selectedGang!.gangCode ?? '',
        ),
      ),
    );
  }

  void _showPremiumFeatureSheet(String featureName) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.1)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.withOpacity(0.3), borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 24),
            const Icon(Icons.workspace_premium, size: 64, color: Colors.orangeAccent),
            const SizedBox(height: 16),
            Text("Fitur Premium", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
            const SizedBox(height: 8),
            Text("Akses ke $featureName dan laporan lengkap tersedia dalam versi Premium SPO Group.", textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7))),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: SPOColors.limeGreen, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                onPressed: () => Navigator.pop(context),
                child: const Text("Mengerti", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );
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
          // 1. Theme-Aware Background
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: isDark
                    ? [SPOColors.primaryGreen.withOpacity(0.3), SPOColors.darkBg]
                    : [SPOColors.primaryGreen.withOpacity(0.05), SPOColors.lightBg],
              ),
            ),
          ),
          Positioned(top: -100, right: -100, child: _buildOrb(SPOColors.accentGreen, 300, isDark)),
          Positioned(bottom: 50, left: -100, child: _buildOrb(SPOColors.limeGreen, 400, isDark)),

          // 2. Main Scrollable Content
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _buildHeader(textColor, subtextColor)),
              SliverToBoxAdapter(child: _buildSupervisorSelector(textColor, subtextColor)),
              SliverToBoxAdapter(child: _buildActionGrid(textColor, subtextColor)),
              SliverToBoxAdapter(child: _buildThemeToggleSection()),
              const SliverToBoxAdapter(child: SizedBox(height: 160)),
            ],
          ),

          // 3. Bottom Navbar Overlay
          Positioned(left: 0, right: 0, bottom: 0, child: _buildBottomNavbar(isDark)),
        ],
      ),
    );
  }

  Widget _buildHeader(Color textColor, Color subtextColor) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Selamat Datang,", style: TextStyle(color: subtextColor, fontSize: 14)),
                  Text(_userName.toUpperCase(), style: TextStyle(color: textColor, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                  if (_isSupervisor) const Text("Mode Supervisor", style: TextStyle(color: Colors.orangeAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface.withOpacity(0.1), shape: BoxShape.circle, border: Border.all(color: Theme.of(context).dividerColor)),
                child: Icon(Icons.notifications_none, color: textColor, size: 24),
              )
            ],
          ),
          const SizedBox(height: 24),
          // Stats Card
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface.withOpacity(isDark(context) ? 0.1 : 0.8),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.2), width: 1.5),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: SPOColors.limeGreen.withOpacity(0.2), borderRadius: BorderRadius.circular(16)),
                      child: const Icon(Icons.groups, color: SPOColors.limeGreen, size: 32),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Gang ${_selectedGang?.gangCode ?? '-'}", style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text("$_workerCount Pekerja Aktif Terdaftar", style: TextStyle(color: subtextColor, fontSize: 13)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSupervisorSelector(Color textColor, Color subtextColor) {
    if (!_isSupervisor || _availableGangs.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface.withOpacity(isDark(context) ? 0.1 : 0.8),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: SPOColors.limeGreen.withOpacity(0.3)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<Gang>(
                value: _selectedGang,
                isExpanded: true,
                dropdownColor: Theme.of(context).colorScheme.surface,
                icon: const Icon(Icons.arrow_drop_down_circle, color: SPOColors.limeGreen),
                items: _availableGangs.map((gang) {
                  return DropdownMenuItem(
                    value: gang,
                    child: Row(
                      children: [
                        const Icon(Icons.groups, color: SPOColors.limeGreen, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text("Gang ${gang.gangCode}", style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                              Text(gang.name ?? '', style: TextStyle(color: subtextColor, fontSize: 11)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (newGang) async {
                  setState(() => _selectedGang = newGang);
                  if (newGang != null) {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setInt('selected_gang_id', newGang.id!);
                    await _loadGangStats();
                    await _checkTodayAttendanceStatus();
                    setState(() {});
                  }
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionGrid(Color textColor, Color subtextColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Sinkronisasi & Data", style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildActionCard(Icons.cloud_download_outlined, "Pull Data", "Tarik data terbaru", Colors.lightBlueAccent, _isSyncing ? null : _pullData)),
              const SizedBox(width: 16),
              Expanded(child: _buildActionCard(Icons.cloud_upload_outlined, "Push Data", "Kirim antrian offline", Colors.orangeAccent, () { /* TODO */ })),
            ],
          ),
          const SizedBox(height: 24),
          Text("Laporan & Manajemen", style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildActionCard(Icons.history_toggle_off, "Riwayat", "Lihat catatan absensi", Colors.purpleAccent, () => _showPremiumFeatureSheet("Riwayat Absensi"))),
              const SizedBox(width: 16),
              Expanded(child: _buildActionCard(Icons.warning_amber_rounded, "Konflik", "Resolusi data bentrok", Colors.redAccent, () => _showPremiumFeatureSheet("Resolusi Konflik"))),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(child: _buildActionCard(Icons.settings_outlined, "Server", "Konfigurasi API", Colors.grey, () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const ServerConfigScreen()));
              })),
              const SizedBox(width: 16),
              Expanded(child: _buildActionCard(Icons.bar_chart_outlined, "Statistik", "Performa bulanan", Colors.tealAccent, () => _showPremiumFeatureSheet("Statistik & Laporan"))),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildThemeToggleSection() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = Theme.of(context).colorScheme.onSurface;
    final subtextColor = Theme.of(context).colorScheme.onSurface.withOpacity(0.6);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface.withOpacity(isDarkMode ? 0.1 : 0.8),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.1)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: (isDarkMode ? Colors.indigo : Colors.orange).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                      isDarkMode ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
                      color: isDarkMode ? Colors.indigoAccent : Colors.orangeAccent,
                      size: 24
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Tampilan Aplikasi", style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold)),
                      Text(isDarkMode ? "Mode Gelap (Night Shift)" : "Mode Terang (Daylight)", style: TextStyle(color: subtextColor, fontSize: 12)),
                    ],
                  ),
                ),
                Switch.adaptive(
                  value: isDarkMode,
                  onChanged: (val) async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setBool('isDarkMode', val);
                    themeNotifier.value = val ? ThemeMode.dark : ThemeMode.light;
                  },
                  activeColor: SPOColors.limeGreen,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Helper to avoid writing Theme.of(context).brightness == Brightness.dark everywhere
  bool isDark(BuildContext context) => Theme.of(context).brightness == Brightness.dark;

  Widget _buildActionCard(IconData icon, String title, String subtitle, Color color, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(16),
            height: 120,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface.withOpacity(isDark(context) ? 0.05 : 0.6),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                  child: Icon(icon, color: color, size: 24),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5), fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavbar(bool isDarkMode) {
    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              height: 85,
              decoration: BoxDecoration(
                color: (isDarkMode ? Colors.black : Colors.white).withOpacity(0.8),
                border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1), width: 1)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildNavItem(Icons.home_filled, "Home", true, () {}, isDarkMode),
                  const SizedBox(width: 80),
                  _buildNavItem(Icons.person_outline, "Profile", false, () {}, isDarkMode),
                ],
              ),
            ),
          ),
        ),

        // Floating Center Button (Auto-Reset at Midnight)
        Positioned(
          top: -35,
          child: GestureDetector(
            onTap: _startAttendance,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 75,
                  height: 75,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: _isCheckedInToday
                          ? [Colors.grey.shade700, Colors.grey.shade900]
                          : [SPOColors.limeGreen, SPOColors.accentGreen],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _isCheckedInToday ? Colors.black.withOpacity(0.3) : SPOColors.limeGreen.withOpacity(0.4),
                        blurRadius: 15, spreadRadius: 2, offset: const Offset(0, 8),
                      )
                    ],
                    border: Border.all(color: Colors.white.withOpacity(0.2), width: 2),
                  ),
                  child: Icon(
                    _isCheckedInToday ? Icons.check_circle_outline : Icons.fingerprint,
                    color: Colors.white, size: 40,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _isCheckedInToday ? "Sudah Check-In" : "Mulai Absensi",
                  style: TextStyle(
                      color: _isCheckedInToday ? Theme.of(context).colorScheme.onSurface.withOpacity(0.7) : SPOColors.limeGreen,
                      fontSize: 12, fontWeight: FontWeight.bold,
                      shadows: [Shadow(blurRadius: 4, color: Colors.black.withOpacity(0.5))]
                  ),
                )
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNavItem(IconData icon, String label, bool isActive, VoidCallback onTap, bool isDarkMode) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: isActive ? SPOColors.limeGreen : (isDarkMode ? Colors.white54 : Colors.grey), size: 28),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: isActive ? SPOColors.limeGreen : (isDarkMode ? Colors.white54 : Colors.grey), fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildOrb(Color color, double size, bool isDarkMode) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color.withOpacity(isDarkMode ? 0.2 : 0.05)),
      child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80), child: Container()),
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