// lib/screens/cafeteria_screen.dart

import 'package:flutter/material.dart';
import '../services/cafeteria_service.dart';
import '../models/menu.dart';

class CafeteriaScreen extends StatefulWidget {
  const CafeteriaScreen({super.key});

  @override
  State<CafeteriaScreen> createState() => _CafeteriaScreenState();
}

class _CafeteriaScreenState extends State<CafeteriaScreen> {
  late Future<CafeteriaMenu> futureMenu;

  @override
  void initState() {
    super.initState();
    futureMenu = fetchCafeteriaMenu();
  }

  Future<void> _refreshMenu() async {
    setState(() {
      futureMenu = fetchCafeteriaMenu();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('오늘의 학식 메뉴'),
        backgroundColor: Colors.green[700],
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _refreshMenu),
        ],
      ),
      body: FutureBuilder<CafeteriaMenu>(
        future: futureMenu,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('오류: ${snapshot.error}'));
          } else if (snapshot.hasData) {
            final menuData = snapshot.data!;
            if (menuData.menuList.isEmpty)
              return const Center(child: Text('메뉴 없음'));

            // [핵심 로직] 데이터를 "식당 구분 > 시간" 순으로 그룹화합니다.
            // Map<식당이름, Map<시간, List<메뉴>>> 구조
            Map<String, Map<String, List<MenuItem>>> groupedMenu = {};

            for (var item in menuData.menuList) {
              if (!groupedMenu.containsKey(item.section)) {
                groupedMenu[item.section] = {};
              }
              if (!groupedMenu[item.section]!.containsKey(item.time)) {
                groupedMenu[item.section]![item.time] = [];
              }
              groupedMenu[item.section]![item.time]!.add(item);
            }

            return ListView(
              padding: const EdgeInsets.all(10),
              children: [
                // 1. 전체 헤더
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.green[50],
                  child: Text(
                    '${menuData.date} (${menuData.restaurant})',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // 2. 그룹화된 메뉴 표시
                ...groupedMenu.entries.map((sectionEntry) {
                  String sectionName = sectionEntry.key; // 예: 휘당
                  var timeMap = sectionEntry.value;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // [섹션 헤더] (예: 휘당)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 8.0,
                          horizontal: 4.0,
                        ),
                        child: Text(
                          sectionName,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.green[800],
                          ),
                        ),
                      ),

                      // 각 시간별 메뉴 리스트
                      ...timeMap.entries.map((timeEntry) {
                        String timeName = timeEntry.key; // 예: 아침
                        List<MenuItem> items = timeEntry.value;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // [시간 헤더] (예: 아침)
                            Container(
                              margin: const EdgeInsets.only(
                                left: 8,
                                bottom: 4,
                                top: 4,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                timeName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),

                            // [메뉴 카드들]
                            ...items.map((item) => _buildMenuCard(item)),
                            const SizedBox(height: 10),
                          ],
                        );
                      }),
                      const Divider(thickness: 2), // 섹션 구분선
                    ],
                  );
                }),
              ],
            );
          }
          return const Center(child: Text('데이터 없음'));
        },
      ),
    );
  }

  // 메뉴 카드 만드는 함수 (이전 코드 활용)
  // 메뉴 카드 디자인 함수 (수정됨: 탄수화물, 지방 추가)
  Widget _buildMenuCard(MenuItem item) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. 메뉴 이름
            Text(
              item.name,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Divider(height: 16, thickness: 1),

            // 2. 영양 정보 (Wrap을 써서 줄바꿈 자동 처리)
            Wrap(
              spacing: 12.0, // 옆 아이템과 간격
              runSpacing: 4.0, // 줄바꿈 간격
              children: [
                _buildInfoItem('열량', item.nutrition.calories, Colors.orange),
                _buildInfoItem('탄수', item.nutrition.carbs, Colors.brown),
                _buildInfoItem('단백', item.nutrition.protein, Colors.blue),
                _buildInfoItem('지방', item.nutrition.fat, Colors.amber[800]),
              ],
            ),

            const SizedBox(height: 8),

            // 3. 알레르기 정보
            if (item.nutrition.allergyInfo != '정보 없음' &&
                item.nutrition.allergyInfo != '없음')
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    size: 14,
                    color: Colors.redAccent,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '알레르기: ${item.nutrition.allergyInfo}',
                      style: TextStyle(color: Colors.grey[700], fontSize: 13),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  // [보조 함수] 영양 정보 아이템을 만드는 함수
  Widget _buildInfoItem(String label, String value, Color? color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.circle, size: 8, color: color), // 작은 색깔 점
        const SizedBox(width: 4),
        Text('$label: $value', style: const TextStyle(fontSize: 13)),
      ],
    );
  }
}
