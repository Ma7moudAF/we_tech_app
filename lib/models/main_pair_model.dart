// الرئيسي: خط وصل داخلي بيوصل بين بورت معين على كابينة الفايبر وكابينة النحاس بس.
// مبيتوصلش بيه عميل مباشرة، لكن لازم يتسجل عليه نفس رقم العميل اللي فعليًا
// بيعدي من خلاله عشان تقدر تدور بالرقم من أي نقطة في السلسلة وتعرف مساره كامل:
// الترمنال <-> الرئيسي <-> البورت.
//
// الرئيسي بيحتوي على خط عميل واحد بس (زي ما الترمنال بيحتوي على عميل واحد).

// وجهة الرئيسي: ممكن تتحدد يدوي من شاشة الكابينة نفسها (زي البورت بالظبط)،
// أو تتحدث تلقائيًا لما ترمنال يختار الرئيسي ده كمصدر ليه (شوف setTerminalSource).
enum MainPairDestinationType {
  box, // الرئيسي واصل بوكس مباشرة
  copperCabinet; // الرئيسي واصل كابينة نحاس تانية (حالة نادرة/تسلسل كبائن)

  String get labelAr {
    switch (this) {
      case MainPairDestinationType.box:
        return 'بوكس';
      case MainPairDestinationType.copperCabinet:
        return 'كابينة نحاس';
    }
  }
}

class MainPairModel {
  final String id;
  final int pairNumber; // رقم الرئيسي جوه الكابينة النحاس
  final bool isFaulty;
  final String? phoneNumber; // نفس رقم العميل - بيتزامن تلقائيًا مع البورت/الترمنال المربوطين

  // مصدر الرئيسي: أنهي بورت في أنهي كابينة فايبر بياخد منه. null لحد ما يتحدد.
  final String? sourceCabinetId;
  final String? sourcePortId;

  // وجهة الرئيسي: أنهي بوكس (أو كابينة نحاس) بياخد منه فعليًا.
  // ممكن تتحدد يدوي من شاشة الكابينة (destinationType + destinationId)،
  // أو تتحدث تلقائيًا لما ترمنال يختار الرئيسي ده كمصدر (destinationBoxId/destinationTerminalId).
  final MainPairDestinationType? destinationType;
  final String? destinationId; // معرف البوكس أو الكابينة النحاس

  final String? destinationBoxId;
  final String? destinationTerminalId;

  MainPairModel({
    required this.id,
    required this.pairNumber,
    this.isFaulty = false,
    this.phoneNumber,
    this.sourceCabinetId,
    this.sourcePortId,
    this.destinationType,
    this.destinationId,
    this.destinationBoxId,
    this.destinationTerminalId,
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
      sourcePortId: map['sourcePortId'],
      destinationType: map['destinationType'] != null
          ? MainPairDestinationType.values.firstWhere(
              (e) => e.name == map['destinationType'],
              orElse: () => MainPairDestinationType.box,
            )
          : null,
      destinationId: map['destinationId'],
      destinationBoxId: map['destinationBoxId'],
      destinationTerminalId: map['destinationTerminalId'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'pairNumber': pairNumber,
      'isFaulty': isFaulty,
      'phoneNumber': phoneNumber,
      'sourceCabinetId': sourceCabinetId,
      'sourcePortId': sourcePortId,
      'destinationType': destinationType?.name,
      'destinationId': destinationId,
      'destinationBoxId': destinationBoxId,
      'destinationTerminalId': destinationTerminalId,
    };
  }
}
