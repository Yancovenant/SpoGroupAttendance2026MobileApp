import 'package:flutter/material.dart';
import '../../data/models/gang.dart';
import '../../core/themes/spo_theme.dart';

class GangSelectionSheet extends StatefulWidget {
  final List<Gang> allGangs;
  final Gang? currentGang;
  final Function(Gang) onSelected;

  const GangSelectionSheet({
    super.key,
    required this.allGangs,
    this.currentGang,
    required this.onSelected,
  });

  @override
  State<GangSelectionSheet> createState() => _GangSelectionSheetState();
}

class _GangSelectionSheetState extends State<GangSelectionSheet> {
  final TextEditingController _searchController = TextEditingController();

  List<Gang> _filteredGangs = [];
  List<Gang> _displayedGangs = [];
  final int _pageSize = 20;
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _filteredGangs = widget.allGangs;
    _loadMore();
  }

  void _loadMore() {
    if (_isLoadingMore) return;
    if (_displayedGangs.length >= _filteredGangs.length) return;

    setState(() => _isLoadingMore = true);

    // Simulate slight delay for smooth pagination UI
    Future.delayed(const Duration(milliseconds: 300), () {
      final start = _displayedGangs.length;
      final end = (_displayedGangs.length + _pageSize).clamp(0, _filteredGangs.length);

      _displayedGangs.addAll(_filteredGangs.sublist(start, end));
      if (mounted) {
        setState(() => _isLoadingMore = false);
      }
    });
  }

  void _onSearchChanged(String query) {
    setState(() {
      _filteredGangs = widget.allGangs.where((g) {
        final code = g.gangCode?.toLowerCase() ?? '';
        final name = g.name.toLowerCase();
        return code.contains(query.toLowerCase()) || name.contains(query.toLowerCase());
      }).toList();
      _displayedGangs = [];
      _loadMore();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        // Attach pagination listener to the sheet's scroll controller
        scrollController.addListener(() {
          if (scrollController.position.pixels >= scrollController.position.maxScrollExtent - 200) {
            _loadMore();
          }
        });

        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Drag Handle
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 12),
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text("Pilih Gang", style: Theme.of(context).textTheme.titleLarge),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    hintText: "Cari kode atau nama gang...",
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: _displayedGangs.length + (_isLoadingMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == _displayedGangs.length) {
                      return const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    final gang = _displayedGangs[index];
                    final isSelected = widget.currentGang?.id == gang.id;
                    return ListTile(
                      leading: Icon(Icons.groups, color: isSelected ? SPOColors.limeGreen : null),
                      title: Text(gang.gangCode ?? 'Gang ${gang.id}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(gang.name),
                      trailing: isSelected ? const Icon(Icons.check_circle, color: SPOColors.limeGreen) : null,
                      onTap: () {
                        widget.onSelected(gang);
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}