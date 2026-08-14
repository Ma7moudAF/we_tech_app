// الشاشة الرئيسية بعد تسجيل الدخول - فيها تابين: الخريطة، والكبائن (اختصار
// دخول من غير ما تدور على الخريطة). التنقل بين الاتنين بـ BottomNavigationBar.

import 'package:flutter/material.dart';

import 'cabinets_list_screen.dart';
import 'map_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: const [
          MapScreen(),
          CabinetsListScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.map_outlined), label: 'الخريطة'),
          NavigationDestination(icon: Icon(Icons.electrical_services_outlined), label: 'الكبائن'),
        ],
      ),
    );
  }
}
