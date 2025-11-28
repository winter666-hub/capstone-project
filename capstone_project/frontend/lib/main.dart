import 'package:flutter/material.dart';
// 지도, 버스 관련 패키지나 로직은 모두 제거했습니다.
import 'screens/cafeteria_screen.dart'; // 당신이 만든 학식 화면 임포트

void main() {
  // 앱 실행 전 초기화 (추후 비동기 작업 등을 위해 유지하는 것이 좋습니다)
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // 앱의 제목 (기기 작업 관리자 등에서 보임)
      title: '학식 앱 (Dev)',

      // 앱의 기본 테마 색상 설정 (학교 상징색 Green)
      theme: ThemeData(
        primarySwatch: Colors.green,
        // 머티리얼 3 디자인 적용 (최신 Flutter 스타일)
        useMaterial3: true,
      ),

      // [핵심] 앱이 켜지자마자 바로 학식 화면을 보여줍니다.
      // 나중에 통합할 때 이 부분을 MainPage(탭 바)로 바꾸면 됩니다.
      home: const CafeteriaScreen(),
    );
  }
}
