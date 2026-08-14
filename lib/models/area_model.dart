class AreaModel {
  final String id;
  final String name;

  AreaModel({required this.id, required this.name});

  factory AreaModel.fromMap(String id, Map<String, dynamic> map) {
    return AreaModel(id: id, name: map['name'] ?? '');
  }

  Map<String, dynamic> toMap() {
    return {'name': name};
  }
}
