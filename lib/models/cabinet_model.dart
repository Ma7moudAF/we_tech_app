enum CabinetType {
  portBox, // فيبر (وحدة)
  copper; // نحاس

  String get labelAr {
    switch (this) {
      case CabinetType.portBox:
        return 'فيبر';
      case CabinetType.copper:
        return 'نحاس';
    }
  }
}

class CabinetModel {
  // كل بلوك بوكسات = 10 بوكسات
  static const int boxesPerBlock = 10;
  // كل بلوك رئيسيات = 100 رئيسي (10 أمشاط)
  static const int mainPairsPerBlock = 100;

  final String id;
  final String name; // اسم الكابينة/الوحدة
  final String code; // كود الكابينة/الوحدة
  final CabinetType type;
  final String areaId;
  final double latitude;
  final double longitude;
  final String? notes;

  // للكبائن النحاس بس: معرف كابينة الفيبر اللي بتغذي الكابينة دي عن طريق رئيسي.
  // كابينة النحاس مسموح ليها بأب واحد بس طول عمرها.
  final String? parentCabinetId;

  // عدد الرئيسيات الكلي على الكابينة (أي نوع فيبر أو نحاس ممكن يبقى ليه رئيسيات)
  final int mainPairsCount;

  // شكل البوكسات جوه الكابينة: عدد البلوكات على الشمال واليمين
  // كل بلوك = boxesPerBlock بوكس. الترقيم بيبدأ من الشمال دايمًا.
  final int boxBlocksLeft;
  final int boxBlocksRight;

  CabinetModel({
    required this.id,
    required this.name,
    required this.code,
    required this.type,
    required this.areaId,
    required this.latitude,
    required this.longitude,
    this.notes,
    this.parentCabinetId,
    this.mainPairsCount = 0,
    this.boxBlocksLeft = 0,
    this.boxBlocksRight = 0,
  });

  // السعة الكلية للبوكسات على الكابينة دي (كل البلوكات شمال ويمين)
  int get boxCapacity => (boxBlocksLeft + boxBlocksRight) * boxesPerBlock;

  // إجمالي بلوكات الرئيسيات المطلوبة عشان تغطي mainPairsCount، موزعة
  // نص بنص بين عمود النص الشمال واليمين (زي ما موضح في add_cabinet_screen)
  int get _mainPairBlocksTotal =>
      mainPairsCount == 0 ? 0 : (mainPairsCount / mainPairsPerBlock).ceil();

  int get mainPairBlocksLeft =>
      (_mainPairBlocksTotal / 2).ceil();

  int get mainPairBlocksRight =>
      (_mainPairBlocksTotal - mainPairBlocksLeft).clamp(0, _mainPairBlocksTotal);

  factory CabinetModel.fromMap(String id, Map<String, dynamic> map) {
    return CabinetModel(
      id: id,
      name: map['name'] ?? '',
      code: map['code'] ?? '',
      type: CabinetType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => CabinetType.portBox,
      ),
      areaId: map['areaId'] ?? '',
      latitude: (map['latitude'] ?? 0).toDouble(),
      longitude: (map['longitude'] ?? 0).toDouble(),
      notes: map['notes'],
      parentCabinetId: map['parentCabinetId'],
      mainPairsCount: map['mainPairsCount'] ?? 0,
      boxBlocksLeft: map['boxBlocksLeft'] ?? 0,
      boxBlocksRight: map['boxBlocksRight'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'code': code,
      'type': type.name,
      'areaId': areaId,
      'latitude': latitude,
      'longitude': longitude,
      'notes': notes,
      'parentCabinetId': parentCabinetId,
      'mainPairsCount': mainPairsCount,
      'boxBlocksLeft': boxBlocksLeft,
      'boxBlocksRight': boxBlocksRight,
    };
  }
}
