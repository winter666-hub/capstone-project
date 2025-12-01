import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

// [주소 설정] 본인의 IP 주소로 수정 필수!
//const String BUS_API_URL = 'http://61.99.11.106:5000/api/bus/arrival';
const String BUS_API_URL =
    'http://10.0.2.2:5000/api/bus/arrival'; // 에뮬레이터용 로컬호스트

// 1. 데이터 모델
class BusArrivalInfo {
  final String routeNo;
  int? totalSeconds;
  String remainingTime;
  String remainingStations;

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
  final String type;
  final String departureTime;
  String remainingToDeparture;

  ScheduleInfo.train({
    required this.routeNo,
    required this.destination,
    required this.type,
    required this.departureTime,
    required this.remainingToDeparture,
  });

  ScheduleInfo.bus({
    required this.routeNo,
    required this.departureTime,
    required this.remainingToDeparture,
  }) : destination = '',
       type = '셔틀';
}

// 2. 메인 화면
class HallymBusArrivalScreen extends StatefulWidget {
  const HallymBusArrivalScreen({super.key});

  @override
  State<HallymBusArrivalScreen> createState() => _HallymBusArrivalScreenState();
}

class _HallymBusArrivalScreenState extends State<HallymBusArrivalScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Timer? _timer;
  bool _isLoading = true;

  // [API 원본 데이터 저장소]
  List<BusArrivalInfo> _apiResultBuffer = [];

  // [정적 시간표 데이터]
  static const List<String> SHUTTLE_TO_STATION_TIMETABLE = [
    "08:30",
    "09:00",
    "10:00",
    "11:00",
    "13:00",
    "14:00",
    "15:00",
    "16:00",
    "17:00",
    "17:40",
    "18:10",
    "19:00",
    "20:00",
  ];
  static const List<String> SHUTTLE_TO_HALLYM_TIMETABLE = [
    "08:05",
    "08:25",
    "08:45",
    "09:15",
    "10:15",
    "11:15",
    "13:15",
    "14:15",
    "15:15",
    "16:15",
    "17:15",
    "18:25",
  ];
  static const List<List<String>> GYEONGCHUN_TIMETABLE = [
    ["06:12", "청량리", "급행"],
    ["07:01", "광운대", "일반"],
    ["12:30", "청량리", "일반"],
    ["14:20", "상봉", "일반"],
    ["16:30", "청량리", "일반"],
    ["17:30", "상봉", "일반"],
    ["18:40", "청량리", "급행"],
    ["20:10", "상봉", "일반"],
    ["22:15", "청량리", "일반"],
    ["23:30", "평내호평", "일반"],
  ];
  static const List<List<String>> ITX_TIMETABLE = [
    ["06:07", "용산"],
    ["07:21", "용산"],
    ["09:18", "용산"],
    ["12:15", "용산"],
    ["15:30", "용산"],
    ["17:12", "용산"],
    ["18:30", "용산"],
    ["19:45", "용산"],
    ["21:15", "용산"],
    ["22:14", "용산"],
  ];

  ScheduleInfo? nextShuttleToStation;
  ScheduleInfo? nextShuttleToHallym;
  ScheduleInfo? nextGyeongchun;
  ScheduleInfo? nextITX;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchBusData();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  // API 데이터 가져오기
  Future<void> _fetchBusData() async {
    try {
      final response = await http.get(Uri.parse(BUS_API_URL));
      if (response.statusCode == 200) {
        final jsonResponse = json.decode(utf8.decode(response.bodyBytes));

        List<BusArrivalInfo> newApiResults = [];
        if (jsonResponse['data'] is List) {
          for (var item in jsonResponse['data']) {
            newApiResults.add(
              BusArrivalInfo(
                routeNo: item['routeNo']?.toString() ?? '?',
                remainingTime: item['message'] ?? '정보없음',
                remainingStations: '${item['remainingStations']}번째 전',
                totalSeconds: item['remainingTimeSec'],
              ),
            );
          }
        }

        if (mounted) {
          setState(() {
            _apiResultBuffer = newApiResults; // 원본 데이터 저장
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      print('버스 로드 실패: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) _updateAllData();
    });
    _updateAllData();
  }

  void _updateAllData() {
    final now = DateTime.now();
    nextShuttleToStation = _calculateNextSchedule(
      SHUTTLE_TO_STATION_TIMETABLE,
      '셔틀',
      now,
    );
    nextShuttleToHallym = _calculateNextSchedule(
      SHUTTLE_TO_HALLYM_TIMETABLE,
      '셔틀',
      now,
    );
    nextGyeongchun = _calculateNextTrain(GYEONGCHUN_TIMETABLE, '경춘선', now);
    nextITX = _calculateNextTrain(ITX_TIMETABLE, 'ITX-청춘', now);

    _decrementRealtimeBuses();
    setState(() {});
  }

  void _decrementRealtimeBuses() {
    for (var bus in _apiResultBuffer) {
      if (bus.totalSeconds != null && bus.totalSeconds! > 0) {
        bus.totalSeconds = bus.totalSeconds! - 1;
        int min = bus.totalSeconds! ~/ 60;
        int sec = bus.totalSeconds! % 60;
        bus.remainingTime = '$min분 $sec초 후 도착';
      } else if (bus.totalSeconds != null && bus.totalSeconds! <= 0) {
        bus.remainingTime = '곧 도착';
      }
    }
  }

  // ⭐️ [핵심 함수] 원하는 버스 번호 목록을 받아, API 데이터와 매칭해서 리스트 생성
  // API에 데이터가 없으면 "도착 정보 없음" 상태의 객체를 생성해서 무조건 보여줌
  List<Widget> _createFixedBusList(List<String> targetRoutes) {
    List<Widget> widgets = [];

    for (String targetNo in targetRoutes) {
      // API 결과 중에서 해당 번호 버스 찾기
      // (API는 같은 번호가 여러 대 올 수 있으므로 where 사용)
      var matchingBuses = _apiResultBuffer
          .where((b) => b.routeNo == targetNo)
          .toList();

      if (matchingBuses.isNotEmpty) {
        // 도착 예정 버스가 있으면 모두 카드 생성
        for (var bus in matchingBuses) {
          widgets.add(_buildBusCard(bus));
        }
      } else {
        // 도착 예정 버스가 없으면 "도착 정보 없음" 카드로 생성 (항상 표시!)
        widgets.add(
          _buildBusCard(
            BusArrivalInfo(
              routeNo: targetNo,
              remainingTime: '도착 정보 없음',
              remainingStations: '-',
              totalSeconds: null,
            ),
          ),
        );
      }
    }
    return widgets;
  }

  // ... (시간표 계산 함수들은 그대로 유지) ...
  ScheduleInfo? _calculateNextSchedule(
    List<String> timetable,
    String routeNo,
    DateTime now,
  ) {
    DateTime? bestTime;
    for (String t in timetable) {
      final parts = t.split(':');
      final time = DateTime(
        now.year,
        now.month,
        now.day,
        int.parse(parts[0]),
        int.parse(parts[1]),
      );
      if (time.isAfter(now)) {
        bestTime = time;
        break;
      }
    }
    if (bestTime == null && timetable.isNotEmpty) {
      final parts = timetable.first.split(':');
      bestTime = DateTime(
        now.year,
        now.month,
        now.day,
        int.parse(parts[0]),
        int.parse(parts[1]),
      ).add(const Duration(days: 1));
    }
    if (bestTime != null) {
      final diff = bestTime.difference(now);
      return ScheduleInfo.bus(
        routeNo: routeNo,
        departureTime:
            "${bestTime.hour.toString().padLeft(2, '0')}:${bestTime.minute.toString().padLeft(2, '0')}",
        remainingToDeparture: _formatDuration(diff),
      );
    }
    return null;
  }

  ScheduleInfo? _calculateNextTrain(
    List<List<String>> timetable,
    String routeNo,
    DateTime now,
  ) {
    for (List<String> row in timetable) {
      try {
        final timeStr = row[0];
        final parts = timeStr.split(':');
        final time = DateTime(
          now.year,
          now.month,
          now.day,
          int.parse(parts[0]),
          int.parse(parts[1]),
        );
        if (time.isAfter(now)) return _makeTrainInfo(routeNo, row, time, now);
      } catch (e) {}
    }
    if (timetable.isNotEmpty) {
      final row = timetable.first;
      final parts = row[0].split(':');
      final time = DateTime(
        now.year,
        now.month,
        now.day,
        int.parse(parts[0]),
        int.parse(parts[1]),
      ).add(const Duration(days: 1));
      return _makeTrainInfo(routeNo, row, time, now);
    }
    return null;
  }

  ScheduleInfo _makeTrainInfo(
    String routeNo,
    List<String> row,
    DateTime departureTime,
    DateTime now,
  ) {
    final diff = departureTime.difference(now);
    return ScheduleInfo.train(
      routeNo: routeNo,
      destination: row[1],
      type: row.length > 2 ? row[2] : routeNo,
      departureTime:
          "${departureTime.hour.toString().padLeft(2, '0')}:${departureTime.minute.toString().padLeft(2, '0')}",
      remainingToDeparture: _formatDuration(diff),
    );
  }

  String _formatDuration(Duration d) {
    if (d.inSeconds <= 0) return '출발';
    if (d.inHours > 0) return '${d.inHours}시간 ${d.inMinutes % 60}분 전';
    return '${d.inMinutes}분 ${d.inSeconds % 60}초 전';
  }

  // =========================================
  // 3. UI 빌드
  // =========================================
  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    // 1. 춘천역 방면 리스트 (300, 12 + 셔틀)
    List<Widget> toStationWidgets = [
      // [수정] 300, 12번은 무조건 표시 (API 데이터 없으면 '정보 없음'으로)
      ..._createFixedBusList(['300', '12', '2']),
      if (nextShuttleToStation != null)
        _buildShuttleCard(nextShuttleToStation!),
    ];

    // 2. 한림대 방면 리스트 (300, 12, 2 + 셔틀)
    List<Widget> toHallymWidgets = [
      // [수정] 300, 12, 2번은 무조건 표시
      ..._createFixedBusList(['300', '12', '2']),
      if (nextShuttleToHallym != null) _buildShuttleCard(nextShuttleToHallym!),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '한림대 교통 정보',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '실시간 버스', icon: Icon(Icons.directions_bus)),
            Tab(text: '시간표 (기차/셔틀)', icon: Icon(Icons.schedule)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          ListView(
            children: [
              _buildSection('🚏 한림대학교 정류장', '춘천역 방면', toStationWidgets),
              const Divider(thickness: 8, color: Color(0xFFF0F0F0)),
              _buildSection('🚏 춘천역 정류장', '한림대학교 방면', toHallymWidgets),
            ],
          ),
          ListView(
            children: [
              _buildTrainSection('🚊 경춘선', nextGyeongchun),
              _buildTrainSection('🚄 ITX-청춘', nextITX),
              // 필요 시 셔틀 시간표도 여기에 추가 가능
            ],
          ),
        ],
      ),
    );
  }

  // UI 위젯 함수들
  Widget _buildSection(String title, String sub, List<Widget> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                sub,
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
        ...items,
      ],
    );
  }

  Widget _buildBusCard(BusArrivalInfo bus) {
    bool hasInfo =
        bus.remainingTime != '도착 정보 없음' && bus.remainingTime != '정보없음';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: ListTile(
          leading: Container(
            width: 60,
            height: 60,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Text(
              bus.routeNo,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Colors.blue.shade800,
              ),
            ),
          ),
          title: Text(
            '${bus.routeNo}번 버스',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              // 정보가 있을 때는 정거장 수 표시, 없으면 '-'
              Text(hasInfo ? bus.remainingStations : '-'),
            ],
          ),
          trailing: Text(
            bus.remainingTime,
            style: TextStyle(
              color: hasInfo ? Colors.red : Colors.grey,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildShuttleCard(ScheduleInfo s) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 2,
      color: Colors.green.shade50,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: ListTile(
          leading: Container(
            width: 60,
            height: 60,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.green),
            ),
            child: const Text(
              "셔틀",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: Colors.green,
              ),
            ),
          ),
          title: const Text(
            '학교 셔틀버스',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text('다음 출발: ${s.departureTime}'),
            ],
          ),
          trailing: Text(
            s.remainingToDeparture,
            style: const TextStyle(
              color: Colors.red,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNoInfoCard(String msg) => Padding(
    padding: const EdgeInsets.all(16),
    child: Text(msg, style: const TextStyle(color: Colors.grey)),
  );

  Widget _buildTrainSection(String title, ScheduleInfo? s) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
        if (s != null)
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            color: s.routeNo == 'ITX-청춘' ? Colors.orange[50] : Colors.blue[50],
            child: ListTile(
              title: Text(
                '다음: ${s.departureTime} (${s.destination})',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              trailing: Text(
                s.remainingToDeparture,
                style: const TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          )
        else
          _buildNoInfoCard('운행 종료'),
      ],
    );
  }
}
