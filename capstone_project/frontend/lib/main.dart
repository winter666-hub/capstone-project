import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

// API 엔드포인트 설정 (백엔드 서버 주소)
const String API_URL = 'http://10.0.2.2:5000';

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
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const HallymMapScreen(),
    );
  }
}

// --- 데이터 모델 (변화 없음) ---
class Building {
  final String id;
  final String name;
  final double lat;
  final double lng;
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
      lat: json['lat'],
      lng: json['lng'],
      imageUrl: json['imageUrl'],
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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchBuildings();
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
      _selectedBuildingId = null; // 경로 검색 시 건물 리스트 강조 초기화
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

  Future<void> _goToRouteBounds() async {
    if (!_controllerCompleter.isCompleted) return;
    final GoogleMapController controller = await _controllerCompleter.future;

    try {
      final origin = _buildings.firstWhere((b) => b.name == _selectedOrigin);
      final destination = _buildings.firstWhere(
        (b) => b.name == _selectedDestination,
      );

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

      controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));
    } catch (e) {
      print('건물 좌표 정보 오류: $e');
    }
  }

  // ⭐️ 수정: 마커 색상을 조건에 따라 다르게 설정
  Set<Marker> _getMarkers() {
    final Set<Marker> markers = {};
    for (var building in _buildings) {
      // 마커 색상 결정 로직
      double hue = BitmapDescriptor.hueRed; // 기본 색상: 빨간색

      // 1. 경로 검색 선택지인 경우 (하늘색/Azure)
      if (_selectedOrigin == building.name ||
          _selectedDestination == building.name) {
        hue = BitmapDescriptor.hueAzure;
      }
      // 2. 건물 목록에서 선택된 경우 (노란색/Yellow)
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

  // --- UI 위젯 구성: 드롭다운 (변화 없음) ---

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

  // --- UI 위젯 구성: 경로 검색 탭 내용 (변화 없음) ---
  Widget _buildDirectionsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _buildDropdown(_selectedOrigin, '출발지를 선택하세요', (String? newValue) {
            setState(() {
              _selectedOrigin = newValue;
              _selectedBuildingId = null; // 경로 드롭다운 사용 시 목록 강조 초기화
            });
          }),
          const SizedBox(height: 10),
          _buildDropdown(_selectedDestination, '도착지를 선택하세요', (
            String? newValue,
          ) {
            setState(() {
              _selectedDestination = newValue;
              _selectedBuildingId = null; // 경로 드롭다운 사용 시 목록 강조 초기화
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
                    style: TextStyle(fontSize: 16, color: Colors.white),
                  ),
          ),
          const SizedBox(height: 20),
          if (_errorMessage != null)
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
          if (_directions != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _directions!.routes.isNotEmpty
                  ? _directions!.routes.map((route) {
                      final index = _directions!.routes.indexOf(route);
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        elevation: 2,
                        child: ExpansionTile(
                          collapsedBackgroundColor: Colors.blue.shade50,
                          title: Text(
                            '${index + 1}. ${route.summary}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text('총 거리: ${route.distance}'),
                          children: route.steps.map((step) {
                            return ListTile(
                              leading: const Icon(
                                Icons.turn_right,
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
                      Center(
                        child: Text(
                          _errorMessage ?? "경로를 찾을 수 없습니다.",
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
            ),
          if (_directions == null && !_isLoading && _errorMessage == null)
            const Center(
              child: Text(
                "출발지와 도착지를 선택하고 검색해주세요.",
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }

  // --- UI 위젯 구성: 건물 목록 탭 내용 (노란색 강조 수정) ---

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

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          elevation: 2,
          child: Container(
            decoration: BoxDecoration(
              color: isSelected
                  ? Colors.yellow.shade100
                  : Colors.white, // 선택 시 노란색 배경
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? Colors.yellow.shade700 : Colors.transparent,
                width: isSelected ? 2 : 0,
              ),
            ),
            child: ListTile(
              tileColor: Colors.transparent,
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(4.0),
                child: Image.network(
                  building.imageUrl,
                  width: 60,
                  height: 60,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      const Icon(Icons.apartment, size: 40),
                ),
              ),
              title: Text(
                building.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text('ID: ${building.id}'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                setState(() {
                  _selectedBuildingId = building.id;
                  // ⭐️ 중요: 건물 목록 항목을 탭하면 경로 검색 상태를 초기화하여,
                  // 마커 색상이 노란색으로 정확히 표시되도록 함
                  _selectedOrigin = null;
                  _selectedDestination = null;
                  _directions = null;
                });

                // 건물 위치로 지도를 이동
                if (_controllerCompleter.isCompleted) {
                  final GoogleMapController controller =
                      await _controllerCompleter.future;
                  controller.animateCamera(
                    CameraUpdate.newLatLngZoom(
                      LatLng(building.lat, building.lng),
                      17.0,
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
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Colors.blue.shade700,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          tabs: const <Widget>[
            Tab(text: '경로 검색', icon: Icon(Icons.alt_route)),
            Tab(text: '건물 목록', icon: Icon(Icons.list)),
          ],
          labelColor: Colors.yellowAccent,
          unselectedLabelColor: Colors.blue.shade200,
          indicatorColor: Colors.yellowAccent,
        ),
      ),
      body: Column(
        children: <Widget>[
          // 상단: 탭 바 뷰
          Expanded(
            flex: 4,
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildDirectionsTab(), // 경로 검색 탭 내용
                _buildBuildingListTab(), // 건물 목록 탭 내용
              ],
            ),
          ),

          // 하단: Google Map
          Expanded(
            flex: 5,
            child: Stack(
              children: [
                GoogleMap(
                  mapType: MapType.hybrid,
                  initialCameraPosition: _hallymCenter,
                  markers: _getMarkers(),
                  onMapCreated: (GoogleMapController controller) {
                    if (!_controllerCompleter.isCompleted) {
                      _controllerCompleter.complete(controller);
                    }
                  },
                ),
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
                      'Web/PC 환경에서 지도 오류 발생 시, index.html의 Google Maps API 키 설정을 확인하세요.',
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
