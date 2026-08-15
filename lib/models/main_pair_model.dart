// الرئيسي: خط وصل داخلي بيوصل بين بورت معين على كابينة الفايبر وكابينة النحاس بس.
// عايش جوه بلوك: cabinets/{copperCabinetId}/blocks/{blockId}/mainPairs/{pairId}
// pairNumber (1-10) رقمه جوه البلوك بس.
//
// الربط حر بالكامل ومفيش أي ربط تلقائي بالترتيب مع بلوك بوكسات - كل رئيسي
// بيتحدد له مصدر (بورت) ووجهة (بوكس+ترمنال) لوحده بشكل مستقل يدوي.

class MainPairModel {
  final String id;
  final int pairNumber; // رقم الرئيسي جوه البلوك (1-10)
  final bool isFaulty;
  final String? phoneNumber; // نفس رقم العميل - متزامن تلقائيًا مع البورت/الترمنال

  // مصدر الرئيسي: أنهي بورت في أنهي شيلف في أنهي كابينة فايبر
  final String? sourceCabinetId;
  final String? sourceShelfId;
  final String? sourcePortId;

  // وجهة الرئيسي: بوكس وترمنال محددين بالظبط (بيتحدث تلقائيًا لما ترمنال
  // يختار الرئيسي ده كمصدر، أو يدوي من شاشة الكابينة)
  final String? destinationBoxId;
  final String? destinationTerminalId;

  final String? notes;

  MainPairModel({
    required this.id,
    required this.pairNumber,
    this.isFaulty = false,
    this.phoneNumber,
    this.sourceCabinetId,
    this.sourceShelfId,
    this.sourcePortId,
    this.destinationBoxId,
    this.destinationTerminalId,
    this.notes,
  });

  // نص وصفي بسيط لمكان الرئيسي (بيتستخدم في العرض والتقارير)
  String get locationLabel => 'رئيسي رقم $pairNumber';

  factory MainPairModel.fromMap(String id, Map<String, dynamic> map) {
    return MainPairModel(
      id: id,
      pairNumber: map['pairNumber'] ?? 0,
      isFaulty: map['isFaulty'] ?? false,
      phoneNumber: map['phoneNumber'],
      sourceCabinetId: map['sourceCabinetId'],
      sourceShelfId: map['sourceShelfId'],
      sourcePortId: map['sourcePortId'],
      destinationBoxId: map['destinationBoxId'],
      destinationTerminalId: map['destinationTerminalId'],
      notes: map['notes'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'pairNumber': pairNumber,
      'isFaulty': isFaulty,
      'phoneNumber': phoneNumber,
      'sourceCabinetId': sourceCabinetId,
      'sourceShelfId': sourceShelfId,
      'sourcePortId': sourcePortId,
      'destinationBoxId': destinationBoxId,
      'destinationTerminalId': destinationTerminalId,
      'notes': notes,
    };
  }
}