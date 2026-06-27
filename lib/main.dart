import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'data/models/user.dart';
import 'data/models/employee.dart';
import 'data/models/gang.dart';
import 'data/models/attendance_record.dart';
import 'core/themes/spo_theme.dart';
import 'screens/splash_screen.dart';
import 'services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.dark);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock orientation to Portrait for Field Workers
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  final prefs = await SharedPreferences.getInstance();
  final isDark = prefs.getBool('isDarkMode') ?? true;
  themeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;

  runApp(
    const SPOAttendanceApp(),
  );
}

class SPOAttendanceApp extends StatelessWidget {
  const SPOAttendanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, mode, child) {
        return MaterialApp(
          title: 'SPO Group Attendance',
          debugShowCheckedModeBanner: false,
          theme: spoLightTheme,
          darkTheme: spoDarkTheme,
          themeMode: mode,
          home: const SplashScreen(),
        );
      },
    );
  }
}