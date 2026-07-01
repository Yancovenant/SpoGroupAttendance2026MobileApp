import 'package:flutter/material.dart';

import '../../core/themes/spo_theme.dart';

class LockedFeatureSheet extends StatelessWidget {
  final String featureName;

  const LockedFeatureSheet({
    super.key,
    required this.featureName,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),

      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [

          Icon(
            Icons.lock_clock_rounded,
            size: 64,
            color: Theme.of(context).colorScheme.primary, // Uses your SPO Green theme
          ),
          const SizedBox(height: 16),

          Text(
            "Segera Hadir",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),

          // 🚀 Changed Description
          Text(
            "Fitur $featureName sedang dalam tahap pengembangan dan akan segera tersedia dalam pembaruan berikutnya.",
            textAlign: TextAlign.center,
            style: TextStyle(
              height: 1.5,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: SPOColors.limeGreen,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text(
                "Oke, Mengerti",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }
}