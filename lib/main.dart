import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'screens/home_shell.dart';

void main() async {
  // لازم نضمن إن Flutter جاهز قبل ما نشغل Firebase
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const WeTechApp());
}

class WeTechApp extends StatelessWidget {
  const WeTechApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'We Tech',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF0F766E),
        useMaterial3: true,
      ),
      // بيفرض اتجاه الكتابة من اليمين لليسار على كل التطبيق
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child!,
        );
      },
      home: const AuthGate(),
    );
  }
}

// الشاشة دي بتقرر تفتح صفحة الدخول ولا الصفحة الرئيسية (تابات الخريطة/الكبائن)
// حسب لو الفني مسجل دخول بالفعل ولا لأ
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasData) {
          return const HomeShell();
        }
        return const LoginScreen();
      },
    );
  }
}