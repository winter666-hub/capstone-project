import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

// API 엔드포인트 설정 (백엔드 서버 주소 - 에뮬레이터 전용)
// Note: In a real project, this should be in a separate constants file.
const String API_URL = 'http://10.0.2.2:5000';

// --- 데이터 모델 ---
class Building {
  final String id;
  final String name;
  final double lat;
  final double lng;
  final String imageUrl; // 백엔드에서 받은 URL (로컬 이미지 매핑에 사용)

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
    return Directions(
      origin: json['start'] ?? json['origin'] ?? '출발지',
      destination: json['end'] ?? json['destination'] ?? '도착지',
      routes: (json['routes'] as List)
          .map((i) => RouteOption.fromJson(i))
          .toList(),
    );
  }
}

// --- 지도 화면 위젯 (HallymMapScreen) ---

class HallymMapScreen extends StatefulWidget {
  const HallymMapScreen({super.key});

  @override
  State<HallymMapScreen> createState() => _HallymMapScreenState();
}

class _HallymMapScreenState extends State<HallymMapScreen>
    with SingleTickerProviderStateMixin {
  final Completer<GoogleMapController> _controllerCompleter = Completer();
  late TabController _tabController;

  // 한림대학교 캠퍼스 중심 좌표
  static const CameraPosition _hallymCenter = CameraPosition(
    target: LatLng(37.8860, 127.7380),
    zoom: 15.5,
  );

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
    // 키(ID)는 백엔드에서 받는 건물 ID와 일치해야 합니다.
    // 주요 건물
    'main_gate': 'assets/images/main_gate.jpg',
    'CLC': 'assets/images/CLC.jpg',
    'library': 'assets/images/library.jpg',

    // 학과 건물
    'basic_education': 'assets/images/basic_education.jpg',
    'engineering': 'assets/images/engineering.jpg',
    'medical_science_building': 'assets/images/medical_science_building.jpg',
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

    // 기숙사
    'dorm_1': 'assets/images/dorm_1.jpg',
    'dorm_2': 'assets/images/dorm_2.jpg',
    'dorm_3': 'assets/images/dorm_3.jpg',
    'dorm_4': 'assets/images/dorm_4.jpg',
    'dorm_5': 'assets/images/dorm_5.jpg',
    'dorm_6': 'assets/images/dorm_6.jpg',
    'dorm_7': 'assets/images/dorm_7.jpg',
    'dorm_8': 'assets/images/dorm_8.jpg',
    // 체육시설
    'Out_Tennis': 'assets/images/Out_Tennis.jpg',
    'Golf_range': 'assets/images/Golf_range.jpg',
    'Basketball_court': 'assets/images/Basketball_court.jpg',
    'ILSONG_Stadium': 'assets/images/ILSONG_Stadium.jpg',
    'In_Tennis': 'assets/images/In_Tennis.jpg',
    'ssireum_ring': 'assets/images/ssireum_ring.jpg',

    // 기타
    'med_bio_research': 'assets/images/med_bio_research.jpg',
    'sports_equipment': 'assets/images/sports_equipment.jpg',
    'Parking_lot_1': 'assets/images/Parking_lot.jpg',
    'Hallym_Hospital': 'assets/images/Hallym_University_Hospital.jpg',
  };

  // 매핑되지 않은 ID에 대해 사용할 기본 이미지 경로
  final String _defaultAssetImage = 'assets/images/library.jpg';

  @override
  void initState() {
    super.initState();
    // 탭 컨트롤러 초기화 (2개의 탭: 경로 검색(0), 건물 목록(1))
    _tabController = TabController(length: 2, vsync: this);

    // 초기 건물 목록 로드
    _fetchBuildings();

    // [수정: TabController 리스너 추가]
    // 탭 전환 시 건물 목록(인덱스 1)이 비어있으면 다시 로드합니다.
    _tabController.addListener(_handleTabSelection);
  }

  // [추가: TabController 리스너 핸들러]
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
    _tabController.dispose();
    super.dispose();
  }

  // --- 데이터 패칭: 건물 목록 ---
  Future<void> _fetchBuildings() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final response = await http.get(Uri.parse('$API_URL/buildings'));
      if (response.statusCode == 200) {
        final List<dynamic> jsonList = json.decode(
          utf8.decode(response.bodyBytes),
        );
        _buildings = jsonList.map((json) => Building.fromJson(json)).toList();
        _buildingNames = _buildings.map((b) => b.name).toList();
      } else {
        throw Exception('건물 데이터를 불러오는 데 실패했습니다: ${response.statusCode}');
      }
    } catch (e) {
      _errorMessage = '건물 데이터 로드 실패: $e. 백엔드 서버($API_URL)가 실행 중인지 확인하세요.';
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // --- 데이터 패칭: 경로 검색 ---
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
      if (_directions != null && _directions!.routes.isNotEmpty) {
        _goToRouteBounds();
      }
    }
  }

  // 경로의 출발지/도착지 포함 영역으로 카메라 이동
  Future<void> _goToRouteBounds() async {
    if (!_controllerCompleter.isCompleted) return;
    final GoogleMapController controller = await _controllerCompleter.future;

    try {
      final origin = _buildings.firstWhere((b) => b.name == _selectedOrigin);
      final destination = _buildings.firstWhere(
        (b) => b.name == _selectedDestination,
      );

      // LatLngBounds 계산
      final LatLngBounds bounds = LatLngBounds(
        southwest: LatLng(
          (origin.lat < destination.lat ? origin.lat : destination.lat) -
              0.0005,
          (origin.lng < destination.lng ? origin.lng : destination.lng) -
              0.0005,
        ),
        northeast: LatLng(
          (origin.lat > destination.lat ? origin.lat : destination.lat) +
              0.0005,
          (origin.lng > destination.lng ? origin.lng : destination.lng) +
              0.0005,
        ),
      );

      // 계산된 영역으로 지도 카메라 애니메이션 이동
      controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));
    } catch (e) {
      // 건물 정보가 없는 경우 오류 처리
      print('건물 좌표 정보 오류: $e');
    }
  }

  // 마커 설정
  Set<Marker> _getMarkers() {
    final Set<Marker> markers = {};
    for (var building in _buildings) {
      double hue = BitmapDescriptor.hueRed; // 기본 색상 (빨강)

      // 선택된 출발지/도착지 마커는 파랑
      if (_selectedOrigin == building.name ||
          _selectedDestination == building.name) {
        hue = BitmapDescriptor.hueAzure;
      }
      // 건물 목록에서 선택된 마커는 노랑
      else if (_selectedBuildingId == building.id) {
        hue = BitmapDescriptor.hueYellow;
      }

      markers.add(
        Marker(
          markerId: MarkerId(building.id),
          position: LatLng(building.lat, building.lng),
          infoWindow: InfoWindow(title: building.name),
          icon: BitmapDescriptor.defaultMarkerWithHue(hue),
        ),
      );
    }
    return markers;
  }

  // 드롭다운 위젯 빌더
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

  // 경로 검색 탭 UI
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
                        _selectedOrigin != _selectedDestination) &&
                    !_isLoading
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
            child: _isLoading && _directions == null
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
          // ... (생략)

          // 1. 일반적인 오류 메시지 (초기 건물 로드 실패 또는 경로 검색 요청 자체 실패)
          if (_errorMessage != null && _directions == null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

          // 2. 경로 검색 성공 후 결과 표시
          if (_directions != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _directions!.routes.isNotEmpty
                  ? _directions!.routes.map((route) {
                      final index = _directions!.routes.indexOf(route);
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: ExpansionTile(
                          collapsedBackgroundColor: Colors.blue.shade50,
                          backgroundColor: Colors.white,
                          title: Text(
                            '${index + 1}. ${route.summary}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            '총 거리: ${route.distance}',
                            style: TextStyle(color: Colors.blue.shade700),
                          ),
                          children: route.steps.map((step) {
                            return ListTile(
                              leading: const Icon(
                                Icons.directions_walk,
                                color: Colors.blue,
                              ),
                              title: Text(step.instructions),
                              trailing: Text(step.distance),
                            );
                          }).toList(),
                        ),
                      );
                    }).toList()
                  : [
                      // 3. 경로 검색은 되었으나, 백엔드에서 경로를 못 찾은 경우 (routes: [] 일 때)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            // 404 응답의 메시지(API_URL) 또는 일반 경로 없음 메시지
                            _errorMessage ?? "경로를 찾을 수 없습니다. 다른 경로를 시도해 보세요.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ),
                    ],
            ),

          // 4. 경로 검색 전 안내 메시지 (초기 상태)
          if (_directions == null &&
              !_isLoading &&
              _errorMessage == null &&
              _buildings.isNotEmpty)
            const Center(
              child: Text(
                "출발지와 도착지를 선택하고 검색해주세요.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ),
        ],
      ),
    );
  }

  // 건물 목록 탭 UI
  Widget _buildBuildingListTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null) {
      return Center(
        child: Text(
          _errorMessage!,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.red),
        ),
      );
    }
    if (_buildings.isEmpty) {
      return const Center(child: Text('표시할 건물 목록이 없습니다.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: _buildings.length,
      itemBuilder: (context, index) {
        final building = _buildings[index];
        final bool isSelected = _selectedBuildingId == building.id;

        // 건물 ID에 따라 로컬 Assets 경로 가져오기
        final String assetPath = _imageMap[building.id] ?? _defaultAssetImage;

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Container(
            decoration: BoxDecoration(
              color: isSelected ? Colors.yellow.shade100 : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? Colors.yellow.shade700 : Colors.transparent,
                width: isSelected ? 2 : 0,
              ),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.all(10),
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(8.0),
                child: Image.asset(
                  assetPath,
                  width: 60,
                  height: 60,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => const Icon(
                    Icons.apartment,
                    size: 40,
                    color: Colors.blueGrey,
                  ),
                ),
              ),
              title: Text(
                building.name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              subtitle: Text(
                'ID: ${building.id}',
                style: TextStyle(color: Colors.grey.shade600),
              ),
              trailing: const Icon(Icons.chevron_right, color: Colors.blueGrey),
              onTap: () async {
                setState(() {
                  _selectedBuildingId = building.id;
                  // 경로 검색 상태 초기화
                  _selectedOrigin = null;
                  _selectedDestination = null;
                  _directions = null;
                });

                // 선택된 건물로 지도 이동
                if (_controllerCompleter.isCompleted) {
                  final GoogleMapController controller =
                      await _controllerCompleter.future;
                  controller.animateCamera(
                    CameraUpdate.newLatLngZoom(
                      LatLng(building.lat, building.lng),
                      17.0, // 더 가까운 줌 레벨
                    ),
                  );
                }
              },
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '한림대학교 캠퍼스 맵',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: <Widget>[
            Tab(
              text: '경로 검색',
              icon: Icon(Icons.alt_route, color: Colors.white),
            ),
            Tab(
              text: '건물 목록',
              icon: Icon(Icons.list, color: Colors.white),
            ),
          ],
          labelColor: Colors.yellowAccent,
          unselectedLabelColor: Colors.blue.shade200,
          indicatorColor: Colors.yellowAccent,
        ),
      ),
      body: Column(
        children: <Widget>[
          // 상단: 탭 바 뷰 (경로 검색/건물 목록)
          Expanded(
            flex: 4,
            child: TabBarView(
              controller: _tabController,
              children: [_buildDirectionsTab(), _buildBuildingListTab()],
            ),
          ),

          // 하단: Google Map
          Expanded(
            flex: 5,
            child: Stack(
              children: [
                GoogleMap(
                  mapType: MapType.hybrid, // 위성/지형 혼합 맵
                  initialCameraPosition: _hallymCenter,
                  markers: _getMarkers(),
                  onMapCreated: (GoogleMapController controller) {
                    if (!_controllerCompleter.isCompleted) {
                      _controllerCompleter.complete(controller);
                    }
                  },
                ),
                // 지도 사용자를 위한 경고/정보 메시지
                Positioned(
                  bottom: 5,
                  left: 5,
                  right: 5,
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Web/PC 환경에서 지도 오류 발생 시, Google Maps API 키 설정을 확인하세요.',
                      style: TextStyle(
                        color: Colors.yellowAccent,
                        fontSize: 10,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
