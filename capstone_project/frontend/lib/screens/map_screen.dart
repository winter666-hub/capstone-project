import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

// API 엔드포인트 설정 (백엔드 서버 주소 - 에뮬레이터 전용)
const String API_URL = 'http://10.0.2.2:5000';

// --- 데이터 모델: 건물 ---
class Building {
  final String id;
  final String name;
  final double lat; // 지도를 제거했지만, 데이터 구조 유지를 위해 남겨둠
  final double lng; // 지도를 제거했지만, 데이터 구조 유지를 위해 남겨둠
  final String imageUrl;

  Building({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    required this.imageUrl,
  });

  factory Building.fromJson(Map<String, dynamic> json) {
    return Building(
      id: json['id'],
      name: json['name'],
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      imageUrl: json['imageUrl'] ?? '',
    );
  }
}

// --- 데이터 모델: 경로 (다시 추가) ---
class Step {
  final String instructions;
  final String distance;

  Step({required this.instructions, required this.distance});

  factory Step.fromJson(Map<String, dynamic> json) {
    return Step(instructions: json['instructions'], distance: json['distance']);
  }
}

class RouteOption {
  final String summary;
  final String distance;
  final List<Step> steps;

  RouteOption({
    required this.summary,
    required this.distance,
    required this.steps,
  });

  factory RouteOption.fromJson(Map<String, dynamic> json) {
    return RouteOption(
      summary: json['summary'],
      distance: json['distance'],
      steps: (json['steps'] as List).map((i) => Step.fromJson(i)).toList(),
    );
  }
}

class Directions {
  final String origin;
  final String destination;
  final List<RouteOption> routes;

  Directions({
    required this.origin,
    required this.destination,
    required this.routes,
  });

  factory Directions.fromJson(Map<String, dynamic> json) {
    // 백엔드 데이터 구조에 맞게 'start'/'end' 또는 'origin'/'destination' 사용
    return Directions(
      origin: json['start'] ?? json['origin'] ?? '출발지',
      destination: json['end'] ?? json['destination'] ?? '도착지',
      routes: (json['routes'] as List)
          .map((i) => RouteOption.fromJson(i))
          .toList(),
    );
  }
}

// --- 메인 앱 위젯 ---
void main() {
  // assets 폴더에 이미지를 추가해야 오류가 발생하지 않습니다.
  // 예: assets/images/main_gate.jpg
  runApp(const HallymCampusApp());
}

class HallymCampusApp extends StatelessWidget {
  const HallymCampusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '한림 캠퍼스 가이드',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
        ),
      ),
      home: const HallymMapScreen(),
    );
  }
}

// --- 건물 및 경로 화면 위젯 (HallymMapScreen) ---

class HallymMapScreen extends StatefulWidget {
  const HallymMapScreen({super.key});

  @override
  State<HallymMapScreen> createState() => _HallymMapScreenState();
}

class _HallymMapScreenState extends State<HallymMapScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // 상태 변수
  List<Building> _buildings = [];
  Directions? _directions;
  List<String> _buildingNames = [];
  String? _selectedOrigin;
  String? _selectedDestination;
  bool _isLoading = true;
  String? _errorMessage;

  String? _selectedBuildingId; // 건물 목록에서 선택된 건물의 ID

  // 건물 ID와 로컬 Assets 경로를 매핑
  final Map<String, String> _imageMap = {
    // 🚨 실제 프로젝트에 맞게 ID와 파일 경로를 수정하세요.
    'main_gate': 'assets/images/main_gate.jpg',
    'CLC': 'assets/images/CLC.jpg',
    'library': 'assets/images/library.jpg', // 일송기념도서관 (데이터에 ID가 없으므로 임의로 추가)
    'basic_education': 'assets/images/basic_education.jpg',
    'engineering': 'assets/images/engineering.jpg',
    'med_bio_research': 'assets/images/med_bio_research.jpg', // 의료*바이오융합연구원
    'international_conf': 'assets/images/international_conf.jpg',
    'international': 'assets/images/international.jpg',
    'Hallym_Rec_Center': 'assets/images/Hallym_Rec_Center.jpg',
    'life_science': 'assets/images/life_science.jpg',
    'main_hall_annex': 'assets/images/main_hall_annex.jpg',
    'main_hall_humanities_1': 'assets/images/main_hall_humanities_1.jpg',
    'humanities_2': 'assets/images/humanities_2.jpg',
    'medicine_hall': 'assets/images/medicine_hall.jpg',
    'natural_science': 'assets/images/natural_science.jpg',
    'social_science_first': 'assets/images/social_science_first.jpg',
    'social_science_second': 'assets/images/social_science_second.jpg',
    'Ilsong_ArtHall': 'assets/images/ilsong_arthall.jpg',
    'forest_of_life': 'assets/images/forest_of_life.jpg',
    'sasaek_gil': 'assets/images/sasaek_gil.jpg',
    'ilsong_garden': 'assets/images/ilsong_garden.jpg',
    'dorm_1': 'assets/images/dorm_1.jpg',
    'dorm_2': 'assets/images/dorm_2.jpg',
    'dorm_3': 'assets/images/dorm_3.jpg',
    'dorm_4': 'assets/images/dorm_4.jpg',
    'dorm_5': 'assets/images/dorm_5.jpg',
    'dorm_6': 'assets/images/dorm_6.jpg',
    'dorm_7': 'assets/images/dorm_7.jpg',
    'dorm_8': 'assets/images/dorm_8.jpg',
    'Out_Tennis': 'assets/images/Out_Tennis.jpg',
    'Golf_range': 'assets/images/Golf_range.jpg',
    'Basketball_court': 'assets/images/Basketball_court.jpg',
    'ILSONG_Stadium': 'assets/images/ILSONG_Stadium.jpg',
    'In_Tennis': 'assets/images/In_Tennis.jpg',
    'ssireum_ring': 'assets/images/ssireum_ring.jpg',
    'sports_equipment': 'assets/images/sports_equipment.jpg',
    'Parking_lot_1': 'assets/images/Parking_lot.jpg',
    'Hallym_Hospital': 'assets/images/Hallym_University_Hospital.jpg',
    // 백엔드 경로 데이터에 '일송기념도서관'이 사용되므로, 이를 'main_hall_humanities_1'의 다른 이름으로 임시 처리
    '일송기념도서관': 'assets/images/library.jpg',
    'H Stadium':
        'assets/images/ILSONG_Stadium.jpg', // 백엔드 경로 데이터에 H Stadium이 사용됨
  };

  final String _defaultAssetImage = 'assets/images/default_building.jpg';

  // 백엔드 경로 데이터에 사용되었으나 건물 목록에 ID가 없는 항목을 처리
  String _mapNameToId(String name) {
    // 일송기념도서관은 실제로 대학본부 인근에 있지만, 편의상 'main_hall_humanities_1'의 ID를 사용하거나,
    // 데이터에 없는 임의의 ID를 사용하여 이미지 맵에 매핑할 수 있습니다.
    if (name == '일송기념도서관') return 'library'; // 임시 ID
    if (name == 'H Stadium')
      return 'ILSONG_Stadium'; // ILSONG Stadium과 동일한 ID 사용

    // 일반적인 건물 이름 매핑
    final building = _buildings.firstWhere(
      (b) => b.name == name,
      orElse: () => Building(
        id: '',
        name: '',
        lat: 0,
        lng: 0,
        imageUrl: '',
      ), // 찾지 못할 경우 빈 Building 반환
    );
    return building.id;
  }

  String _getImagePathForBuildingName(String name) {
    final buildingId = _mapNameToId(name);
    return _imageMap[buildingId] ?? _defaultAssetImage;
  }

  @override
  void initState() {
    super.initState();
    // 탭 컨트롤러 초기화 (2개의 탭: 경로 검색(0), 건물 목록(1))
    _tabController = TabController(length: 2, vsync: this);

    // 초기 건물 목록 로드
    _fetchBuildings();

    // 탭 전환 시 건물 목록(인덱스 1)이 비어있으면 다시 로드합니다.
    _tabController.addListener(_handleTabSelection);
  }

  void _handleTabSelection() {
    // 건물 목록 탭(인덱스 1)이 선택되었고 탭 전환 중이 아닐 때
    if (_tabController.index == 1 && !_tabController.indexIsChanging) {
      // 건물 목록이 비어 있거나, 이전에 오류 메시지가 남아있을 경우 다시 로드를 시도합니다.
      if (_buildings.isEmpty || _errorMessage != null) {
        print('건물 목록 탭 선택됨: 데이터가 없거나 오류 상태이므로 다시 로드 시도.');
        _fetchBuildings();
      } else {
        print('건물 목록 탭 선택됨: 데이터가 이미 있으므로 로드 건너뛰기.');
      }
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabSelection);
    _tabController.dispose();
    super.dispose();
  }

  // --- 데이터 패칭: 건물 목록 ---
  Future<void> _fetchBuildings() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null; // 로드 시도 시 오류 메시지 초기화
    });
    try {
      final response = await http.get(Uri.parse('$API_URL/buildings'));
      if (response.statusCode == 200) {
        final List<dynamic> jsonList = json.decode(
          utf8.decode(response.bodyBytes),
        );
        _buildings = jsonList.map((json) => Building.fromJson(json)).toList();
        _buildingNames = _buildings.map((b) => b.name).toList();

        // 경로 검색에 사용되는 이름 중 목록에 없는 항목 추가 (예: 일송기념도서관)
        if (!_buildingNames.contains('일송기념도서관')) {
          _buildingNames.add('일송기념도서관');
        }
        if (!_buildingNames.contains('H Stadium')) {
          _buildingNames.add('H Stadium');
        }
      } else {
        throw Exception('건물 데이터를 불러오는 데 실패했습니다: ${response.statusCode}');
      }
    } catch (e) {
      // 오류 발생 시 오류 메시지 업데이트
      _errorMessage = '건물 데이터 로드 실패: $e. 백엔드 서버($API_URL)가 실행 중인지 확인하세요.';
      _buildings = []; // 데이터 로드 실패 시 목록을 비워둡니다.
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // --- 데이터 패칭: 경로 검색 (복원) ---
  Future<void> _fetchDirections() async {
    if (_selectedOrigin == null ||
        _selectedDestination == null ||
        _selectedOrigin == _selectedDestination)
      return;

    setState(() {
      _isLoading = true;
      _directions = null;
      _errorMessage = null;
      _selectedBuildingId = null;
    });

    final uri = Uri.parse('$API_URL/directions').replace(
      queryParameters: {
        'originName': _selectedOrigin,
        'destName': _selectedDestination,
      },
    );

    try {
      final response = await http.get(uri);
      final jsonResponse = json.decode(utf8.decode(response.bodyBytes));

      if (response.statusCode == 200) {
        _directions = Directions.fromJson(jsonResponse);
      } else if (response.statusCode == 404) {
        _errorMessage = jsonResponse['message'] ?? '경로를 찾을 수 없습니다.';
        _directions = Directions(
          origin: _selectedOrigin!,
          destination: _selectedDestination!,
          routes: [],
        );
      } else {
        throw Exception('경로 검색 실패: ${response.statusCode}');
      }
    } catch (e) {
      _errorMessage = '경로 검색 요청 실패: $e. 백엔드 서버($API_URL)를 확인하세요.';
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 드롭다운 위젯 빌더 (복원)
  Widget _buildDropdown(
    String? selectedValue,
    String hint,
    Function(String?) onChanged,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedValue,
          hint: Text(hint, style: TextStyle(color: Colors.grey[600])),
          isExpanded: true,
          items: _buildingNames.map((String value) {
            return DropdownMenuItem<String>(value: value, child: Text(value));
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  // 경로 검색 탭 UI (복원)
  Widget _buildDirectionsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _buildDropdown(_selectedOrigin, '출발지를 선택하세요', (String? newValue) {
            setState(() {
              _selectedOrigin = newValue;
              _selectedBuildingId = null;
            });
          }),
          const SizedBox(height: 10),
          _buildDropdown(_selectedDestination, '도착지를 선택하세요', (
            String? newValue,
          ) {
            setState(() {
              _selectedDestination = newValue;
              _selectedBuildingId = null;
            });
          }),
          const SizedBox(height: 15),
          ElevatedButton(
            onPressed:
                (_selectedOrigin != null &&
                    _selectedDestination != null &&
                    _selectedOrigin != _selectedDestination)
                ? () => _fetchDirections()
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade500,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 4,
            ),
            child:
                _isLoading &&
                    _directions == null &&
                    _selectedOrigin != null &&
                    _selectedDestination != null
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Text(
                    '경로 검색',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
          const SizedBox(height: 20),
          // 경로 검색 결과 표시
          if (_errorMessage != null && _directions == null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                _errorMessage!,
                style: const TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

          if (_directions != null) _buildDirectionsResult(_directions!),
        ],
      ),
    );
  }

  // --- 경로 검색 결과 UI (Directions 위젯) ---
  Widget _buildDirectionsResult(Directions directions) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '📍 ${directions.origin}에서 ${directions.destination}까지의 경로',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const Divider(height: 20),
        // 경로 옵션 목록
        ...directions.routes.map((route) {
          return Card(
            margin: const EdgeInsets.only(bottom: 15),
            elevation: 3,
            child: ExpansionTile(
              initiallyExpanded:
                  directions.routes.indexOf(route) == 0, // 첫 번째 경로만 기본으로 펼침
              title: Text(
                '${route.summary} (${route.distance})',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade700,
                ),
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 경로 단계 목록
                      ...route.steps.map((step) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(top: 4.0, right: 8.0),
                                child: Icon(
                                  Icons.location_pin,
                                  size: 18,
                                  color: Colors.green,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  '${route.steps.indexOf(step) + 1}. ${step.instructions} (${step.distance})',
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }

  // --- 건물 목록 탭 UI (BuildingListTab) ---
  Widget _buildBuildingListTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red, fontSize: 16),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _fetchBuildings,
                child: const Text('다시 로드'),
              ),
            ],
          ),
        ),
      );
    }

    // 건물 목록 표시
    return ListView.builder(
      itemCount: _buildings.length,
      itemBuilder: (context, index) {
        final building = _buildings[index];
        final isSelected = building.id == _selectedBuildingId;
        final imagePath = _getImagePathForBuildingName(building.name);

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
          elevation: 4,
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.blue.shade100,
              child: Text(
                building.name[0],
                style: TextStyle(color: Colors.blue.shade700),
              ),
            ),
            title: Text(
              building.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              'ID: ${building.id} | 위도/경도: ${building.lat.toStringAsFixed(4)}, ${building.lng.toStringAsFixed(4)}',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              setState(() {
                _selectedBuildingId = isSelected ? null : building.id; // 선택 토글
              });
            },
          ),
        );
      },
    );
  }

  // --- 메인 빌드 메서드 ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('한림 캠퍼스 가이드'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const <Widget>[
            Tab(icon: Icon(Icons.route), text: '경로 검색'),
            Tab(icon: Icon(Icons.business), text: '건물 목록'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: <Widget>[_buildDirectionsTab(), _buildBuildingListTab()],
      ),
      // 선택된 건물이 있을 경우 상세 정보 패널 표시
      endDrawer: _selectedBuildingId != null
          ? _buildBuildingDetailDrawer()
          : null,
    );
  }

  // --- 건물 상세 정보 드로어 (우측 슬라이드 패널) ---
  Widget _buildBuildingDetailDrawer() {
    final selectedBuilding = _buildings.firstWhere(
      (b) => b.id == _selectedBuildingId,
      orElse: () =>
          Building(id: '', name: '선택 오류', lat: 0, lng: 0, imageUrl: ''),
    );

    // 건물이 존재하지 않으면 드로어를 표시하지 않습니다.
    if (selectedBuilding.id.isEmpty) return const SizedBox.shrink();

    final imagePath = _getImagePathForBuildingName(selectedBuilding.name);

    return Drawer(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // 건물 이미지 (헤더)
            DrawerHeader(
              decoration: BoxDecoration(color: Colors.blue.shade50),
              padding: EdgeInsets.zero,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    imagePath,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Image.asset(_defaultAssetImage, fit: BoxFit.cover);
                    },
                  ),
                  Align(
                    alignment: Alignment.bottomLeft,
                    child: Container(
                      padding: const EdgeInsets.all(16.0),
                      color: Colors.black54,
                      child: Text(
                        selectedBuilding.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 상세 정보
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '건물 정보',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                    ),
                  ),
                  const Divider(height: 10),
                  _buildDetailRow(
                    Icons.account_tree,
                    'ID',
                    selectedBuilding.id,
                  ),
                  _buildDetailRow(
                    Icons.location_on,
                    '위도',
                    selectedBuilding.lat.toStringAsFixed(6),
                  ),
                  _buildDetailRow(
                    Icons.location_on,
                    '경도',
                    selectedBuilding.lng.toStringAsFixed(6),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    '추가 정보',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                    ),
                  ),
                  const Divider(height: 10),
                  // 임시 추가 정보 (백엔드에서 더 많은 정보를 제공하지 않으므로)
                  const Text(
                    '이곳은 한림대학교 캠퍼스 내의 주요 건물/시설입니다. 실제 이용 및 위치 정보는 변동될 수 있습니다.',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 30),
                  // 드로어 닫기 버튼
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context); // 드로어 닫기
                      setState(() {
                        _selectedBuildingId = null; // 선택 해제
                      });
                    },
                    icon: const Icon(Icons.close),
                    label: const Text('닫기'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade400,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 상세 정보 항목 위젯
  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, color: Colors.blue, size: 20),
          const SizedBox(width: 10),
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
