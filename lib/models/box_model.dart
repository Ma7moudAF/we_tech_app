class BoxModel {
  // سعة "المشط" الواحد الجاي من الكابينة - ثابتة، أي بوكس سعته أكبر من كده
  // معناه إنه بيشغل أكتر من مشط على الكابينة
  static const int combCapacity = 10;

  final String id;
  final String name; // اسم/كود البوكس
  final String parentCabinetId; // الكابينة الأب (بورت بوكس أو نحاس)
  final String areaId; // المنطقة اللي البوكس فيها
  final double latitude;
  final double longitude;
  final int terminalsCount; // عدد الترمنالات على البوكس (لازم يكون من مضاعفات 10)
  final String? notes;

  // رقم مكان البوكس داخل بلوكات الكابينة (1, 2, 3...) - بيحدد في أنهي بلوك
  // وفي أنهي مكان جوه البلوك ده هيظهر البوكس في رسمة الكابينة من جوه.
  // null لو البوكس لسه ملوش مكان محدد.
  final int? slotNumber;

  BoxModel({
    required this.id,
    required this.name,
    required this.parentCabinetId,
    required this.areaId,
    required this.latitude,
    required this.longitude,
    this.terminalsCount = combCapacity,
    this.notes,
    this.slotNumber,
  });

  // عدد "المشاط" اللي البوكس ده بيشغلها فعليًا على الكابينة
  // بوكس سعته 10 = مشط واحد / بوكس سعته 20 = مشطين... وهكذا
  int get combsCount => (terminalsCount / combCapacity).ceil();

  // بيتأكد إن السعة مضاعف صحيح لسعة المشط (10)
  static bool isValidTerminalsCount(int count) {
    return count > 0 && count % combCapacity == 0;
  }

  factory BoxModel.fromMap(String id, Map<String, dynamic> map) {
    return BoxModel(
      id: id,
      name: map['name'] ?? '',
      parentCabinetId: map['parentCabinetId'] ?? '',
      areaId: map['areaId'] ?? '',
      latitude: (map['latitude'] ?? 0).toDouble(),
      longitude: (map['longitude'] ?? 0).toDouble(),
      terminalsCount: map['terminalsCount'] ?? combCapacity,
      notes: map['notes'],
      slotNumber: map['slotNumber'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'parentCabinetId': parentCabinetId,
      'areaId': areaId,
      'latitude': latitude,
      'longitude': longitude,
      'terminalsCount': terminalsCount,
      'notes': notes,
      'slotNumber': slotNumber,
    };
  }
}
