import 'package:flutter/material.dart';
import 'server_config_screen.dart';

class OnboardScreen extends StatelessWidget {
  const OnboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // backgroundColor: Theme.of(context),
      body: SafeArea(
        child: Center(
          child: Column(
            children: [
              const Spacer(flex: 2),
              // Image.network("https://i.postimg.cc/Qtxc8xgv/welcome-image.png"),
              const Spacer(flex: 3),
              Text(
                "Welcome to our SPO Group \nattendance app",
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall!
                    .copyWith(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Text(
                "Easily report your attendance status \nwhenever you're online or offline.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context)
                      .textTheme
                      .bodyLarge!
                      .color!
                      .withOpacity(0.64),
                ),
              ),
              const Spacer(flex: 3),
              TextButton.icon(
                onPressed: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const ServerConfigScreen()));
                },
                icon: const Text("Skip"),
                label: const Icon(
                  Icons.arrow_forward_ios,
                  size: 20,
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
