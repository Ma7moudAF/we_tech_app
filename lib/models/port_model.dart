// البورت: بداية خط العميل الفعلي على كابينة الفايبر.
// عايش جوه شيلف: cabinets/{fiberCabinetId}/shelves/{shelfId}/ports/{portId}
// portNumber متسلسل على الشيلف كله (1-512). رقم المشط ومكان البورت جواه
// بيتحسبوا منه تلقائيًا (combNumber / positionInComb) - مش مخزنين لوحدهم.
//
// البورت ممكن يوصل لواحدة من 3 حالات (destinationType):
// - direct: عميل FTTH مباشر على البورت نفسه (من غير بوكس وسيط)
// - box: واصل بوكس + ترمنال محدد بالظبط (سواء تابع لنفس الكابينة أو مكان تاني)
// - copperMainPair: واصل رئيسي محدد جوه بلوك رئيسيات على كابينة نحاس

import 'terminal_model.dart';

enum PortDestinationType {
  direct,
  box,
  copperMainPair;

  String get labelAr {
    switch (this) {
      case PortDestinationType.direct:
        return 'مباشر (FTTH)';
      case PortDestinationType.box:
        return 'بوكس';
      case PortDestinationType.copperMainPair:
        return 'كابينة نحاس';
    }
  }
}

class PortModel {
  static const int portsPerComb = 16;

  final String id;
  final int portNumber; // رقم البورت متسلسل عالشيلف كله (1-512)
  final bool isFaulty;
  final PortDestinationType? destinationType;

  // نفس رقم العميل - موجود دايمًا كنسخة denormalized للعرض/البحث حتى لو
  // مش direct (بيتزامن تلقائيًا من الترمنال أو الرئيسي المربوطين)
  final String? phoneNumber;
  // بيانات العميل - مستخدمة لما destinationType == direct بس
  final String? customerName;
  final CustomerType? customerType;
  final IsolationStatus isolationStatus;

  // لو destinationType == box
  final String? destinationBoxId;
  final String? destinationTerminalId;

  // لو destinationType == copperMainPair
  final String? destinationCopperCabinetId;
  final String? destinationMainPairBlockId;
  final String? destinationMainPairId;

  final String? notes;

  PortModel({
    required this.id,
    required this.portNumber,
    this.isFaulty = false,
    this.destinationType,
    this.phoneNumber,
    this.customerName,
    this.customerType,
    this.isolationStatus = IsolationStatus.unknown,
    this.destinationBoxId,
    this.destinationTerminalId,
    this.destinationCopperCabinetId,
    this.destinationMainPairBlockId,
    this.destinationMainPairId,
    this.notes,
  });

  // رقم المشط ومكان البورت جواه - بيتحسبوا من portNumber مباشرة، مش مخزنين
  int get combNumber => ((portNumber - 1) ~/ portsPerComb) + 1;
  int get positionInComb => ((portNumber - 1) % portsPerComb) + 1;

  String get locationLabel => 'بورت $portNumber (مشط $combNumber - $positionInComb)';

  factory PortModel.fromMap(String id, Map<String, dynamic> map) {
    return PortModel(
      id: id,
      portNumber: map['portNumber'] ?? 0,
      isFaulty: map['isFaulty'] ?? false,
      destinationType: map['destinationType'] != null
          ? PortDestinationType.values.firstWhere(
            (e) => e.name == map['destinationType'],
        orElse: () => PortDestinationType.direct,
      )
          : null,
      phoneNumber: map['phoneNumber'],
      customerName: map['customerName'],
      customerType: map['customerType'] != null
          ? CustomerType.values.firstWhere(
            (e) => e.name == map['customerType'],
        orElse: () => CustomerType.voice,
      )
          : null,
      isolationStatus: IsolationStatus.values.firstWhere(
            (e) => e.name == map['isolationStatus'],
        orElse: () => IsolationStatus.unknown,
      ),
      destinationBoxId: map['destinationBoxId'],
      destinationTerminalId: map['destinationTerminalId'],
      destinationCopperCabinetId: map['destinationCopperCabinetId'],
      destinationMainPairBlockId: map['destinationMainPairBlockId'],
      destinationMainPairId: map['destinationMainPairId'],
      notes: map['notes'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'portNumber': portNumber,
      'isFaulty': isFaulty,
      'destinationType': destinationType?.name,
      'phoneNumber': phoneNumber,
      'customerName': customerName,
      'customerType': customerType?.name,
      'isolationStatus': isolationStatus.name,
      'destinationBoxId': destinationBoxId,
      'destinationTerminalId': destinationTerminalId,
      'destinationCopperCabinetId': destinationCopperCabinetId,
      'destinationMainPairBlockId': destinationMainPairBlockId,
      'destinationMainPairId': destinationMainPairId,
      'notes': notes,
    };
  }
}