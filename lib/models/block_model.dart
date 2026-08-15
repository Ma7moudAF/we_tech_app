// البلوك: تجميع تنظيمي/بصري لـ 10 عناصر على الكابينة (بوكسات أو رئيسيات بس -
// البورتات ليها هيكل مختلف تمامًا، شوف shelf_model.dart).
// النوع بيتحدد بحرية وقت ما الفني يضيف البلوك فعليًا - مش مفروض حسب نوع
// الكابينة. سعة كل بلوك = 10 عناصر ثابتة دايمًا.
//
// شكل الكابينة تماثلي: عمودين (شمال ويمين)، الفني بيضيف بلوك في أي عمود
// بحرية في أي وقت - كل عمود ترقيمه (blockNumber) مستقل عن التاني.
//
// ملحوظة معمارية مهمة: البلوك تنظيمي/بصري بس - مفيش أي ربط تلقائي بين
// بلوك بوكسات وبلوك رئيسيات. كل ربط فعلي (رئيسي↔بوكس/ترمنال أو رئيسي↔بورت)
// بيتحدد يدوي وحر لكل عنصر لوحده، من غير أي قيد بالترتيب.

enum BlockSide {
  left,
  right;

  String get labelAr {
    switch (this) {
      case BlockSide.left:
        return 'شمال';
      case BlockSide.right:
        return 'يمين';
    }
  }
}

enum BlockType {
  box,
  mainPair;

  String get labelAr {
    switch (this) {
      case BlockType.box:
        return 'بوكسات';
      case BlockType.mainPair:
        return 'رئيسيات';
    }
  }
}

class BlockModel {
  // سعة كل بلوك ثابتة دايمًا - 10 عناصر
  static const int capacity = 10;

  final String id;
  final int blockNumber; // ترتيبه جوه نفس العمود (شمال أو يمين) بس
  final BlockSide side;
  final BlockType type;

  BlockModel({
    required this.id,
    required this.blockNumber,
    required this.side,
    required this.type,
  });

  factory BlockModel.fromMap(String id, Map<String, dynamic> map) {
    return BlockModel(
      id: id,
      blockNumber: map['blockNumber'] ?? 0,
      side: BlockSide.values.firstWhere(
            (e) => e.name == map['side'],
        orElse: () => BlockSide.left,
      ),
      type: BlockType.values.firstWhere(
            (e) => e.name == map['type'],
        orElse: () => BlockType.box,
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'blockNumber': blockNumber,
      'side': side.name,
      'type': type.name,
    };
  }
}