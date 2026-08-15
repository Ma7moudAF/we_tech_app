// شاشة تفاصيل الكابينة - بتعرض رئيسيات بلوك معين بتاعتها
// وبتسمح بتعديل حالة كل رئيسي (تعطيل / رقم تليفون / وجهة على بوكس + ترمنال محدد)
//
// ملحوظة مهمة: رقم الرئيسي (pairNumber) بيبقى من 1 لـ 10 بس جوه البلوك نفسه
// (مش رقم عام على الكابينة كلها) - عشان كده الشاشة دي لازم تاخد بلوك محدد
// (BlockModel) مش الكابينة لوحدها، وبتقرأ رئيسيات البلوك ده بس.
//
// تحديد "وجهة" الرئيسي هنا مش تعديل حر - هو فعليًا بينفذ setMainPairDestination
// (بدل ما الترمنال هو اللي يختار مصدره من شاشة البوكس، هنا بنختار من الرئيسي:
// رايح على أنهي بوكس وأنهي ترمنال بالظبط جواه). ده بيحافظ على نفس تزامن رقم
// التليفون عبر السلسلة كلها.

import 'package:flutter/material.dart';
import 'move_location_screen.dart';
import '../models/block_model.dart';
import '../models/box_model.dart';
import '../models/cabinet_model.dart';
import '../models/main_pair_model.dart';
import '../models/terminal_model.dart';
import '../services/firestore_service.dart';

class CabinetDetailsScreen extends StatefulWidget {
  final CabinetModel cabinet;
  final BlockModel block; // بلوك الرئيسيات المطلوب عرضه (كل بلوك = 10 رئيسي)

  const CabinetDetailsScreen({
    super.key,
    required this.cabinet,
    required this.block,
  });

  @override
  State<CabinetDetailsScreen> createState() => _CabinetDetailsScreenState();
}

class _CabinetDetailsScreenState extends State<CabinetDetailsScreen> {
  final _firestoreService = FirestoreService();
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _moveOnMap(CabinetModel cabinet) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MoveLocationScreen(
          title: 'تحريك ${cabinet.name}',
          initialLatitude: cabinet.latitude,
          initialLongitude: cabinet.longitude,
          onSave: (lat, lng) => _firestoreService.updateCabinet(
            cabinet.id,
            {
              'latitude': lat,
              'longitude': lng,
            },
          ),
        ),
      ),
    );
  }

  void _editPair(MainPairModel pair) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _EditMainPairSheet(
        pair: pair,
        cabinet: widget.cabinet,
        block: widget.block,
        firestoreService: _firestoreService,
      ),
    );
  }

  Color _statusColor(MainPairModel pair) {
    if (pair.isFaulty) return Colors.red;
    if (pair.phoneNumber != null && pair.phoneNumber!.isNotEmpty) {
      return Colors.blue;
    }
    return Colors.green;
  }

  String _statusLabel(MainPairModel pair) {
    if (pair.isFaulty) return 'معطل';
    if (pair.phoneNumber != null && pair.phoneNumber!.isNotEmpty) {
      return 'مشغول';
    }
    return 'فاضي';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${widget.cabinet.name} - بلوك رئيسيات ${widget.block.blockNumber} (${widget.block.side.labelAr})',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.pin_drop_outlined),
            tooltip: 'تحريك مكان الكابينة على الخريطة',
            onPressed: () => _moveOnMap(widget.cabinet),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: widget.cabinet.type == CabinetType.portBox
                ? Colors.blue.shade50
                : Colors.orange.shade50,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(
                  widget.cabinet.type == CabinetType.portBox
                      ? Icons.electrical_services
                      : Icons.hub,
                  color: widget.cabinet.type == CabinetType.portBox
                      ? Colors.blue
                      : Colors.orange,
                ),
                const SizedBox(width: 8),
                Text('النوع: ${widget.cabinet.type.labelAr}'),
                const Spacer(),
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
                hintText: 'دور برقم الرئيسي أو رقم التليفون',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _query = v.trim()),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<MainPairModel>>(
              stream: _firestoreService.streamMainPairsInBlock(
                widget.cabinet.id,
                widget.block.id,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final pairs = snapshot.data ?? [];
                if (pairs.isEmpty) {
                  return _buildEmptyState();
                }

                final filtered = _query.isEmpty
                    ? pairs
                    : pairs.where((p) {
                  return p.pairNumber.toString().contains(_query) ||
                      p.locationLabel.contains(_query) ||
                      (p.phoneNumber ?? '').contains(_query);
                }).toList();

                if (filtered.isEmpty) {
                  return const Center(child: Text('مفيش نتايج'));
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final pair = filtered[index];
                    return Card(
                      child: ListTile(
                        onTap: () => _editPair(pair),
                        leading: CircleAvatar(
                          backgroundColor: _statusColor(pair),
                          child: Text(
                            '${pair.pairNumber}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          pair.phoneNumber != null &&
                              pair.phoneNumber!.isNotEmpty
                              ? pair.phoneNumber!
                              : _statusLabel(pair),
                        ),
                        subtitle: Text(
                          pair.destinationBoxId != null
                              ? '${pair.locationLabel} · رايح على بوكس وترمنال محدد'
                              : pair.locationLabel,
                        ),
                        trailing: pair.isFaulty
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

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.dns_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text(
              'مفيش رئيسيات في البلوك ده - ده مش المفروض يحصل لو البلوك '
                  'اتضاف صح (البلوك بيتولدله 10 رئيسي أوتوماتيك وقت الإضافة).',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// شيت تعديل رئيسي واحد
class _EditMainPairSheet extends StatefulWidget {
  final MainPairModel pair;
  final CabinetModel cabinet;
  final BlockModel block;
  final FirestoreService firestoreService;

  const _EditMainPairSheet({
    required this.pair,
    required this.cabinet,
    required this.block,
    required this.firestoreService,
  });

  @override
  State<_EditMainPairSheet> createState() => _EditMainPairSheetState();
}

class _EditMainPairSheetState extends State<_EditMainPairSheet> {
  late bool _isFaulty;
  late TextEditingController _phoneController;

  // بوكس وترمنال الوجهة المختارين
  String? _destinationBoxId;
  int? _destinationTerminalNumber;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _isFaulty = widget.pair.isFaulty;
    _phoneController =
        TextEditingController(text: widget.pair.phoneNumber ?? '');
    _destinationBoxId = widget.pair.destinationBoxId;
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      final phone = _phoneController.text.trim().isEmpty
          ? null
          : _phoneController.text.trim();

      // نحدّث حالة الرئيسي نفسها (تعطيل/رقم) الأول
      await widget.firestoreService.updateMainPair(
        widget.cabinet.id,
        widget.block.id,
        widget.pair.id,
        {'isFaulty': _isFaulty, 'phoneNumber': phone},
      );

      // لو محدد بوكس وترمنال، ننفذ setMainPairDestination عشان يتزامن الرقم
      // صح على طول السلسلة (رئيسي <-> ترمنال <-> بورت)
      if (_destinationBoxId != null && _destinationTerminalNumber != null) {
        final terms = await widget.firestoreService
            .streamTerminals(_destinationBoxId!)
            .first;
        TerminalModel? terminal;
        for (final t in terms) {
          if (t.terminalNumber == _destinationTerminalNumber) {
            terminal = t;
            break;
          }
        }
        if (terminal == null) {
          throw Exception('الترمنال المختار مش موجود، حاول تاني');
        }
        await widget.firestoreService.setMainPairDestination(
          copperCabinetId: widget.cabinet.id,
          blockId: widget.block.id,
          pairId: widget.pair.id,
          boxId: _destinationBoxId!,
          terminalId: terminal.id,
          phoneNumber: phone,
        );
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is Exception
                  ? e.toString().replaceFirst('Exception: ', '')
                  : 'حصل خطأ',
            ),
          ),
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
              widget.pair.locationLabel,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text(
              'بلوك ${widget.block.blockNumber} (${widget.block.side.labelAr})',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey,
              ),
            ),
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
                labelText: 'رقم التليفون (اسيبه فاضي لو الرئيسي فاضي)',
                prefixIcon: Icon(Icons.call_outlined),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Text('رايح على', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(
              'اختار البوكس وبعده رقم الترمنال بالظبط اللي الرئيسي ده واخده',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.grey),
            ),
            const SizedBox(height: 12),
            _buildBoxPicker(),
            if (_destinationBoxId != null) ...[
              const SizedBox(height: 16),
              _buildTerminalPicker(),
            ],
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

  Widget _buildBoxPicker() {
    return StreamBuilder<List<BoxModel>>(
      stream: widget.firestoreService.streamBoxes(widget.cabinet.areaId),
      builder: (context, snapshot) {
        final boxes = snapshot.data ?? [];
        final validValue =
        boxes.any((b) => b.id == _destinationBoxId) ? _destinationBoxId : null;
        return DropdownButtonFormField<String?>(
          initialValue: validValue,
          decoration: const InputDecoration(
            labelText: 'اختر البوكس',
            border: OutlineInputBorder(),
          ),
          items: [
            const DropdownMenuItem(value: null, child: Text('مفيش وجهة محددة')),
            ...boxes.map((b) => DropdownMenuItem(value: b.id, child: Text(b.name))),
          ],
          onChanged: (v) => setState(() {
            _destinationBoxId = v;
            _destinationTerminalNumber = null;
          }),
        );
      },
    );
  }

  Widget _buildTerminalPicker() {
    return StreamBuilder<List<TerminalModel>>(
      stream: widget.firestoreService.streamTerminals(_destinationBoxId!),
      builder: (context, snapshot) {
        final terminals = snapshot.data ?? [];
        if (terminals.isEmpty) {
          return const Text(
            'البوكس ده لسه مفيهوش ترمنالات متولدة',
            style: TextStyle(color: Colors.orange),
          );
        }

        if (_destinationTerminalNumber == null &&
            widget.pair.destinationBoxId == _destinationBoxId &&
            widget.pair.destinationTerminalId != null) {
          for (final t in terminals) {
            if (t.id == widget.pair.destinationTerminalId) {
              _destinationTerminalNumber = t.terminalNumber;
              break;
            }
          }
        }

        final validValue =
        terminals.any((t) => t.terminalNumber == _destinationTerminalNumber)
            ? _destinationTerminalNumber
            : null;

        return DropdownButtonFormField<int?>(
          initialValue: validValue,
          decoration: const InputDecoration(
            labelText: 'اختر الترمنال',
            border: OutlineInputBorder(),
          ),
          items: terminals
              .map((t) => DropdownMenuItem(
            value: t.terminalNumber,
            child: Text(
              'ترمنال ${t.terminalNumber}'
                  '${t.phoneNumber != null && t.phoneNumber!.isNotEmpty ? " (مشغول: ${t.phoneNumber})" : " (فاضي)"}',
            ),
          ))
              .toList(),
          onChanged: (v) => setState(() => _destinationTerminalNumber = v),
        );
      },
    );
  }
}