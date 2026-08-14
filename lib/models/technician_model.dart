enum UserRole {
  technician, // فني
  admin; // أدمن

  String get labelAr {
    switch (this) {
      case UserRole.technician:
        return 'فني';
      case UserRole.admin:
        return 'أدمن';
    }
  }
}

class TechnicianModel {
  final String uid; // معرف Firebase Auth
  final String loginId; // الـ ID اللي بيسجل بيه دخول
  final String name;
  final UserRole role;
  final List<String> areaIds; // المناطق المسندة له

  TechnicianModel({
    required this.uid,
    required this.loginId,
    required this.name,
    this.role = UserRole.technician,
    this.areaIds = const [],
  });

  factory TechnicianModel.fromMap(String uid, Map<String, dynamic> map) {
    return TechnicianModel(
      uid: uid,
      loginId: map['loginId'] ?? '',
      name: map['name'] ?? '',
      role: UserRole.values.firstWhere(
            (e) => e.name == map['role'],
        orElse: () => UserRole.technician,
      ),
      areaIds: List<String>.from(map['areaIds'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'loginId': loginId,
      'name': name,
      'role': role.name,
      'areaIds': areaIds,
    };
  }

  // بيحوّل الـ ID لصيغة إيميل وهمية عشان يستخدمها Firebase Auth من وراء الكواليس
  static String loginIdToEmail(String loginId) => '$loginId@wetech.local';

  // Firebase بيرفض أي باسورد أقل من 6 خانات.
  // عشان نسمح للفني يكتب باسورد قصيرة (رقم واحد مثلاً)،
  // بنكمّلها تلقائيًا لـ 6 خانات بإضافة أصفار في الآخر قبل ما نبعتها لـ Firebase.
  // مهم: أي حساب بيتعمل يدوي في Firebase Console لازم يستخدم نفس الدالة دي
  // لحساب الباسورد الفعلي اللي هيتحط في الكونسول.
  static String padPassword(String rawPassword) {
    if (rawPassword.length >= 6) return rawPassword;
    return rawPassword.padRight(6, '0');
  }
}