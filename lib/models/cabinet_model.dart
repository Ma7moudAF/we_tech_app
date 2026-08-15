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
  });

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
    };
  }
}