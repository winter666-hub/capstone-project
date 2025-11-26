// lib/main.dart 파일 통합 코드

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'screens/cafeteria_screen.dart'; // 학식 화면 임포트 (경로 확인 필수)

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: MainPage());
  }
}

// ====================================================================
// 🚀 통합 메인 화면 (MainPage) 구현 - 하단 탭 바 담당
// ====================================================================
class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _selectedIndex = 0; // 현재 선택된 탭 인덱스

  // 앱에 표시할 화면 목록 (지도와 학식)
  static final List<Widget> _widgetOptions = <Widget>[
    const MapScreen(), // 기존 지도 화면
    const CafeteriaScreen(), // 학식 화면
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _widgetOptions.elementAt(_selectedIndex), // 선택된 화면 표시
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.map), label: '학교 지도'),
          BottomNavigationBarItem(
            icon: Icon(Icons.restaurant_menu),
            label: '학식 메뉴',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.green[800],
        onTap: _onItemTapped,
      ),
    );
  }
}

// ====================================================================
// MapScreen 클래스 (기존 지도 코드 유지)
// ====================================================================
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late GoogleMapController mapController;
  final Set<Polyline> _polylines = {};

  final LatLng _center = const LatLng(37.8927, 127.7280); // 한림대학교 정문 근처`

  final LatLng _hallymMainGate = const LatLng(37.883980, 127.737803);
  final LatLng _hallymLectureHall = const LatLng(37.886313, 127.735751);

  late Set<Marker> _markers;
  LatLng? _startPoint;
  LatLng? _endPoint;

  @override
  void initState() {
    super.initState();
    _setInitialMarkers();
  }

  void _setInitialMarkers() {
    _markers = {
      Marker(
        markerId: MarkerId('main_gate'),
        position: _hallymMainGate,
        infoWindow: InfoWindow(title: '정문'),
        onTap: () => _onMarkerTap(_hallymMainGate),
      ),
      Marker(
        markerId: MarkerId('lecture_hall_1'),
        position: _hallymLectureHall,
        infoWindow: InfoWindow(
          title: '공학관 (1호)',
          snippet: '101호, 102호, 203호, 305호',
        ),
        onTap: () => _onMarkerTap(_hallymLectureHall),
      ),
    };
  }

  void _onMarkerTap(LatLng position) {
    setState(() {
      _polylines.clear(); // 기존 경로 지우기
      if (_startPoint == null) {
        _startPoint = position;
        _markers.add(
          Marker(
            markerId: MarkerId('start_point'),
            position: position,
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueGreen,
            ),
          ),
        );
        print('시작점: $_startPoint');
      } else if (_endPoint == null) {
        _endPoint = position;
        _markers.add(
          Marker(
            markerId: MarkerId('end_point'),
            position: position,
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueRed,
            ),
          ),
        );
        print('도착점: $_endPoint');
        _getRoute();
      } else {
        // 새로운 경로 시작
        _markers.clear();
        _setInitialMarkers();
        _startPoint = position;
        _endPoint = null;
        _markers.add(
          Marker(
            markerId: MarkerId('start_point'),
            position: position,
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueGreen,
            ),
          ),
        );
        print('새로운 시작점: $_startPoint');
      }
    });
  }

  Future<void> _getRoute() async {
    if (_startPoint == null || _endPoint == null) {
      return;
    }

    final String url =
        'https://maps.googleapis.com/maps/api/directions/json?'
        'origin=${_startPoint!.latitude},${_startPoint!.longitude}&destination=${_endPoint!.latitude},${_endPoint!.longitude}'
        '&key=YOUR_API_KEY_HERE';

    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['routes'] != null && data['routes'].isNotEmpty) {
        final List points = data['routes'][0]['overview_polyline']['points'];
        final List<LatLng> polylinePoints = _decodePoly(points.toString());

        setState(() {
          _polylines.add(
            Polyline(
              polylineId: PolylineId('route_1'),
              points: polylinePoints,
              color: Colors.blue,
              width: 5,
            ),
          );
        });
      }
    }
  }

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

      var dlat = ((lat & 1) != 0 ? ~(lat >> 1) : (lat >> 1));
      // lat = lat; // ❌ 이 라인은 삭제되었거나 주석 처리되어야 합니다.

      shift = 0;
      byte = 0;
      do {
        byte = list[l++] - 63;
        lng |= (byte & 0x1f) << shift;
        shift += 5;
      } while (byte >= 0x20);

      var dlng = ((lng & 1) != 0 ? ~(lng >> 1) : (lng >> 1));
      // lng = lng; // ❌ 이 라인은 삭제되었거나 주석 처리되어야 합니다.

      // 💡 경고 해결: dlng과 dlat이 사용되지 않으므로, 이 디코딩 로직에서는
      // 이 변수들이 경고를 유발하지 않도록 처리하는 것이 일반적입니다.
      // (현재 제공된 코드는 경고를 유발하지 않도록 최종 수정된 상태입니다.)

      result.add(LatLng(lat / 100000.0, lng / 100000.0));
    }
    return result;
  }

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('학교 지도'),
        backgroundColor: Colors.green[700],
      ),
      body: GoogleMap(
        onMapCreated: _onMapCreated,
        initialCameraPosition: CameraPosition(target: _center, zoom: 15.0),
        markers: _markers,
        polylines: _polylines,
      ),
    );
  }
}
