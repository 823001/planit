// timetable_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
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

  List<Map<String, dynamic>> _courses = [];
  bool _isLoading = true;

  late final TabController _tabController;
  final List<String> _days = ['월', '화', '수', '목', '금'];

  final Color _primaryColor = const Color(0xFF6768F0);
  final Color _backgroundTop = const Color(0xFF191C3D);
  final Color _backgroundBottom = const Color(0xFF101226);
  final Color _cardBackground = const Color(0xFF262744);

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
          data['id'] = doc.id;
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
          backgroundColor: _cardBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            '강의 삭제',
            style: GoogleFonts.notoSansKr(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Text(
            '‘$title’ 강의를 정말로 삭제하시겠습니까?',
            style: GoogleFonts.notoSansKr(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
          actions: [
            TextButton(
              child: Text(
                '취소',
                style: GoogleFonts.notoSansKr(
                  color: Colors.white70,
                ),
              ),
              onPressed: () => Navigator.pop(context, false),
            ),
            TextButton(
              child: Text(
                '삭제',
                style: GoogleFonts.notoSansKr(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.w600,
                ),
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
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_backgroundTop, _backgroundBottom],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(
            '시간표 관리',
            style: GoogleFonts.notoSansKr(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // 강의 추가 카드 버튼
                GestureDetector(
                  onTap: _navigateToAddCourse,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: _cardBackground,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.25),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: _primaryColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.add,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '새로운 강의를 추가하세요',
                                style: GoogleFonts.notoSansKr(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '과목, 강의실, 요일, 시간을 자유롭게 편집할 수 있어요.',
                                style: GoogleFonts.notoSansKr(
                                  fontSize: 12,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // 요일 탭
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF24253F),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    labelStyle: GoogleFonts.notoSansKr(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                    unselectedLabelStyle: GoogleFonts.notoSansKr(
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                    ),
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white54,
                    indicator: BoxDecoration(
                      color: _primaryColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    tabs: _days.map((d) => Tab(text: d)).toList(),
                  ),
                ),
                const SizedBox(height: 10),

                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _courses.isEmpty
                      ? Center(
                    child: Text(
                      '추가된 강의가 없습니다.\n위의 버튼을 눌러 강의를 추가해 주세요.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.notoSansKr(
                        fontSize: 14,
                        color: Colors.white60,
                      ),
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
        ),
      ),
    );
  }

  Widget _buildTimetableForDay(String day) {
    final dayCourses = _courses.where((c) => c['day'] == day).toList();

    if (dayCourses.isEmpty) {
      return Center(
        child: Text(
          '$day요일에 등록된 강의가 없습니다.',
          style: GoogleFonts.notoSansKr(
            fontSize: 14,
            color: Colors.white60,
          ),
        ),
      );
    }

    const int startHour = 9;
    const int endHour = 23;
    const double hourHeight = 64.0;

    final hours = List<int>.generate(
      endHour - startHour + 1,
          (index) => startHour + index,
    );

    final double totalHeight = hours.length * hourHeight;

    return SingleChildScrollView(
      child: SizedBox(
        height: totalHeight,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 44,
              child: Column(
                children: hours.map((h) {
                  return SizedBox(
                    height: hourHeight,
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: Text(
                        '$h시',
                        style: GoogleFonts.notoSansKr(
                          fontSize: 11,
                          color: Colors.white54,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(width: 8),

            Expanded(
              child: Stack(
                children: [
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

                  ...dayCourses.map((course) {
                    final startStr =
                        (course['startTime'] as String?) ?? '09:00';
                    final endStr =
                        (course['endTime'] as String?) ?? '10:00';

                    final start = _parseTime(startStr);
                    final end = _parseTime(endStr);

                    double startInHour =
                        start.hour + start.minute / 60.0;
                    double endInHour =
                        end.hour + end.minute / 60.0;

                    startInHour = startInHour.clamp(
                        startHour.toDouble(), endHour.toDouble());
                    endInHour = endInHour.clamp(
                        startInHour, endHour.toDouble());

                    final double top =
                        (startInHour - startHour) * hourHeight;
                    final double height =
                        (endInHour - startInHour) * hourHeight;

                    if (height <= 0) return const SizedBox.shrink();

                    return Positioned(
                      top: top,
                      left: 0,
                      right: 0,
                      height: height < 44 ? 44 : height,
                      child: GestureDetector(
                        onTap: () => _navigateToEditCourse(course),
                        child: Container(
                          margin:
                          const EdgeInsets.symmetric(vertical: 2),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: _primaryColor,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color:
                                Colors.black.withOpacity(0.25),
                                blurRadius: 10,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Row(
                            crossAxisAlignment:
                            CrossAxisAlignment.center,
                            children: [
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
                                      style: GoogleFonts.notoSansKr(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '$startStr ~ $endStr',
                                      style: GoogleFonts.notoSansKr(
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

  // 필요하면 다른 화면에서 재활용 가능
  Widget _buildCourseCard(Map<String, dynamic> course, int index) {
    return InkWell(
      onTap: () => _navigateToEditCourse(course),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _cardBackground,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    course['title'] ?? '강의명 없음',
                    style: GoogleFonts.notoSansKr(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${course['prof'] ?? '-'} | ${course['room'] ?? '-'}',
                    style: GoogleFonts.notoSansKr(
                      fontSize: 13,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _primaryColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: [
                      Text(
                        course['day'] ?? '-',
                        style: GoogleFonts.notoSansKr(
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${course['startTime'] ?? ''}~${course['endTime'] ?? ''}',
                        style: GoogleFonts.notoSansKr(
                          fontSize: 11,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Colors.white70,
                  ),
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
