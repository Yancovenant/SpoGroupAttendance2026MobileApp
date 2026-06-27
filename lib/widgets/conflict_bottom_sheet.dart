import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/themes/spo_theme.dart';

class ConflictResolutionSheet extends StatefulWidget {
  final List<Map<String, dynamic>> conflicts;
  final Function(List<String> resolvedWorkerIds) onResolve;

  const ConflictResolutionSheet({
    super.key,
    required this.conflicts,
    required this.onResolve,
  });

  @override
  State<ConflictResolutionSheet> createState() => _ConflictResolutionSheetState();
}

class _ConflictResolutionSheetState extends State<ConflictResolutionSheet> {
  Set<String> _workersToKeep = {};
  Set<String> _workersToRemove = {}; // The ones the mandor unchecks

  @override
  void initState() {
    super.initState();
    // Initialize all conflicting workers as "selected" by default
    for (var conflict in widget.conflicts) {
      for (var entry in conflict['entries']) {
        _workersToKeep.add(entry['employee_id'].toString());
      }
    }
  }

  void _toggleWorker(String empId) {
    HapticFeedback.mediumImpact(); // Heavy haptic for conflict resolution
    setState(() {
      if (_workersToKeep.contains(empId)) {
        _workersToKeep.remove(empId);
        _workersToRemove.add(empId);
      } else {
        _workersToKeep.add(empId);
        _workersToRemove.remove(empId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF112211), // Darker glass background
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        border: Border(top: BorderSide(color: SPOColors.conflictRed, width: 2)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 20),
            width: 40, height: 5,
            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              children: [
                const Icon(Icons.error_outline, color: SPOColors.conflictRed, size: 48),
                const SizedBox(height: 12),
                const Text("Konflik Absensi Terdeteksi", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text(
                  "Pekerja di bawah ini sudah diabsen oleh gang lain atau memiliki konflik data. Silakan hapus centang pada pekerja yang tidak ikut hari ini.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),

          // List of Conflicting Workers
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.4),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _workersToKeep.length + _workersToRemove.length,
              itemBuilder: (context, index) {
                final allIds = [..._workersToKeep, ..._workersToRemove];
                final empId = allIds[index];
                final isChecked = _workersToKeep.contains(empId);

                return ListTile(
                  leading: Icon(
                    isChecked ? Icons.check_circle : Icons.cancel,
                    color: isChecked ? SPOColors.limeGreen : SPOColors.conflictRed,
                  ),
                  title: Text("Pekerja ID: $empId", style: const TextStyle(color: Colors.white)),
                  subtitle: Text(
                    isChecked ? "Akan dikirim" : "Dibatalkan (Konflik)",
                    style: TextStyle(color: isChecked ? Colors.white54 : SPOColors.conflictRed.withOpacity(0.7)),
                  ),
                  trailing: Switch(
                    value: isChecked,
                    activeColor: SPOColors.limeGreen,
                    onChanged: (val) => _toggleWorker(empId),
                  ),
                );
              },
            ),
          ),

          // Action Button
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _workersToRemove.isEmpty ? Colors.grey : SPOColors.limeGreen,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: _workersToRemove.isEmpty
                    ? null
                    : () {
                  // Pass the removed IDs back to the Sync Engine to update local DB and retry
                  widget.onResolve(_workersToRemove.toList());
                  Navigator.pop(context);
                },
                child: Text(
                  _workersToRemove.isEmpty
                      ? "Pilih pekerja yang akan dibatalkan"
                      : "Hapus & Coba Sinkron Ulang (${_workersToRemove.length})",
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }
}