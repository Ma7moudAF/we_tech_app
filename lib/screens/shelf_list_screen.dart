// شاشة ليستة الشيلفات بتاعة كابينة فيبر معينة - كل شيلف فيه 512 بورت ثابتين
// (32 مشط × 16 بورت) بيتولدوا أوتوماتيك أول ما الشيلف يتضاف.
//
// ملحوظة: الشاشة دي بتسمح بإضافة شيلف وعرض عدده بس - تعديل/تعمير البورتات
// نفسها (تحديد عميل مباشر / وجهة بوكس / وجهة رئيسي لكل بورت) محتاج شاشة
// تفاصيل بورتات منفصلة، مش موجودة في التطبيق لسه (زي شاشة تفاصيل البوكس
// بالظبط لكن للبورتات) - لو عايزها قولّي أبنيها.

import 'package:flutter/material.dart';

import '../models/shelf_model.dart';
import '../services/firestore_service.dart';

class ShelvesListScreen extends StatefulWidget {
  final String fiberCabinetId;
  final String cabinetName;

  const ShelvesListScreen({
    super.key,
    required this.fiberCabinetId,
    required this.cabinetName,
  });

  @override
  State<ShelvesListScreen> createState() => _ShelvesListScreenState();
}

class _ShelvesListScreenState extends State<ShelvesListScreen> {
  final _firestoreService = FirestoreService();
  bool _isAdding = false;

  Future<void> _addShelf() async {
    setState(() => _isAdding = true);
    try {
      await _firestoreService.addShelf(fiberCabinetId: widget.fiberCabinetId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حصل خطأ أثناء إضافة الشيلف: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isAdding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('شيلفات ${widget.cabinetName}')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isAdding ? null : _addShelf,
        icon: _isAdding
            ? const SizedBox(
          height: 16,
          width: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.white,
          ),
        )
            : const Icon(Icons.add),
        label: const Text('إضافة شيلف'),
      ),
      body: StreamBuilder<List<ShelfModel>>(
        stream: _firestoreService.streamShelves(widget.fiberCabinetId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final shelves = snapshot.data ?? [];
          if (shelves.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.dns_outlined,
                        size: 64, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    const Text(
                      'مفيش شيلفات مضافة لسه\nدوس على "إضافة شيلف" تحت',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: shelves.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final shelf = shelves[index];
              return ListTile(
                leading: const Icon(Icons.dns_outlined, color: Colors.purple),
                title: Text('شيلف ${shelf.shelfNumber}'),
                subtitle: Text(
                  '${ShelfModel.combsPerShelf} مشط × ${ShelfModel.portsPerComb} بورت '
                      '(${ShelfModel.totalPortsPerShelf} بورت)'
                      '${shelf.notes != null && shelf.notes!.isNotEmpty ? '\n${shelf.notes}' : ''}',
                ),
                isThreeLine: shelf.notes != null && shelf.notes!.isNotEmpty,
              );
            },
          );
        },
      ),
    );
  }
}