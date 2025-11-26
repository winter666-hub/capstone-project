// lib/models/menu.dart

class Nutrition {
  final String calories;
  final String protein;
  final String allergyInfo;
  // [추가됨] 탄수화물, 지방, 추가정보 필드
  final String carbs;
  final String fat;
  final String info;

  Nutrition.fromJson(Map<String, dynamic>? json)
    : calories = json?['칼로리'] ?? '정보 없음',
      protein = json?['단백질'] ?? '정보 없음',
      allergyInfo = json?['알레르기_정보'] ?? '정보 없음',
      // [추가됨] JSON 키와 매핑
      carbs = json?['탄수화물'] ?? '정보 없음',
      fat = json?['지방'] ?? '정보 없음',
      info = json?['정보'] ?? '';
}

class MenuItem {
  final String name;
  final String price;
  final String time;
  final String section;
  final Nutrition nutrition;

  MenuItem.fromJson(Map<String, dynamic>? json)
    : name = json?['메뉴 이름'] ?? '이름 없음',
      price = json?['가격'] ?? '',
      section = json?['식당 구분'] ?? '기타', // [추가]
      time = json?['식사 시간'] ?? '', // [추가]
      nutrition = Nutrition.fromJson(json?['영양 정보']);
}

class CafeteriaMenu {
  final String date;
  final String restaurant;
  final String price;
  final List<MenuItem> menuList;

  CafeteriaMenu.fromJson(Map<String, dynamic> json)
    : date = json['날짜'] ?? '날짜 미정',
      restaurant = json['식당'] ?? '식당 미정',
      price = json['가격'] ?? '',
      menuList = (json['메뉴 목록'] is List)
          ? (json['메뉴 목록'] as List).map((i) => MenuItem.fromJson(i)).toList()
          : [];
}
