import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'timetable_screen.dart';
import 'task_list_screen.dart';
import 'attendance_screen.dart';
import 'store_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _points = 0;

  double _taskProgress = 0.0;
  double _assignmentRate = 0.0;
  double _attendanceRate = 0.0;
  int _attendanceDays = 0;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  Future<void> _refreshData() async {
    await _loadPoints();
    await _loadTaskStats();
    await _loadAttendanceStats();
  }

  // Firestore에서 포인트 불러오기
  Future<void> _loadPoints() async {
    final user = _auth.currentUser;

    // 로그인 안 되어 있으면 0P로
    if (user == null) {
      setState(() {
        _points = 0;
      });
      return;
    }

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();

      int points = 0;
      if (doc.exists) {
        final data = doc.data();
        final p = data?['points'];
        if (p is int) {
          points = p;
        } else if (p is num) {
          points = p.toInt();
        }
      }

      setState(() {
        _points = points;
      });
    } catch (e) {
      print('포인트 로드 오류: $e');
      setState(() {
        _points = 0;
      });
    }
  }

  Future<void> _loadTaskStats() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      int totalTasks = 0;
      int completedTasks = 0;

      final coursesSnap = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('courses')
          .get();


      for (var courseDoc in coursesSnap.docs) {
        final tasksSnap = await courseDoc.reference.collection('tasks').get();


        for (var taskDoc in tasksSnap.docs) {
          totalTasks++;
          final isDone = taskDoc.data()['isDone'] as bool? ?? false;
          if (isDone) completedTasks++;
        }
      }

      double rate = 0.0;
      if (totalTasks > 0) {
        rate = completedTasks / totalTasks;
      }

      if (mounted) {
        setState(() {
          _taskProgress = rate;
          _assignmentRate = rate;
        });
      }
    } catch (e) {
      print('할 일 통계 로드 오류: $e');
    }
  }

  // 3. 출석 통계 (이번 주 월요일 기준)
  Future<void> _loadAttendanceStats() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final now = DateTime.now();
      final monday = now.subtract(Duration(days: now.weekday - 1));
      final startOfWeek = DateTime(monday.year, monday.month, monday.day);

      int checkedCount = 0;

      final attendanceSnap = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('attendance')
          .get();

      for (var doc in attendanceSnap.docs) {
        final dateKey = doc.id;
        final parts = dateKey.split('-');
        if (parts.length == 3) {
          final date = DateTime(
            int.parse(parts[0]),
            int.parse(parts[1]),
            int.parse(parts[2]),
          );

          if (date.isAtSameMomentAs(startOfWeek) || date.isAfter(startOfWeek)) {
            final diff = date.difference(startOfWeek).inDays;
            if (diff < 7) {
              checkedCount++;
            }
          }
        }
      }

      if (mounted) {
        setState(() {
          _attendanceDays = checkedCount;
          _attendanceRate = checkedCount / 7.0;
          if (_attendanceRate > 1.0) _attendanceRate = 1.0;
        });
      }
    } catch (e) {
      print('출석 통계 로드 오류: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PlanIT'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Chip(
              backgroundColor: Colors.black.withOpacity(0.2),
              label: Text(
                '$_points P',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          IconButton(onPressed: () {}, icon: const Icon(Icons.menu)),
        ],
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 0.9,
                children: [
                  _buildMenuButton(
                    context: context,
                    icon: Icons.calendar_today,
                    title: '시간표',
                    subtitle: '강의 일정 관리',
                    targetScreen: const TimetableScreen(),
                  ),
                  _buildMenuButton(
                    context: context,
                    icon: Icons.checklist,
                    title: '할 일 목록',
                    subtitle: '업무 관리 및 추적',
                    targetScreen: const TaskListScreen(),
                    onReturned: _refreshData,
                  ),
                  _buildMenuButton(
                    context: context,
                    icon: Icons.check_circle_outline,
                    title: '출석 체크',
                    subtitle: '매일 포인트 획득',
                    targetScreen: const AttendanceScreen(),
                    onReturned: _refreshData, // 출석 후 포인트 새로고침
                  ),
                  _buildMenuButton(
                    context: context,
                    icon: Icons.storefront,
                    title: '포인트 상점',
                    subtitle: '포인트로 아이템 구매',
                    targetScreen: const StoreScreen(),
                    onReturned: _refreshData,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildStatsSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuButton({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget targetScreen,
    VoidCallback? onReturned,
    bool isNew = false,
  }) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => targetScreen),
        ).then((_) {
          if (onReturned != null) onReturned();
        });
      },
      child: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: const Color(0xFF6768F0).withOpacity(0.2),
          borderRadius: BorderRadius.circular(20.0),
        ),
        child: Stack(
          children: [
            // 중앙 정렬
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(icon, size: 40, color: Colors.white),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            if (isNew)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.yellow[700],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'NEW',
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsSection() {
    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: const Color(0xFF6768F0).withOpacity(0.2),
        borderRadius: BorderRadius.circular(20.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '이번주 학습 통계',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          _buildStatBar(title: '계획 진행률', value:_taskProgress, displayText: '${(_taskProgress * 100).toInt()}% 완료'),
          const SizedBox(height: 16),
          _buildStatBar(title: '출석률', value: _attendanceRate, displayText: '$_attendanceDays/7일 (${(_attendanceRate * 100).toInt()}%)'),
          const SizedBox(height: 16),
          _buildStatBar(title: '과제 완료율', value: _assignmentRate, displayText: '${(_assignmentRate * 100).toInt()}% 완료'),
        ],
      ),
    );
  }

  Widget _buildStatBar({
    required String title,
    required double value,
    required String displayText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, color: Colors.white70),
            ),
            Text(
              displayText,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: value,
            minHeight: 10,
            backgroundColor: Colors.black.withOpacity(0.3),
            color: const Color(0xFF6768F0),
          ),
        ),
      ],
    );
  }
}