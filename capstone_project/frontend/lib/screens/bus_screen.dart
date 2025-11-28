import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

// [주소 설정] 에뮬레이터 전용 IP 사용
const String BUS_API_URL = 'http://10.0.2.2:5000/api/bus/arrival';

// =========================================
// 1. 데이터 모델 (BusArrivalInfo, ScheduleInfo)
// =========================================

class BusArrivalInfo {
  final String routeNo;
  String remainingTime;
  String remainingStations;
  int? totalSeconds;

  BusArrivalInfo({
    required this.routeNo,
    required this.remainingTime,
    required this.remainingStations,
    this.totalSeconds,
  });
}

class ScheduleInfo {
  final String routeNo;
  final String destination;
  final String type; // 셔틀/기차 구분
  final String departureTime; // "HH:mm" 형식
  String remainingToDeparture;

  ScheduleInfo({
    required this.routeNo,
    this.destination = '',
    this.type = '셔틀',
    required this.departureTime,
    this.remainingToDeparture = '',
  });
}

// =========================================
// 2. 버스 화면 위젯 (메인 로직)
// =========================================

class HallymBusArrivalScreen extends StatefulWidget {
  const HallymBusArrivalScreen({super.key});

  @override
  State<HallymBusArrivalScreen> createState() => _HallymBusArrivalScreenState();
}

class _HallymBusArrivalScreenState extends State<HallymBusArrivalScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Timer? _timer;

  // [데이터]
  List<BusArrivalInfo> busArrivals = [];
  // [정적 데이터] 시간표는 API가 없으므로 로컬에서 정의 (예시 데이터)
  List<ScheduleInfo> schedules = [
    ScheduleInfo(
      routeNo: 'ITX-청춘',
      destination: '용산',
      type: '기차',
      departureTime: '15:30',
    ),
    ScheduleInfo(
      routeNo: '한림대 셔틀',
      destination: '춘천역',
      type: '셔틀',
      departureTime: '15:15',
    ),
  ];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchInitialData();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  // --- API 호출 및 데이터 로드 함수 ---
  Future<void> _fetchInitialData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http.get(Uri.parse(BUS_API_URL));
      if (response.statusCode == 200) {
        final jsonResponse = json.decode(utf8.decode(response.bodyBytes));

        List<BusArrivalInfo> newArrivals = [];
        // 'data' 키가 있는지 확인하고 순회
        if (jsonResponse['data'] is List) {
          for (var item in jsonResponse['data']) {
            newArrivals.add(
              BusArrivalInfo(
                routeNo: item['routeNo'] ?? 'N/A',
                remainingTime: item['message'] ?? '정보 없음',
                remainingStations: '${item['remainingStations']}번째 전',
                totalSeconds: item['totalSeconds'],
              ),
            );
          }
        }

        setState(() {
          busArrivals = newArrivals;
          _isLoading = false;
        });
      } else {
        throw Exception('API 연결 오류: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        print('버스 API 로드 실패: $e');
      });
    }
  }

  // --- 타이머 시작 함수 (1초마다 갱신) ---
  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        _updateBusTimes();
        _updateScheduleTimes(); // 시간표 남은 시간도 갱신
      });
    });
  }

  // --- 실시간 버스 시간 갱신 함수 ---
  void _updateBusTimes() {
    for (var bus in busArrivals) {
      if (bus.totalSeconds != null && bus.totalSeconds! > 0) {
        bus.totalSeconds = bus.totalSeconds! - 1;
        int min = bus.totalSeconds! ~/ 60;
        int sec = bus.totalSeconds! % 60;
        bus.remainingTime = '$min분 $sec초 후 도착';
      } else if (bus.totalSeconds != null && bus.totalSeconds! == 0) {
        bus.remainingTime = '잠시 후 도착';
        bus.totalSeconds = null;
      }
    }
  }

  // --- 정적 시간표 남은 시간 갱신 함수 ---
  void _updateScheduleTimes() {
    DateTime now = DateTime.now();
    for (var item in schedules) {
      try {
        List<String> parts = item.departureTime.split(':');
        int hour = int.parse(parts[0]);
        int minute = int.parse(parts[1]);
        DateTime depart = DateTime(now.year, now.month, now.day, hour, minute);

        if (depart.isBefore(now)) {
          depart = depart.add(const Duration(days: 1));
        }

        Duration diff = depart.difference(now);
        int dMin = diff.inMinutes;
        int dSec = diff.inSeconds % 60;

        item.remainingToDeparture = '$dMin분 $dSec초 후 출발';
      } catch (e) {
        item.remainingToDeparture = '시간 계산 오류';
      }
    }
  }

  // =========================================
  // 3. UI 구성 함수
  // =========================================

  // (실제 build() 함수에서 호출되는 RealTime 탭)
  Widget _buildRealTimeBusTab() {
    if (busArrivals.isEmpty) {
      return const Center(child: Text("현재 실시간 버스 정보가 없습니다."));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: busArrivals.length,
      itemBuilder: (context, index) {
        final bus = busArrivals[index];
        return Card(
          elevation: 3,
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: const CircleAvatar(
              backgroundColor: Colors.blue,
              child: Icon(Icons.directions_bus, color: Colors.white),
            ),
            title: Text(
              '${bus.routeNo}번 버스',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            subtitle: Text(bus.remainingStations),
            trailing: Text(
              bus.remainingTime,
              style: const TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        );
      },
    );
  }

  // (실제 build() 함수에서 호출되는 Schedule 탭)
  Widget _buildScheduleTab() {
    // 앱 시작 시 바로 보이도록 업데이트 함수 한 번 호출
    if (schedules.isNotEmpty && schedules.first.remainingToDeparture.isEmpty) {
      _updateScheduleTimes();
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: schedules.length,
      itemBuilder: (context, index) {
        final schedule = schedules[index];
        bool isTrain = schedule.type == '기차';

        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Icon(
                  isTrain ? Icons.train : Icons.airport_shuttle,
                  color: isTrain ? Colors.green : Colors.orange,
                  size: 32,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${schedule.routeNo} ${isTrain ? "(${schedule.destination})" : ""}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        '출발: ${schedule.departureTime}',
                        style: TextStyle(color: Colors.grey[700]),
                      ),
                    ],
                  ),
                ),
                Text(
                  schedule.remainingToDeparture,
                  style: const TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // [최종] 로딩이 끝나면 Scaffold와 TabBarView를 반환
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '교통 정보',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.blue[200],
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: '실시간 버스', icon: Icon(Icons.directions_bus)),
            Tab(text: '시간표 (기차/셔틀)', icon: Icon(Icons.schedule)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildRealTimeBusTab(), _buildScheduleTab()],
      ),
    );
  }
}
