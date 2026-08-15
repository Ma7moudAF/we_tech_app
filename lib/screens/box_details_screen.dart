// شاشة تفاصيل البوكس - بتعرض الترمنالات بتاعته
// وبتسمح بتعديل كل ترمنال (رقم / عميل / حالة العزل / تعطيل / توصيل غير مباشر)
// وكمان بتسمح بتبديل بيانات ترمنالين مع بعض، وتعديل بيانات البوكس نفسه (الاسم/الملاحظات)
// وتحريك مكان البوكس على الخريطة (زرار الـ pin في الـ AppBar)
//
// ملحوظة: سعة البوكس ثابتة دايمًا 10 ترمنال (نفس سعة البلوك) - مش قابلة للتعديل.
// ربط الترمنال بمصدره (بورت/رئيسي) بيتحدد من شاشة الشيلف/بلوك الرئيسيات
// (مش من هنا)، عشان تزامن الرقم عبر السلسلة يفضل من مكان واحد موحّد.

import 'package:flutter/material.dart';

import '../models/box_model.dart';
import '../models/terminal_model.dart';
import '../services/firestore_service.dart';
import 'move_location_screen.dart';

class BoxDetailsScreen extends StatefulWidget {
  final BoxModel box;

  const BoxDetailsScreen({super.key, required this.box});

  @override
  State<BoxDetailsScreen> createState() => _BoxDetailsScreenState();
}

class _BoxDetailsScreenState extends State<BoxDetailsScreen> {
  final _firestoreService = FirestoreService();
  final _searchController = TextEditingController();
  String _query = '';
  bool _isGenerating = false;

  bool _swapMode = false;
  TerminalModel? _swapFirst;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _ensureTerminals(BoxModel box) async {
    setState(() => _isGenerating = true);
    try {
      await _firestoreService.ensureTerminalsCount(box.id, box.terminalsCount);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حصل خطأ: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  void _toggleSwapMode() {
    setState(() {
      _swapMode = !_swapMode;
      _swapFirst = null;
    });
    if (_swapMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اختار أول ترمنال هتبدله')),
      );
    }
  }

  void _editBoxInfo(BoxModel box) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _EditBoxInfoSheet(
        box: box,
        firestoreService: _firestoreService,
      ),
    );
  }

  void _moveOnMap(BoxModel box) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MoveLocationScreen(
          title: 'تحريك ${box.name}',
          initialLatitude: box.latitude,
          initialLongitude: box.longitude,
          onSave: (lat, lng) => _firestoreService.updateBox(box.id, {
            'latitude': lat,
            'longitude': lng,
          }),
        ),
      ),
    );
  }

  Future<void> _onTerminalTap(BoxModel box, TerminalModel terminal) async {
    if (!_swapMode) {
      _editTerminal(box, terminal);
      return;
    }

    if (_swapFirst == null) {
      setState(() => _swapFirst = terminal);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'تمام، دلوقتي اختار الترمنال اللي هتبدل بيانات ${terminal.terminalNumber} معاه'),
        ),
      );
      return;
    }

    if (_swapFirst!.id == terminal.id) {
      setState(() => _swapFirst = null);
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد التبديل'),
        content: Text(
          'هيتبدل كل بيانات العميل بين ترمنال ${_swapFirst!.terminalNumber} '
              'وترمنال ${terminal.terminalNumber}. متأكد؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('تبديل'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _firestoreService.swapTerminals(box.id, _swapFirst!, terminal);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('اتبدلت البيانات بنجاح')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('حصل خطأ: $e')),
          );
        }
      }
    }

    setState(() {
      _swapFirst = null;
      _swapMode = false;
    });
  }

  void _editTerminal(BoxModel box, TerminalModel terminal) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => StreamBuilder<List<TerminalModel>>(
        stream: _firestoreService.streamTerminals(box.id),
        builder: (context, snapshot) {
          final allTerminals = snapshot.data ?? [terminal];
          return _EditTerminalSheet(
            terminal: terminal,
            box: box,
            allTerminals: allTerminals,
            firestoreService: _firestoreService,
          );
        },
      ),
    );
  }

  Color _statusColor(TerminalModel t) {
    if (t.isFaulty) return Colors.red;
    if (t.phoneNumber != null && t.phoneNumber!.isNotEmpty) return Colors.blue;
    return Colors.green;
  }

  Color _isolationColor(IsolationStatus status) {
    switch (status) {
      case IsolationStatus.ok:
        return Colors.green;
      case IsolationStatus.percentage:
        return Colors.orange;
      case IsolationStatus.unknown:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<BoxModel?>(
      stream: _firestoreService.streamBox(widget.box.id),
      initialData: widget.box,
      builder: (context, boxSnapshot) {
        final box = boxSnapshot.data ?? widget.box;

        return Scaffold(
          appBar: AppBar(
            title: Text(box.name),
            actions: [
              IconButton(
                icon: const Icon(Icons.pin_drop_outlined),
                tooltip: 'تحريك مكان البوكس على الخريطة',
                onPressed: () => _moveOnMap(box),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'تعديل بيانات البوكس',
                onPressed: () => _editBoxInfo(box),
              ),
              IconButton(
                icon: Icon(
                  Icons.swap_horiz,
                  color: _swapMode ? Colors.orangeAccent : null,
                ),
                tooltip: 'تبديل رقمين',
                onPressed: _toggleSwapMode,
              ),
            ],
          ),
          body: Column(
            children: [
              if (_swapMode)
                Container(
                  width: double.infinity,
                  color: Colors.orange.shade50,
                  padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    _swapFirst == null
                        ? 'وضع التبديل شغال - اختار أول ترمنال'
                        : 'اتخار ترمنال ${_swapFirst!.terminalNumber} - دلوقتي اختار التاني',
                    style: const TextStyle(color: Colors.orange),
                  ),
                ),
              Container(
                width: double.infinity,
                color: Colors.green.shade50,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    const Icon(Icons.inventory_2, color: Colors.green),
                    const SizedBox(width: 8),
                    Text('مكان ${box.positionInBlock} · ${box.terminalsCount} ترمنال'),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    _legendDot(Colors.green, 'فاضي'),
                    const SizedBox(width: 10),
                    _legendDot(Colors.blue, 'مشغول'),
                    const SizedBox(width: 10),
                    _legendDot(Colors.red, 'معطل'),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    hintText: 'دور برقم الترمنال أو رقم التليفون أو اسم العميل',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (v) => setState(() => _query = v.trim()),
                ),
              ),
              Expanded(
                child: StreamBuilder<List<TerminalModel>>(
                  stream: _firestoreService.streamTerminals(box.id),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final terminals = snapshot.data ?? [];
                    if (terminals.isEmpty) {
                      return _buildEmptyState(box);
                    }

                    final filtered = _query.isEmpty
                        ? terminals
                        : terminals.where((t) {
                      return t.terminalNumber.toString().contains(_query) ||
                          (t.phoneNumber ?? '').contains(_query) ||
                          (t.customerName ?? '').contains(_query);
                    }).toList();

                    if (filtered.isEmpty) {
                      return const Center(child: Text('مفيش نتايج'));
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final t = filtered[index];
                        final isSelectedForSwap = _swapFirst?.id == t.id;
                        return Card(
                          shape: isSelectedForSwap
                              ? RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: const BorderSide(
                                color: Colors.orangeAccent, width: 2),
                          )
                              : null,
                          child: ListTile(
                            onTap: () => _onTerminalTap(box, t),
                            leading: CircleAvatar(
                              backgroundColor: _statusColor(t),
                              child: Text(
                                '${t.terminalNumber}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            title: Text(
                              t.phoneNumber != null && t.phoneNumber!.isNotEmpty
                                  ? t.phoneNumber!
                                  : 'فاضي',
                            ),
                            subtitle: Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                if (t.customerName != null &&
                                    t.customerName!.isNotEmpty)
                                  Text(t.customerName!),
                                if (t.customerType != null)
                                  Chip(
                                    label: Text(
                                      t.customerType!.labelAr,
                                      style: const TextStyle(fontSize: 10),
                                    ),
                                    visualDensity: VisualDensity.compact,
                                    materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                                    padding: EdgeInsets.zero,
                                  ),
                                Chip(
                                  label: Text(
                                    t.isolationStatus.labelAr,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: _isolationColor(t.isolationStatus),
                                    ),
                                  ),
                                  visualDensity: VisualDensity.compact,
                                  materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                                  padding: EdgeInsets.zero,
                                  side: BorderSide(
                                    color: _isolationColor(t.isolationStatus),
                                  ),
                                ),
                                if (t.sourceId != null)
                                  const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.link, size: 12, color: Colors.teal),
                                      SizedBox(width: 2),
                                      Text(
                                        'مربوط بمصدر',
                                        style: TextStyle(fontSize: 10, color: Colors.teal),
                                      ),
                                    ],
                                  ),
                                if (t.crossConnectedTo != null)
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.call_split,
                                          size: 12, color: Colors.purple),
                                      const SizedBox(width: 2),
                                      Text(
                                        'فعليًا رقم ${t.crossConnectedTo}',
                                        style: const TextStyle(
                                            fontSize: 10, color: Colors.purple),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                            trailing: t.isFaulty
                                ? const Icon(Icons.warning_amber_rounded,
                                color: Colors.red)
                                : const Icon(Icons.chevron_left),
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
      },
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _buildEmptyState(BoxModel box) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined,
                size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'مفيش ترمنالات مسجلة على البوكس ده لسه\n'
                  '(متوقع ${box.terminalsCount} ترمنال)',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _isGenerating ? null : () => _ensureTerminals(box),
              icon: _isGenerating
                  ? const SizedBox(
                height: 16,
                width: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
                  : const Icon(Icons.add),
              label: const Text('توليد الترمنالات'),
            ),
          ],
        ),
      ),
    );
  }
}

// شيت تعديل بيانات البوكس نفسه (الاسم / الملاحظات - السعة ثابتة مش قابلة للتعديل)
class _EditBoxInfoSheet extends StatefulWidget {
  final BoxModel box;
  final FirestoreService firestoreService;

  const _EditBoxInfoSheet({
    required this.box,
    required this.firestoreService,
  });

  @override
  State<_EditBoxInfoSheet> createState() => _EditBoxInfoSheetState();
}

class _EditBoxInfoSheetState extends State<_EditBoxInfoSheet> {
  late TextEditingController _nameController;
  late TextEditingController _notesController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.box.name);
    _notesController = TextEditingController(text: widget.box.notes ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      await widget.firestoreService.updateBox(widget.box.id, {
        'name': _nameController.text.trim(),
        'notes': _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      });
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حصل خطأ: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'تعديل بيانات البوكس',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'اسم/كود البوكس',
                prefixIcon: Icon(Icons.inventory_2_outlined),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _notesController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'ملاحظات',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _isSaving ? null : _save,
                child: _isSaving
                    ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
                    : const Text('حفظ'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// شيت تعديل ترمنال واحد
class _EditTerminalSheet extends StatefulWidget {
  final TerminalModel terminal;
  final BoxModel box;
  final List<TerminalModel> allTerminals;
  final FirestoreService firestoreService;

  const _EditTerminalSheet({
    required this.terminal,
    required this.box,
    required this.allTerminals,
    required this.firestoreService,
  });

  @override
  State<_EditTerminalSheet> createState() => _EditTerminalSheetState();
}

class _EditTerminalSheetState extends State<_EditTerminalSheet> {
  late TextEditingController _phoneController;
  late TextEditingController _nameController;
  late TextEditingController _notesController;
  CustomerType? _customerType;
  bool _isFaulty = false;
  IsolationStatus _isolationStatus = IsolationStatus.unknown;
  int? _crossConnectedTo;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _phoneController =
        TextEditingController(text: widget.terminal.phoneNumber ?? '');
    _nameController =
        TextEditingController(text: widget.terminal.customerName ?? '');
    _notesController =
        TextEditingController(text: widget.terminal.notes ?? '');
    _customerType = widget.terminal.customerType;
    _isFaulty = widget.terminal.isFaulty;
    _isolationStatus = widget.terminal.isolationStatus;
    _crossConnectedTo = widget.terminal.crossConnectedTo;
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _nameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      await widget.firestoreService.updateTerminal(
        widget.box.id,
        widget.terminal.id,
        {
          'phoneNumber': _phoneController.text.trim().isEmpty
              ? null
              : _phoneController.text.trim(),
          'customerName': _nameController.text.trim().isEmpty
              ? null
              : _nameController.text.trim(),
          'customerType': _customerType?.name,
          'isFaulty': _isFaulty,
          'isolationStatus': _isolationStatus.name,
          'crossConnectedTo': _crossConnectedTo,
          'notes': _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
        },
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حصل خطأ: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final otherTerminals =
    widget.allTerminals.where((t) => t.id != widget.terminal.id).toList();

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ترمنال رقم ${widget.terminal.terminalNumber}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (widget.terminal.sourceId != null) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.teal.shade50,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.link, size: 14, color: Colors.teal),
                    SizedBox(width: 4),
                    Text(
                      'الترمنال ده مربوط بمصدر (بورت/رئيسي) - عدّل الربط من شاشة المصدر',
                      style: TextStyle(fontSize: 11, color: Colors.teal),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('معطل'),
              value: _isFaulty,
              onChanged: (v) => setState(() => _isFaulty = v),
            ),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'رقم التليفون (اسيبه فاضي لو الترمنال فاضي)',
                prefixIcon: Icon(Icons.call_outlined),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'اسم العميل',
                prefixIcon: Icon(Icons.person_outline),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<CustomerType?>(
              initialValue: _customerType,
              decoration: const InputDecoration(
                labelText: 'تصنيف العميل',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('غير محدد')),
                ...CustomerType.values.map(
                      (c) => DropdownMenuItem(value: c, child: Text(c.labelAr)),
                ),
              ],
              onChanged: (v) => setState(() => _customerType = v),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<IsolationStatus>(
              initialValue: _isolationStatus,
              decoration: const InputDecoration(
                labelText: 'حالة العزل',
                border: OutlineInputBorder(),
              ),
              items: IsolationStatus.values
                  .map((s) => DropdownMenuItem(value: s, child: Text(s.labelAr)))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _isolationStatus = v);
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int?>(
              initialValue:
              otherTerminals.any((t) => t.terminalNumber == _crossConnectedTo)
                  ? _crossConnectedTo
                  : null,
              decoration: const InputDecoration(
                labelText: 'التوصيل الفعلي (لو مش مباشر لنفس الرقم)',
                helperText: 'اسيبه فاضي لو التوصيل مباشر وعادي',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('مباشر (عادي)')),
                ...otherTerminals.map(
                      (t) => DropdownMenuItem(
                    value: t.terminalNumber,
                    child: Text('فعليًا رقم ${t.terminalNumber}'),
                  ),
                ),
              ],
              onChanged: (v) => setState(() => _crossConnectedTo = v),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _notesController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'ملاحظات',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _isSaving ? null : _save,
                child: _isSaving
                    ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
                    : const Text('حفظ'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}