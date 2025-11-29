import 'package:flutter/material.dart'; //ddd
import 'screens/map_screen.dart'; // 지도
import 'screens/cafeteria_screen.dart'; // 학식
import 'screens/bus_screen.dart';

// 프로젝트 구조에 따라 다른 화면 파일들을 여기서 임포트해야 합니다.
// 예시: import 'package:capstone_project/screens/map_screen.dart';

// 🚨 [주의] 실제 앱 실행에 필요한 API URL, 지도, 버스, 학식 화면 위젯들은 
// 'screens/' 폴더 내의 다른 파일에 정의되어 있고, 여기서 불러와야 합니다.

void main() {
  runApp(const MyApp());
}

// =========================================
// 1. 앱의 기본 구조 (Theme 및 오류 수정)
// =========================================
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // 🚨 [핵심 수정 부분] Shader 컴파일 오류 해결을 위해 Material 3를 끕니다.
    return MaterialApp(
      title: '한림대 캠퍼스 통합 앱',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        // 중요: 이 설정을 false로 해야 윈도우 환경의 셰이더 컴파일 오류(-1073741819)가 사라집니다.
        useMaterial3: false, 
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      // 홈 화면은 메인 페이지(하단 탭 바)를 관리하는 위젯으로 설정합니다.
      home: const MainPage(), 
    );
  }
}

// =========================================
// 2. 메인 페이지 (하단 탭 바 관리)
// =========================================
class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _selectedIndex = 0;

  // 🚨 [TODO] 여기에 실제 Map, Cafeteria, Bus 스크린 위젯을 넣어주세요.
  // 예시: HallymMapScreen(), CafeteriaScreen(), BusArrivalScreen()
  final List<Widget> _widgetOptions = <Widget>[
    const MapScreen(),
    const CafeteriaScreen(),
    const HallymBusArrivalScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('한림대 올인원 정보'),
        backgroundColor: Colors.blue.shade700,
      ),
      body: _widgetOptions.elementAt(_selectedIndex),
      
      // 하단 네비게이션 바
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.map),
            label: '지도',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.restaurant),
            label: '학식',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.directions_bus),
            label: '교통',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.blue.shade800,
        onTap: _onItemTapped,
      ),
    );
  }
}
