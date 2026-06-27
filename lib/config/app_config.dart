// import 'package:flutter/material.dart';
// import '../services/settings.dart';
//
// class AppConfig {
//   // Informasi Aplikasi
//   static const String appName = "SPO Attend";
//   static const String appVersion = "0.0.3";
//
//   // API - These are now dynamic and loaded from settings
//   static String _protocol = "https";
//   static bool _bypassSSLHandshake = true;
//   static String _baseDomain = "mobile.spogroup.co.id";
//
//   // Initialize settings - call this when app starts
//   static Future<void> initializeSettings() async {
//     try {
//       _protocol = await SettingsService.getProtocol();
//       _bypassSSLHandshake = await SettingsService.getBypassSSL();
//       _baseDomain = await SettingsService.getBaseDomain();
//     } catch (e) {
//       // Keep default values if settings fail to load
//       print('Failed to load settings: $e');
//     }
//   }
//
//   // Getters for dynamic values
//   static String get protocol => _protocol;
//   static bool get bypassSSLHandshake => _bypassSSLHandshake;
//   static String get baseDomain => _baseDomain;
//   static String get baseURL => "$_protocol://$_baseDomain";
//
//   // Static API endpoints
//   static const String loginAPI = '/auth/login';
//   static const String refreshAPI = '/auth/refresh';
//   static const String pullAPI = '/sync/pull';
//   static const String pushAPI = '/sync/push';
//
//   static const String dbName = "spo_v1_0.db";
//   static const int dbVersion = 1;
//
//   static const int maxOffline = 7; // hari
//
//   static const Duration requestTimeout = Duration(seconds: 10);
//
//   // SPO GROUP Brand Color Scheme
//   static const Color primaryColor = Color(0xFF1B5E20); // SPO Green (Darker)
//   static const Color primaryLightColor = Color(0xFF2E7D32); // SPO Green (Medium)
//   static const Color primaryDarkColor = Color(0xFF0D4A14); // SPO Green (Darkest)
//   static const Color accentColor = Color(0xFFD32F2F); // SPO Red (Vibrant)
//   static const Color accentLightColor = Color(0xFFE57373); // SPO Red (Light)
//   static const Color backgroundColor = Color(0xFFF8F9FA); // Light Gray Background
//   static const Color surfaceColor = Color(0xFFFFFFFF); // White
//   static const Color errorColor = Color(0xFFD32F2F); // SPO Red
//   static const Color warningColor = Color(0xFFFFA000); // Amber
//   static const Color successColor = Color(0xFF2E7D32); // SPO Green
//   static const Color textPrimaryColor = Color(0xFF1A1A1A); // Dark Gray
//   static const Color textSecondaryColor = Color(0xFF666666); // Medium Gray
//   static const Color dividerColor = Color(0xFFE0E0E0); // Light Gray
//
//   static const Color formPrimaryColor = Color(0xFF1B5E20); // SPO Green for primary elements
//   static const Color formAccentColor = Color(0xFFD32F2F); // SPO Red for accents
//   static const Color formNeutralColor = Color(0xFF666666); // Neutral gray for secondary elements
//
//   // Styling
//   static const double baseFontSize = 16; // 1 rem
//
//   static const double borderRadius = 8; // 0.5 rem
//   static const double borderRadiusMD = 16;
//   static const double borderRadiusLG = 30;
//
//   static const double borderCircle = 100;
//   static const double padding = 16; // 1 rem
//   static const double paddingSmall = padding * 0.875; // 0.875 rem
//   static const double paddingLarge = padding * 1.5; // 1.5 rem
//   static final BoxShadow shadow = BoxShadow(
//     color: Colors.black.withValues(alpha: 0.1),
//     blurRadius: 10,
//     offset: Offset(0, 4),
//   );
//
//   static const TextStyle headingStyle = TextStyle(
//     fontSize: 1.5 * baseFontSize, // 1.5 rem
//     fontWeight: FontWeight.bold,
//     color: textPrimaryColor,
//   );
//   static const TextStyle subHeadingStyle = TextStyle(
//     fontSize: 1.125 * baseFontSize, // 1.125 rem
//     fontWeight: FontWeight.w500,
//     color: textSecondaryColor,
//   );
//   static const TextStyle bodyStyle = TextStyle(
//     fontSize: baseFontSize, // 1 rem
//     fontWeight: FontWeight.normal,
//     color: textPrimaryColor,
//   );
//   static const TextStyle captionStyle = TextStyle(
//     fontSize: 0.875 * baseFontSize, // 0.875 rem
//     fontWeight: FontWeight.normal,
//     color: textSecondaryColor,
//   );
//
//   // button
//   static ButtonStyle primaryButtonStyle = ElevatedButton.styleFrom(
//     backgroundColor: primaryColor,
//     foregroundColor: Colors.white,
//     padding: EdgeInsets.symmetric(horizontal: padding, vertical: paddingSmall),
//     shape: RoundedRectangleBorder(
//       borderRadius: BorderRadius.circular(borderRadius),
//     ),
//     textStyle: bodyStyle,
//   );
//   static ButtonStyle secondaryButtonStyle = ElevatedButton.styleFrom(
//     backgroundColor: Colors.white,
//     foregroundColor: primaryColor,
//     padding: EdgeInsets.symmetric(horizontal: padding, vertical: paddingSmall),
//     shape: RoundedRectangleBorder(
//       borderRadius: BorderRadius.circular(borderRadius),
//     ),
//     textStyle: bodyStyle,
//   );
//   static ButtonStyle dangerButtonStyle = ElevatedButton.styleFrom(
//     backgroundColor: errorColor,
//     foregroundColor: Colors.white,
//     padding: EdgeInsets.symmetric(horizontal: padding, vertical: paddingSmall),
//     shape: RoundedRectangleBorder(
//       borderRadius: BorderRadius.circular(borderRadius),
//     ),
//     textStyle: bodyStyle,
//   );
//
//   // card
//   static BoxDecoration cardDecoration = BoxDecoration(
//       color: surfaceColor,
//       borderRadius: BorderRadius.circular(borderRadius),
//       boxShadow: [
//         shadow,
//       ]
//   );
//
//   // input
//   static InputDecoration inputDecoration = InputDecoration(
//     filled: true,
//     fillColor: backgroundColor,
//     border: OutlineInputBorder(
//       borderRadius: BorderRadius.circular(borderRadius),
//       borderSide: BorderSide(color: dividerColor),
//     ),
//     enabledBorder: OutlineInputBorder(
//       borderRadius: BorderRadius.circular(borderRadius),
//       borderSide: BorderSide(color: dividerColor),
//     ),
//     focusedBorder: OutlineInputBorder(
//       borderRadius: BorderRadius.circular(borderRadius),
//       borderSide: BorderSide(color: primaryColor, width: 2),
//     ),
//     errorBorder: OutlineInputBorder(
//       borderRadius: BorderRadius.circular(borderRadius),
//       borderSide: BorderSide(color: errorColor, width: 2),
//     ),
//     contentPadding: EdgeInsets.symmetric(horizontal: padding, vertical: paddingSmall),
//   );
// }