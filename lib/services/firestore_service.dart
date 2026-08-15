// خدمة التعامل مع Firestore - قراءة وكتابة الكبائن والبلوكات والشيلفات
// والبورتات والرئيسيات والبوكسات والترمنالات
//
// هيكل البيانات:
// - cabinets/{cabinetId}
// - cabinets/{cabinetId}/blocks/{blockId}                  (بوكسات/رئيسيات - side + blockNumber، سعة 10)
// - cabinets/{cabinetId}/blocks/{blockId}/mainPairs/{id}    (لو النوع mainPair)
// - cabinets/{cabinetId}/shelves/{shelfId}                  (بورتات - كابينة فيبر بس، ثابت 32 مشط × 16 بورت)
// - cabinets/{cabinetId}/shelves/{shelfId}/ports/{portId}   (portNumber متسلسل 1-512)
// - boxes/{boxId}                                           (top-level، فيها blockId+positionInBlock)
// - boxes/{boxId}/terminals/{terminalId}
//
// سلسلة تتبع الرقم: الترمنال <-> الرئيسي <-> البورت
// الربط بين كل حلقة والتانية **حر بالكامل يدوي** - مفيش أي ربط تلقائي
// بالترتيب بين بلوك بوكسات وبلوك رئيسيات أو شيلف بورتات. كل عنصر بيتحدد
// له مصدر/وجهة لوحده.
//
// أي تعديل في رقم التليفون بيتزامن تلقائيًا مع كل نقطة في السلسلة عن طريق
// setTerminalSource (من اتجاه الترمنال) أو setMainPairDestination/
// setPortDestinationBox (من اتجاه الرئيسي/البورت - بتنفذ نفس المنطق).

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/area_model.dart';
import '../models/block_model.dart';
import '../models/box_model.dart';
import '../models/cabinet_model.dart';
import '../models/main_pair_model.dart';
import '../models/port_model.dart';
import '../models/shelf_model.dart';
import '../models/terminal_model.dart';

class FirestoreService {
  final _db = FirebaseFirestore.instance;

  // ==================== كبائن ====================

  Stream<List<CabinetModel>> streamCabinets(String areaId) {
    return _db
        .collection('cabinets')
        .where('areaId', isEqualTo: areaId)
        .snapshots()
        .map((snap) =>
        snap.docs.map((d) => CabinetModel.fromMap(d.id, d.data())).toList());
  }

  Stream<CabinetModel?> streamCabinet(String cabinetId) {
    return _db.collection('cabinets').doc(cabinetId).snapshots().map(
          (doc) => doc.exists ? CabinetModel.fromMap(doc.id, doc.data()!) : null,
    );
  }

  Future<String> addCabinet({
    required String name,
    required String code,
    required CabinetType type,
    required String areaId,
    required double latitude,
    required double longitude,
    String? notes,
  }) async {
    final ref = _db.collection('cabinets').doc();
    await ref.set(CabinetModel(
      id: ref.id,
      name: name,
      code: code,
      type: type,
      areaId: areaId,
      latitude: latitude,
      longitude: longitude,
      notes: notes,
    ).toMap());
    return ref.id;
  }

  Future<void> updateCabinet(
      String cabinetId,
      Map<String, dynamic> data,
      ) async {
    await _db.collection('cabinets').doc(cabinetId).update(data);
  }

  // بيربط كابينة نحاس بكابينة فيبر "أب". كابينة النحاس مسموح ليها بأب واحد
  // بس طول عمرها - أول ما تتربط بكابينة فيبر مينفعش تترّبط بكابينة فيبر تانية.
  Future<void> linkCopperCabinetToParent(
      String copperCabinetId,
      String fiberCabinetId,
      ) async {
    final copperRef = _db.collection('cabinets').doc(copperCabinetId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(copperRef);
      if (!snap.exists) {
        throw Exception('الكابينة النحاس المختارة مش موجودة');
      }
      final currentParent = snap.data()?['parentCabinetId'] as String?;
      if (currentParent != null && currentParent != fiberCabinetId) {
        throw Exception(
          'الكابينة النحاس دي متوصلة بالفعل بكابينة فيبر تانية، مينفعش تتوصل من هنا كمان',
        );
      }
      if (currentParent == null) {
        tx.update(copperRef, {'parentCabinetId': fiberCabinetId});
      }
    });
  }

  // ==================== بلوكات (بوكسات / رئيسيات) ====================

  Stream<List<BlockModel>> streamBlocks(String cabinetId) {
    return _db
        .collection('cabinets')
        .doc(cabinetId)
        .collection('blocks')
        .orderBy('blockNumber')
        .snapshots()
        .map((snap) =>
        snap.docs.map((d) => BlockModel.fromMap(d.id, d.data())).toList());
  }

  // بيضيف بلوك جديد في عمود معين (شمال أو يمين) على الكابينة. رقمه بيتحدد
  // تلقائيًا = آخر بلوك في نفس العمود ده + 1 (كل عمود ترقيمه مستقل).
  // لو النوع mainPair بيولّد 10 عناصر فاضية جواه على طول.
  // لو النوع box، مبيولّدش حاجة - البوكسات بتتضاف يدوي من الفني.
  Future<String> addBlock({
    required String cabinetId,
    required BlockSide side,
    required BlockType type,
  }) async {
    final blocksRef = _db.collection('cabinets').doc(cabinetId).collection('blocks');
    final existingInSide = await blocksRef
        .where('side', isEqualTo: side.name)
        .orderBy('blockNumber', descending: true)
        .limit(1)
        .get();
    final nextNumber = existingInSide.docs.isEmpty
        ? 1
        : ((existingInSide.docs.first.data()['blockNumber'] ?? 0) as int) + 1;

    final blockRef = blocksRef.doc();
    final batch = _db.batch();
    batch.set(
      blockRef,
      BlockModel(id: blockRef.id, blockNumber: nextNumber, side: side, type: type).toMap(),
    );

    if (type == BlockType.mainPair) {
      final pairsRef = blockRef.collection('mainPairs');
      for (int i = 1; i <= BlockModel.capacity; i++) {
        batch.set(pairsRef.doc(), MainPairModel(id: '', pairNumber: i).toMap());
      }
    }

    await batch.commit();
    return blockRef.id;
  }

  Future<void> updateBlock(
      String cabinetId,
      String blockId,
      Map<String, dynamic> data,
      ) async {
    await _db
        .collection('cabinets')
        .doc(cabinetId)
        .collection('blocks')
        .doc(blockId)
        .update(data);
  }

  // ==================== شيلفات وبورتات (كابينة فيبر بس) ====================

  Stream<List<ShelfModel>> streamShelves(String fiberCabinetId) {
    return _db
        .collection('cabinets')
        .doc(fiberCabinetId)
        .collection('shelves')
        .orderBy('shelfNumber')
        .snapshots()
        .map((snap) => snap.docs.map((d) => ShelfModel.fromMap(d.id, d.data())).toList());
  }

  // بيضيف شيلف جديد ويولّد كل الـ 512 بورت جواه أوتوماتيك (32 مشط × 16 بورت).
  // رقمه بيتحدد تلقائيًا = آخر شيلف + 1.
  // ملحوظة: Firestore batch محدود بـ 500 عملية، فبنقسّم الكتابة على أكتر من
  // batch (16 بورت في كل batch عشان نفضل تحت الحد بأمان).
  Future<String> addShelf({
    required String fiberCabinetId,
    String? notes,
  }) async {
    final shelvesRef = _db.collection('cabinets').doc(fiberCabinetId).collection('shelves');
    final existing = await shelvesRef.orderBy('shelfNumber', descending: true).limit(1).get();
    final nextNumber =
    existing.docs.isEmpty ? 1 : ((existing.docs.first.data()['shelfNumber'] ?? 0) as int) + 1;

    final shelfRef = shelvesRef.doc();
    await shelfRef.set(ShelfModel(id: shelfRef.id, shelfNumber: nextNumber, notes: notes).toMap());

    final portsRef = shelfRef.collection('ports');
    final totalPorts = ShelfModel.combsPerShelf * ShelfModel.portsPerComb; // 512
    for (int start = 1; start <= totalPorts; start += PortModel.portsPerComb) {
      final batch = _db.batch();
      final end = (start + PortModel.portsPerComb - 1).clamp(1, totalPorts);
      for (int n = start; n <= end; n++) {
        batch.set(portsRef.doc(), PortModel(id: '', portNumber: n).toMap());
      }
      await batch.commit();
    }

    return shelfRef.id;
  }

  Future<void> updateShelf(
      String fiberCabinetId,
      String shelfId,
      Map<String, dynamic> data,
      ) async {
    await _db
        .collection('cabinets')
        .doc(fiberCabinetId)
        .collection('shelves')
        .doc(shelfId)
        .update(data);
  }

  Stream<List<PortModel>> streamPortsInShelf(String fiberCabinetId, String shelfId) {
    return _db
        .collection('cabinets')
        .doc(fiberCabinetId)
        .collection('shelves')
        .doc(shelfId)
        .collection('ports')
        .orderBy('portNumber')
        .snapshots()
        .map((snap) => snap.docs.map((d) => PortModel.fromMap(d.id, d.data())).toList());
  }

  // تحديث عام لحقول بورت (تعطيل/ملاحظات)
  Future<void> updatePort(
      String fiberCabinetId,
      String shelfId,
      String portId,
      Map<String, dynamic> data,
      ) async {
    await _db
        .collection('cabinets')
        .doc(fiberCabinetId)
        .collection('shelves')
        .doc(shelfId)
        .collection('ports')
        .doc(portId)
        .update(data);
  }

  // بيحدد البورت كـ direct (FTTH) ببيانات عميل مباشرة عليه من غير بوكس وسيط
  Future<void> setPortDirect({
    required String fiberCabinetId,
    required String shelfId,
    required String portId,
    required String? phoneNumber,
    String? customerName,
    dynamic customerType,
    dynamic isolationStatus,
  }) async {
    await _db
        .collection('cabinets')
        .doc(fiberCabinetId)
        .collection('shelves')
        .doc(shelfId)
        .collection('ports')
        .doc(portId)
        .update({
      'destinationType': PortDestinationType.direct.name,
      'phoneNumber': phoneNumber,
      'customerName': customerName,
      'customerType': customerType?.name,
      'isolationStatus': isolationStatus?.name,
      'destinationBoxId': null,
      'destinationTerminalId': null,
      'destinationCopperCabinetId': null,
      'destinationMainPairBlockId': null,
      'destinationMainPairId': null,
    });
  }

  // بيوصل بورت مباشرة ببوكس + ترمنال محدد (بيستخدم نفس منطق setTerminalSource
  // من اتجاه البورت)
  Future<void> setPortDestinationBox({
    required String fiberCabinetId,
    required String shelfId,
    required String portId,
    required String boxId,
    required String terminalId,
    required String? phoneNumber,
  }) async {
    await setTerminalSource(
      boxId: boxId,
      terminalId: terminalId,
      sourceCabinetId: fiberCabinetId,
      sourceCabinetType: CabinetType.portBox,
      sourceBlockId: null,
      sourceShelfId: shelfId,
      sourceId: portId,
      phoneNumber: phoneNumber,
    );
  }

  // ==================== بوكسات ====================

  Stream<List<BoxModel>> streamBoxes(String areaId) {
    return _db
        .collection('boxes')
        .where('areaId', isEqualTo: areaId)
        .snapshots()
        .map((snap) => snap.docs.map((d) => BoxModel.fromMap(d.id, d.data())).toList());
  }

  Stream<List<BoxModel>> streamBoxesForCabinet(String cabinetId) {
    return _db
        .collection('boxes')
        .where('parentCabinetId', isEqualTo: cabinetId)
        .snapshots()
        .map((snap) => snap.docs.map((d) => BoxModel.fromMap(d.id, d.data())).toList());
  }

  Stream<List<BoxModel>> streamBoxesInBlock(String cabinetId, String blockId) {
    return _db
        .collection('boxes')
        .where('parentCabinetId', isEqualTo: cabinetId)
        .where('blockId', isEqualTo: blockId)
        .snapshots()
        .map((snap) => snap.docs.map((d) => BoxModel.fromMap(d.id, d.data())).toList());
  }

  Stream<BoxModel?> streamBox(String boxId) {
    return _db.collection('boxes').doc(boxId).snapshots().map(
          (doc) => doc.exists ? BoxModel.fromMap(doc.id, doc.data()!) : null,
    );
  }

  // بيضيف بوكس في مكان محدد (blockId + positionInBlock). بيرفض لو المكان متاخد.
  Future<String> addBox({
    required String name,
    required String parentCabinetId,
    required String blockId,
    required int positionInBlock,
    required String areaId,
    required double latitude,
    required double longitude,
    String? notes,
  }) async {
    if (positionInBlock < 1 || positionInBlock > BlockModel.capacity) {
      throw Exception('المكان جوه البلوك لازم يكون بين 1 و ${BlockModel.capacity}');
    }

    final existing = await _db
        .collection('boxes')
        .where('blockId', isEqualTo: blockId)
        .where('positionInBlock', isEqualTo: positionInBlock)
        .limit(1)
        .get();
    if (existing.docs.isNotEmpty) {
      throw Exception('المكان ده متاخد بالفعل ببوكس تاني');
    }

    final ref = _db.collection('boxes').doc();
    await ref.set(BoxModel(
      id: ref.id,
      name: name,
      parentCabinetId: parentCabinetId,
      blockId: blockId,
      positionInBlock: positionInBlock,
      areaId: areaId,
      latitude: latitude,
      longitude: longitude,
      notes: notes,
    ).toMap());
    return ref.id;
  }

  Future<void> updateBox(String boxId, Map<String, dynamic> data) async {
    await _db.collection('boxes').doc(boxId).update(data);
  }

  // ==================== ترمنالات ====================

  Stream<List<TerminalModel>> streamTerminals(String boxId) {
    return _db
        .collection('boxes')
        .doc(boxId)
        .collection('terminals')
        .orderBy('terminalNumber')
        .snapshots()
        .map((snap) => snap.docs.map((d) => TerminalModel.fromMap(d.id, d.data())).toList());
  }

  Future<void> ensureTerminalsCount(String boxId, int count) async {
    final termsRef = _db.collection('boxes').doc(boxId).collection('terminals');
    final snap = await termsRef.get();
    final existingNumbers =
    snap.docs.map((d) => (d.data()['terminalNumber'] as num?)?.toInt() ?? 0).toSet();

    final batch = _db.batch();
    var hasChanges = false;
    for (int i = 1; i <= count; i++) {
      if (!existingNumbers.contains(i)) {
        final ref = termsRef.doc();
        batch.set(ref, TerminalModel(id: ref.id, terminalNumber: i).toMap());
        hasChanges = true;
      }
    }
    if (hasChanges) await batch.commit();
  }

  // بيحدّث بيانات ترمنال عادية (اسم/نوع/عزل/تعطيل) - من غير ما يلمس الربط بالمصدر.
  // استخدم setTerminalSource لأي تعديل بيمس sourceId أو رقم التليفون.
  Future<void> updateTerminal(
      String boxId,
      String terminalId,
      Map<String, dynamic> data,
      ) async {
    await _db.collection('boxes').doc(boxId).collection('terminals').doc(terminalId).update(data);
  }

  // ---- الدالة الجوهرية للربط: بتربط ترمنال بمصدره الفعلي (بورت أو رئيسي) ----
  // بتشتغل من أي الاتجاهين (من شاشة البوكس، أو من شاشة البورت/الرئيسي).
  // مرّر sourceId = null لفك الربط.
  // sourceBlockId يتبعت لو المصدر رئيسي، sourceShelfId يتبعت لو المصدر بورت
  // (الاتنين مش هيبقوا مبعوتين مع بعض).
  Future<void> setTerminalSource({
    required String boxId,
    required String terminalId,
    required String sourceCabinetId,
    required CabinetType sourceCabinetType,
    required String? sourceBlockId,
    required String? sourceShelfId,
    required String? sourceId,
    required String? phoneNumber,
  }) async {
    final terminalRef = _db.collection('boxes').doc(boxId).collection('terminals').doc(terminalId);

    if (sourceId == null) {
      final oldSnap = await terminalRef.get();
      final oldCabinetId = oldSnap.data()?['sourceCabinetId'] as String?;
      final oldBlockId = oldSnap.data()?['sourceBlockId'] as String?;
      final oldShelfId = oldSnap.data()?['sourceShelfId'] as String?;
      final oldSourceId = oldSnap.data()?['sourceId'] as String?;

      await terminalRef.update({
        'sourceCabinetId': null,
        'sourceBlockId': null,
        'sourceShelfId': null,
        'sourceId': null,
      });

      if (oldCabinetId != null && oldSourceId != null) {
        await _clearSourceDestination(oldCabinetId, oldBlockId, oldShelfId, oldSourceId);
      }
      return;
    }

    final batch = _db.batch();
    batch.update(terminalRef, {
      'sourceCabinetId': sourceCabinetId,
      'sourceBlockId': sourceBlockId,
      'sourceShelfId': sourceShelfId,
      'sourceId': sourceId,
    });

    if (sourceCabinetType == CabinetType.copper) {
      final pairRef = _db
          .collection('cabinets')
          .doc(sourceCabinetId)
          .collection('blocks')
          .doc(sourceBlockId)
          .collection('mainPairs')
          .doc(sourceId);
      batch.update(pairRef, {
        'phoneNumber': phoneNumber,
        'destinationBoxId': boxId,
        'destinationTerminalId': terminalId,
      });
    } else {
      final portRef = _db
          .collection('cabinets')
          .doc(sourceCabinetId)
          .collection('shelves')
          .doc(sourceShelfId)
          .collection('ports')
          .doc(sourceId);
      batch.update(portRef, {
        'phoneNumber': phoneNumber,
        'destinationType': PortDestinationType.box.name,
        'destinationBoxId': boxId,
        'destinationTerminalId': terminalId,
        'destinationCopperCabinetId': null,
        'destinationMainPairBlockId': null,
        'destinationMainPairId': null,
      });
    }
    await batch.commit();

    // لو المصدر رئيسي، نكمّل السلسلة لحد البورت الأصلي بتاعه (لو موصول)
    // عشان الرقم يبان صح من أول نقطة في السلسلة كمان.
    if (sourceCabinetType == CabinetType.copper && sourceBlockId != null) {
      final pairSnap = await _db
          .collection('cabinets')
          .doc(sourceCabinetId)
          .collection('blocks')
          .doc(sourceBlockId)
          .collection('mainPairs')
          .doc(sourceId)
          .get();
      final srcPortCabinetId = pairSnap.data()?['sourceCabinetId'] as String?;
      final srcPortShelfId = pairSnap.data()?['sourceShelfId'] as String?;
      final srcPortId = pairSnap.data()?['sourcePortId'] as String?;
      if (srcPortCabinetId != null && srcPortShelfId != null && srcPortId != null) {
        await _db
            .collection('cabinets')
            .doc(srcPortCabinetId)
            .collection('shelves')
            .doc(srcPortShelfId)
            .collection('ports')
            .doc(srcPortId)
            .update({'phoneNumber': phoneNumber});
      }
    }
  }

  // بتصفّي وجهة بورت أو رئيسي (لما ترمنال يتفك من مصدره) - من غير ما تمسح
  // مصدره هو نفسه (مصدر الرئيسي وهو البورت بيفضل زي ما هو).
  Future<void> _clearSourceDestination(
      String cabinetId,
      String? blockId,
      String? shelfId,
      String sourceId,
      ) async {
    if (blockId != null) {
      await _db
          .collection('cabinets')
          .doc(cabinetId)
          .collection('blocks')
          .doc(blockId)
          .collection('mainPairs')
          .doc(sourceId)
          .update({
        'phoneNumber': null,
        'destinationBoxId': null,
        'destinationTerminalId': null,
      });
    } else if (shelfId != null) {
      await _db
          .collection('cabinets')
          .doc(cabinetId)
          .collection('shelves')
          .doc(shelfId)
          .collection('ports')
          .doc(sourceId)
          .update({
        'phoneNumber': null,
        'destinationType': null,
        'destinationBoxId': null,
        'destinationTerminalId': null,
      });
    }
  }

  Future<void> swapTerminals(String boxId, TerminalModel a, TerminalModel b) async {
    final termsRef = _db.collection('boxes').doc(boxId).collection('terminals');
    final batch = _db.batch();
    batch.update(termsRef.doc(a.id), {
      'phoneNumber': b.phoneNumber,
      'customerName': b.customerName,
      'customerType': b.customerType?.name,
      'isFaulty': b.isFaulty,
      'isolationStatus': b.isolationStatus.name,
      'crossConnectedTo': b.crossConnectedTo,
      'notes': b.notes,
      'sourceCabinetId': b.sourceCabinetId,
      'sourceBlockId': b.sourceBlockId,
      'sourceShelfId': b.sourceShelfId,
      'sourceId': b.sourceId,
    });
    batch.update(termsRef.doc(b.id), {
      'phoneNumber': a.phoneNumber,
      'customerName': a.customerName,
      'customerType': a.customerType?.name,
      'isFaulty': a.isFaulty,
      'isolationStatus': a.isolationStatus.name,
      'crossConnectedTo': a.crossConnectedTo,
      'notes': a.notes,
      'sourceCabinetId': a.sourceCabinetId,
      'sourceBlockId': a.sourceBlockId,
      'sourceShelfId': a.sourceShelfId,
      'sourceId': a.sourceId,
    });
    await batch.commit();

    if (a.sourceId != null) {
      await _syncSourcePhoneOnly(
          a.sourceCabinetId, a.sourceBlockId, a.sourceShelfId, a.sourceId, b.phoneNumber);
    }
    if (b.sourceId != null) {
      await _syncSourcePhoneOnly(
          b.sourceCabinetId, b.sourceBlockId, b.sourceShelfId, b.sourceId, a.phoneNumber);
    }
  }

  Future<void> _syncSourcePhoneOnly(
      String? cabinetId,
      String? blockId,
      String? shelfId,
      String? sourceId,
      String? phoneNumber,
      ) async {
    if (cabinetId == null || sourceId == null) return;

    if (blockId != null) {
      final pairRef = _db
          .collection('cabinets')
          .doc(cabinetId)
          .collection('blocks')
          .doc(blockId)
          .collection('mainPairs')
          .doc(sourceId);
      await pairRef.update({'phoneNumber': phoneNumber});

      final pairSnap = await pairRef.get();
      final srcPortCabinetId = pairSnap.data()?['sourceCabinetId'] as String?;
      final srcPortShelfId = pairSnap.data()?['sourceShelfId'] as String?;
      final srcPortId = pairSnap.data()?['sourcePortId'] as String?;
      if (srcPortCabinetId != null && srcPortShelfId != null && srcPortId != null) {
        await _db
            .collection('cabinets')
            .doc(srcPortCabinetId)
            .collection('shelves')
            .doc(srcPortShelfId)
            .collection('ports')
            .doc(srcPortId)
            .update({'phoneNumber': phoneNumber});
      }
    } else if (shelfId != null) {
      await _db
          .collection('cabinets')
          .doc(cabinetId)
          .collection('shelves')
          .doc(shelfId)
          .collection('ports')
          .doc(sourceId)
          .update({'phoneNumber': phoneNumber});
    }
  }

  // ==================== رئيسيات (جوه بلوك، كابينة نحاس بس) ====================

  Stream<List<MainPairModel>> streamMainPairsInBlock(String copperCabinetId, String blockId) {
    return _db
        .collection('cabinets')
        .doc(copperCabinetId)
        .collection('blocks')
        .doc(blockId)
        .collection('mainPairs')
        .orderBy('pairNumber')
        .snapshots()
        .map((snap) => snap.docs.map((d) => MainPairModel.fromMap(d.id, d.data())).toList());
  }

  Future<void> updateMainPair(
      String copperCabinetId,
      String blockId,
      String pairId,
      Map<String, dynamic> data,
      ) async {
    await _db
        .collection('cabinets')
        .doc(copperCabinetId)
        .collection('blocks')
        .doc(blockId)
        .collection('mainPairs')
        .doc(pairId)
        .update(data);
  }

  // بيحدد مصدر رئيسي معين: أنهي بورت في أنهي شيلف في أنهي كابينة فايبر
  // بياخد منه. بيقفل تلقائيًا إن الكابينة النحاس دي أبوها الكابينة الفايبر
  // دي (أول مرة بس)، وبيزامن رقم التليفون لو الرئيسي كان بالفعل مشغول.
  Future<void> assignMainPairSource({
    required String copperCabinetId,
    required String blockId,
    required String pairId,
    required String sourceFiberCabinetId,
    required String sourcePortShelfId,
    required String sourcePortId,
  }) async {
    await linkCopperCabinetToParent(copperCabinetId, sourceFiberCabinetId);

    final pairRef = _db
        .collection('cabinets')
        .doc(copperCabinetId)
        .collection('blocks')
        .doc(blockId)
        .collection('mainPairs')
        .doc(pairId);
    final portRef = _db
        .collection('cabinets')
        .doc(sourceFiberCabinetId)
        .collection('shelves')
        .doc(sourcePortShelfId)
        .collection('ports')
        .doc(sourcePortId);

    final pairSnap = await pairRef.get();
    final existingPhone = pairSnap.data()?['phoneNumber'] as String?;

    final batch = _db.batch();
    batch.update(pairRef, {
      'sourceCabinetId': sourceFiberCabinetId,
      'sourceShelfId': sourcePortShelfId,
      'sourcePortId': sourcePortId,
    });
    batch.update(portRef, {
      'destinationType': PortDestinationType.copperMainPair.name,
      'destinationCopperCabinetId': copperCabinetId,
      'destinationMainPairBlockId': blockId,
      'destinationMainPairId': pairId,
      'phoneNumber': existingPhone,
      'destinationBoxId': null,
      'destinationTerminalId': null,
    });
    await batch.commit();
  }

  // بيوصل رئيسي مباشرة ببوكس + ترمنال محدد (بيستخدم نفس منطق setTerminalSource
  // من اتجاه الرئيسي)
  Future<void> setMainPairDestination({
    required String copperCabinetId,
    required String blockId,
    required String pairId,
    required String boxId,
    required String terminalId,
    required String? phoneNumber,
  }) async {
    await setTerminalSource(
      boxId: boxId,
      terminalId: terminalId,
      sourceCabinetId: copperCabinetId,
      sourceCabinetType: CabinetType.copper,
      sourceBlockId: blockId,
      sourceShelfId: null,
      sourceId: pairId,
      phoneNumber: phoneNumber,
    );
  }

  // ==================== بيانات تجريبية ====================

  Future<void> seedSampleData(String areaId) async {
    final areaRef = _db.collection('areas').doc(areaId);
    await areaRef.set(AreaModel(id: areaId, name: 'منطقة تجريبية').toMap());

    final cab1 = _db.collection('cabinets').doc();
    await cab1.set(CabinetModel(
      id: cab1.id,
      name: 'كابينة PB-01',
      code: 'PB-01',
      type: CabinetType.portBox,
      areaId: areaId,
      latitude: 30.0444,
      longitude: 31.2357,
    ).toMap());

    final cab2 = _db.collection('cabinets').doc();
    await cab2.set(CabinetModel(
      id: cab2.id,
      name: 'كابينة نحاس C-01',
      code: 'C-01',
      type: CabinetType.copper,
      areaId: areaId,
      latitude: 30.0460,
      longitude: 31.2380,
    ).toMap());

    final shelfId = await addShelf(fiberCabinetId: cab1.id);
    final fiberBoxBlockId =
    await addBlock(cabinetId: cab1.id, side: BlockSide.left, type: BlockType.box);
    final mainPairBlockId =
    await addBlock(cabinetId: cab2.id, side: BlockSide.left, type: BlockType.mainPair);
    final copperBoxBlockId =
    await addBlock(cabinetId: cab2.id, side: BlockSide.right, type: BlockType.box);

    final box1 = await addBox(
      name: 'بوكس B-01',
      parentCabinetId: cab2.id,
      blockId: copperBoxBlockId,
      positionInBlock: 1,
      areaId: areaId,
      latitude: 30.0470,
      longitude: 31.2390,
    );

    await addBox(
      name: 'بوكس B-02',
      parentCabinetId: cab1.id,
      blockId: fiberBoxBlockId,
      positionInBlock: 1,
      areaId: areaId,
      latitude: 30.0430,
      longitude: 31.2340,
    );

    await ensureTerminalsCount(box1, 5);
    final termsRef = _db.collection('boxes').doc(box1).collection('terminals');
    final termsSnap = await termsRef.orderBy('terminalNumber').get();
    for (int i = 0; i < termsSnap.docs.length; i++) {
      final t = termsSnap.docs[i];
      final num = i + 1;
      await termsRef.doc(t.id).update({
        'customerName': 'عميل تجريبي $num',
        'customerType':
        num % 2 == 0 ? CustomerType.service160.name : CustomerType.voice.name,
        'isFaulty': num == 3,
        'isolationStatus': num == 1 ? IsolationStatus.ok.name : IsolationStatus.unknown.name,
      });
    }

    final firstPairSnap = await _db
        .collection('cabinets')
        .doc(cab2.id)
        .collection('blocks')
        .doc(mainPairBlockId)
        .collection('mainPairs')
        .orderBy('pairNumber')
        .limit(1)
        .get();
    final firstPortSnap = await _db
        .collection('cabinets')
        .doc(cab1.id)
        .collection('shelves')
        .doc(shelfId)
        .collection('ports')
        .orderBy('portNumber')
        .limit(1)
        .get();

    if (firstPairSnap.docs.isNotEmpty && firstPortSnap.docs.isNotEmpty) {
      final pairId = firstPairSnap.docs.first.id;
      final portId = firstPortSnap.docs.first.id;

      await assignMainPairSource(
        copperCabinetId: cab2.id,
        blockId: mainPairBlockId,
        pairId: pairId,
        sourceFiberCabinetId: cab1.id,
        sourcePortShelfId: shelfId,
        sourcePortId: portId,
      );

      if (termsSnap.docs.isNotEmpty) {
        final termId = termsSnap.docs.first.id;
        await termsRef.doc(termId).update({'phoneNumber': '01000000099'});
        await setTerminalSource(
          boxId: box1,
          terminalId: termId,
          sourceCabinetId: cab2.id,
          sourceCabinetType: CabinetType.copper,
          sourceBlockId: mainPairBlockId,
          sourceShelfId: null,
          sourceId: pairId,
          phoneNumber: '01000000099',
        );
      }
    }
  }
}