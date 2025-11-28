import 'package:flutter/material.dart';
import 'dart:async';

// =========================================
// 1. 데이터 모델
// =========================================

class BusArrivalInfo {
  final String routeNo;
  int? totalSeconds; // 초 단위로 남은 시간을 저장 (카운트다운용)
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
  final String departureTime; // "HH:mm"
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
  }) : destination = '', type = '셔틀';
}

// =========================================
// 2. 메인 애플리케이션 위젯
// =========================================

void main() {
  runApp(const BusArrivalApp());
}

class BusArrivalApp extends StatelessWidget {
  const BusArrivalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '한림대 교통 정보',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0.5,
        ),
      ),
      home: const HallymBusArrivalScreen(),
    );
  }
}

// =========================================
// 3. 메인 화면 상태 위젯 (_HallymBusArrivalScreenState)
// =========================================

class HallymBusArrivalScreen extends StatefulWidget {
  const HallymBusArrivalScreen({super.key});

  @override
  State<HallymBusArrivalScreen> createState() => _HallymBusArrivalScreenState();
}

class _HallymBusArrivalScreenState extends State<HallymBusArrivalScreen> {
  // ⭐️ 정적 시간표 데이터 (Java 코드 기반)
  static const List<String> SHUTTLE_TO_STATION_TIMETABLE = ["17:40", "18:10", "19:00"];
  static const List<String> SHUTTLE_TO_HALLYM_TIMETABLE = [
    "08:05","08:25","08:30","08:45","09:00","09:15","09:20","09:45",
    "10:00","10:15","10:25","10:45"
  ];
  static const List<List<String>> GYEONGCHUN_TIMETABLE = [
    ["05:00", "청량리", "일반"], ["05:26", "청량리", "일반"], ["06:12", "청량리", "급행"],
    ["07:01", "광운대", "일반"], ["23:30", "평내호평", "일반"]
  ];
  static const List<List<String>> ITX_TIMETABLE = [
    ["06:07", "용산"], ["07:21", "용산"], ["18:56", "용산"], ["22:14", "용산"]
  ];

  // ⭐️ API로 가져오는 버스 정보 (샘플 데이터 - totalSeconds를 사용하여 초기화)
  List<BusArrivalInfo> hallymToStationRealtime = [
    BusArrivalInfo(routeNo: '300', remainingTime: '도착 정보 없음', remainingStations: '-'),
    BusArrivalInfo(routeNo: '12', remainingTime: '5분 38초', remainingStations: '6', totalSeconds: 338),
  ];
  List<BusArrivalInfo> stationToHallymRealtime = [
    BusArrivalInfo(routeNo: '300', remainingTime: '50분 00초', remainingStations: '43', totalSeconds: 3000),
    BusArrivalInfo(routeNo: '12', remainingTime: '도착 정보 없음', remainingStations: '-'),
    BusArrivalInfo(routeNo: '2', remainingTime: '도착 정보 없음', remainingStations: '-'),
  ];

  ScheduleInfo? nextShuttleToStation;
  ScheduleInfo? nextShuttleToHallym;
  ScheduleInfo? nextGyeongchun;
  ScheduleInfo? nextITX;

  Timer? _timer;

  @override
  void initState() {
    super.initState();

    // ⭐️ [수정 반영] 초기 데이터 로드 및 타이머 시작
    _updateAllData();

    // 1초마다 모든 데이터 (정적 시간표 + 실시간 카운트다운) 갱신
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        _updateAllData();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // 3. 통합된 데이터 업데이트 로직 (모든 갱신 처리)
  void _updateAllData() {
    final now = DateTime.now();

    // 1) 셔틀 및 기차 시간표 업데이트 (정적 스케줄 계산)
    nextShuttleToStation = _calculateNextSchedule(SHUTTLE_TO_STATION_TIMETABLE, '셔틀(한림대)', now);
    nextShuttleToHallym = _calculateNextSchedule(SHUTTLE_TO_HALLYM_TIMETABLE, '셔틀(춘천역)', now);
    nextGyeongchun = _calculateNextTrain(GYEONGCHUN_TIMETABLE, '경춘선', now);
    nextITX = _calculateNextTrain(ITX_TIMETABLE, 'ITX-청춘', now);

    // 2) 실시간 버스 카운트다운 업데이트 (초 감소)
    _decrementRealtimeBuses();

    // 3) UI 갱신
    if (mounted) {
      setState(() {});
    }
  }

  // 4. 실시간 버스 카운트다운 로직
  void _decrementRealtimeBuses() {
    // 춘천역 방면 버스 처리
    for (var bus in hallymToStationRealtime) {
      if (bus.totalSeconds != null && bus.totalSeconds! > 0) {
        bus.totalSeconds = bus.totalSeconds! - 1;
        bus.remainingTime = _formatDuration(Duration(seconds: bus.totalSeconds!));
      } else if (bus.totalSeconds == 0) {
        bus.remainingTime = '곧 도착 (0분)';
        bus.totalSeconds = null; // 카운트다운 중지
      }
    }

    // 한림대 방면 버스 처리
    for (var bus in stationToHallymRealtime) {
      if (bus.totalSeconds != null && bus.totalSeconds! > 0) {
        bus.totalSeconds = bus.totalSeconds! - 1;
        bus.remainingTime = _formatDuration(Duration(seconds: bus.totalSeconds!));
      } else if (bus.totalSeconds == 0) {
        bus.remainingTime = '곧 도착 (0분)';
        bus.totalSeconds = null;
      }
    }
  }

  // 5. 다음 출발 시간 계산 로직 (다음 날 처리 포함)
  ScheduleInfo? _calculateNextSchedule(List<String> timetable, String routeNo, DateTime now) {
    for (String t in timetable) {
      try {
        final parts = t.split(':');
        final hour = int.parse(parts[0]);
        final minute = int.parse(parts[1]);

        DateTime departureTime = DateTime(now.year, now.month, now.day, hour, minute);

        // 자정 이후 출발하는 경우를 위해, 출발 시간이 현재 시각보다 이전이면 다음 날로 처리
        if (departureTime.isBefore(now)) {
          departureTime = departureTime.add(const Duration(days: 1));
        }

        final Duration remaining = departureTime.difference(now);
        final String formattedTime = _formatDuration(remaining);

        return ScheduleInfo.bus(
          routeNo: routeNo,
          departureTime: t,
          remainingToDeparture: formattedTime,
        );
      } catch (e) {
        // debugPrint('Schedule parsing error: $e');
      }
    }
    return null;
  }

  ScheduleInfo? _calculateNextTrain(List<List<String>> timetable, String routeNo, DateTime now) {
    for (List<String> row in timetable) {
      try {
        final timeStr = row[0];
        final parts = timeStr.split(':');
        final hour = int.parse(parts[0]);
        final minute = int.parse(parts[1]);
        final destination = row[1];
        final type = row.length > 2 ? row[2] : routeNo;

        DateTime departureTime = DateTime(now.year, now.month, now.day, hour, minute);

        // 자정 이후 출발하는 경우를 위해, 출발 시간이 현재 시각보다 이전이면 다음 날로 처리
        if (departureTime.isBefore(now)) {
          departureTime = departureTime.add(const Duration(days: 1));
        }

        final Duration remaining = departureTime.difference(now);
        final String formattedTime = _formatDuration(remaining);

        return ScheduleInfo.train(
          routeNo: routeNo,
          destination: destination,
          type: type,
          departureTime: timeStr,
          remainingToDeparture: formattedTime,
        );
      } catch (e) {
        // debugPrint('Train parsing error: $e');
      }
    }
    return null;
  }

  // 6. 남은 시간 포맷팅 (Java 코드 로직 기반)
  String _formatDuration(Duration duration) {
    if (duration.inSeconds <= 0) return '출발 완료';

    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    final StringBuffer sb = StringBuffer();
    if (hours > 0) sb.write('${hours}시간 ');

    if (hours > 0) {
      sb.write('${minutes}분');
    } else if (minutes > 0) {
      sb.write('${minutes}분 ${seconds}초');
    } else {
      sb.write('${seconds}초');
    }

    return sb.toString().trim();
  }

  // =========================================
  // 7. UI 빌드 및 컴포넌트
  // =========================================

  @override
  Widget build(BuildContext context) {

    // 춘천역 방면 (실시간 버스 + 셔틀버스)
    List<Widget> hallymToStationItems = [
      ...hallymToStationRealtime.map((bus) => _buildBusCard(bus)).toList(),
      if (nextShuttleToStation != null)
        _buildShuttleCard(nextShuttleToStation!),
      if (nextShuttleToStation == null && !hallymToStationRealtime.any((e) => e.remainingTime != '도착 정보 없음'))
        _buildNoInfoCard('현재 춘천역 방면 운행 정보가 없습니다.'),
    ];

    // 한림대 방면 (실시간 버스 + 셔틀버스)
    List<Widget> stationToHallymItems = [
      ...stationToHallymRealtime.map((bus) => _buildBusCard(bus)).toList(),
      if (nextShuttleToHallym != null)
        _buildShuttleCard(nextShuttleToHallym!),
      if (nextShuttleToHallym == null && !stationToHallymRealtime.any((e) => e.remainingTime != '도착 정보 없음'))
        _buildNoInfoCard('현재 한림대 방면 운행 정보가 없습니다.'),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('한림대 교통 정보', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        children: <Widget>[
          // 춘천역 방면 섹션 (300, 12, 셔틀 포함)
          _buildArrivalSection(
            title: '🚌 춘천역 방면',
            subtitle: '한림대학교 (학교 앞) 정류장',
            items: hallymToStationItems,
          ),

          const Divider(thickness: 8.0, color: Color(0xFFF0F0F0)),

          // 한림대학교 방면 섹션 (300, 12, 셔틀 포함)
          _buildArrivalSection(
            title: '🚌 한림대학교 방면',
            subtitle: '춘천역 (꿈자람어린이공원) 정류장',
            items: stationToHallymItems,
          ),

          const Divider(thickness: 8.0, color: Color(0xFFF0F0F0)),

          // 🚊 경춘선 섹션
          _buildTrainSection(
            title: '🚊 경춘선',
            schedule: nextGyeongchun,
            emptyMessage: '오늘 남은 경춘선 열차 없음',
          ),

          // 🚄 ITX-청춘 섹션
          _buildTrainSection(
            title: '🚄 ITX-청춘',
            schedule: nextITX,
            emptyMessage: '오늘 남은 ITX 열차 없음',
          ),

          const SizedBox(height: 30),
        ],
      ),
    );
  }

  // 8. UI 컴포넌트 정의

  Widget _buildArrivalSection({
    required String title,
    required String subtitle,
    required List<Widget> items,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(subtitle, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
            ],
          ),
        ),
        ...items,
      ],
    );
  }

  Widget _buildBusCard(BusArrivalInfo bus) {
    bool hasInfo = bus.remainingTime != '도착 정보 없음';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      elevation: 0.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Row(
          children: [
            SizedBox(
              width: 60,
              child: Text(
                bus.routeNo,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: hasInfo ? Colors.blue : Colors.grey,
                ),
              ),
            ),

            const SizedBox(width: 20),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasInfo ? bus.remainingTime : '도착 정보 없음',
                    style: TextStyle(
                      fontSize: hasInfo ? 16 : 14,
                      fontWeight: hasInfo ? FontWeight.bold : FontWeight.normal,
                      color: hasInfo ? Colors.redAccent : Colors.grey,
                    ),
                  ),
                  if (hasInfo)
                    Text(
                      '${bus.remainingStations}번째 전',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                ],
              ),
            ),

            IconButton(
              icon: Icon(Icons.notifications_none, color: Colors.grey[400]),
              onPressed: () {},
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShuttleCard(ScheduleInfo schedule) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      elevation: 0.5,
      color: Colors.lightGreen[50],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Row(
          children: [
            SizedBox(
              width: 60,
              child: Text(
                '셔틀',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Colors.green,
                ),
              ),
            ),

            const SizedBox(width: 20),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '다음 출발: ${schedule.departureTime}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  Text(
                    '출발까지: ${schedule.remainingToDeparture}',
                    style: const TextStyle(fontSize: 14, color: Colors.redAccent),
                  ),
                ],
              ),
            ),

            Icon(Icons.access_time_filled, color: Colors.green[300]),
          ],
        ),
      ),
    );
  }

  Widget _buildNoInfoCard(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Text(
          message,
          style: const TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)
      ),
    );
  }

  Widget _buildTrainSection({
    required String title,
    required ScheduleInfo? schedule,
    required String emptyMessage,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        ),

        if (schedule == null)
          _buildNoInfoCard(emptyMessage)
        else
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            elevation: 1.0,
            color: schedule.routeNo == 'ITX-청춘' ? Colors.orange[50] : Colors.blue[50],
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '다음 출발: ${schedule.departureTime}',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Chip(
                        label: Text(schedule.type, style: const TextStyle(fontSize: 12, color: Colors.white)),
                        backgroundColor: schedule.routeNo == 'ITX-청춘' ? Colors.orange : Colors.blue,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('행선지: ${schedule.destination}', style: const TextStyle(fontSize: 14, color: Colors.grey)),
                        ],
                      ),
                      Text(
                        '출발까지: ${schedule.remainingToDeparture}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}