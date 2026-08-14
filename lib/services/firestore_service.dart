// خدمة التعامل مع Firestore - قراءة وكتابة الكبائن والبوكسات والبورتات والرئيسيات والترمنالات
//
// سلسلة تتبع الرقم: الترمنال <-> الرئيسي <-> البورت
// - البورت: بيعيش تحت كابينة الفايبر بس (collection 'ports')
// - الرئيسي: بيعيش تحت كابينة النحاس بس (collection 'mainPairs')، وبيحمل مرجع
//   لمصدره (sourceCabinetId + sourcePortId) عشان تعرف واخد من كابينة فايبر أنهي وبورت كام
// - الترمنال: بيعيش تحت البوكس، وبيحمل مرجع (sourceCabinetId + sourceId) للبورت
//   أو الرئيسي اللي بياخد منه فعليًا (حسب نوع الكابينة الأب بتاعة البوكس)
//
// أي تعديل في رقم التليفون بيتزامن تلقائيًا مع كل نقطة في السلسلة عشان تقدر
// تدور بالرقم من أي مكان وتلاقي مساره كامل.
//
// ملحوظة: الرئيسي كمان ممكن ياخد "وجهة" (destinationType/destinationId) بشكل
// يدوي من شاشة الكابينة نفسها (زي البورت بالظبط) عن طريق setMainPairDestination،
// بشكل منفصل عن destinationBoxId/destinationTerminalId اللي بتتحدث تلقائيًا
// من ناحية الترمنال (setTerminalSource).

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/area_model.dart';
import '../models/box_model.dart';
import '../models/cabinet_model.dart';
import '../models/main_pair_model.dart';
import '../models/port_model.dart';
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
    int mainPairsCount = 0,
    int boxBlocksLeft = 0,
    int boxBlocksRight = 0,
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
      mainPairsCount: mainPairsCount,
      boxBlocksLeft: boxBlocksLeft,
      boxBlocksRight: boxBlocksRight,
      notes: notes,
    ).toMap());
    return ref.id;
  }

  // ==================== بوكسات ====================

  Stream<List<BoxModel>> streamBoxes(String areaId) {
    return _db
        .collection('boxes')
        .where('areaId', isEqualTo: areaId)
        .snapshots()
        .map((snap) =>
        snap.docs.map((d) => BoxModel.fromMap(d.id, d.data())).toList());
  }

  Stream<List<BoxModel>> streamBoxesForCabinet(String cabinetId) {
    return _db
        .collection('boxes')
        .where('parentCabinetId', isEqualTo: cabinetId)
        .snapshots()
        .map((snap) =>
        snap.docs.map((d) => BoxModel.fromMap(d.id, d.data())).toList());
  }

  Future<String> addBox({
    required String name,
    required String parentCabinetId,
    required String areaId,
    required double latitude,
    required double longitude,
    int terminalsCount = BoxModel.combCapacity,
    int? slotNumber,
    String? notes,
  }) async {
    if (!BoxModel.isValidTerminalsCount(terminalsCount)) {
      throw Exception(
        'عدد الترمنالات لازم يكون من مضاعفات ${BoxModel.combCapacity}',
      );
    }

    final ref = _db.collection('boxes').doc();
    await ref.set(BoxModel(
      id: ref.id,
      name: name,
      parentCabinetId: parentCabinetId,
      areaId: areaId,
      latitude: latitude,
      longitude: longitude,
      terminalsCount: terminalsCount,
      slotNumber: slotNumber,
      notes: notes,
    ).toMap());
    return ref.id;
  }

  // بيولّد بوكسات فاضية بالسلوتات المطلوبة على كابينة معينة، من غير ما يدخل
  // أي بيانات ترمنالات (البوكس بيتحفظ بس بمكانه وسعته الافتراضية 10 ترمنال/مشط
  // واحد). بيتجاهل أي سلوت متاخد بالفعل عشان منكررش بوكسات على نفس المكان.
  // مستخدمة لما بتتضاف كابينة وفيها بلوكات بوكسات (كل بلوك = 10 سلوتات:
  // بلوك 1 = سلوت 1-10، بلوك 2 = سلوت 11-20، وهكذا).
  Future<void> generateEmptySlotBoxes({
    required String parentCabinetId,
    required String areaId,
    required double latitude,
    required double longitude,
    required int fromSlot,
    required int toSlot,
    required String namePrefix,
  }) async {
    final existing = await _db
        .collection('boxes')
        .where('parentCabinetId', isEqualTo: parentCabinetId)
        .get();
    final takenSlots = existing.docs
        .map((d) => (d.data()['slotNumber'] as num?)?.toInt())
        .whereType<int>()
        .toSet();

    final batch = _db.batch();
    var hasChanges = false;
    for (int slot = fromSlot; slot <= toSlot; slot++) {
      if (takenSlots.contains(slot)) continue;
      final ref = _db.collection('boxes').doc();
      batch.set(ref, BoxModel(
        id: ref.id,
        name: '$namePrefix-$slot',
        parentCabinetId: parentCabinetId,
        areaId: areaId,
        latitude: latitude,
        longitude: longitude,
        slotNumber: slot,
      ).toMap());
      hasChanges = true;
    }
    if (hasChanges) await batch.commit();
  }

  Stream<BoxModel?> streamBox(String boxId) {
    return _db.collection('boxes').doc(boxId).snapshots().map(
          (doc) => doc.exists ? BoxModel.fromMap(doc.id, doc.data()!) : null,
    );
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
        .map((snap) =>
        snap.docs.map((d) => TerminalModel.fromMap(d.id, d.data())).toList());
  }

  Future<void> ensureTerminalsCount(String boxId, int count) async {
    final termsRef = _db.collection('boxes').doc(boxId).collection('terminals');
    final snap = await termsRef.get();
    final existingNumbers = snap.docs
        .map((d) => (d.data()['terminalNumber'] as num?)?.toInt() ?? 0)
        .toSet();

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
  // استخدم setTerminalSource لأي تعديل بيمس sourceId أو رقم التليفون، عشان
  // يتزامن الرقم صح مع الرئيسي والبورت.
  Future<void> updateTerminal(
      String boxId,
      String terminalId,
      Map<String, dynamic> data,
      ) async {
    await _db
        .collection('boxes')
        .doc(boxId)
        .collection('terminals')
        .doc(terminalId)
        .update(data);
  }

  // بيربط ترمنال بمصدره الفعلي (بورت لو الكابينة الأب فايبر، رئيسي لو نحاس)،
  // وبيزامن رقم التليفون مع كل نقطة في السلسلة (ترمنال <-> رئيسي <-> بورت).
  // مرّر sourceId = null لفك الربط.
  Future<void> setTerminalSource({
    required String boxId,
    required String terminalId,
    required String parentCabinetId,
    required CabinetType parentCabinetType,
    required String? sourceId,
    required String? phoneNumber,
  }) async {
    final terminalRef =
    _db.collection('boxes').doc(boxId).collection('terminals').doc(terminalId);

    if (sourceId == null) {
      await terminalRef.update({'sourceCabinetId': null, 'sourceId': null});
      return;
    }

    final batch = _db.batch();
    batch.update(terminalRef, {
      'sourceCabinetId': parentCabinetId,
      'sourceId': sourceId,
    });

    if (parentCabinetType == CabinetType.copper) {
      final pairRef = _db
          .collection('cabinets')
          .doc(parentCabinetId)
          .collection('mainPairs')
          .doc(sourceId);
      batch.update(pairRef, {
        'phoneNumber': phoneNumber,
        'destinationBoxId': boxId,
        'destinationTerminalId': terminalId,
      });

      // نتابع لحد البورت الأصلي كمان عشان الرقم يبان صح من أول نقطة في السلسلة
      final pairSnap = await pairRef.get();
      final sourcePortId = pairSnap.data()?['sourcePortId'] as String?;
      final sourcePortCabinetId = pairSnap.data()?['sourceCabinetId'] as String?;
      if (sourcePortId != null && sourcePortCabinetId != null) {
        final portRef = _db
            .collection('cabinets')
            .doc(sourcePortCabinetId)
            .collection('ports')
            .doc(sourcePortId);
        batch.update(portRef, {'phoneNumber': phoneNumber});
      }
    } else {
      final portRef =
      _db.collection('cabinets').doc(parentCabinetId).collection('ports').doc(sourceId);
      batch.update(portRef, {
        'phoneNumber': phoneNumber,
        'destinationType': PortDestinationType.box.name,
        'destinationId': boxId,
      });
    }

    await batch.commit();
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
      'sourceId': a.sourceId,
    });
    await batch.commit();

    // بعد التبديل، لازم نحدّث مراجع الرئيسي/البورت بتوع الاتنين عشان تفضل متزامنة
    // (كل ترمنال بقى معاه بيانات التاني، فالمصدر بتاعه لازم يتحدث برقمه الجديد)
    if (a.sourceId != null) {
      await _syncSourcePhoneOnly(a.sourceCabinetId, a.sourceId, b.phoneNumber);
    }
    if (b.sourceId != null) {
      await _syncSourcePhoneOnly(b.sourceCabinetId, b.sourceId, a.phoneNumber);
    }
  }

  Future<void> _syncSourcePhoneOnly(
      String? cabinetId,
      String? sourceId,
      String? phoneNumber,
      ) async {
    if (cabinetId == null || sourceId == null) return;
    final cabinet = await _db.collection('cabinets').doc(cabinetId).get();
    if (!cabinet.exists) return;
    final type = cabinet.data()?['type'] == CabinetType.copper.name
        ? CabinetType.copper
        : CabinetType.portBox;
    final collection = type == CabinetType.copper ? 'mainPairs' : 'ports';
    await _db
        .collection('cabinets')
        .doc(cabinetId)
        .collection(collection)
        .doc(sourceId)
        .update({'phoneNumber': phoneNumber});

    if (type == CabinetType.copper) {
      final pairSnap = await _db
          .collection('cabinets')
          .doc(cabinetId)
          .collection('mainPairs')
          .doc(sourceId)
          .get();
      final sourcePortId = pairSnap.data()?['sourcePortId'] as String?;
      final sourcePortCabinetId = pairSnap.data()?['sourceCabinetId'] as String?;
      if (sourcePortId != null && sourcePortCabinetId != null) {
        await _db
            .collection('cabinets')
            .doc(sourcePortCabinetId)
            .collection('ports')
            .doc(sourcePortId)
            .update({'phoneNumber': phoneNumber});
      }
    }
  }

  // ==================== بورتات (كابينة فايبر بس) ====================

  Stream<List<PortModel>> streamPorts(String fiberCabinetId) {
    return _db
        .collection('cabinets')
        .doc(fiberCabinetId)
        .collection('ports')
        .orderBy('portNumber')
        .snapshots()
        .map((snap) =>
        snap.docs.map((d) => PortModel.fromMap(d.id, d.data())).toList());
  }

  Future<void> generatePorts(String fiberCabinetId, int count) async {
    final portsRef = _db.collection('cabinets').doc(fiberCabinetId).collection('ports');
    final existing = await portsRef.limit(1).get();
    if (existing.docs.isNotEmpty) return;

    final batch = _db.batch();
    for (int i = 1; i <= count; i++) {
      final ref = portsRef.doc();
      batch.set(ref, PortModel(id: ref.id, portNumber: i).toMap());
    }
    await batch.commit();
  }
  Future<void> updateCabinet(
      String cabinetId,
      Map<String, dynamic> data,
      ) async {
    await _db
        .collection('cabinets')
        .doc(cabinetId)
        .update(data);
  }

  // بيحدّث بيانات بورت (تعطيل بس عادة - رقم التليفون بيتزامن تلقائيًا من الترمنال/الرئيسي)
  Future<void> updatePort(
      String fiberCabinetId,
      String portId,
      Map<String, dynamic> data,
      ) async {
    await _db
        .collection('cabinets')
        .doc(fiberCabinetId)
        .collection('ports')
        .doc(portId)
        .update(data);
  }

  // ==================== رئيسيات (كابينة نحاس بس) ====================

  Stream<List<MainPairModel>> streamMainPairs(String copperCabinetId) {
    return _db
        .collection('cabinets')
        .doc(copperCabinetId)
        .collection('mainPairs')
        .orderBy('pairNumber')
        .snapshots()
        .map((snap) =>
        snap.docs.map((d) => MainPairModel.fromMap(d.id, d.data())).toList());
  }

  Future<void> generateMainPairs(String copperCabinetId, int count) async {
    final pairsRef =
    _db.collection('cabinets').doc(copperCabinetId).collection('mainPairs');
    final existing = await pairsRef.limit(1).get();
    if (existing.docs.isNotEmpty) return;

    final batch = _db.batch();
    for (int i = 1; i <= count; i++) {
      final ref = pairsRef.doc();
      batch.set(ref, MainPairModel(id: ref.id, pairNumber: i).toMap());
    }
    await batch.commit();
  }

  Future<void> updateMainPair(
      String copperCabinetId,
      String pairId,
      Map<String, dynamic> data,
      ) async {
    await _db
        .collection('cabinets')
        .doc(copperCabinetId)
        .collection('mainPairs')
        .doc(pairId)
        .update(data);
  }

  // ملحوظة: شاشة تعديل الرئيسي حاليًا بتستخدم setTerminalSource (بوكس +
  // ترمنال محدد بالظبط) بدل الدالة دي، عشان يفضل الرقم متزامن صح مع الترمنال
  // الفعلي. الدالة دي موجودة للاستخدام المستقبلي لو احتجت وجهة يدوية حرة
  // (بوكس بس من غير ترمنال محدد) - مش مستخدمة دلوقتي في أي شاشة.
  //
  // data المتوقعة: {isFaulty, phoneNumber, destinationType, destinationId}
  Future<void> setMainPairDestination(
      String copperCabinetId,
      String pairId,
      Map<String, dynamic> data,
      ) async {
    await _db
        .collection('cabinets')
        .doc(copperCabinetId)
        .collection('mainPairs')
        .doc(pairId)
        .update(data);
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

  // بيحدد مصدر رئيسي معين: أنهي بورت في أنهي كابينة فايبر بياخد منه.
  // بيقفل تلقائيًا إن الكابينة النحاس دي أبوها الكابينة الفايبر دي (أول مرة بس).
  Future<void> assignMainPairSource({
    required String copperCabinetId,
    required String pairId,
    required String sourceFiberCabinetId,
    required String sourcePortId,
  }) async {
    await linkCopperCabinetToParent(copperCabinetId, sourceFiberCabinetId);

    final batch = _db.batch();
    final pairRef =
    _db.collection('cabinets').doc(copperCabinetId).collection('mainPairs').doc(pairId);
    final portRef = _db
        .collection('cabinets')
        .doc(sourceFiberCabinetId)
        .collection('ports')
        .doc(sourcePortId);

    batch.update(pairRef, {
      'sourceCabinetId': sourceFiberCabinetId,
      'sourcePortId': sourcePortId,
    });
    batch.update(portRef, {
      'destinationType': PortDestinationType.copperCabinet.name,
      'destinationId': copperCabinetId,
    });
    await batch.commit();
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
      mainPairsCount: 100,
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
      mainPairsCount: 50,
    ).toMap());

    final box1 = _db.collection('boxes').doc();
    await box1.set(BoxModel(
      id: box1.id,
      name: 'بوكس B-01',
      parentCabinetId: cab2.id,
      areaId: areaId,
      latitude: 30.0470,
      longitude: 31.2390,
      terminalsCount: 10,
    ).toMap());

    final box2 = _db.collection('boxes').doc();
    await box2.set(BoxModel(
      id: box2.id,
      name: 'بوكس B-02',
      parentCabinetId: cab1.id,
      areaId: areaId,
      latitude: 30.0430,
      longitude: 31.2340,
      terminalsCount: 10,
    ).toMap());

    // بورتات تجريبية على كابينة الفايبر
    final portsRef = cab1.collection('ports');
    final portDocs = <DocumentReference>[];
    for (int i = 1; i <= 10; i++) {
      final ref = portsRef.doc();
      portDocs.add(ref);
      await ref.set(PortModel(id: ref.id, portNumber: i).toMap());
    }

    // رئيسيات تجريبية على كابينة النحاس
    final pairsRef = cab2.collection('mainPairs');
    final pairDocs = <DocumentReference>[];
    for (int i = 1; i <= 10; i++) {
      final ref = pairsRef.doc();
      pairDocs.add(ref);
      await ref.set(MainPairModel(id: ref.id, pairNumber: i).toMap());
    }

    // ترمنالات تجريبية على البوكس الأول (تابع كابينة النحاس)
    final termsRef = box1.collection('terminals');
    for (int i = 1; i <= 5; i++) {
      final ref = termsRef.doc();
      await ref.set(TerminalModel(
        id: ref.id,
        terminalNumber: i,
        customerName: 'عميل تجريبي $i',
        customerType: i % 2 == 0 ? CustomerType.service160 : CustomerType.voice,
        isFaulty: i == 3,
        isolationStatus: i == 1 ? IsolationStatus.ok : IsolationStatus.unknown,
      ).toMap());
    }

    // نربط رئيسي رقم 1 بالكابينة النحاس بمصدره: بورت رقم 1 في كابينة الفايبر
    await assignMainPairSource(
      copperCabinetId: cab2.id,
      pairId: pairDocs[0].id,
      sourceFiberCabinetId: cab1.id,
      sourcePortId: portDocs[0].id,
    );

    // ونربط ترمنال 1 في بوكس B-01 بنفس الرئيسي، ونديله رقم تليفون - عشان تشوف
    // إزاي الرقم بيتزامن على طول السلسلة كلها (بورت 1 <-> رئيسي 1 <-> ترمنال 1)
    final firstTermSnap = await termsRef.orderBy('terminalNumber').limit(1).get();
    if (firstTermSnap.docs.isNotEmpty) {
      final termId = firstTermSnap.docs.first.id;
      await termsRef.doc(termId).update({'phoneNumber': '01000000099'});
      await setTerminalSource(
        boxId: box1.id,
        terminalId: termId,
        parentCabinetId: cab2.id,
        parentCabinetType: CabinetType.copper,
        sourceId: pairDocs[0].id,
        phoneNumber: '01000000099',
      );
    }
  }
}