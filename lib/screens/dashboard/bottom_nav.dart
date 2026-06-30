import 'package:flutter/material.dart';

class BottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final VoidCallback startAttendance;
  final bool isCheckInDone;
  final bool isCheckOutDone;

  const BottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.startAttendance,
    required this.isCheckInDone,
    required this.isCheckOutDone,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDisabled = isCheckInDone && isCheckOutDone;
    final bool isCheckOutNext = isCheckInDone && !isCheckOutDone;

    IconData attendanceIcon = isDisabled
        ? Icons.check_circle_outline
        : (isCheckOutNext ? Icons.exit_to_app : Icons.fingerprint);

    List<Color> outerAttendanceColor = isDisabled
        ? [Colors.grey.shade400, Colors.grey.shade600]
        : (isCheckOutNext
        ? [
      Theme.of(context).colorScheme.tertiaryContainer,
      Theme.of(context).colorScheme.onTertiaryContainer,
    ]
        : [
      Theme.of(context).colorScheme.primaryContainer,
      Theme.of(context).colorScheme.onPrimaryContainer,
    ]);

    List<Color> innerAttendanceColor = isDisabled
        ? [Colors.grey.shade600, Colors.grey.shade400]
        : (isCheckOutNext
        ? [
      Theme.of(context).colorScheme.onTertiaryContainer,
      Theme.of(context).colorScheme.tertiaryContainer,
    ]
        : [
      Theme.of(context).colorScheme.onPrimaryContainer,
      Theme.of(context).colorScheme.primaryContainer,
    ]);

    String label = isDisabled ? "Selesai" : (isCheckOutNext ? "Check-Out" : "Check-In");

    return BottomNavigationBar(
      currentIndex: currentIndex,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
      type: BottomNavigationBarType.fixed,
      onTap: onTap,
      items: <BottomNavigationBarItem>[
        const BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
        BottomNavigationBarItem(
          icon: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              Icon(attendanceIcon, color: Colors.transparent),
              Positioned(
                top: -40,
                child: Material(
                  type: MaterialType.transparency,
                  child: InkResponse(
                    containedInkWell:
                    false, // CRITICAL: This allows the ripple to "leak" out of the container
                    highlightShape:
                    BoxShape.rectangle, // Matches your rect shape
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      startAttendance();
                    },
                    child: Opacity(
                      opacity: isDisabled ? 0.5 : 1.0,
                      child: Container(
                        padding: const EdgeInsetsGeometry.all(8),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerLowest,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Container(
                            padding: const EdgeInsetsGeometry.all(6),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: outerAttendanceColor,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: innerAttendanceColor,
                                ),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              child: Icon(
                                Icons.fingerprint,
                                color: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerLowest,
                              ),
                            )),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          label: label,
        ),
        const BottomNavigationBarItem(
            icon: Icon(Icons.person), label: 'Profile'),
      ],
    );
  }
}
