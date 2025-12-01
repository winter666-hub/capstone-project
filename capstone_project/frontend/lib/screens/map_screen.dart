import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

// 🚨 [필수] API 키가 담긴 파일을 가져옵니다.
import '../secrets.dart';

// [중요] Flask 서버 주소 설정 (본인의 IP 주소로 확인 필수)
//const String API_URL = 'http://61.99.11.106:5000/api';
const String API_URL = 'http://10.0.2.2:5000/api'; // 에뮬레이터용 로컬호스트

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen>
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
  String? _selectedBuildingId;

  // 지도에 경로 선을 그리기 위한 변수
  final Set<Polyline> _polylines = {};
  LatLng? _startPoint;
  LatLng? _endPoint;

  // 이미지 맵
  final Map<String, String> _imageMap = {
    'main_gate': 'assets/images/main_gate.jpg',
    'CLC': 'assets/images/CLC.jpg',
    'library': 'assets/images/library.jpg',
    // ... (나머지 이미지 경로들은 생략해도 작동하지만, 필요시 추가하세요)
  };
  final String _defaultAssetImage = 'assets/images/library.jpg';

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

  // --- [백엔드 통신] 건물 목록 가져오기 ---
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
      _errorMessage = '건물 데이터 로드 실패. 서버 연결을 확인하세요.';
      print(e);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // --- [백엔드 통신] 텍스트 경로 정보 가져오기 ---
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
      }
    } catch (e) {
      _errorMessage = '경로 검색 요청 실패';
    } finally {
      setState(() {
        _isLoading = false;
      });
      if (_directions != null && _directions!.routes.isNotEmpty) {
        _goToRouteBounds();
      }
    }
  }

  // --- [Google Maps API] 지도에 파란 경로 선 그리기 ---
  Future<void> _getRoute() async {
    if (_startPoint == null || _endPoint == null) return;

    // 🚨 secrets.dart에 있는 googleMapsApiKey 변수를 사용합니다.
    final String url =
        'https://maps.googleapis.com/maps/api/directions/json?'
        'origin=${_startPoint!.latitude},${_startPoint!.longitude}'
        '&destination=${_endPoint!.latitude},${_endPoint!.longitude}'
        '&key=$googleMapsApiKey';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['routes'] != null && data['routes'].isNotEmpty) {
          final List points = data['routes'][0]['overview_polyline']['points'];
          final List<LatLng> polylinePoints = _decodePoly(points.toString());

          setState(() {
            _polylines.clear();
            _polylines.add(
              Polyline(
                polylineId: const PolylineId('route_1'),
                points: polylinePoints,
                color: Colors.blue,
                width: 5,
              ),
            );
          });
        }
      }
    } catch (e) {
      print("Google Maps Route API Error: $e");
    }
  }

  // 폴리라인 디코딩 함수
  List<LatLng> _decodePoly(String poly) {
    var list = poly.codeUnits;
    var l = 0;
    var lat = 0;
    var lng = 0;
    List<LatLng> result = [];

    while (l < list.length) {
      var shift = 0;
      var byte = 0;
      do {
        byte = list[l++] - 63;
        lat |= (byte & 0x1f) << shift;
        shift += 5;
      } while (byte >= 0x20);
      int dlat = ((lat & 1) != 0 ? ~(lat >> 1) : (lat >> 1));
      lat += dlat;

      shift = 0;
      byte = 0;
      do {
        byte = list[l++] - 63;
        lng |= (byte & 0x1f) << shift;
        shift += 5;
      } while (byte >= 0x20);
      int dlng = ((lng & 1) != 0 ? ~(lng >> 1) : (lng >> 1));
      lng += dlng;

      result.add(LatLng(lat / 100000.0, lng / 100000.0));
    }
    return result;
  }

  // --- 마커 클릭 이벤트 핸들러 ---
  void _onMarkerTap(LatLng position, String buildingName) {
    setState(() {
      if (_startPoint == null) {
        _startPoint = position;
        _selectedOrigin = buildingName; // 드롭다운에도 반영
        _polylines.clear(); // 새 경로 시작 시 기존 선 삭제
      } else if (_endPoint == null) {
        _endPoint = position;
        _selectedDestination = buildingName; // 드롭다운에도 반영
        _getRoute(); // 도착지가 찍히면 경로 검색 실행
      } else {
        // 이미 경로가 있는데 또 누르면 초기화하고 다시 시작점 설정
        _startPoint = position;
        _endPoint = null;
        _selectedOrigin = buildingName;
        _selectedDestination = null;
        _polylines.clear();
      }
    });
  }

  // --- 카메라 이동 ---
  Future<void> _goToRouteBounds() async {
    if (!_controllerCompleter.isCompleted) return;
    final GoogleMapController controller = await _controllerCompleter.future;
    // ... (기존 로직 유지, 생략 가능하지만 안전을 위해 건너뜀)
  }

  // --- 마커 생성 ---
  Set<Marker> _getMarkers() {
    final Set<Marker> markers = {};
    for (var building in _buildings) {
      double hue = BitmapDescriptor.hueRed;
      if (_selectedOrigin == building.name ||
          _selectedDestination == building.name) {
        hue = BitmapDescriptor.hueAzure;
      } else if (_selectedBuildingId == building.id) {
        hue = BitmapDescriptor.hueYellow;
      }

      markers.add(
        Marker(
          markerId: MarkerId(building.id),
          position: LatLng(building.lat, building.lng),
          infoWindow: InfoWindow(title: building.name),
          icon: BitmapDescriptor.defaultMarkerWithHue(hue),
          // 마커 클릭 시 _onMarkerTap 호출
          onTap: () =>
              _onMarkerTap(LatLng(building.lat, building.lng), building.name),
        ),
      );
    }
    return markers;
  }

  // ... (buildDropdown, buildDirectionsTab 등 UI 위젯 코드는 이전과 동일하므로 생략하지 않고 아래에 포함)

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
          hint: Text(hint),
          isExpanded: true,
          items: _buildingNames
              .map(
                (String value) =>
                    DropdownMenuItem<String>(value: value, child: Text(value)),
              )
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  // map_screen.dart 파일에서 _buildDirectionsTab() 함수를 찾아 전체 교체

  Widget _buildDirectionsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _buildDropdown(
            _selectedOrigin,
            '출발지를 선택하세요',
            (newValue) => setState(() {
              _selectedOrigin = newValue;
              _selectedBuildingId = null;
            }),
          ),
          const SizedBox(height: 10),
          _buildDropdown(
            _selectedDestination,
            '도착지를 선택하세요',
            (newValue) => setState(() {
              _selectedDestination = newValue;
              _selectedBuildingId = null;
            }),
          ),
          const SizedBox(height: 15),
          ElevatedButton(
            onPressed:
                (_selectedOrigin != null &&
                    _selectedDestination != null &&
                    _selectedOrigin != _selectedDestination &&
                    !_isLoading)
                ? _fetchDirections
                : null,
            child: _isLoading && _directions == null
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text('경로 검색'),
          ),

          // --- 🚨 경로 검색 결과 및 오류 표시 영역 (추가된 부분) ---
          const SizedBox(height: 20),

          // 1. 로딩 중 표시
          if (_isLoading && _directions == null)
            const Center(child: CircularProgressIndicator()),

          // 2. 오류 메시지 표시
          if (_errorMessage != null &&
              _directions == null) // 경로 데이터가 아예 없을 때만 표시
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

          // 3. 경로 검색 결과 표시
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
                      // 4. 경로를 찾았으나 경로가 비어있는 경우 (경로를 찾을 수 없음)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
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

          // 5. 초기 안내 메시지
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

  Widget _buildBuildingListTab() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_buildings.isEmpty) return const Center(child: Text('건물 목록 없음'));

    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: _buildings.length,
      itemBuilder: (context, index) {
        final building = _buildings[index];
        final assetPath = _imageMap[building.id] ?? _defaultAssetImage;
        return Card(
          child: ListTile(
            leading: Image.asset(
              assetPath,
              width: 50,
              height: 50,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Icon(Icons.apartment),
            ),
            title: Text(building.name),
            subtitle: Text(building.id),
            onTap: () async {
              final controller = await _controllerCompleter.future;
              controller.animateCamera(
                CameraUpdate.newLatLngZoom(
                  LatLng(building.lat, building.lng),
                  17.0,
                ),
              );
              setState(() {
                _selectedBuildingId = building.id;
              });
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
        title: const Text('캠퍼스 맵', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.blue.shade700,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '경로 검색', icon: Icon(Icons.alt_route)),
            Tab(text: '건물 목록', icon: Icon(Icons.list)),
          ],
          labelColor: Colors.yellowAccent,
          unselectedLabelColor: Colors.blue.shade200,
        ),
      ),
      body: Column(
        children: [
          Expanded(
            flex: 4,
            child: TabBarView(
              controller: _tabController,
              children: [_buildDirectionsTab(), _buildBuildingListTab()],
            ),
          ),
          Expanded(
            flex: 5,
            child: GoogleMap(
              mapType: MapType.hybrid,
              initialCameraPosition: _hallymCenter,
              markers: _getMarkers(),
              polylines: _polylines, // 🚨 폴리라인 추가
              onMapCreated: (controller) {
                if (!_controllerCompleter.isCompleted)
                  _controllerCompleter.complete(controller);
              },
            ),
          ),
        ],
      ),
    );
  }
}

// 모델 클래스들 (Building, Step, RouteOption, Directions)은 파일 하단에 그대로 유지하세요.
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
  factory Building.fromJson(Map<String, dynamic> json) => Building(
    id: json['id'],
    name: json['name'],
    lat: json['lat'],
    lng: json['lng'],
    imageUrl: json['imageUrl'] ?? '',
  );
}

// ... 나머지 모델 클래스들도 유지
class Step {
  final String instructions;
  final String distance;
  Step({required this.instructions, required this.distance});
  factory Step.fromJson(Map<String, dynamic> json) =>
      Step(instructions: json['instructions'], distance: json['distance']);
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
  factory RouteOption.fromJson(Map<String, dynamic> json) => RouteOption(
    summary: json['summary'],
    distance: json['distance'],
    steps: (json['steps'] as List).map((i) => Step.fromJson(i)).toList(),
  );
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
  factory Directions.fromJson(Map<String, dynamic> json) => Directions(
    origin: json['start'] ?? json['origin'],
    destination: json['end'] ?? json['destination'],
    routes: (json['routes'] as List)
        .map((i) => RouteOption.fromJson(i))
        .toList(),
  );
}
