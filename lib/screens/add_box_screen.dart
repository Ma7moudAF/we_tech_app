// شاشة إضافة بوكس جديد - بتلقط الموقع الجغرافي تلقائيًا من الـ GPS

import 'package:flutter/material.dart';

import '../models/box_model.dart';
import '../models/cabinet_model.dart';
import '../services/firestore_service.dart';
import '../services/location_service.dart';

class AddBoxScreen extends StatefulWidget {
  final String areaId;

  const AddBoxScreen({super.key, required this.areaId});

  @override
  State<AddBoxScreen> createState() => _AddBoxScreenState();
}

class _AddBoxScreenState extends State<AddBoxScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _terminalsController =
      TextEditingController(text: '${BoxModel.combCapacity}');
  final _notesController = TextEditingController();
  final _firestoreService = FirestoreService();

  String? _parentCabinetId;
  CabinetModel? _parentCabinet;
  int? _slotNumber;
  double? _latitude;
  double? _longitude;
  bool _isLocating = true;
  bool _isSaving = false;
  String? _locationError;

  @override
  void initState() {
    super.initState();
    _captureLocation();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _terminalsController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _captureLocation() async {
    setState(() {
      _isLocating = true;
      _locationError = null;
    });
    try {
      final position = await LocationService.getCurrentLocation();
      if (mounted) {
        setState(() {
          _latitude = position.latitude;
          _longitude = position.longitude;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _locationError = e.toString().replaceFirst('Exception: ', '');
        });
      }
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_latitude == null || _longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لازم تلقط الموقع الأول قبل الحفظ')),
      );
      return;
    }
    if (_parentCabinetId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اختار الكابينة الأب')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await _firestoreService.addBox(
        name: _nameController.text.trim(),
        parentCabinetId: _parentCabinetId!,
        areaId: widget.areaId,
        latitude: _latitude!,
        longitude: _longitude!,
        terminalsCount:
            int.tryParse(_terminalsController.text.trim()) ??
                BoxModel.combCapacity,
        slotNumber: _slotNumber,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حصل خطأ: ${e.toString().replaceFirst('Exception: ', '')}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إضافة بوكس جديد')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildLocationCard(),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'اسم/كود البوكس',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'اكتب اسم البوكس' : null,
              ),
              const SizedBox(height: 16),
              StreamBuilder<List<CabinetModel>>(
                stream: _firestoreService.streamCabinets(widget.areaId),
                builder: (context, snapshot) {
                  final cabinets = snapshot.data ?? [];
                  final validValue = cabinets.any((c) => c.id == _parentCabinetId)
                      ? _parentCabinetId
                      : null;
                  return DropdownButtonFormField<String>(
                    value: validValue,
                    decoration: const InputDecoration(
                      labelText: 'الكابينة الأب',
                      border: OutlineInputBorder(),
                    ),
                    items: cabinets
                        .map((c) => DropdownMenuItem(
                              value: c.id,
                              child: Text('${c.name} (${c.type.labelAr})'),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() {
                      _parentCabinetId = v;
                      CabinetModel? found;
                      for (final c in cabinets) {
                        if (c.id == v) {
                          found = c;
                          break;
                        }
                      }
                      _parentCabinet = found;
                      _slotNumber = null;
                    }),
                    validator: (v) => v == null ? 'اختار الكابينة الأب' : null,
                  );
                },
              ),
              const SizedBox(height: 16),
              if (_parentCabinet != null) _buildSlotPicker(),
              const SizedBox(height: 16),
              TextFormField(
                controller: _terminalsController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'عدد الترمنالات (مضاعف ${BoxModel.combCapacity})',
                  border: const OutlineInputBorder(),
                ),
                validator: (v) {
                  final n = int.tryParse((v ?? '').trim());
                  if (n == null || !BoxModel.isValidTerminalsCount(n)) {
                    return 'لازم يكون مضاعف ${BoxModel.combCapacity}';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _notesController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'ملاحظات (اختياري)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _isSaving ? null : _save,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('حفظ البوكس'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSlotPicker() {
    final cabinet = _parentCabinet!;
    if (cabinet.boxCapacity == 0) {
      return const Padding(
        padding: EdgeInsets.only(bottom: 4),
        child: Text(
          'الكابينة دي مفيهاش بلوكات بوكسات محددة، فالبوكس هيتضاف من غير مكان ثابت في الرسمة.',
          style: TextStyle(color: Colors.orange),
        ),
      );
    }
    return StreamBuilder<List<BoxModel>>(
      stream: _firestoreService.streamBoxesForCabinet(cabinet.id),
      builder: (context, snapshot) {
        final takenSlots = (snapshot.data ?? [])
            .map((b) => b.slotNumber)
            .whereType<int>()
            .toSet();
        final availableSlots = List.generate(cabinet.boxCapacity, (i) => i + 1)
            .where((s) => !takenSlots.contains(s))
            .toList();
        final validValue =
            availableSlots.contains(_slotNumber) ? _slotNumber : null;

        if (availableSlots.isEmpty) {
          return const Text(
            'كل السلوتات متاخدة على الكابينة دي بالفعل',
            style: TextStyle(color: Colors.red),
          );
        }

        return DropdownButtonFormField<int>(
          value: validValue,
          decoration: const InputDecoration(
            labelText: 'مكان البوكس (سلوت)',
            border: OutlineInputBorder(),
          ),
          items: availableSlots
              .map((s) => DropdownMenuItem(value: s, child: Text('سلوت $s')))
              .toList(),
          onChanged: (v) => setState(() => _slotNumber = v),
        );
      },
    );
  }

  Widget _buildLocationCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.my_location, color: Colors.teal),
            const SizedBox(width: 12),
            Expanded(
              child: _isLocating
                  ? const Text('جاري تحديد الموقع...')
                  : _locationError != null
                      ? Text(_locationError!,
                          style: const TextStyle(color: Colors.red))
                      : Text(
                          'الموقع: ${_latitude!.toStringAsFixed(6)}, ${_longitude!.toStringAsFixed(6)}',
                        ),
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'تحديث الموقع',
              onPressed: _isLocating ? null : _captureLocation,
            ),
          ],
        ),
      ),
    );
  }
}
