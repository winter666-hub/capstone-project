import 'package:flutter/material.dart';
import 'package:capstone_project/mapscreen.dart';

// API URL 정의는 맵 스크린에서 주로 사용되므로 그곳에 정의하거나,
// 별도의 constants.dart 파일에 두는 것이 일반적입니다.
// 여기서는 mapscreen.dart에서 API_URL을 재정의하도록 합니다.

void main() {
  runApp(const MyApp());
}

// 최상위 위젯: 앱의 기본 구조와 테마를 정의
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '한림 캠퍼스 맵',
      theme: ThemeData(
        // 앱의 주요 색상 테마 설정
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        appBarTheme: AppBarTheme(
          // AppBar의 기본 스타일을 정의하여 일관성 유지
          backgroundColor: Colors.blue.shade700,
          foregroundColor: Colors.white,
        ),
      ),
      // 앱의 홈 화면으로 HallymMapScreen 지정
      home: const HallymMapScreen(),
    );
  }
}
