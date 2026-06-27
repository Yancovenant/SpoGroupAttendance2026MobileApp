import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:crypto/crypto.dart';
import 'package:bcrypt/bcrypt.dart';
import '../core/themes/spo_theme.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../services/database_helper.dart';
import '../data/models/user.dart';
import '../data/models/employee.dart';
import '../data/models/gang.dart';
import 'server_config_screen.dart';
import 'loading_screen.dart';
import 'dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _api = ApiService();
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    if (username.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Username and password are required'), backgroundColor: Colors.red),
      );
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() => _isLoading = true);

    final isConfigured = await StorageService.isConfigured();
    if (!isConfigured) {
      if (mounted) {
        final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => const ServerConfigScreen()));
        if (result != true) {
          setState(() => _isLoading = false);
          return;
        }
      }
    }

    final loginResult = await _api.login(username, password);

    if (loginResult['success'] == true) {
      final authData = loginResult['data']['auth'];
      debugPrint('[SPO_DEBUG] Saving login result Api, $loginResult');
      await StorageService.saveAuthTokens(
        token: authData['token'].toString(),
        accessToken: authData['access_token'].toString(),
        userId: int.parse(loginResult['data']['result']['user_id'].toString())
      );
      debugPrint('[SPO_DEBUG] Successfully saving login api data');
      await _pullInitialData();
    } else {
      final offlineSuccess = await _tryOfflineLogin(username, password);
      if (offlineSuccess && mounted) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const DashboardScreen()));
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(loginResult['message'] ?? 'Login failed'), backgroundColor: Colors.red),
        );
      }
    }

    if (mounted) setState(() => _isLoading = false);
  }

  Future<bool> _tryOfflineLogin(String username, String password) async {
    final db = DatabaseHelper.instance;
    final user = await db.getUserByUsername(username);
    if (user == null) return false;

    if (user.isPasswordMd5) {
      final hash = md5.convert(utf8.encode(password)).toString();
      return hash == user.passwordHash;
    } else {
      try {
        return BCrypt.checkpw(password, user.passwordHash);
      } catch (e) {
        return false;
      }
    }
  }

  Future<void> _pullInitialData() async {
    debugPrint('[SPO_DEBUG] 1. Navigating to Loading Screen...');
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LoadingScreen(message: 'Downloading initial data...')),
    );

    try {
      debugPrint('[SPO_DEBUG] 2. Calling API pullData...');
      final pullResult = await _api.pullData();
      debugPrint('[SPO_DEBUG] 3. API pullData finished. Success: ${pullResult['success']}');

      if (pullResult['success'] == true) {
        debugPrint('[SPO_DEBUG] 4. Extracting result payload...');
        final resultData = pullResult['data']?['result'];
        if (resultData == null) {
          debugPrint('[SPO_DEBUG] WARNING: Server returned success, but result data is null!');
        } else {
          debugPrint('[SPO_DEBUG] 5. Saving data to local SQLite DB...');
          await _saveDataToLocal(resultData);
          debugPrint('[SPO_DEBUG] 6. Data saved successfully!');
        }
        if (mounted) {
          debugPrint('[SPO_DEBUG] 7. Navigating to Dashboard...');
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const DashboardScreen()));
        }
      } else {
        debugPrint('[SPO_DEBUG] Pull FAILED: ${pullResult['message']}');
        if (mounted) {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const DashboardScreen()));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to pull data, using offline mode'), backgroundColor: Colors.orange),
          );
        }
      }
    } catch (e, stacktrace) {
      debugPrint('[SPO_DEBUG] ❌ CRITICAL ERROR during pullInitialData: $e');
      debugPrint('[SPO_DEBUG] Stacktrace: $stacktrace');
      if (mounted) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const DashboardScreen()));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _saveDataToLocal(Map<String, dynamic> data) async {
    debugPrint('[SPO_DEBUG] -> Entering _saveDataToLocal...');
    if (data == null || data is! Map) {
      debugPrint('[SPO_DEBUG] -> Data is null or not a Map. Type: ${data.runtimeType}');
      return;
    }

    final db = DatabaseHelper.instance;

    try {
      await db.savePulledData(data);
      debugPrint('[SPO_DEBUG] -> _saveDataToLocal completed successfully.');
    } catch (e, stacktrace) {
      debugPrint('[SPO_DEBUG] ❌ ERROR in _saveDataToLocal: $e');
      debugPrint('[SPO_DEBUG] Stacktrace: $stacktrace');
      rethrow; // Let the parent catch block handle navigation
    }
  }

  @override
  Widget build(BuildContext context) {
    // (Keep your exact same UI build method from before, it is perfect)
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [SPOColors.primaryGreen, SPOColors.darkBg],
              ),
            ),
          ),
          Positioned(
            top: -50, right: -50,
            child: Container(
              width: 200, height: 200,
              decoration: BoxDecoration(shape: BoxShape.circle, color: SPOColors.accentGreen.withOpacity(0.3)),
              child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50), child: Container()),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 40),
                    const Text('Welcome Back', style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    Text('Sign in to continue to SPO Attendance', style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 16)),
                    const SizedBox(height: 50),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(color: Colors.white.withOpacity(0.15), width: 1.5),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 24, offset: const Offset(0, 12))],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Username', style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _usernameController,
                                style: const TextStyle(color: Colors.white, fontSize: 16),
                                decoration: InputDecoration(
                                  filled: true, fillColor: Colors.white.withOpacity(0.05),
                                  hintText: 'Enter your username', hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                                  prefixIcon: Icon(Icons.person_outline, color: Colors.white.withOpacity(0.5)),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
                                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
                                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: SPOColors.limeGreen, width: 2)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                ),
                              ),
                              const SizedBox(height: 24),
                              Text('Password', style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                style: const TextStyle(color: Colors.white, fontSize: 16),
                                decoration: InputDecoration(
                                  filled: true, fillColor: Colors.white.withOpacity(0.05),
                                  hintText: 'Enter your password', hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                                  prefixIcon: Icon(Icons.lock_outline, color: Colors.white.withOpacity(0.5)),
                                  suffixIcon: IconButton(
                                    icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: Colors.white.withOpacity(0.5)),
                                    onPressed: () { HapticFeedback.selectionClick(); setState(() => _obscurePassword = !_obscurePassword); },
                                  ),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
                                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
                                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: SPOColors.limeGreen, width: 2)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                ),
                              ),
                              const SizedBox(height: 32),
                              SizedBox(
                                width: double.infinity, height: 56,
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _handleLogin,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: SPOColors.limeGreen, foregroundColor: Colors.black, elevation: 0,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    disabledBackgroundColor: SPOColors.limeGreen.withOpacity(0.5),
                                  ),
                                  child: _isLoading
                                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5, valueColor: AlwaysStoppedAnimation<Color>(Colors.black)))
                                      : const Text('LOGIN', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                    TextButton.icon(
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const ServerConfigScreen()));
                      },
                      icon: Icon(Icons.settings_outlined, color: Colors.white.withOpacity(0.7), size: 20),
                      label: Text('Server Configuration', style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14)),
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
}