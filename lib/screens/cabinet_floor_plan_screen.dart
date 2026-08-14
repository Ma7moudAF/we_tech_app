// شاشة "الكابينة من جوه" - رسمة بصرية بالبلوكات:
// - عمود أقصى اليمين وعمود أقصى الشمال = بلوكات بوكسات (كل بلوك = 10 بوكسات)
// - عمود النص اليمين وعمود النص الشمال = بلوكات رئيسيات (كل بلوك = 100 رئيسي / 10 أمشاط)
// الترقيم في الاتنين (بوكسات ورئيسيات) بيبدأ من الشمال دايمًا

import 'package:flutter/material.dart';

import '../models/box_model.dart';
import '../models/cabinet_model.dart';
import '../services/firestore_service.dart';
import 'add_box_screen.dart';
import 'box_details_screen.dart';
import 'cabinet_details_screen.dart';
import 'cabinet_report_screen.dart';

class CabinetFloorPlanScreen extends StatefulWidget {
  final CabinetModel cabinet;

  const CabinetFloorPlanScreen({super.key, required this.cabinet});

  @override
  State<CabinetFloorPlanScreen> createState() => _CabinetFloorPlanScreenState();
}

class _CabinetFloorPlanScreenState extends State<CabinetFloorPlanScreen> {
  final _firestoreService = FirestoreService();

  @override
  Widget build(BuildContext context) {
    final cabinet = widget.cabinet;
    return Scaffold(
      appBar: AppBar(
        title: Text('${cabinet.name} - من جوه'),
        actions: [
          IconButton(
            icon: const Icon(Icons.print_outlined),
            tooltip: 'طباعة تقرير الكابينة',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CabinetReportScreen(cabinet: cabinet),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.list_alt),
            tooltip: 'عرض الرئيسيات كليستة',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CabinetDetailsScreen(cabinet: cabinet),
              ),
            ),
          ),
        ],
      ),
      body: StreamBuilder<List<BoxModel>>(
        stream: _firestoreService.streamBoxesForCabinet(cabinet.id),
        builder: (context, boxesSnapshot) {
          final boxes = boxesSnapshot.data ?? [];

          if (cabinet.boxCapacity == 0 && cabinet.mainPairsCount == 0) {
            return _buildEmptyState();
          }

          return Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              // ترتيب الأعمدة من الشمال لليمين في الكود:
              // بوكسات شمال (يبدأ الترقيم من هنا) - رئيسيات نص-شمال - رئيسيات نص-يمين - بوكسات يمين
              // وبما إن التطبيق RTL، أول عنصر في الليستة بيظهر أقصى اليمين تلقائيًا
              children: [
                _buildBoxColumn(
                  label: 'بوكسات يمين',
                  blocksCount: cabinet.boxBlocksRight,
                  startSlot: cabinet.boxBlocksLeft * CabinetModel.boxesPerBlock + 1,
                  boxes: boxes,
                ),
                const SizedBox(width: 8),
                _buildMainPairColumn(
                  label: 'رئيسيات يمين',
                  blocksCount: cabinet.mainPairBlocksRight,
                  startBlockIndex: cabinet.mainPairBlocksLeft,
                ),
                const SizedBox(width: 4),
                _buildMainPairColumn(
                  label: 'رئيسيات شمال',
                  blocksCount: cabinet.mainPairBlocksLeft,
                  startBlockIndex: 0,
                ),
                const SizedBox(width: 8),
                _buildBoxColumn(
                  label: 'بوكسات شمال',
                  blocksCount: cabinet.boxBlocksLeft,
                  startSlot: 1,
                  boxes: boxes,
                ),
              ],
            ),
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
            Icon(Icons.dashboard_customize_outlined,
                size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text(
              'الكابينة دي لسه ملهاش شكل محدد (مفيش بلوكات بوكسات ولا رئيسيات)',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBoxColumn({
    required String label,
    required int blocksCount,
    required int startSlot,
    required List<BoxModel> boxes,
  }) {
    if (blocksCount == 0) return const SizedBox.shrink();
    return Expanded(
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(height: 4),
          Expanded(
            child: ListView.builder(
              itemCount: blocksCount,
              itemBuilder: (context, i) {
                final blockStart = startSlot + i * CabinetModel.boxesPerBlock;
                final blockEnd = blockStart + CabinetModel.boxesPerBlock - 1;
                final boxesInBlock = boxes
                    .where((b) =>
                        b.slotNumber != null &&
                        b.slotNumber! >= blockStart &&
                        b.slotNumber! <= blockEnd)
                    .length;
                return _BlockTile(
                  color: Colors.green,
                  title: 'بلوك بوكسات',
                  subtitle: '$boxesInBlock/${CabinetModel.boxesPerBlock}',
                  onTap: () => _openBoxBlock(blockStart, blockEnd, boxes),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainPairColumn({
    required String label,
    required int blocksCount,
    required int startBlockIndex,
  }) {
    if (blocksCount == 0) return const SizedBox.shrink();
    return Expanded(
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(height: 4),
          Expanded(
            child: ListView.builder(
              itemCount: blocksCount,
              itemBuilder: (context, i) {
                final blockIndex = startBlockIndex + i;
                final pairStart = blockIndex * CabinetModel.mainPairsPerBlock + 1;
                final pairEnd = pairStart + CabinetModel.mainPairsPerBlock - 1;
                return _BlockTile(
                  color: Colors.blue,
                  title: 'بلوك رئيسيات',
                  subtitle: '$pairStart - $pairEnd',
                  onTap: () => _openMainPairBlock(pairStart, pairEnd),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _openBoxBlock(int blockStart, int blockEnd, List<BoxModel> boxes) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        builder: (context, scrollController) {
          final slots = List.generate(
              blockEnd - blockStart + 1, (i) => blockStart + i);
          return ListView.separated(
            controller: scrollController,
            padding: const EdgeInsets.all(16),
            itemCount: slots.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final slot = slots[i];
              BoxModel? box;
              for (final b in boxes) {
                if (b.slotNumber == slot) {
                  box = b;
                  break;
                }
              }
              if (box != null) {
                final b = box;
                return ListTile(
                  leading: const Icon(Icons.inventory_2, color: Colors.green),
                  title: Text(b.name),
                  subtitle: Text('سلوت $slot · ${b.terminalsCount} ترمنال'),
                  trailing: const Icon(Icons.chevron_left),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => BoxDetailsScreen(box: b),
                      ),
                    );
                  },
                );
              }
              return ListTile(
                leading: const Icon(Icons.add_circle_outline, color: Colors.grey),
                title: Text('سلوت $slot فاضي'),
                subtitle: const Text('اضغط لإضافة بوكس هنا'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          AddBoxScreen(areaId: widget.cabinet.areaId),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  void _openMainPairBlock(int pairStart, int pairEnd) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CabinetDetailsScreen(
          cabinet: widget.cabinet,
          pairNumberRange: RangeValues(
            pairStart.toDouble(),
            pairEnd.toDouble(),
          ),
        ),
      ),
    );
  }
}

class _BlockTile extends StatelessWidget {
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _BlockTile({
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            border: Border.all(color: color),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              Text(title, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text(subtitle, style: const TextStyle(fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }
}
