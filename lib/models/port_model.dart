// البورت: بداية خط العميل الفعلي على كابينة الفايبر (كارت الشبكة).
// البورت مختلف عن الرئيسي - الرئيسي بيوصل بين الفايبر والنحاس بس،
// أما البورت فهو أول نقطة في مسار الخط اللي بنفضل نوصله لحد راوتر العميل.
enum PortDestinationType {
  box, // البورت واصل بوكس مباشرة (مفيش كابينة نحاس في النص)
  copperCabinet; // البورت واصل كابينة نحاس (وبعدين الرئيسي هو اللي بياخد منه)

  String get labelAr {
    switch (this) {
      case PortDestinationType.box:
        return 'بوكس';
      case PortDestinationType.copperCabinet:
        return 'كابينة نحاس';
    }
  }
}

class PortModel {
  final String id;
  final int portNumber; // رقم البورت جوه الكابينة
  final bool isFaulty;
  final String? phoneNumber; // نفس رقم العميل - بيتزامن تلقائيًا مع الرئيسي/الترمنال المربوطين
  final PortDestinationType? destinationType;
  final String? destinationId; // معرف البوكس أو الكابينة النحاس اللي البورت واصلها

  PortModel({
    required this.id,
    required this.portNumber,
    this.isFaulty = false,
    this.phoneNumber,
    this.destinationType,
    this.destinationId,
  });

  factory PortModel.fromMap(String id, Map<String, dynamic> map) {
    return PortModel(
      id: id,
      portNumber: map['portNumber'] ?? 0,
      isFaulty: map['isFaulty'] ?? false,
      phoneNumber: map['phoneNumber'],
      destinationType: map['destinationType'] != null
          ? PortDestinationType.values.firstWhere(
              (e) => e.name == map['destinationType'],
              orElse: () => PortDestinationType.box,
            )
          : null,
      destinationId: map['destinationId'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'portNumber': portNumber,
      'isFaulty': isFaulty,
      'phoneNumber': phoneNumber,
      'destinationType': destinationType?.name,
      'destinationId': destinationId,
    };
  }
}
