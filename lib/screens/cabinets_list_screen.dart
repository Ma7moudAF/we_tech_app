// شاشة ليستة الكبائن - اختصار دخول من غير ما تدور على الخريطة.
// كل صف فيه: دوسة عادية تفتح الكابينة، زرار لعرض بوكساتها، زرار لتحديد
// مكانها على الخريطة، وزرار للاتجاه إليها (خط سير + مسافة من موقعك الحالي).

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../models/cabinet_model.dart';
import '../services/firestore_service.dart';
import 'boxes_list_screen.dart';
import 'cabinet_floor_plan_screen.dart';
import 'map_screen.dart';

// منطقة الاختبار الحالية - نفس المتغير المستخدم في map_screen.dart
const String kCurrentAreaId = 'area_test';

class CabinetsListScreen extends StatefulWidget {
  const CabinetsListScreen({super.key});

  @override
  State<CabinetsListScreen> createState() => _CabinetsListScreenState();
}

class _CabinetsListScreenState extends State<CabinetsListScreen> {
  final _firestoreService = FirestoreService();
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openDetails(CabinetModel cabinet) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CabinetFloorPlanScreen(cabinet: cabinet),
      ),
    );
  }

  void _openBoxes(CabinetModel cabinet) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BoxesListScreen(
          areaId: cabinet.areaId,
          parentCabinetId: cabinet.id,
          title: 'بوكسات ${cabinet.name}',
        ),
      ),
    );
  }

  void _showOnMap(CabinetModel cabinet) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MapScreen(
          focusPoint: LatLng(cabinet.latitude, cabinet.longitude),
          focusLabel: cabinet.name,
        ),
      ),
    );
  }

  void _navigateTo(CabinetModel cabinet) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MapScreen(
          focusPoint: LatLng(cabinet.latitude, cabinet.longitude),
          focusLabel: cabinet.name,
          autoNavigate: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الكبائن')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'دور باسم الكابينة أو كودها',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _query = v.trim()),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<CabinetModel>>(
              stream: _firestoreService.streamCabinets(kCurrentAreaId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                // مؤقت للتشخيص: لو فيه مشكلة صلاحيات (Security Rules) أو أي
                // خطأ تاني في القراءة، هيبان هنا واضح بدل ما يتبلع بصمت
                // ويظهر "مفيش كبائن" وكأنها مفيش بيانات فعلًا.
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'حصل خطأ أثناء قراءة الكبائن:\n${snapshot.error}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  );
                }
                final cabinets = snapshot.data ?? [];
                final filtered = _query.isEmpty
                    ? cabinets
                    : cabinets
                    .where((c) =>
                c.name.contains(_query) || c.code.contains(_query))
                    .toList();

                if (filtered.isEmpty) {
                  return const Center(child: Text('مفيش كبائن'));
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final cabinet = filtered[index];
                    return ListTile(
                      onTap: () => _openDetails(cabinet),
                      leading: Icon(
                        cabinet.type == CabinetType.portBox
                            ? Icons.electrical_services
                            : Icons.hub,
                        color: cabinet.type == CabinetType.portBox
                            ? Colors.blue
                            : Colors.orange,
                      ),
                      title: Text(cabinet.name),
                      subtitle: Text('${cabinet.code} · ${cabinet.type.labelAr}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.inventory_2_outlined),
                            tooltip: 'عرض بوكساتها',
                            onPressed: () => _openBoxes(cabinet),
                          ),
                          IconButton(
                            icon: const Icon(Icons.location_on_outlined),
                            tooltip: 'حدد مكانها على الخريطة',
                            onPressed: () => _showOnMap(cabinet),
                          ),
                          IconButton(
                            icon: const Icon(Icons.directions),
                            tooltip: 'اتجه إليها',
                            onPressed: () => _navigateTo(cabinet),
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