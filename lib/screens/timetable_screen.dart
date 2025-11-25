// timetable_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:planit/screens/add_course_screen.dart';

class TimetableScreen extends StatefulWidget {
  const TimetableScreen({super.key});

  @override
  State<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<TimetableScreen>
    with SingleTickerProviderStateMixin {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  List<Map<String, dynamic>> _courses = []; // 각 강의 + docId 저장
  bool _isLoading = true;

  late final TabController _tabController;
  final List<String> _days = ['월', '화', '수', '목', '금'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _days.length, vsync: this);
    _loadCourses();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadCourses() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('로그인이 필요합니다.')),
        );
        if (mounted) Navigator.pop(context);
        return;
      }

      final snapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('courses')
          .orderBy('day')
          .orderBy('startTime')
          .get();

      setState(() {
        _courses = snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id; // 삭제/수정용 docId 저장
          return data;
        }).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('시간표 불러오는 중 오류가 발생했습니다 : $e')),
      );
    }
  }

  Future<void> _deleteCourse(int index) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('로그인이 필요합니다.')),
        );
        return;
      }

      final course = _courses[index];
      final docId = course['id'] as String?;

      if (docId == null) return;

      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('courses')
          .doc(docId)
          .delete();

      setState(() {
        _courses.removeAt(index);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('강의가 삭제되었습니다.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('강의 삭제 중 오류가 발생했습니다 : $e')),
      );
    }
  }

  Future<void> _confirmDelete(int index) async {
    final course = _courses[index];
    final title = (course['title'] ?? '이 강의') as String;

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('강의 삭제'),
          content: Text('‘$title’ 강의를 정말로 삭제하시겠습니까?'),
          actions: [
            TextButton(
              child: const Text('취소'),
              onPressed: () => Navigator.pop(context, false),
            ),
            TextButton(
              child: const Text(
                '삭제',
                style: TextStyle(color: Colors.red),
              ),
              onPressed: () => Navigator.pop(context, true),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      await _deleteCourse(index);
    }
  }

  Future<void> _navigateToAddCourse() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AddCourseScreen(),
      ),
    );
    if (result == true) {
      _loadCourses();
    }
  }

  Future<void> _navigateToEditCourse(Map<String, dynamic> course) async {
    final String? docId = course['id'] as String?;
    if (docId == null) return;

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddCourseScreen(
          course: course,
          courseId: docId,
        ),
      ),
    );
    if (result == true) {
      _loadCourses();
    }
  }

  TimeOfDay _parseTime(String str) {
    final parts = str.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);
    return TimeOfDay(hour: hour, minute: minute);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('시간표 관리'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // 강의 추가 버튼
            ElevatedButton(
              onPressed: _navigateToAddCourse,
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add),
                  SizedBox(width: 8),
                  Text(
                    '새로운 강의를 추가하세요',
                    style:
                    TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 요일 탭
            TabBar(
              controller: _tabController,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              indicatorColor: const Color(0xFF6768F0),
              tabs: _days.map((d) => Tab(text: d)).toList(),
            ),
            const SizedBox(height: 8),

            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _courses.isEmpty
                  ? const Center(
                child: Text(
                  '추가된 강의가 없습니다.\n위의 버튼을 눌러 강의를 추가해 주세요.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 16, color: Colors.white54),
                ),
              )
                  : TabBarView(
                controller: _tabController,
                children: _days
                    .map((day) => _buildTimetableForDay(day))
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 시간표 형식으로 보여주기
  Widget _buildTimetableForDay(String day) {
    final dayCourses = _courses.where((c) => c['day'] == day).toList();

    if (dayCourses.isEmpty) {
      return Center(
        child: Text(
          '$day요일에 등록된 강의가 없습니다.',
          style: const TextStyle(fontSize: 16, color: Colors.white54),
        ),
      );
    }

    // 세로축: 9시 ~ 23시 (밤 11시)
    const int startHour = 9;
    const int endHour = 23;
    const double hourHeight = 64.0; // 1시간당 높이(px)

    final hours = List<int>.generate(
      endHour - startHour + 1,
          (index) => startHour + index,
    );

    final double totalHeight = hours.length * hourHeight;

    TimeOfDay _parseTime(String str) {
      final parts = str.split(':');
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      return TimeOfDay(hour: hour, minute: minute);
    }

    return SingleChildScrollView(
      child: SizedBox(
        height: totalHeight,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 왼쪽 시간 라벨 컬럼
            SizedBox(
              width: 40,
              child: Column(
                children: hours.map((h) {
                  return SizedBox(
                    height: hourHeight,
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: Text(
                        '$h시',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.white70,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(width: 8),

            // 오른쪽 실제 시간표 영역 (Stack 위에 시간선 + 강의 블록)
            Expanded(
              child: Stack(
                children: [
                  // 시간별 가로선
                  ...hours.map((h) {
                    final double top =
                        (h - startHour).toDouble() * hourHeight;
                    return Positioned(
                      top: top,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: 1,
                        color: Colors.white12,
                      ),
                    );
                  }).toList(),

                  // 강의 블록들
                  ...dayCourses.map((course) {
                    final startStr =
                        (course['startTime'] as String?) ?? '09:00';
                    final endStr =
                        (course['endTime'] as String?) ?? '10:00';

                    final start = _parseTime(startStr);
                    final end = _parseTime(endStr);

                    double startInHour =
                        start.hour + start.minute / 60.0;
                    double endInHour = end.hour + end.minute / 60.0;

                    // 표시 범위(9~23시) 밖이면 잘라서 보이도록 클램프
                    startInHour = startInHour.clamp(
                        startHour.toDouble(), endHour.toDouble());
                    endInHour = endInHour.clamp(
                        startInHour, endHour.toDouble());

                    final double top =
                        (startInHour - startHour) * hourHeight;
                    final double height =
                        (endInHour - startInHour) * hourHeight;

                    // 높이가 0이하인 경우 표시하지 않음
                    if (height <= 0) return const SizedBox.shrink();

                    return Positioned(
                      top: top,
                      left: 0,
                      right: 0,
                      height: height < 40 ? 40 : height,
                      child: GestureDetector(
                        onTap: () => _navigateToEditCourse(course),
                        child: Container(
                          margin:
                          const EdgeInsets.symmetric(vertical: 2),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6768F0),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // 강의 정보 한 줄로 가로 표시
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                  CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '${course['title'] ?? '강의명 없음'} | '
                                          '${course['prof'] ?? '-'} | '
                                          '${course['room'] ?? '-'}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '$startStr ~ $endStr',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.white70,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.white,
                                  size: 18,
                                ),
                                onPressed: () => _confirmDelete(
                                    _courses.indexOf(course)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 기존 카드 리스트 뷰가 필요하면 유지해서 다른 화면에서 재활용할 수 있음
  Widget _buildCourseCard(Map<String, dynamic> course, int index) {
    return InkWell(
      onTap: () => _navigateToEditCourse(course),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color.fromARGB(255, 59, 58, 112),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // 강의 정보
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    course['title'] ?? '강의명 없음',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${course['prof'] ?? '-'} | ${course['room'] ?? '-'}',
                    style: const TextStyle(
                        fontSize: 14, color: Colors.white70),
                  ),
                ],
              ),
            ),

            // 요일 / 시간 + 삭제 아이콘
            Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6768F0),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: [
                      Text(
                        course['day'] ?? '-',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${course['startTime'] ?? ''}~${course['endTime'] ?? ''}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      color: Colors.white70),
                  onPressed: () => _confirmDelete(index),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
