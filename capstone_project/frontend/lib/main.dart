import 'package:flutter/material.dart';
import 'screens/map_screen.dart'; // 지도
import 'screens/cafeteria_screen.dart'; // 학식
import 'screens/bus_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '한림대 올인원 앱',
      theme: ThemeData(primarySwatch: Colors.green, useMaterial3: true),
      // [핵심] 이제 MainPage가 정의되었으므로 에러가 사라집니다.
      home: const MainPage(),
    );
  }
}

// ====================================================================
// 🚀 MainPage 정의 (하단 탭 바가 있는 메인 화면)
// ====================================================================
class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _selectedIndex = 2; // 현재 선택된 탭 번호 (0: 지도, 1: 학식)

  // 탭별 화면 목록
  static final List<Widget> _widgetOptions = <Widget>[
    const MapScreen(), // 0번: 지도 화면 (lib/screens/map_screen.dart)
    const CafeteriaScreen(), // 1번: 학식 화면 (lib/screens/cafeteria_screen.dart)
    const HallymBusArrivalScreen(), // [추가] 2번: 버스 화면
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _widgetOptions.elementAt(_selectedIndex),

      bottomNavigationBar: BottomNavigationBar(
        // 탭이 3개 이상일 때는 type을 fixed로 설정해야 색상이 잘 나옵니다.
        type: BottomNavigationBarType.fixed,

        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.map), label: '캠퍼스 맵'),
          BottomNavigationBarItem(
            icon: Icon(Icons.restaurant_menu),
            label: '학식 메뉴',
          ),
          // 2. 탭 바 아이템에 버스 아이콘 추가
          BottomNavigationBarItem(
            icon: Icon(Icons.directions_bus), // 🚨 [추가]
            label: '교통 정보',
          ),
        ],
        // ... (나머지 코드 동일)
      ),
    );
  }
}
