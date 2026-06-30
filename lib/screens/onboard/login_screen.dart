import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:crypto/crypto.dart';
import 'package:bcrypt/bcrypt.dart';
import '../../core/themes/spo_theme.dart';
import '../../services/api_service.dart';
import '../../services/storage_service.dart';
import '../../services/database_helper.dart';
import '../../data/models/user.dart';
import '../../data/models/employee.dart';
import '../../data/models/gang.dart';
import 'server_config_screen.dart';
import '../loading_screen.dart';
import '../dashboard/dashboard_main.dart';

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
        const SnackBar(
            content: Text('Username and password are required'),
            backgroundColor: Colors.red),
      );
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() => _isLoading = true);

    final isConfigured = await StorageService.isConfigured();
    if (!isConfigured) {
      if (mounted) {
        final result = await Navigator.push(context,
            MaterialPageRoute(builder: (_) => const ServerConfigScreen()));
        if (result != true) {
          setState(() => _isLoading = false);
          return;
        }
      }
    }

    final loginResult = await _api.login(username, password);
    debugPrint(
        '[SPO_DEBUG] LOGIN: 📥 Raw Server Response: ${loginResult['data']}');

    if (loginResult['success'] == true) {
      try {
        final data = loginResult['data'];
        final authData = data['auth'] ?? {};
        final resultData = data['result'] ?? {};

        final token = authData['token']?.toString() ?? '';
        final accessToken = authData['access_token']?.toString() ?? '';
        final userIdStr =
            (resultData['user_id'] ?? authData['user_id'])?.toString() ?? '0';

        debugPrint('[SPO_DEBUG] LOGIN: 🔑 Parsed Token: $token');
        debugPrint('[SPO_DEBUG] LOGIN: 🔑 Parsed UserId: $userIdStr');

        await StorageService.saveAuthTokens(
          token: token,
          accessToken: accessToken,
          userId: int.tryParse(userIdStr) ?? 0,
        );
        debugPrint('[SPO_DEBUG] Successfully saving login api data');
        await _pullInitialData();
      } catch (e, stack) {
        debugPrint('[SPO_DEBUG] LOGIN: ❌ Error parsing login data: $e');
        debugPrint('[SPO_DEBUG] LOGIN: Stack: $stack');
      }
    } else {
      final offlineSuccess = await _tryOfflineLogin(username, password);
      if (offlineSuccess && mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const DashboardScreen()),
              (route) => false,
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(loginResult['message'] ?? 'Login failed'),
              backgroundColor: Colors.red),
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
      MaterialPageRoute(
          builder: (_) =>
          const LoadingScreen(message: 'Downloading initial data...')),
    );

    try {
      debugPrint('[SPO_DEBUG] 2. Calling API pullData...');
      final pullResult = await _api.pullData();
      debugPrint(
          '[SPO_DEBUG] 3. API pullData finished. Success: ${pullResult['success']}');

      if (pullResult['success'] == true) {
        debugPrint('[SPO_DEBUG] 4. Extracting result payload...');
        final resultData = pullResult['data']?['result'];
        if (resultData == null) {
          debugPrint(
              '[SPO_DEBUG] WARNING: Server returned success, but result data is null!');
        } else {
          debugPrint('[SPO_DEBUG] 5. Saving data to local SQLite DB...');
          await _saveDataToLocal(resultData);
          debugPrint('[SPO_DEBUG] 6. Data saved successfully!');
        }
        if (mounted) {
          debugPrint('[SPO_DEBUG] 7. Navigating to Dashboard...');
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const DashboardScreen()),
                (route) => false,
          );
        }
      } else {
        debugPrint('[SPO_DEBUG] Pull FAILED: ${pullResult['message']}');
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const DashboardScreen()),
                (route) => false,
          );
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Failed to pull data, using offline mode'),
                backgroundColor: Colors.orange),
          );
        }
      }
    } catch (e, stacktrace) {
      debugPrint('[SPO_DEBUG] ❌ CRITICAL ERROR during pullInitialData: $e');
      debugPrint('[SPO_DEBUG] Stacktrace: $stacktrace');
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const DashboardScreen()),
              (route) => false,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _saveDataToLocal(Map<String, dynamic> data) async {
    debugPrint('[SPO_DEBUG] -> Entering _saveDataToLocal...');
    if (data == null || data is! Map) {
      debugPrint(
          '[SPO_DEBUG] -> Data is null or not a Map. Type: ${data.runtimeType}');
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

  //
  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    // (Keep your exact same UI build method from before, it is perfect)
    return Scaffold(
      body: LogoWithTitle(
        title: "Sign in",
        subText: "Welcome back! Sign in to continue to SPO Group Attendance",
        children: [
          Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _usernameController,
                  decoration: const InputDecoration(
                    hintText: "Username",
                    prefixIcon: Icon(
                      Icons.person_outline,
                    ),
                    filled: true,
                    border: OutlineInputBorder(
                      borderSide: BorderSide.none,
                      borderRadius: BorderRadius.all(Radius.circular(50)),
                    ),
                  ),
                  onSaved: (username) {},
                  onChanged: (value) {},
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return "Username is required";
                    }
                  },
                ),
                SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    hintText: "Password",
                    prefixIcon: Icon(
                      Icons.lock_outline,
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword
                          ? Icons.visibility_off
                          : Icons.visibility),
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        setState(() => _obscurePassword = !_obscurePassword);
                      },
                    ),
                    filled: true,
                    border: OutlineInputBorder(
                      borderSide: BorderSide.none,
                      borderRadius: BorderRadius.all(Radius.circular(50)),
                    ),
                  ),
                  onSaved: (username) {},
                  onChanged: (value) {},
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return "Password is required";
                    }
                  },
                ),
                SizedBox(height: 16),
                FilledButton(
                  onPressed: () {
                    if (_formKey.currentState!.validate() && !_isLoading) {
                      _handleLogin();
                    }
                  },
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                    shape: const StadiumBorder(),
                  ),
                  child: const Text("Sign in"),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class LogoWithTitle extends StatelessWidget {
  final String title, subText;
  final List<Widget> children;

  const LogoWithTitle(
      {Key? key,
        required this.title,
        this.subText = '',
        required this.children})
      : super(key: key);
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: LayoutBuilder(builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            children: [
              SizedBox(height: constraints.maxHeight * 0.1),
              Image.asset(
                'assets/logo_light.jpg',
                height: 100,
              ),
              SizedBox(
                height: constraints.maxHeight * 0.1,
                width: double.infinity,
              ),
              Text(
                title,
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall!
                    .copyWith(fontWeight: FontWeight.bold),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Text(
                  subText,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    height: 1.5,
                    color: Theme.of(context)
                        .textTheme
                        .bodyLarge!
                        .color!
                        .withOpacity(0.64),
                  ),
                ),
              ),
              ...children,
            ],
          ),
        );
      }),
    );
  }
}
