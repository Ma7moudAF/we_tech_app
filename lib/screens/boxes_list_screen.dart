// شاشة ليستة البوكسات - إما كل بوكسات كابينة معينة (parentCabinetId محدد)
// أو كل بوكسات المنطقة (parentCabinetId = null). كل صف فيه زرار لتحديد
// مكانه على الخريطة، وزرار للاتجاه إليه (خط سير + مسافة من موقعك الحالي).

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../models/box_model.dart';
import '../services/firestore_service.dart';
import 'box_details_screen.dart';
import 'map_screen.dart';

class BoxesListScreen extends StatefulWidget {
  final String areaId;
  final String? parentCabinetId; // null = كل بوكسات المنطقة
  final String title;

  const BoxesListScreen({
    super.key,
    required this.areaId,
    required this.title,
    this.parentCabinetId,
  });

  @override
  State<BoxesListScreen> createState() => _BoxesListScreenState();
}

class _BoxesListScreenState extends State<BoxesListScreen> {
  final _firestoreService = FirestoreService();
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openDetails(BoxModel box) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => BoxDetailsScreen(box: box)),
    );
  }

  void _showOnMap(BoxModel box) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MapScreen(
          focusPoint: LatLng(box.latitude, box.longitude),
          focusLabel: box.name,
        ),
      ),
    );
  }

  void _navigateTo(BoxModel box) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MapScreen(
          focusPoint: LatLng(box.latitude, box.longitude),
          focusLabel: box.name,
          autoNavigate: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stream = widget.parentCabinetId != null
        ? _firestoreService.streamBoxesForCabinet(widget.parentCabinetId!)
        : _firestoreService.streamBoxes(widget.areaId);

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'دور باسم البوكس',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _query = v.trim()),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<BoxModel>>(
              stream: stream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final boxes = snapshot.data ?? [];
                final filtered = _query.isEmpty
                    ? boxes
                    : boxes
                    .where((b) => b.name.contains(_query))
                    .toList();

                if (filtered.isEmpty) {
                  return const Center(child: Text('مفيش بوكسات'));
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final box = filtered[index];
                    return ListTile(
                      onTap: () => _openDetails(box),
                      leading: const Icon(Icons.inventory_2, color: Colors.green),
                      title: Text(box.name),
                      subtitle: Text(
                        'مكان ${box.positionInBlock} · ${box.terminalsCount} ترمنال',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.location_on_outlined),
                            tooltip: 'حدد مكانه على الخريطة',
                            onPressed: () => _showOnMap(box),
                          ),
                          IconButton(
                            icon: const Icon(Icons.directions),
                            tooltip: 'اتجه إليه',
                            onPressed: () => _navigateTo(box),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}