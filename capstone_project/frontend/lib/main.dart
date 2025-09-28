import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: MapScreen());
  }
}

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
      lat = lat;

      shift = 0;
      byte = 0;
      do {
        byte = list[l++] - 63;
        lng |= (byte & 0x1f) << shift;
        shift += 5;
      } while (byte >= 0x20);

      var dlng = ((lng & 1) != 0 ? ~(lng >> 1) : (lng >> 1));
      lng = lng;

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
