// الشيلف: حاوية ثابتة الحجم للبورتات على كابينة الفيبر بس.
// كل شيلف = 32 مشط ثابتين، كل مشط = 16 بورت (تتولد كلها أوتوماتيك أول ما
// الشيلف يتضاف - مفيش إضافة أمشاط تدريجية زي البلوكات).
// الترقيم (shelfNumber) بيتحدد تلقائيًا زي البلوك (آخر شيلف + 1).
// ملحوظة: الشيلف مش بالضرورة شمال/يمين - ممكن يكونوا جنب بعض أو فوق بعض،
// فمفيش حقل "side" هنا، بس ترقيم تسلسلي.
//
// رقم البورت (PortModel.portNumber) متسلسل على الشيلف كله (1-512)، ورقم
// المشط ومكانه جواه بيتحسبوا منه تلقائيًا (شوف PortModel.combNumber).

class ShelfModel {
  static const int combsPerShelf = 32;
  static const int portsPerComb = 16;
  static const int totalPortsPerShelf = combsPerShelf * portsPerComb; // 512

  final String id;
  final int shelfNumber;
  final String? notes;

  ShelfModel({
    required this.id,
    required this.shelfNumber,
    this.notes,
  });

  factory ShelfModel.fromMap(String id, Map<String, dynamic> map) {
    return ShelfModel(
      id: id,
      shelfNumber: map['shelfNumber'] ?? 0,
      notes: map['notes'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'shelfNumber': shelfNumber,
      'notes': notes,
    };
  }
}