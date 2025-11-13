import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart'; // PolylinePoints는 더 이상 사용하지 않지만, import는 유지
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart'; // [필수 추가] GPS 사용을 위한 패키지

// *** 중요: 모바일 테스트 시 'localhost' 대신 컴퓨터의 IP 주소 사용 ***
// 예: const String backendUrl = 'http://192.168.1.10:5000';
const String backendUrl = 'http://localhost:5000';

/// 지도 및 경로 안내 기능을 제공하는 페이지 위젯
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  // --- 상태 변수들 ---
  GoogleMapController? _mapController;
  List<Building> _buildings = [];
  Building? _selectedOrigin;
  Building? _selectedDestination;
  LatLng? _currentLocation;

  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {}; // 경로선 제거로 인해 이 Set은 항상 비어있음
  List<Map<String, String>> _directionsSteps = []; // 경로 안내 텍스트 저장

  // 로딩 상태 변수
  bool _isFetchingBuildings = true;
  bool _isFetchingDirections = false;
  bool _isGettingLocation = false;

  // 초기 지도 위치 (예: 한림대학교 중앙)
  static const _initialCameraPosition = CameraPosition(
    target: LatLng(37.8845, 127.7385),
    zoom: 15.5,
  );

  // --- 생명주기 및 초기화 ---
  @override
  void initState() {
    super.initState();
    _fetchBuildings();
  }

  // [추가된 유틸리티] --- 에러 다이얼로그 ---
  void _showErrorDialog(String message) {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('오류 발생'),
        content: Text(message),
        actions: <Widget>[
          TextButton(
            child: const Text('확인'),
            onPressed: () {
              Navigator.of(ctx).pop();
            },
          ),
        ],
      ),
    );
  }

  // --- 비즈니스 로직: GPS ---
  /// 현재 GPS 위치 가져오기 (권한 요청 포함)
  Future<void> _getCurrentLocation() async {
    setState(() {
      _isGettingLocation = true;
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showErrorDialog('위치 서비스(GPS)가 비활성화되어 있습니다.');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showErrorDialog('위치 권한이 거부되었습니다.');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showErrorDialog('위치 권한이 영구적으로 거부되었습니다. 앱 설정에서 권한을 허용해주세요.');
        return;
      }

      // 권한이 허용되면 현재 위치 탐색
      final Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
        // '내 위치'를 출발지로 즉시 설정
        _selectedOrigin = Building(
          id: 'current_location',
          name: '내 위치',
          position: _currentLocation!,
        );
      });

      _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(CameraPosition(target: _currentLocation!, zoom: 16)),
      );

      _updateMarkersAndRoute();
    } catch (e) {
      _showErrorDialog('현재 위치를 가져오는 중 오류 발생: $e');
    } finally {
      setState(() {
        _isGettingLocation = false;
      });
    }
  }

  // --- 비즈니스 로직: 네트워크 ---
  /// 백엔드에서 건물 목록 가져오기
  Future<void> _fetchBuildings() async {
    setState(() {
      _isFetchingBuildings = true;
    });
    try {
      final response = await http.get(Uri.parse('$backendUrl/buildings'));
      if (response.statusCode == 200) {
        // UTF-8로 디코딩하여 한글 깨짐 방지
        final List<dynamic> buildingJson = json.decode(utf8.decode(response.bodyBytes));
        setState(() {
          _buildings = buildingJson.map((json) => Building.fromJson(json)).toList();
        });
      } else {
        _showErrorDialog('서버에서 건물 목록을 가져오는 데 실패했습니다.');
      }
    } catch (e) {
      _showErrorDialog('건물 목록을 불러오는 중 오류가 발생했습니다: $e');
    } finally {
      setState(() {
        _isFetchingBuildings = false;
      });
    }
  }

  /// 백엔드에서 경로 정보 가져오기
  Future<void> _fetchDirections() async {
    if (_selectedOrigin == null || _selectedDestination == null) return;

    // 같은 건물을 선택한 경우 경로 요청 안함
    if (_selectedOrigin!.id == _selectedDestination!.id) {
      _clearRoute(); // 경로만 초기화
      _updateMarkers(); // 마커는 업데이트
      return;
    }

    setState(() {
      _isFetchingDirections = true;
      _directionsSteps.clear(); // 이전 경로 정보 삭제
    });

    final origin = _selectedOrigin!.position;
    final destination = _selectedDestination!.position;

    final url = Uri.parse(
      '$backendUrl/directions?originLat=${origin.latitude}&originLng=${origin.longitude}&destLat=${destination.latitude}&destLng=${destination.longitude}',
    );

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        // UTF-8로 디코딩
        final data = json.decode(utf8.decode(response.bodyBytes));
        _processRouteWithoutDrawing(data); // 지도 이동만 처리

        // 경로 안내 텍스트 업데이트
        setState(() {
          _directionsSteps = (data['steps'] as List).map((step) {
            return {
              "instructions": _stripHtmlIfNeeded(step['html_instructions']),
              "distance": step['distance'],
            };
          }).toList();
        });
      } else {
        _showErrorDialog('경로 정보를 가져오는 데 실패했습니다.');
        _clearRoute();
      }
    } catch (e) {
      _showErrorDialog('경로 정보를 불러오는 중 오류가 발생했습니다: $e');
      _clearRoute();
    } finally {
      setState(() {
        _isFetchingDirections = false;
      });
    }
  }

  // --- 비즈니스 로직: 지도 컨트롤 ---
  /// 경로 정보 처리 (지도 이동만 하고, 선 그리기는 제외)
  void _processRouteWithoutDrawing(Map<String, dynamic> routeData) {
    // 지도 카메라를 경로의 경계에 맞게 이동
    final LatLngBounds bounds = LatLngBounds(
      southwest: LatLng(
        routeData['bounds']['southwest']['lat'],
        routeData['bounds']['southwest']['lng'],
      ),
      northeast: LatLng(
        routeData['bounds']['northeast']['lat'],
        routeData['bounds']['northeast']['lng'],
      ),
    );

    // 계산된 경로에 맞게 카메라 이동
    _mapController?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));
  }

  /// 마커 업데이트 및 경로 재탐색
  void _updateMarkersAndRoute() {
    _updateMarkers();
    if (_selectedOrigin != null && _selectedDestination != null) {
      _fetchDirections();
    }
  }

  /// 마커 업데이트 (경로 탐색 없음)
  void _updateMarkers() {
    setState(() {
      _markers.clear();
      if (_selectedOrigin != null) {
        _markers.add(
          Marker(
            markerId: const MarkerId('origin'),
            position: _selectedOrigin!.position,
            infoWindow: InfoWindow(title: '출발: ${_selectedOrigin!.name}'),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          ),
        );
      }
      // 도착지 마커
      if (_selectedDestination != null) {
        _markers.add(
          Marker(
            markerId: const MarkerId('destination'),
            position: _selectedDestination!.position,
            infoWindow: InfoWindow(title: '도착: ${_selectedDestination!.name}'),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          ),
        );
      }
    });
  }

  /// 경로만 초기화 (마커 유지)
  void _clearRoute() {
    setState(() {
      _polylines.clear(); // 비어있는 Set 유지
      _directionsSteps.clear();
    });
  }

  /// 모든 선택 초기화
  void _clearAll() {
    setState(() {
      _selectedOrigin = null;
      _selectedDestination = null;
      _currentLocation = null;
      _markers.clear();
      _polylines.clear();
      _directionsSteps.clear();
    });
    // 지도 위치 초기화
    _mapController?.animateCamera(CameraUpdate.newCameraPosition(_initialCameraPosition));
  }

  // --- UI 빌드 ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('캠퍼스 경로 안내'),
        backgroundColor: const Color.fromARGB(255, 25, 63, 115),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), tooltip: '초기화', onPressed: _clearAll),
        ],
      ),
      body: Row(
        children: [
          // 왼쪽 지도 영역
          Expanded(
            flex: 3,
            child: GoogleMap(
              initialCameraPosition: _initialCameraPosition,
              onMapCreated: (controller) => _mapController = controller,
              markers: _markers,
              polylines: _polylines, // 비어있는 Set
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
            ),
          ),
          // 오른쪽 컨트롤 패널
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.all(16.0),
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('출발지 선택', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  _buildOriginSelector(),

                  const SizedBox(height: 20),
                  const Text('도착지 선택', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  _buildBuildingList(isOrigin: false),
                  const Divider(height: 40),
                  const Text('경로 안내', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  _buildDirectionsList(), // 디자인 개선된 경로 안내 목록
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 출발지 선택 위젯 (GPS 버튼 + 건물 목록)
  Widget _buildOriginSelector() {
    final bool isCurrentLocationSelected = _selectedOrigin?.id == 'current_location';

    return SizedBox(
      height: 60,
      child: Row(
        children: [
          // '내 위치' 버튼
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ActionChip(
              avatar: _isGettingLocation
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location, size: 18),
              label: const Text('내 위치'),
              backgroundColor: isCurrentLocationSelected
                  ? Colors.blue.shade100
                  : Colors.grey.shade200,
              onPressed: _isGettingLocation ? null : _getCurrentLocation,
            ),
          ),
          // 건물 목록
          Expanded(child: _buildBuildingList(isOrigin: true)),
        ],
      ),
    );
  }

  /// 건물 선택 목록 위젯
  Widget _buildBuildingList({required bool isOrigin}) {
    if (_isFetchingBuildings) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_buildings.isEmpty) {
      return const Center(child: Text('건물 목록 없음'));
    }

    return ListView.builder(
      scrollDirection: Axis.horizontal,
      itemCount: _buildings.length,
      itemBuilder: (context, index) {
        final building = _buildings[index];
        final bool isSelected = isOrigin
            ? _selectedOrigin?.id == building.id
            : _selectedDestination?.id == building.id;

        return GestureDetector(
          onTap: () {
            setState(() {
              if (isOrigin) {
                _selectedOrigin = building;
              } else {
                _selectedDestination = building;
              }
              _updateMarkersAndRoute();
            });
          },
          child: Card(
            color: isSelected ? Colors.blue.shade100 : Colors.white,
            elevation: 3,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              alignment: Alignment.center,
              child: Text(building.name, style: const TextStyle(fontWeight: FontWeight.w500)),
            ),
          ),
        );
      },
    );
  }

  // [디자인 개선 적용] --- 경로 안내 텍스트 목록 위젯 ---
  Widget _buildDirectionsList() {
    if (_isFetchingDirections) {
      return const Expanded(child: Center(child: CircularProgressIndicator()));
    }

    if (_selectedOrigin == null || _selectedDestination == null) {
      return const Expanded(child: Center(child: Text('출발지와 도착지를 선택해주세요.')));
    }

    if (_selectedOrigin!.id == _selectedDestination!.id) {
      return const Expanded(child: Center(child: Text('출발지와 도착지가 동일합니다.')));
    }

    if (_directionsSteps.isEmpty && !_isFetchingDirections) {
      return const Expanded(child: Center(child: Text('경로를 찾을 수 없습니다.')));
    }

    // Card 기반의 Step-by-Step 안내 목록
    return Expanded(
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 8, bottom: 8),
        itemCount: _directionsSteps.length,
        itemBuilder: (context, index) {
          final step = _directionsSteps[index];
          final isLastStep = index == _directionsSteps.length - 1;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              child: ListTile(
                // 단계 아이콘
                leading: Icon(
                  isLastStep ? Icons.flag_rounded : Icons.directions_walk,
                  color: isLastStep ? Colors.red.shade700 : Colors.blue.shade700,
                ),
                // 안내 텍스트
                title: Text(
                  '${index + 1}. ${step['instructions']!}',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5),
                ),
                // 거리 정보 (우측 강조)
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    step['distance']!,
                    style: const TextStyle(
                      color: Colors.black54,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              ),
            ),
          );
        },
      ),
    );
  }

  // --- 유틸리티 ---
  /// HTML 태그 제거 유틸리티 함수
  String _stripHtmlIfNeeded(String text) {
    return text.replaceAll(RegExp(r'<[^>]*>|&[^;]+;'), ' ');
  }
}

/// 건물 데이터 모델
class Building {
  final String id;
  final String name;
  final LatLng position;

  Building({required this.id, required this.name, required this.position});

  factory Building.fromJson(Map<String, dynamic> json) {
    return Building(
      id: json['id'],
      name: json['name'],
      position: LatLng(json['latitude'], json['longitude']),
    );
  }
}
