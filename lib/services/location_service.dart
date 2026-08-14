// خدمة بسيطة لجلب موقع الجهاز الحالي (GPS)
// محتاجة باكدج geolocator: ضيفها في pubspec.yaml
//   geolocator: ^13.0.0   (أو أحدث نسخة متاحة وقت التشغيل)
//
// وبرضو محتاجة صلاحيات الموقع في إعدادات المشروع:
// أندرويد (android/app/src/main/AndroidManifest.xml) جوه <manifest>:
//   <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
//   <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
//
// iOS (ios/Runner/Info.plist):
//   <key>NSLocationWhenInUseUsageDescription</key>
//   <string>التطبيق محتاج موقعك عشان يسجل مكان الكابينة/البوكس بدقة</string>

import 'package:geolocator/geolocator.dart';

class LocationService {
  // بيرجع موقع الجهاز الحالي، وبيتأكد إن كل الصلاحيات والخدمات متاحة الأول
  // بيرمي Exception برسالة عربي واضحة لو حصلت أي مشكلة، عشان تتعرض في SnackBar مباشرة
  static Future<Position> getCurrentLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('خدمة تحديد الموقع (GPS) مقفولة على الجهاز، افتحها الأول');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('لازم توافق على صلاحية الموقع عشان الميزة دي تشتغل');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception(
        'صلاحية الموقع متمنوعة نهائيًا لهذا التطبيق، فعّلها يدوي من إعدادات الجهاز',
      );
    }

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    );
  }
}
