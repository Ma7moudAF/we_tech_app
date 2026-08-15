// حالة العزل بتاعة الترمنال
enum IsolationStatus {
  percentage, // نسبة
  ok, // تمام
  unknown; // غير معروف

  String get labelAr {
    switch (this) {
      case IsolationStatus.percentage:
        return 'نسبة';
      case IsolationStatus.ok:
        return 'تمام';
      case IsolationStatus.unknown:
        return 'غير معروف';
    }
  }
}

// تصنيف العميل
enum CustomerType {
  voice, // عميل صوت
  service160; // عميل 160

  String get labelAr {
    switch (this) {
      case CustomerType.voice:
        return 'عميل صوت';
      case CustomerType.service160:
        return 'عميل 160';
    }
  }
}

class TerminalModel {
  final String id; // معرف الترمنال في فايرستور
  final int terminalNumber; // رقم الترمنال على البوكس (1, 2, 3...)
  final String? phoneNumber; // الرقم المسجل على الترمنال ده
  final String? customerName; // اسم العميل
  final CustomerType? customerType; // صوت / 160
  final bool isFaulty; // معطل ولا لأ
  final IsolationStatus isolationStatus; // حالة العزل
  final int? crossConnectedTo; // لو التوصيل مش مباشر: بيوصل فعليًا لترمنال رقم كام
  final String? notes; // أي ملاحظات إضافية

  // مصدر خط الترمنال ده فعليًا: بورت أو رئيسي.
  // sourceCabinetId = الكابينة اللي فيها المصدر (ممكن تختلف عن الكابينة
  // الأب بتاعة البوكس نفسه - المصدر ممكن يكون في كابينة تانية).
  // لو المصدر رئيسي: sourceBlockId (بلوك الرئيسيات) + sourceId (معرف الرئيسي).
  // لو المصدر بورت: sourceShelfId (الشيلف) + sourceId (معرف البورت).
  // الاتنين مش هيبقوا مليانين مع بعض في نفس الوقت - واحد بس حسب نوع المصدر.
  final String? sourceCabinetId;
  final String? sourceBlockId; // لو المصدر رئيسي
  final String? sourceShelfId; // لو المصدر بورت
  final String? sourceId;

  TerminalModel({
    required this.id,
    required this.terminalNumber,
    this.phoneNumber,
    this.customerName,
    this.customerType,
    this.isFaulty = false,
    this.isolationStatus = IsolationStatus.unknown,
    this.crossConnectedTo,
    this.notes,
    this.sourceCabinetId,
    this.sourceBlockId,
    this.sourceShelfId,
    this.sourceId,
  });

  factory TerminalModel.fromMap(String id, Map<String, dynamic> map) {
    return TerminalModel(
      id: id,
      terminalNumber: map['terminalNumber'] ?? 0,
      phoneNumber: map['phoneNumber'],
      customerName: map['customerName'],
      customerType: map['customerType'] != null
          ? CustomerType.values.firstWhere(
            (e) => e.name == map['customerType'],
        orElse: () => CustomerType.voice,
      )
          : null,
      isFaulty: map['isFaulty'] ?? false,
      isolationStatus: IsolationStatus.values.firstWhere(
            (e) => e.name == map['isolationStatus'],
        orElse: () => IsolationStatus.unknown,
      ),
      crossConnectedTo: map['crossConnectedTo'],
      notes: map['notes'],
      sourceCabinetId: map['sourceCabinetId'],
      sourceBlockId: map['sourceBlockId'],
      sourceShelfId: map['sourceShelfId'],
      sourceId: map['sourceId'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'terminalNumber': terminalNumber,
      'phoneNumber': phoneNumber,
      'customerName': customerName,
      'customerType': customerType?.name,
      'isFaulty': isFaulty,
      'isolationStatus': isolationStatus.name,
      'crossConnectedTo': crossConnectedTo,
      'notes': notes,
      'sourceCabinetId': sourceCabinetId,
      'sourceBlockId': sourceBlockId,
      'sourceShelfId': sourceShelfId,
      'sourceId': sourceId,
    };
  }

  TerminalModel copyWith({
    String? phoneNumber,
    String? customerName,
    CustomerType? customerType,
    bool? isFaulty,
    IsolationStatus? isolationStatus,
    int? crossConnectedTo,
    String? notes,
    String? sourceCabinetId,
    String? sourceBlockId,
    String? sourceShelfId,
    String? sourceId,
  }) {
    return TerminalModel(
      id: id,
      terminalNumber: terminalNumber,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      customerName: customerName ?? this.customerName,
      customerType: customerType ?? this.customerType,
      isFaulty: isFaulty ?? this.isFaulty,
      isolationStatus: isolationStatus ?? this.isolationStatus,
      crossConnectedTo: crossConnectedTo ?? this.crossConnectedTo,
      notes: notes ?? this.notes,
      sourceCabinetId: sourceCabinetId ?? this.sourceCabinetId,
      sourceBlockId: sourceBlockId ?? this.sourceBlockId,
      sourceShelfId: sourceShelfId ?? this.sourceShelfId,
      sourceId: sourceId ?? this.sourceId,
    );
  }
}