import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/models/gang.dart';

import '../../core/themes/spo_theme.dart';

import '../settings/settings_screen.dart';
import '../history/history_screen.dart';

import '../../main.dart'; // For themeNotifier
import '../../widgets/extension_context.dart';

class HomeScreen extends StatelessWidget {
  // Header
  final Gang? selectedGang; //_selectedGang
  final String userName; // _userName
  final bool isSupervisor; // _isSupervisor
  final VoidCallback? onGangChipTap;
  final VoidCallback? onNotificationTap;
  final VoidCallback? onProfileAvatarTap;

  // Body
  final bool isSyncing;
  final bool isPushing;
  final VoidCallback? onPullData;
  final VoidCallback? onPushData;

  const HomeScreen({
    super.key,
    this.selectedGang,
    required this.userName,
    required this.isSupervisor,
    required this.isSyncing,
    required this.isPushing,
    this.onPullData,
    this.onPushData,
    this.onGangChipTap,
    this.onNotificationTap,
    this.onProfileAvatarTap,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          HeaderHome(
            selectedGang: selectedGang,
            userName: userName,
            isSupervisor: isSupervisor,
            onGangChipTap: onGangChipTap,
            onNotificationTap: onNotificationTap,
            onProfileAvatarTap: onProfileAvatarTap,
          ),
          BodyHome(
            isSyncing: isSyncing,
            isPushing: isPushing,
            onPullData: onPullData,
            onPushData: onPushData,
          ),
        ],
      ),
    );
  }
}

class HeaderHome extends StatelessWidget {
  final Gang? selectedGang;
  final String userName;
  final bool isSupervisor;
  final VoidCallback? onGangChipTap;
  final VoidCallback? onNotificationTap;
  final VoidCallback? onProfileAvatarTap;

  const HeaderHome({
    super.key,
    this.selectedGang,
    required this.userName,
    required this.isSupervisor,
    this.onGangChipTap,
    this.onNotificationTap,
    this.onProfileAvatarTap,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: -30,
            right: -20,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),
          Positioned(
            top: 40,
            left: -40,
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF58A7A0).withValues(alpha: 0.12),
              ),
            ),
          ),
          Positioned(
            top: 80,
            right: 40,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFE3562A).withValues(alpha: 0.08),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: <Widget>[
                    GestureDetector(
                      onTap: isSupervisor ? onGangChipTap : null,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                            color: const Color(0x33FFFFFF),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                                color: Colors.white.withValues(alpha: 0.12))),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.groups,
                              color: Theme.of(context).colorScheme.primary,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Gang ${selectedGang?.gangCode ?? '-'}',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (isSupervisor) ...[
                              const SizedBox(width: 4),
                              Icon(Icons.arrow_drop_down, color: Theme.of(context).colorScheme.primary, size: 20),
                            ]
                          ],
                        ),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: Icon(
                        Icons.notifications_none,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      onPressed: onNotificationTap,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    GestureDetector(
                      onTap: onProfileAvatarTap,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              SPOColors.limeGreen,
                              SPOColors.accentGreen,
                            ],
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 27,
                          backgroundColor:
                          Theme.of(context).colorScheme.surface,
                          child: Text(
                            userName.isNotEmpty
                                ? userName[0].toUpperCase()
                                : 'U',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          "Selamat Datang,",
                          style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.6),
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          userName.toUpperCase(),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                        if (isSupervisor)
                          const Text(
                            "Mode Supervisor",
                            style: TextStyle(
                              color: Colors.orangeAccent,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class BodyHome extends StatelessWidget {
  final bool isSyncing;
  final bool isPushing;
  final VoidCallback? onPullData;
  final VoidCallback? onPushData;

  const BodyHome({
    super.key,
    required this.isSyncing,
    required this.isPushing,
    this.onPullData,
    this.onPushData,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(
        bottom: 48,
        top: 12,
        left: 12,
        right: 12,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(36)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(24),
            ),
            padding: const EdgeInsetsGeometry.all(12),
            child: SectionActionSync(
              isSyncing: isSyncing,
              isPushing: isPushing,
              onPullData: onPullData,
              onPushData: onPushData,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            child: const SectionInformational(),
          ),
          const SizedBox(height: 32),
          Center(
            child: Column(
              children: [
                Text(
                  "Mode terang atau gelap nih?",
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium!
                      .copyWith(fontWeight: FontWeight.bold),
                ),
                Text(
                  "Nyala atau matiin switch sesuai keinginan",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    height: 1.5,
                    color: Theme.of(context)
                        .textTheme
                        .bodySmall!
                        .color!
                        .withOpacity(0.64),
                  ),
                ),
                const SizedBox(height: 16),
                const SectionThemeToggle(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SectionActionSync extends StatelessWidget {
  final bool isSyncing;
  final bool isPushing;
  final VoidCallback? onPullData;
  final VoidCallback? onPushData;

  const SectionActionSync({
    super.key,
    required this.isSyncing,
    required this.isPushing,
    this.onPullData,
    this.onPushData,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      spacing: 12,
      children: [
        ButtonCardLabel(
          icon: Icons.cloud_download_outlined,
          title: "Pull data",
          onTap: isSyncing ? null : onPullData,
        ),
        ButtonCardLabel(
          icon: Icons.cloud_upload_outlined,
          title: "Push data",
          onTap: isPushing ? null : onPushData,
        ),
      ],
    );
  }
}

class ButtonCardLabel extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback? onTap;

  const ButtonCardLabel({
    super.key,
    required this.icon,
    required this.title,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      spacing: 4,
      children: [
        ElevatedButton(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
            elevation: 1,
            backgroundColor:
            Theme.of(context).colorScheme.surfaceContainerLowest,
            minimumSize: const Size(0, 60),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Icon(icon),
        ),
        Text(
          title,
          style: Theme.of(context).textTheme.labelMedium!,
        ),
      ],
    );
  }
}

class SectionInformational extends StatelessWidget {
  const SectionInformational({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Laporan & Manajemen",
          style: Theme.of(context)
              .textTheme
              .bodyMedium!
              .copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Row(
          spacing: 12,
          children: [
            Expanded(
              child: InformationalButtonLabel(
                icon: Icons.history_toggle_off,
                title: "Riwayat",
                subText: "Lihat catatan absensi",
                color: Colors.purpleAccent,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const HistoryScreen()),
                  );
                },
              ),
            ),
            Expanded(
              child: InformationalButtonLabel(
                icon: Icons.warning_amber_rounded,
                title: "Konflik",
                subText: "Resolusi data bentrok",
                color: Colors.redAccent,
                onTap: () => context.showLockedFeatureSheet("Resolusi Konflik"),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          spacing: 12,
          children: [
            Expanded(
              child: InformationalButtonLabel(
                icon: Icons.bar_chart_outlined,
                title: "Statistik",
                subText: "Performa bulanan",
                color: Colors.tealAccent,
                onTap: () =>
                    context.showLockedFeatureSheet("Statistik & Laporan"),
              ),
            ),
            Expanded(
              child: InformationalButtonLabel(
                icon: Icons.settings_outlined,
                title: "Settings",
                subText: "Konfigurasi api",
                color: Colors.grey,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class InformationalButtonLabel extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subText;
  final Color color;
  final VoidCallback? onTap;

  const InformationalButtonLabel({
    super.key,
    required this.icon,
    required this.title,
    required this.subText,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        elevation: 0,
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
        // minimumSize: const Size(0, 60),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsetsGeometry.all(12),
        alignment: Alignment.centerLeft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon),
              ),
              const Icon(Icons.arrow_right_outlined),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: Theme.of(context)
                .textTheme
                .labelMedium!
                .copyWith(fontWeight: FontWeight.bold),
          ),
          Text(
            subText,
            style: TextStyle(
              height: 1.5,
              color: Theme.of(context)
                  .textTheme
                  .labelSmall!
                  .color!
                  .withOpacity(0.64),
            ),
          ),
        ],
      ),
    );
  }
}

class SectionThemeToggle extends StatelessWidget {
  const SectionThemeToggle({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final bool isSwitchOn = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: () async {
        final bool newSwitchState = !isSwitchOn;

        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isDarkMode', newSwitchState);

        themeNotifier.value = newSwitchState ? ThemeMode.dark : ThemeMode.light;
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            alignment: Alignment.topCenter,
            children: [
              isSwitchOn
                  ? const SizedBox()
                  : Container(
                height: 90,
                width: 90,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [
                    Colors.black12,
                    Colors.black54,
                  ]),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black26,
                        offset: Offset(20, 0),
                        blurRadius: 60),
                    BoxShadow(
                        color: Colors.white10,
                        offset: Offset(-1, 0),
                        blurRadius: 60),
                  ],
                  borderRadius:
                  BorderRadius.vertical(top: Radius.circular(32)),
                ),
              ),
              Container(
                height: 100,
                width: 90,
                margin: const EdgeInsets.only(top: 15, right: 5),
                foregroundDecoration: BoxDecoration(
                  color: isSwitchOn
                      ? Theme.of(context).scaffoldBackgroundColor
                      : Colors.transparent,
                  borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(30)),
                ),
                decoration: BoxDecoration(
                    gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Theme.of(context).scaffoldBackgroundColor,
                          Theme.of(context).primaryColor,
                        ]),
                    boxShadow: const [
                      BoxShadow(
                          color: Colors.white24,
                          offset: Offset(-1, 0),
                          blurRadius: 0),
                      BoxShadow(
                          color: Colors.black87,
                          offset: Offset(3, 0),
                          blurRadius: 0)
                    ],
                    borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(30))),
              ),
            ],
          ),
          //// ****** Bottom Part ****** ///////
          Stack(
            alignment: Alignment.bottomCenter,
            children: [
              isSwitchOn
                  ? Container(
                height: 90,
                width: 90,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [
                    Colors.black,
                    Colors.green,
                  ]),
                  boxShadow: [
                    const BoxShadow(
                        color: Colors.black87,
                        offset: Offset(-15, 1),
                        blurRadius: 40),
                    BoxShadow(
                        color: Colors.green.withOpacity(0.5),
                        offset: const Offset(10, 2),
                        blurRadius: 50)
                  ],
                  borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(30)),
                ),
              )
                  : const SizedBox(),
              Container(
                height: 100,
                width: 90,
                margin: const EdgeInsets.only(bottom: 10, right: 5),
                foregroundDecoration: BoxDecoration(
                  color: isSwitchOn
                      ? Colors.transparent
                      : Theme.of(context).scaffoldBackgroundColor,
                  borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(30)),
                ),
                decoration: BoxDecoration(
                    gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Theme.of(context).scaffoldBackgroundColor,
                          Theme.of(context).primaryColor,
                          Theme.of(context).primaryColor,
                          Theme.of(context).primaryColor,
                          Theme.of(context).primaryColor,
                        ]),
                    boxShadow: const [
                      BoxShadow(
                          color: Colors.white24,
                          offset: Offset(-1, 0),
                          blurRadius: 0),
                      BoxShadow(
                          color: Colors.black87,
                          offset: Offset(3, 0),
                          blurRadius: 0)
                    ],
                    borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(30))),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
