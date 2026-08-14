// شاشة الخريطة - بتعرض الكبائن والبوكسات كنقاط وبتتحدث لحظيًا من Firestore
// كل نقطة بتعرض اسمها تحت الأيقونة عشان تعرف تفرق بينهم من غير ما تدوس عليهم
//
// الشاشة تقدر تتفتح بوضعين إضافيين (جايين من شاشة ليستة الكبائن/البوكسات):
// - focusPoint فقط: بتفتح الخريطة مركزة على النقطة دي مباشرة
// - focusPoint + autoNavigate=true: بتلقط موقعك الحالي كمان وترسم خط مستقيم
//   (خط طيران، مش مسار على الطريق الفعلي) بينك وبين النقطة، مع حساب المسافة

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/box_model.dart';
import '../models/cabinet_model.dart';
import '../services/firestore_service.dart';
import '../services/location_service.dart';
import 'add_box_screen.dart';
import 'add_cabinet_screen.dart';
import 'box_details_screen.dart';
import 'cabinet_floor_plan_screen.dart';

// منطقة الاختبار الحالية - هنستبدلها بنظام اختيار منطقة حقيقي بعدين
const String kCurrentAreaId = 'area_test';

class MapScreen extends StatefulWidget {
  // لو اتحددت، الخريطة بتفتح مركزة على النقطة دي بدل المتوسط الافتراضي
  final LatLng? focusPoint;
  final String? focusLabel;
  // لو true (ولازم focusPoint يكون متحدد كمان)، بتلقط موقعك الحالي تلقائيًا
  // وترسم خط سير بينك وبين focusPoint مع حساب المسافة
  final bool autoNavigate;

  const MapScreen({
    super.key,
    this.focusPoint,
    this.focusLabel,
    this.autoNavigate = false,
  });

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final _firestoreService = FirestoreService();
  final _mapController = MapController();
  final _distanceCalculator = const Distance();
  bool _isSeeding = false;
  bool _isLocating = false;
  LatLng? _myLocation;

  // خط السير الحالي (لو موجود): النقطة اللي رايحلها + اسمها
  LatLng? _routeTarget;
  String? _routeTargetLabel;

  @override
  void initState() {
    super.initState();
    if (widget.autoNavigate && widget.focusPoint != null) {
      // نأجل التنفيذ لحد ما أول فريم يترسم عشان mapController يكون جاهز
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _startRouteTo(widget.focusPoint!, widget.focusLabel ?? 'الوجهة');
      });
    }
  }

  Future<void> _seedSampleData() async {
    setState(() => _isSeeding = true);
    try {
      await _firestoreService.seedSampleData(kCurrentAreaId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('اتضافت بيانات تجريبية بنجاح')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حصل خطأ: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSeeding = false);
    }
  }

  // بيلقط موقع الجهاز الحالي وبيحرك الخريطة عليه (من غير رسم خط سير)
  Future<void> _goToMyLocation() async {
    setState(() => _isLocating = true);
    try {
      final position = await LocationService.getCurrentLocation();
      final latLng = LatLng(position.latitude, position.longitude);
      setState(() => _myLocation = latLng);
      _mapController.move(latLng, 17);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  // بيلقط موقعك الحالي وبيرسم خط مستقيم (خط طيران) بينك وبين target، وبيحسب
  // المسافة بالكيلومتر. الخط مش مسار فعلي على الطريق - مجرد اتجاه ومسافة تقريبية.
  Future<void> _startRouteTo(LatLng target, String label) async {
    setState(() => _isLocating = true);
    try {
      final position = await LocationService.getCurrentLocation();
      final me = LatLng(position.latitude, position.longitude);
      setState(() {
        _myLocation = me;
        _routeTarget = target;
        _routeTargetLabel = label;
      });
      _focusCameraOnRoute(me, target);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  void _clearRoute() {
    setState(() {
      _routeTarget = null;
      _routeTargetLabel = null;
    });
  }

  // بيحرك الخريطة لمنتصف المسافة بين موقعك والوجهة، وبيختار مستوى زوم مناسب
  // حسب المسافة (كل ما المسافة أكبر كل ما نبعد الزووم) عشان الخط كله يبان
  double _zoomForDistanceKm(double km) {
    if (km < 1) return 16;
    if (km < 3) return 15;
    if (km < 8) return 13;
    if (km < 20) return 12;
    if (km < 60) return 10;
    return 8;
  }

  void _focusCameraOnRoute(LatLng me, LatLng target) {
    final km = _distanceCalculator.as(LengthUnit.Kilometer, me, target);
    final midpoint = LatLng(
      (me.latitude + target.latitude) / 2,
      (me.longitude + target.longitude) / 2,
    );
    _mapController.move(midpoint, _zoomForDistanceKm(km));
  }

  void _openCabinetDetails(CabinetModel cabinet) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CabinetFloorPlanScreen(cabinet: cabinet),
      ),
    );
  }

  void _openBoxDetails(BoxModel box) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BoxDetailsScreen(box: box),
      ),
    );
  }

  void _showAddMenu() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.electrical_services, color: Colors.blue),
              title: const Text('إضافة كابينة'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        const AddCabinetScreen(areaId: kCurrentAreaId),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.inventory_2, color: Colors.green),
              title: const Text('إضافة بوكس'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        const AddBoxScreen(areaId: kCurrentAreaId),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الخريطة'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'تسجيل خروج',
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddMenu,
        tooltip: 'إضافة كابينة أو بوكس',
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<List<CabinetModel>>(
        stream: _firestoreService.streamCabinets(kCurrentAreaId),
        builder: (context, cabinetsSnapshot) {
          return StreamBuilder<List<BoxModel>>(
            stream: _firestoreService.streamBoxes(kCurrentAreaId),
            builder: (context, boxesSnapshot) {
              final cabinets = cabinetsSnapshot.data ?? [];
              final boxes = boxesSnapshot.data ?? [];
              final isLoading = cabinetsSnapshot.connectionState ==
                      ConnectionState.waiting ||
                  boxesSnapshot.connectionState == ConnectionState.waiting;

              if (isLoading) {
                return const Center(child: CircularProgressIndicator());
              }

              if (cabinets.isEmpty && boxes.isEmpty) {
                return _buildEmptyState();
              }

              return _buildMap(cabinets, boxes);
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.map_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text(
              'مفيش كبائن ولا بوكسات مسجلة في المنطقة دي لسه',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _isSeeding ? null : _seedSampleData,
              icon: _isSeeding
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add_location_alt_outlined),
              label: const Text('أضف بيانات تجريبية'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _showAddMenu,
              icon: const Icon(Icons.add),
              label: const Text('أو ضيف كابينة/بوكس بنفسك'),
            ),
          ],
        ),
      ),
    );
  }

  // ماركر بيعرض أيقونة دايرية + اسم في شريحة تحتها. النقطة الجغرافية بتتحدد
  // عند نص الأيقونة بالظبط (alignment: topCenter) عشان الاسم يفضل تحتها من
  // غير ما يزحزح مكان النقطة الفعلي على الخريطة.
  Marker _buildLabeledMarker({
    required LatLng point,
    required IconData icon,
    required Color color,
    required String label,
    required double iconSize,
    required VoidCallback onTap,
  }) {
    return Marker(
      point: point,
      width: 100,
      height: iconSize + 26,
      alignment: Alignment.topCenter,
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: iconSize,
              height: iconSize,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: const [
                  BoxShadow(color: Colors.black26, blurRadius: 4),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: iconSize * 0.5),
            ),
            const SizedBox(height: 2),
            Container(
              constraints: const BoxConstraints(maxWidth: 100),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
                boxShadow: const [
                  BoxShadow(color: Colors.black26, blurRadius: 2),
                ],
              ),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMap(List<CabinetModel> cabinets, List<BoxModel> boxes) {
    final markers = <Marker>[
      ...cabinets.map((cabinet) => _buildLabeledMarker(
            point: LatLng(cabinet.latitude, cabinet.longitude),
            icon: cabinet.type == CabinetType.portBox
                ? Icons.electrical_services
                : Icons.hub,
            color: cabinet.type == CabinetType.portBox
                ? Colors.blue
                : Colors.orange,
            label: cabinet.name,
            iconSize: 44,
            onTap: () => _openCabinetDetails(cabinet),
          )),
      ...boxes.map((box) => _buildLabeledMarker(
            point: LatLng(box.latitude, box.longitude),
            icon: Icons.inventory_2,
            color: Colors.green,
            label: box.name,
            iconSize: 38,
            onTap: () => _openBoxDetails(box),
          )),
      if (_myLocation != null)
        Marker(
          point: _myLocation!,
          width: 26,
          height: 26,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.blueAccent,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: const [
                BoxShadow(color: Colors.black38, blurRadius: 6),
              ],
            ),
          ),
        ),
    ];

    // مركز الخريطة الافتراضي: النقطة المطلوب التركيز عليها لو موجودة،
    // وإلا متوسط كل النقاط عشان الفتح يكون مظبوط على المنطقة كلها
    LatLng initialCenter;
    double initialZoom;
    if (widget.focusPoint != null) {
      initialCenter = widget.focusPoint!;
      initialZoom = 17;
    } else {
      final allPoints = [
        ...cabinets.map((c) => LatLng(c.latitude, c.longitude)),
        ...boxes.map((b) => LatLng(b.latitude, b.longitude)),
      ];
      final centerLat =
          allPoints.map((p) => p.latitude).reduce((a, b) => a + b) /
              allPoints.length;
      final centerLng =
          allPoints.map((p) => p.longitude).reduce((a, b) => a + b) /
              allPoints.length;
      initialCenter = LatLng(centerLat, centerLng);
      initialZoom = 15;
    }

    final showRoute = _myLocation != null && _routeTarget != null;
    final routeDistanceKm = showRoute
        ? _distanceCalculator.as(LengthUnit.Kilometer, _myLocation!, _routeTarget!)
        : null;

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: initialCenter,
            initialZoom: initialZoom,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.wetech.we_tech_app',
            ),
            if (showRoute)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: [_myLocation!, _routeTarget!],
                    strokeWidth: 4,
                    color: Colors.deepPurple,
                  ),
                ],
              ),
            MarkerLayer(markers: markers),
            const RichAttributionWidget(
              attributions: [
                TextSourceAttribution('OpenStreetMap contributors'),
              ],
            ),
          ],
        ),
        // شريط المسافة وخط السير، بيظهر بس لما فيه مسار شغال
        if (showRoute)
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: Card(
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    const Icon(Icons.directions, color: Colors.deepPurple),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'المسافة إلى ${_routeTargetLabel ?? "الوجهة"}: '
                        '${routeDistanceKm!.toStringAsFixed(routeDistanceKm < 1 ? 3 : 1)} كم '
                        '(خط مستقيم)',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: 'إلغاء المسار',
                      onPressed: _clearRoute,
                    ),
                  ],
                ),
              ),
            ),
          ),
        Positioned(
          bottom: 16,
          left: 16,
          child: FloatingActionButton(
            heroTag: 'myLocationBtn',
            backgroundColor: Colors.white,
            onPressed: _isLocating ? null : _goToMyLocation,
            child: _isLocating
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.my_location, color: Colors.teal),
          ),
        ),
      ],
    );
  }
}
