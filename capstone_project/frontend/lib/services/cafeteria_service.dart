// lib/services/cafeteria_service.dart

import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/menu.dart';
import '../constants/api_constants.dart';

Future<CafeteriaMenu> fetchCafeteriaMenu() async {
  // 1. 서버에 요청 보냄
  final response = await http.get(Uri.parse(BASE_URL));

  // 2. 한글 깨짐 방지 디코딩
  final jsonResponse = json.decode(utf8.decode(response.bodyBytes));

  if (response.statusCode == 200) {
    // 🚨 [수정 포인트] 아까 추가한 print 문이 에러 원인입니다. 삭제하거나 아래처럼 고치세요.
    // print('✅ API 응답 수신 성공. 메뉴 항목 수: ${jsonResponse['menu_list'].length}'); <-- 이거 지우세요!

    print('✅ API 응답 수신 성공: $jsonResponse'); // 전체 데이터를 찍어서 확인

    return CafeteriaMenu.fromJson(jsonResponse);
  } else {
    // 서버가 200 OK가 아닌 응답(에러 메시지 등)을 보냈을 때
    print('❌ API 에러 발생: $jsonResponse');
    throw Exception('Failed to load menu. Status: ${response.statusCode}');
  }
}
