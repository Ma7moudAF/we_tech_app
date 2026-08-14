// شاشة إضافة كابينة جديدة - بتلقط الموقع الجغرافي تلقائيًا من الـ GPS
// وبتحدد شكل الكابينة من جوه (بلوكات البوكسات + عدد الرئيسيات)
// أي نوع (فيبر أو نحاس) ممكن يبقى ليه بوكسات، رئيسيات، أو الاتنين مع بعض
//
// لو النوع "نحاس": الشاشة بتسأل على طول عن الكابينة الفيبر الأم اللي كابينة
// النحاس دي هتاخد منها (زي ما اتفقنا: كابينة النحاس مسموح ليها بأب واحد بس
// طول عمرها، ومفيهاش "كود بورت" محدد وقت الإنشاء - الربط ده بيبقى بعدين لما
// يتحدد رئيسي معين واخد من بورت معين، شوف assignMainPairSource).
//
// وبلوكات البوكسات: بدل ما تتضاف يدوي واحد واحد، لما تحفظ الكابينة، البوكسات
// الفاضية بتتولد تلقائيًا بنفس اللحظة (بلوك 1 = سلوت 1-10، بلوك 2 = سلوت
// 11-20، وهكذا) من غير ما تدخل بياناتها - تقدر تعدلها بعدين من شاشة الرسمة.

import 'package:flutter/material.dart';

import '../models/cabinet_model.dart';
import '../services/firestore_service.dart';
import '../services/location_service.dart';
import '../widgets/location_picker_map.dart';


class AddCabinetScreen extends StatefulWidget {
  final String areaId;

  const AddCabinetScreen({super.key, required this.areaId});

  @override
  State<AddCabinetScreen> createState() => _AddCabinetScreenState();
}

class _AddCabinetScreenState extends State<AddCabinetScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();
  final _mainPairsController = TextEditingController(text: '0');
  final _boxBlocksLeftController = TextEditingController(text: '0');
  final _boxBlocksRightController = TextEditingController(text: '0');
  final _notesController = TextEditingController();
  final _firestoreService = FirestoreService();

  CabinetType _type = CabinetType.portBox;
  String? _sourceFiberCabinetId; // كابينة النحاس بس: الكابينة الفيبر الأم
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
    _codeController.dispose();
    _mainPairsController.dispose();
    _boxBlocksLeftController.dispose();
    _boxBlocksRightController.dispose();
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

  int get _mainPairsCount => int.tryParse(_mainPairsController.text.trim()) ?? 0;
  int get _boxBlocksLeft =>
      int.tryParse(_boxBlocksLeftController.text.trim()) ?? 0;
  int get _boxBlocksRight =>
      int.tryParse(_boxBlocksRightController.text.trim()) ?? 0;

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_latitude == null || _longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لازم تلقط الموقع الأول قبل الحفظ')),
      );
      return;
    }
    if (_type == CabinetType.copper && _sourceFiberCabinetId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('اختار الكابينة الفيبر الأم اللي كابينة النحاس دي هتاخد منها'),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final cabinetId = await _firestoreService.addCabinet(
        name: _nameController.text.trim(),
        code: _codeController.text.trim(),
        type: _type,
        areaId: widget.areaId,
        latitude: _latitude!,
        longitude: _longitude!,
        mainPairsCount: _mainPairsCount,
        boxBlocksLeft: _boxBlocksLeft,
        boxBlocksRight: _boxBlocksRight,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      );

      // لو نحاس ومحددة كابينة فيبر أم، نربطهم على طول
      if (_type == CabinetType.copper && _sourceFiberCabinetId != null) {
        await _firestoreService.linkCopperCabinetToParent(
          cabinetId,
          _sourceFiberCabinetId!,
        );
      }

      // نولّد بوكسات فاضية تلقائيًا لكل بلوك اتحدد (شمال ويمين)، بنفس منطق
      // الترقيم بتاع شاشة الرسمة: شمال بيبدأ من سلوت 1، يمين بعد كده مباشرة
      if (_boxBlocksLeft > 0) {
        await _firestoreService.generateEmptySlotBoxes(
          parentCabinetId: cabinetId,
          areaId: widget.areaId,
          latitude: _latitude!,
          longitude: _longitude!,
          fromSlot: 1,
          toSlot: _boxBlocksLeft * CabinetModel.boxesPerBlock,
          namePrefix: _nameController.text.trim(),
        );
      }
      if (_boxBlocksRight > 0) {
        final rightStart = _boxBlocksLeft * CabinetModel.boxesPerBlock + 1;
        await _firestoreService.generateEmptySlotBoxes(
          parentCabinetId: cabinetId,
          areaId: widget.areaId,
          latitude: _latitude!,
          longitude: _longitude!,
          fromSlot: rightStart,
          toSlot: rightStart + _boxBlocksRight * CabinetModel.boxesPerBlock - 1,
          namePrefix: _nameController.text.trim(),
        );
      }

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
    final mainPairBlocks = (_mainPairsCount / CabinetModel.mainPairsPerBlock).ceil();
    final boxCapacity =
        (_boxBlocksLeft + _boxBlocksRight) * CabinetModel.boxesPerBlock;

    return Scaffold(
      appBar: AppBar(title: const Text('إضافة كابينة جديدة')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildLocationCard(),
              if (_latitude != null &&
                  _longitude != null &&
                  _latitude!.isFinite &&
                  _longitude!.isFinite &&
                  _latitude! >= -90 &&
                  _latitude! <= 90 &&
                  _longitude! >= -180 &&
                  _longitude! <= 180) ...[
                const SizedBox(height: 12),
                LocationPickerMap(
                  initialLatitude: _latitude!,
                  initialLongitude: _longitude!,
                  onLocationChanged: (latLng) {
                    setState(() {
                      _latitude = latLng.latitude;
                      _longitude = latLng.longitude;
                    });
                  },
                ),
              ],
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'اسم الكابينة/الوحدة',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'اكتب اسم الكابينة' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _codeController,
                decoration: const InputDecoration(
                  labelText: 'كود الكابينة/الوحدة',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'اكتب كود الكابينة' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<CabinetType>(
                initialValue: _type,
                decoration: const InputDecoration(
                  labelText: 'نوع الكابينة',
                  border: OutlineInputBorder(),
                ),
                items: CabinetType.values
                    .map((t) => DropdownMenuItem(value: t, child: Text(t.labelAr)))
                    .toList(),
                onChanged: (v) => setState(() {
                  _type = v ?? _type;
                  if (_type != CabinetType.copper) _sourceFiberCabinetId = null;
                }),
              ),
              if (_type == CabinetType.copper) ...[
                const SizedBox(height: 16),
                _buildSourceFiberPicker(),
              ],
              const SizedBox(height: 24),
              Text('شكل البوكسات', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                'كل بلوك = 10 بوكسات هتتولد فاضية تلقائيًا لحد ما تحفظ الكابينة. اسيبهم صفر لو الكابينة دي مفيهاش بوكسات مباشرة.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _boxBlocksLeftController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'بلوكات شمال',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => setState(() {}),
                      validator: (v) =>
                      int.tryParse((v ?? '').trim()) == null ? 'رقم؟' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _boxBlocksRightController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'بلوكات يمين',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => setState(() {}),
                      validator: (v) =>
                      int.tryParse((v ?? '').trim()) == null ? 'رقم؟' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'سعة البوكسات الكلية: $boxCapacity بوكس (هتتولد فاضية تلقائيًا)',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 24),
              Text('عدد الرئيسيات', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                'هيتوزعوا تلقائيًا نص بنص بين عمود النص الشمال واليمين (كل بلوك = 100 رئيسي). اسيبها صفر لو مفيش.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _mainPairsController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'عدد الرئيسيات',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
                validator: (v) =>
                int.tryParse((v ?? '').trim()) == null ? 'اكتب رقم' : null,
              ),
              const SizedBox(height: 8),
              Text(
                'هيبقى فيه $mainPairBlocks بلوك رئيسيات ($_mainPairsCount رئيسي)',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 24),
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
                    : const Text('حفظ الكابينة'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Dropdown يظهر بس لما النوع = نحاس، بيعرض كبائن الفيبر الموجودة في نفس
  // المنطقة عشان تختار أنهي واحدة "الأم" اللي الكابينة دي هتاخد منها.
  Widget _buildSourceFiberPicker() {
    return StreamBuilder<List<CabinetModel>>(
      stream: _firestoreService.streamCabinets(widget.areaId),
      builder: (context, snapshot) {
        final fiberCabinets = (snapshot.data ?? [])
            .where((c) => c.type == CabinetType.portBox)
            .toList();
        final validValue = fiberCabinets.any((c) => c.id == _sourceFiberCabinetId)
            ? _sourceFiberCabinetId
            : null;

        if (fiberCabinets.isEmpty) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'مفيش كبائن فيبر مسجلة في المنطقة دي لسه، لازم تضيف كابينة فيبر الأول',
              style: TextStyle(color: Colors.orange),
            ),
          );
        }

        return DropdownButtonFormField<String>(
          initialValue: validValue,
          decoration: const InputDecoration(
            labelText: 'الكابينة الفيبر الأم (واخدة منها)',
            helperText: 'كابينة النحاس دي هتترتبط بيها - مفيش كود بورت محدد دلوقتي',
            border: OutlineInputBorder(),
          ),
          items: fiberCabinets
              .map((c) => DropdownMenuItem(value: c.id, child: Text('${c.name} (${c.code})')))
              .toList(),
          onChanged: (v) => setState(() => _sourceFiberCabinetId = v),
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