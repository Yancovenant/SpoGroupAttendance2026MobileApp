import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../services/storage_service.dart';

import '../settings/settings_screen.dart';
import '../settings/about_screen.dart';
import '../onboard/login_screen.dart';

class ProfileScreen extends StatefulWidget {
  final String employeeName;
  final String employeeGangCode;

  const ProfileScreen({super.key, required this.employeeName, required this.employeeGangCode});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _appVersion = "1.0.0";

  @override
  void initState() {
    super.initState();
    _loadAppVersion();
  }

  Future<void> _loadAppVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) setState(() => _appVersion = info.version);
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Keluar dari akunmu?"),
        content: const Text("Nanti ketemu lagi dilain waktu ya?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Gak jadi")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Iya, keluar")),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await StorageService.clearAuth();
      // Wipe the stack so they can't press "Back" to get to Dashboard
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
            (route) => false,
      );
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Profile"),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Container(
          padding: const EdgeInsetsGeometry.all(12),
          child: Column(
            spacing: 18,
            children: [
              Material(
                color: Theme.of(context).colorScheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(24),
                elevation: 0,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsetsGeometry.all(12),
                  child: ListTile(
                    contentPadding: const EdgeInsetsGeometry.all(0),
                    leading: Container(
                      width: 54.0,
                      height: 54.0,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      child: Center(
                        child: Text(
                          widget.employeeName.isNotEmpty
                              ? widget.employeeName[0].toUpperCase()
                              : 'U',
                          style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    title: Text(widget.employeeName),
                    subtitle: Text("Gang ${widget.employeeGangCode}"),
                  ),
                ),
              ),
              Material(
                color: Theme.of(context).colorScheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(24),
                clipBehavior: Clip.antiAlias,
                elevation: 0,
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.settings_outlined),
                      title: const Text("Pengaturan & Keamanan"),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const SettingsScreen()),
                        );
                      },
                    ),
                    const Divider(height: 0),
                    ListTile(
                      leading: const Icon(Icons.info_outline),
                      title: const Text("About"),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const AboutScreen()),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              Text(
                "Versi $_appVersion",
                style: Theme.of(context).textTheme.bodySmall!,
              ),
              const SizedBox(height: 48),
              FilledButton.icon(
                onPressed: _logout,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                  shape: const StadiumBorder(),
                ),
                icon: const Icon(Icons.logout),
                label: const Text("Keluar"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

