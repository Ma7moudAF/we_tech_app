import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../services/location_service.dart';

class LocationPickerMap extends StatefulWidget {
  final double initialLatitude;
  final double initialLongitude;
  final ValueChanged<LatLng> onLocationChanged;

  const LocationPickerMap({
    super.key,
    required this.initialLatitude,
    required this.initialLongitude,
    required this.onLocationChanged,
  });

  @override
  State<LocationPickerMap> createState() => _LocationPickerMapState();
}

class _LocationPickerMapState extends State<LocationPickerMap> {
  final MapController _mapController = MapController();

  late LatLng _selectedLocation;

  bool _isLocating = false;

  static const LatLng _defaultLocation = LatLng(
    30.0444,
    31.2357,
  );

  bool _isValidCoordinate(double lat, double lng) {
    return lat.isFinite &&
        lng.isFinite &&
        lat >= -90 &&
        lat <= 90 &&
        lng >= -180 &&
        lng <= 180;
  }

  @override
  void initState() {
    super.initState();

    if (_isValidCoordinate(
      widget.initialLatitude,
      widget.initialLongitude,
    )) {
      _selectedLocation = LatLng(
        widget.initialLatitude,
        widget.initialLongitude,
      );
    } else {
      _selectedLocation = _defaultLocation;
    }
  }

  void _selectLocation(LatLng location) {
    if (!_isValidCoordinate(
      location.latitude,
      location.longitude,
    )) {
      return;
    }

    setState(() {
      _selectedLocation = location;
    });

    widget.onLocationChanged(location);
  }

  Future<void> _goToMyLocation() async {
    if (_isLocating) return;

    setState(() {
      _isLocating = true;
    });

    try {
      final position = await LocationService.getCurrentLocation();

      final location = LatLng(
        position.latitude,
        position.longitude,
      );

      if (!_isValidCoordinate(
        location.latitude,
        location.longitude,
      )) {
        throw Exception('الموقع الحالي غير صالح');
      }

      _selectLocation(location);

      // نحاول تحريك الخريطة بعد ما تكون جاهزة.
      _mapController.move(location, 17);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceFirst('Exception: ', ''),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLocating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 350,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _selectedLocation,
                initialZoom: 15,
                minZoom: 3,
                maxZoom: 19,
                onTap: (_, point) {
                  _selectLocation(point);
                },
              ),
              children: [
                TileLayer(
                  urlTemplate:
                  'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.wetech.we_tech_app',
                ),

                MarkerLayer(
                  markers: [
                    Marker(
                      point: _selectedLocation,
                      width: 50,
                      height: 50,
                      child: const Icon(
                        Icons.location_pin,
                        size: 50,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),

                const RichAttributionWidget(
                  attributions: [
                    TextSourceAttribution(
                      'OpenStreetMap contributors',
                    ),
                  ],
                ),
              ],
            ),

            Positioned(
              left: 12,
              bottom: 12,
              child: FloatingActionButton.small(
                heroTag: null,
                backgroundColor: Colors.white,
                foregroundColor: Colors.teal,
                onPressed:
                _isLocating ? null : _goToMyLocation,
                child: _isLocating
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                )
                    : const Icon(Icons.my_location),
              ),
            ),

            Positioned(
              top: 12,
              right: 12,
              child: Material(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(8),
                child: const Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  child: Text(
                    'اضغط على الخريطة لتحديد المكان',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}