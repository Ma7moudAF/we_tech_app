// شاشة "الكابينة من جوه" - رسمة بصرية بالبلوكات الفعلية المتخزنة في Firestore:
// - عمود أقصى اليمين وعمود أقصى الشمال = بلوكات بوكسات (كل بلوك = 10 بوكسات)
// - عمود النص اليمين وعمود النص الشمال = بلوكات رئيسيات (كل بلوك = 10 رئيسي)
// البلوكات بتتقرأ من streamBlocks (مش من حقول محسوبة على الكابينة - دي
// مش موجودة أصلًا في CabinetModel). الترقيم (بوكسات ورئيسيات) بيبدأ من 1
// جوه كل بلوك لوحده - مفيش رقم عام على الكابينة كلها.

import 'package:flutter/material.dart';

import '../models/block_model.dart';
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
  bool _isAddingBlock = false;

  // بيفتح دايالوج بسيط يختار منه الفني الجانب (شمال/يمين) ونوع البلوك
  // (بوكسات/رئيسيات)، وبعدين بينفذ addBlock فعليًا في Firestore.
  Future<void> _showAddBlockDialog() async {
    BlockSide side = BlockSide.left;
    BlockType type = BlockType.box;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('إضافة بلوك جديد'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('الجانب'),
              const SizedBox(height: 4),
              SegmentedButton<BlockSide>(
                segments: const [
                  ButtonSegment(value: BlockSide.left, label: Text('شمال')),
                  ButtonSegment(value: BlockSide.right, label: Text('يمين')),
                ],
                selected: {side},
                onSelectionChanged: (v) => setDialogState(() => side = v.first),
              ),
              const SizedBox(height: 16),
              const Text('نوع البلوك'),
              const SizedBox(height: 4),
              SegmentedButton<BlockType>(
                segments: const [
                  ButtonSegment(value: BlockType.box, label: Text('بوكسات')),
                  ButtonSegment(value: BlockType.mainPair, label: Text('رئيسيات')),
                ],
                selected: {type},
                onSelectionChanged: (v) => setDialogState(() => type = v.first),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('إضافة'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    setState(() => _isAddingBlock = true);
    try {
      await _firestoreService.addBlock(
        cabinetId: widget.cabinet.id,
        side: side,
        type: type,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حصل خطأ أثناء إضافة البلوك: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isAddingBlock = false);
    }
  }

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
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isAddingBlock ? null : _showAddBlockDialog,
        icon: _isAddingBlock
            ? const SizedBox(
          height: 16,
          width: 16,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
        )
            : const Icon(Icons.add),
        label: const Text('إضافة بلوك'),
      ),
      body: StreamBuilder<List<BlockModel>>(
        stream: _firestoreService.streamBlocks(cabinet.id),
        builder: (context, blocksSnapshot) {
          if (blocksSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final blocks = blocksSnapshot.data ?? [];

          if (blocks.isEmpty) {
            return _buildEmptyState();
          }

          final boxBlocksLeft = blocks
              .where((b) => b.type == BlockType.box && b.side == BlockSide.left)
              .toList()
            ..sort((a, b) => a.blockNumber.compareTo(b.blockNumber));
          final boxBlocksRight = blocks
              .where((b) => b.type == BlockType.box && b.side == BlockSide.right)
              .toList()
            ..sort((a, b) => a.blockNumber.compareTo(b.blockNumber));
          final mainPairBlocksLeft = blocks
              .where((b) => b.type == BlockType.mainPair && b.side == BlockSide.left)
              .toList()
            ..sort((a, b) => a.blockNumber.compareTo(b.blockNumber));
          final mainPairBlocksRight = blocks
              .where((b) => b.type == BlockType.mainPair && b.side == BlockSide.right)
              .toList()
            ..sort((a, b) => a.blockNumber.compareTo(b.blockNumber));

          return StreamBuilder<List<BoxModel>>(
            stream: _firestoreService.streamBoxesForCabinet(cabinet.id),
            builder: (context, boxesSnapshot) {
              final boxes = boxesSnapshot.data ?? [];

              return Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  // ترتيب الأعمدة من الشمال لليمين في الكود:
                  // بوكسات شمال - رئيسيات نص-شمال - رئيسيات نص-يمين - بوكسات يمين
                  // وبما إن التطبيق RTL، أول عنصر في الليستة بيظهر أقصى اليمين تلقائيًا
                  children: [
                    _buildBoxColumn(
                      label: 'بوكسات يمين',
                      blocks: boxBlocksRight,
                      boxes: boxes,
                    ),
                    const SizedBox(width: 8),
                    _buildMainPairColumn(
                      label: 'رئيسيات يمين',
                      blocks: mainPairBlocksRight,
                    ),
                    const SizedBox(width: 4),
                    _buildMainPairColumn(
                      label: 'رئيسيات شمال',
                      blocks: mainPairBlocksLeft,
                    ),
                    const SizedBox(width: 8),
                    _buildBoxColumn(
                      label: 'بوكسات شمال',
                      blocks: boxBlocksLeft,
                      boxes: boxes,
                    ),
                  ],
                ),
              );
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
            Icon(Icons.dashboard_customize_outlined,
                size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text(
              'الكابينة دي لسه ملهاش شكل محدد (مفيش بلوكات بوكسات ولا رئيسيات)\n'
                  'دوس على "إضافة بلوك" تحت عشان تبدأ',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBoxColumn({
    required String label,
    required List<BlockModel> blocks,
    required List<BoxModel> boxes,
  }) {
    if (blocks.isEmpty) return const SizedBox.shrink();
    return Expanded(
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(height: 4),
          Expanded(
            child: ListView.builder(
              itemCount: blocks.length,
              itemBuilder: (context, i) {
                final block = blocks[i];
                final boxesInBlock =
                    boxes.where((b) => b.blockId == block.id).length;
                return _BlockTile(
                  color: Colors.green,
                  title: 'بلوك بوكسات ${block.blockNumber}',
                  subtitle: '$boxesInBlock/${BlockModel.capacity}',
                  onTap: () => _openBoxBlock(block, boxes),
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
    required List<BlockModel> blocks,
  }) {
    if (blocks.isEmpty) return const SizedBox.shrink();
    return Expanded(
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(height: 4),
          Expanded(
            child: ListView.builder(
              itemCount: blocks.length,
              itemBuilder: (context, i) {
                final block = blocks[i];
                return _BlockTile(
                  color: Colors.blue,
                  title: 'بلوك رئيسيات ${block.blockNumber}',
                  subtitle: '1 - ${BlockModel.capacity}',
                  onTap: () => _openMainPairBlock(block),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _openBoxBlock(BlockModel block, List<BoxModel> boxes) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        builder: (context, scrollController) {
          final positions = List.generate(BlockModel.capacity, (i) => i + 1);
          return ListView.separated(
            controller: scrollController,
            padding: const EdgeInsets.all(16),
            itemCount: positions.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final position = positions[i];
              BoxModel? box;
              for (final b in boxes) {
                if (b.blockId == block.id && b.positionInBlock == position) {
                  box = b;
                  break;
                }
              }
              if (box != null) {
                final b = box;
                return ListTile(
                  leading: const Icon(Icons.inventory_2, color: Colors.green),
                  title: Text(b.name),
                  subtitle: Text('مكان $position · ${b.terminalsCount} ترمنال'),
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
                title: Text('مكان $position فاضي'),
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

  void _openMainPairBlock(BlockModel block) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CabinetDetailsScreen(
          cabinet: widget.cabinet,
          block: block,
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