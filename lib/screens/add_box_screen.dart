// شاشة إضافة بوكس جديد - بتلقط الموقع الجغرافي تلقائيًا من الـ GPS
// الفني بيختار: الكابينة الأب -> بلوك بوكسات (شمال/يمين) -> مكان فاضي جواه (1-10)

import 'package:flutter/material.dart';

import '../models/block_model.dart';
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
  final _notesController = TextEditingController();
  final _firestoreService = FirestoreService();

  String? _parentCabinetId;
  String? _blockId;
  int? _positionInBlock;
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
    if (_blockId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اختار بلوك البوكسات')),
      );
      return;
    }
    if (_positionInBlock == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اختار مكان البوكس جوه البلوك')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await _firestoreService.addBox(
        name: _nameController.text.trim(),
        parentCabinetId: _parentCabinetId!,
        blockId: _blockId!,
        positionInBlock: _positionInBlock!,
        areaId: widget.areaId,
        latitude: _latitude!,
        longitude: _longitude!,
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
                    initialValue: validValue,
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
                      _blockId = null;
                      _positionInBlock = null;
                    }),
                    validator: (v) => v == null ? 'اختار الكابينة الأب' : null,
                  );
                },
              ),
              const SizedBox(height: 16),
              if (_parentCabinetId != null) _buildBlockPicker(),
              const SizedBox(height: 16),
              if (_blockId != null) _buildPositionPicker(),
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

  Widget _buildBlockPicker() {
    return StreamBuilder<List<BlockModel>>(
      stream: _firestoreService.streamBlocks(_parentCabinetId!),
      builder: (context, snapshot) {
        final boxBlocks =
        (snapshot.data ?? []).where((b) => b.type == BlockType.box).toList();

        if (boxBlocks.isEmpty) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'مفيش بلوكات بوكسات على الكابينة دي لسه - ضيف بلوك بوكسات الأول '
                  'من شاشة "الكابينة من جوه"',
              style: TextStyle(color: Colors.orange),
            ),
          );
        }

        final validValue = boxBlocks.any((b) => b.id == _blockId) ? _blockId : null;

        return DropdownButtonFormField<String>(
          initialValue: validValue,
          decoration: const InputDecoration(
            labelText: 'بلوك البوكسات',
            border: OutlineInputBorder(),
          ),
          items: boxBlocks
              .map((b) => DropdownMenuItem(
            value: b.id,
            child: Text('${b.side.labelAr} - بلوك ${b.blockNumber}'),
          ))
              .toList(),
          onChanged: (v) => setState(() {
            _blockId = v;
            _positionInBlock = null;
          }),
        );
      },
    );
  }

  Widget _buildPositionPicker() {
    return StreamBuilder<List<BoxModel>>(
      stream: _firestoreService.streamBoxesInBlock(_parentCabinetId!, _blockId!),
      builder: (context, snapshot) {
        final takenPositions =
        (snapshot.data ?? []).map((b) => b.positionInBlock).toSet();
        final availablePositions = List.generate(BlockModel.capacity, (i) => i + 1)
            .where((p) => !takenPositions.contains(p))
            .toList();
        final validValue =
        availablePositions.contains(_positionInBlock) ? _positionInBlock : null;

        if (availablePositions.isEmpty) {
          return const Text(
            'كل الأماكن في البلوك ده متاخدة بالفعل',
            style: TextStyle(color: Colors.red),
          );
        }

        return DropdownButtonFormField<int>(
          initialValue: validValue,
          decoration: const InputDecoration(
            labelText: 'مكان البوكس جوه البلوك',
            border: OutlineInputBorder(),
          ),
          items: availablePositions
              .map((p) => DropdownMenuItem(value: p, child: Text('مكان $p')))
              .toList(),
          onChanged: (v) => setState(() => _positionInBlock = v),
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