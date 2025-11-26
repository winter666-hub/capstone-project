import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

//Map Frontend
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
        // 모바일 앱 느낌을 위해 기본 색상을 조정
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const HallymMapScreen(),
    );
  }
}

// --- 데이터 모델 (변화 없음) ---

// 건물 데이터 구조
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

// 경로 단계 데이터 구조
class Step {
  final String instructions;
  final String distance;

  Step({required this.instructions, required this.distance});

  factory Step.fromJson(Map<String, dynamic> json) {
    return Step(instructions: json['instructions'], distance: json['distance']);
  }
}

// 개별 경로 데이터 구조
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

// 전체 경로 응답 데이터 구조
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
          .map((i) => RouteOption.fromJson(i)).toList(),
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
  // TabController를 state에 통합하여 모바일 네비게이션에 적합하게 사용
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

  @override
  void initState() {
    super.initState();
    // 탭은 경로 검색, 건물 목록 2개
    _tabController = TabController(length: 2, vsync: this);
    _fetchBuildings();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // --- 데이터 패칭: 건물 목록 (변화 없음) ---
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

  // --- 데이터 패칭: 경로 검색 (변화 없음) ---
  Future<void> _fetchDirections() async {
    if (_selectedOrigin == null ||
        _selectedDestination == null ||
        _selectedOrigin == _selectedDestination) return;

    setState(() {
      _isLoading = true;
      _directions = null;
      _errorMessage = null;
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

  // --- 맵 이동 및 마커 로직 (변화 없음) ---

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

      // 모바일 환경에 맞춰 패딩 조정
      controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));
    } catch (e) {
      print('건물 좌표 정보 오류: $e');
    }
  }

  Set<Marker> _getMarkers() {
    final Set<Marker> markers = {};
    for (var building in _buildings) {
      markers.add(
        Marker(
          markerId: MarkerId(building.id),
          position: LatLng(building.lat, building.lng),
          infoWindow: InfoWindow(title: building.name),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            (_selectedOrigin == building.name ||
                _selectedDestination == building.name)
                ? BitmapDescriptor.hueAzure
                : BitmapDescriptor.hueRed,
          ),
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

  // --- UI 위젯 구성: 경로 검색 탭 내용 ---

  Widget _buildDirectionsTab() {
    // 모바일에서 스크롤 가능하도록 SingleChildScrollView 사용
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // 출발지 드롭다운
          _buildDropdown(_selectedOrigin, '출발지를 선택하세요', (String? newValue) {
            setState(() {
              _selectedOrigin = newValue;
            });
          }),
          const SizedBox(height: 10),
          // 도착지 드롭다운
          _buildDropdown(_selectedDestination, '도착지를 선택하세요', (String? newValue) {
            setState(() {
              _selectedDestination = newValue;
            });
          }),
          const SizedBox(height: 15),
          // 검색 버튼
          ElevatedButton(
            onPressed: (_selectedOrigin != null &&
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

          // 에러 메시지 표시
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

          // 경로 검색 결과 리스트
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
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
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
                    )
                ),
              ],
            ),
          // 로딩 중이거나 검색 전일 경우
          if (_directions == null && !_isLoading && _errorMessage == null)
            const Center(
              child: Text("출발지와 도착지를 선택하고 검색해주세요.", textAlign: TextAlign.center,),
            ),
        ],
      ),
    );
  }

  // --- UI 위젯 구성: 건물 목록 탭 내용 ---

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
          ));
    }
    if (_buildings.isEmpty) {
      return const Center(child: Text('표시할 건물 목록이 없습니다.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: _buildings.length,
      itemBuilder: (context, index) {
        final building = _buildings[index];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          elevation: 2,
          child: ListTile(
            // 건물 이미지를 왼쪽 리딩 위젯으로 사용
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(4.0),
              child: Image.network(
                building.imageUrl,
                width: 60,
                height: 60,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                const Icon(Icons.apartment, size: 40), // 이미지 로드 실패 시 아이콘
              ),
            ),
            title: Text(
              building.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text('ID: ${building.id}'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
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
                // 지도로 이동 후 탭을 지도 뷰로 변경할 수도 있습니다 (선택 사항)
                // _tabController.animateTo(0);
              }
            },
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
        // AppBar의 하단에 TabBar를 배치하여 모바일 앱 디자인에 맞춤
        bottom: TabBar(
          controller: _tabController,
          tabs: const <Widget>[
            Tab(text: '경로 검색', icon: Icon(Icons.alt_route)),
            Tab(text: '건물 목록', icon: Icon(Icons.list)),
          ],
          labelColor: Colors.white,
          unselectedLabelColor: Colors.blue.shade200,
          indicatorColor: Colors.white,
        ),
      ),
      body: Column(
        children: <Widget>[
          // 상단: 탭 바 뷰 - 모바일에서 적절한 높이를 차지하도록 Expanded 비율 조정
          // 화면의 약 45% (4/9)를 상단 콘텐츠 영역으로 사용
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

          // 하단: Google Map - 화면의 약 55% (5/9)를 지도 영역으로 사용
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
                // 웹 환경에서 API 키 누락 시 발생하는 TypeError에 대한 안내 메시지는 모바일에서는 제거하거나 단순화하는 것이 좋지만,
                // 개발 환경을 고려하여 Positioned 위젯의 크기만 조정하여 유지합니다.
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
                        fontSize: 10, // 모바일 화면에 맞춰 글꼴 크기 축소
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
