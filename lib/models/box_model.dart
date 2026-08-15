// البوكس: مكانه محدد بـ blockId + positionInBlock جوه بلوك من نوع box
// على كابينة معينة. سعته ثابتة دايمًا 10 ترمنال (نفس سعة البلوك).
// مبيتعملش أوتوماتيك - الفني هو اللي بيضيفه لما يوصله فعليًا على الأرض.

class BoxModel {
  // عدد الترمنالات ثابت دايمًا (نفس سعة البلوك BlockModel.capacity)
  static const int terminalsCapacity = 10;

  final String id;
  final String name; // اسم/كود البوكس
  final String parentCabinetId; // الكابينة الأب (فيبر أو نحاس)
  final String blockId; // بلوك البوكسات اللي البوكس ده مكانه فيه
  final int positionInBlock; // مكانه جوه البلوك (1-10)
  final String areaId; // المنطقة اللي البوكس فيها
  final double latitude;
  final double longitude;
  final int terminalsCount; // ثابت 10 دايمًا
  final String? notes;

  BoxModel({
    required this.id,
    required this.name,
    required this.parentCabinetId,
    required this.blockId,
    required this.positionInBlock,
    required this.areaId,
    required this.latitude,
    required this.longitude,
    this.terminalsCount = terminalsCapacity,
    this.notes,
  });

  factory BoxModel.fromMap(String id, Map<String, dynamic> map) {
    return BoxModel(
      id: id,
      name: map['name'] ?? '',
      parentCabinetId: map['parentCabinetId'] ?? '',
      blockId: map['blockId'] ?? '',
      positionInBlock: map['positionInBlock'] ?? 0,
      areaId: map['areaId'] ?? '',
      latitude: (map['latitude'] ?? 0).toDouble(),
      longitude: (map['longitude'] ?? 0).toDouble(),
      terminalsCount: map['terminalsCount'] ?? terminalsCapacity,
      notes: map['notes'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'parentCabinetId': parentCabinetId,
      'blockId': blockId,
      'positionInBlock': positionInBlock,
      'areaId': areaId,
      'latitude': latitude,
      'longitude': longitude,
      'terminalsCount': terminalsCount,
      'notes': notes,
    };
  }
}