import 'package:flutter/material.dart';

import '../widgets/location_picker_map.dart';

class MoveLocationScreen extends StatefulWidget {
  final String title;
  final double initialLatitude;
  final double initialLongitude;
  final Future<void> Function(double latitude, double longitude) onSave;

  const MoveLocationScreen({
    super.key,
    required this.title,
    required this.initialLatitude,
    required this.initialLongitude,
    required this.onSave,
  });

  @override
  State<MoveLocationScreen> createState() => _MoveLocationScreenState();
}

class _MoveLocationScreenState extends State<MoveLocationScreen> {
  late double _latitude;
  late double _longitude;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _latitude = widget.initialLatitude;
    _longitude = widget.initialLongitude;
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);

    try {
      await widget.onSave(_latitude, _longitude);

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'حصل خطأ: ${e.toString().replaceFirst('Exception: ', '')}',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: LocationPickerMap(
                initialLatitude: _latitude,
                initialLongitude: _longitude,
                onLocationChanged: (latLng) {
                  setState(() {
                    _latitude = latLng.latitude;
                    _longitude = latLng.longitude;
                  });
                },
              ),
            ),

            const SizedBox(height: 16),

            FilledButton.icon(
              onPressed: _isSaving ? null : _save,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              icon: _isSaving
                  ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
                  : const Icon(Icons.save_outlined),
              label: Text(
                _isSaving ? 'جاري الحفظ...' : 'حفظ الموقع',
              ),
            ),
          ],
        ),
      ),
    );
  }
}