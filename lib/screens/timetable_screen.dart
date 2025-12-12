import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'add_course_screen.dart';

class TimetableScreen extends StatefulWidget {
  const TimetableScreen({super.key});

  @override
  State<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<TimetableScreen>
    with SingleTickerProviderStateMixin {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  late final TabController _tabController;
  final List<String> _days = ['월', '화', '수', '목', '금'];

  final Color _primaryColor = const Color(0xFF6768F0);
  final Color _backgroundTop = const Color(0xFF191C3D);
  final Color _backgroundBottom = const Color(0xFF101226);
  final Color _cardBackground = const Color(0xFF262744);

  static const int _maxTimetables = 5;
  static const String _prefsSelectedTimetableKey = 'selected_timetable_id';

  bool _isLoading = true;

  List<Map<String, dynamic>> _timetables = [];
  String? _selectedTimetableId;

  List<Map<String, dynamic>> _courses = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _days.length, vsync: this);
    _init();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    await _loadTimetables();
    await _loadCourses();
  }

  Future<void> _loadTimetables() async {
    final user = _auth.currentUser;
    if (user == null) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('로그인이 필요합니다.')),
        );
        Navigator.pop(context);
      }
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final savedSelected = prefs.getString(_prefsSelectedTimetableKey);

      final snap = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('timetables')
          .orderBy('createdAt', descending: false)
          .get();

      var list = snap.docs.map((d) {
        final data = d.data();
        data['id'] = d.id;
        return data;
      }).toList();

      if (list.isEmpty) {
        final defaultId = await _createTimetableInternal(name: '기본 시간표');
        list = [
          {'id': defaultId, 'name': '기본 시간표'}
        ];
      }

      String selectedId = list.first['id'] as String;
      if (savedSelected != null &&
          list.any((t) => (t['id'] as String) == savedSelected)) {
        selectedId = savedSelected;
      } else {
        await prefs.setString(_prefsSelectedTimetableKey, selectedId);
      }

      if (!mounted) return;
      setState(() {
        _timetables = list;
        _selectedTimetableId = selectedId;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('시간표 목록 불러오는 중 오류: $e')),
      );
    }
  }

  Future<String> _createTimetableInternal({required String name}) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('not logged in');

    final ref = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('timetables')
        .doc();

    await ref.set({
      'name': name,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return ref.id;
  }

  Future<void> _createTimetable() async {
    if (_timetables.length >= _maxTimetables) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('시간표는 최대 5개까지 만들 수 있어요!')),
      );
      return;
    }

    final name = await _promptText(
      title: '새 시간표 만들기',
      hint: '예) 2025-1학기 시간표',
      initial: '',
      confirmText: '생성',
    );
    if (name == null) return;

    try {
      final id = await _createTimetableInternal(name: name);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsSelectedTimetableKey, id);

      await _loadTimetables();
      await _loadCourses();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('새 시간표가 생성되었습니다.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('시간표 생성 오류: $e')),
      );
    }
  }

  Future<void> _renameSelectedTimetable() async {
    final user = _auth.currentUser;
    if (user == null) return;
    final tid = _selectedTimetableId;
    if (tid == null) return;

    final current = _timetables
        .firstWhere((t) => t['id'] == tid, orElse: () => {'name': '시간표'});
    final currentName = (current['name'] ?? '시간표') as String;

    final name = await _promptText(
      title: '시간표 이름 변경',
      hint: '예) 2학기 시간표',
      initial: currentName,
      confirmText: '저장',
    );
    if (name == null) return;

    try {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('timetables')
          .doc(tid)
          .update({'name': name, 'updatedAt': FieldValue.serverTimestamp()});

      await _loadTimetables();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('시간표 이름이 변경되었습니다.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('이름 변경 오류: $e')),
      );
    }
  }

  Future<void> _deleteSelectedTimetable() async {
    final user = _auth.currentUser;
    if (user == null) return;
    final tid = _selectedTimetableId;
    if (tid == null) return;

    if (_timetables.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('마지막 시간표는 삭제할 수 없어요.')),
      );
      return;
    }

    final current = _timetables.firstWhere((t) => t['id'] == tid);
    final currentName = (current['name'] ?? '시간표') as String;

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: _cardBackground,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            '시간표 삭제',
            style: GoogleFonts.notoSansKr(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Text(
            '‘$currentName’ 시간표와 그 안의 모든 강의가 삭제됩니다.\n정말 삭제하시겠습니까?',
            style: GoogleFonts.notoSansKr(color: Colors.white70, fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('취소', style: GoogleFonts.notoSansKr(color: Colors.white70)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                '삭제',
                style: GoogleFonts.notoSansKr(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (ok != true) return;

    try {
      final ttRef = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('timetables')
          .doc(tid);

      final courseSnap = await ttRef.collection('courses').get();
      final batch = _firestore.batch();
      for (final d in courseSnap.docs) {
        batch.delete(d.reference);
      }
      batch.delete(ttRef);
      await batch.commit();

      final remaining = _timetables.where((t) => t['id'] != tid).toList();
      final newSelected = remaining.first['id'] as String;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsSelectedTimetableKey, newSelected);

      await _loadTimetables();
      await _loadCourses();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('시간표가 삭제되었습니다.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('시간표 삭제 오류: $e')),
      );
    }
  }

  Future<void> _loadCourses() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final tid = _selectedTimetableId;
    if (tid == null) {
      if (mounted) setState(() => _courses = []);
      return;
    }

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('timetables')
          .doc(tid)
          .collection('courses')
          .orderBy('day')
          .orderBy('startTime')
          .get();

      if (!mounted) return;
      setState(() {
        _courses = snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return data;
        }).toList();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('시간표 불러오는 중 오류가 발생했습니다 : $e')),
      );
    }
  }

  Future<void> _onSelectTimetable(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsSelectedTimetableKey, id);

    if (!mounted) return;
    setState(() {
      _selectedTimetableId = id;
      _courses = [];
    });

    await _loadCourses();
  }

  Future<void> _deleteCourse(int index) async {
    try {
      final user = _auth.currentUser;
      final tid = _selectedTimetableId;
      if (user == null || tid == null) {
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
          .collection('timetables')
          .doc(tid)
          .collection('courses')
          .doc(docId)
          .delete();

      if (!mounted) return;
      setState(() => _courses.removeAt(index));

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
              onPressed: () => Navigator.pop(context, false),
              child: Text('취소', style: GoogleFonts.notoSansKr(color: Colors.white70)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                '삭제',
                style: GoogleFonts.notoSansKr(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.w600,
                ),
              ),
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
    final tid = _selectedTimetableId;
    if (tid == null) return;

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddCourseScreen(timetableId: tid),
      ),
    );
    if (result == true) {
      _loadCourses();
    }
  }

  Future<void> _navigateToEditCourse(Map<String, dynamic> course) async {
    final tid = _selectedTimetableId;
    if (tid == null) return;

    final String? docId = course['id'] as String?;
    if (docId == null) return;

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddCourseScreen(
          timetableId: tid,
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
    final selected = _timetables
        .firstWhere((t) => t['id'] == _selectedTimetableId, orElse: () => {});
    final selectedName = (selected['name'] ?? '시간표') as String;

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
          actions: [
            IconButton(
              tooltip: '시간표 만들기',
              onPressed: _createTimetable,
              icon: const Icon(Icons.add_box_outlined),
            ),
            IconButton(
              tooltip: '이름 변경',
              onPressed: _renameSelectedTimetable,
              icon: const Icon(Icons.edit_outlined),
            ),
            IconButton(
              tooltip: '시간표 삭제',
              onPressed: _deleteSelectedTimetable,
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: _cardBackground,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '선택된 시간표: $selectedName',
                          style: GoogleFonts.notoSansKr(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 10),
                      DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedTimetableId,
                          dropdownColor: const Color(0xFF2D2C59),
                          icon: const Icon(Icons.arrow_drop_down, color: Colors.white70),
                          items: _timetables.map((t) {
                            return DropdownMenuItem<String>(
                              value: t['id'] as String,
                              child: Text(
                                (t['name'] ?? '시간표') as String,
                                style: GoogleFonts.notoSansKr(color: Colors.white),
                              ),
                            );
                          }).toList(),
                          onChanged: (v) {
                            if (v == null) return;
                            _onSelectTimetable(v);
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                GestureDetector(
                  onTap: _navigateToAddCourse,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                          child: const Icon(Icons.add, color: Colors.white, size: 20),
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
                      : (_courses.isEmpty)
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
                    children: _days.map((day) => _buildTimetableForDay(day)).toList(),
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
          style: GoogleFonts.notoSansKr(fontSize: 14, color: Colors.white60),
        ),
      );
    }

    const int startHour = 9;
    const int endHour = 23;
    const double hourHeight = 64.0;

    final hours = List<int>.generate(endHour - startHour + 1, (i) => startHour + i);
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
                        style: GoogleFonts.notoSansKr(fontSize: 11, color: Colors.white54),
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
                    final double top = (h - startHour).toDouble() * hourHeight;
                    return Positioned(
                      top: top,
                      left: 0,
                      right: 0,
                      child: Container(height: 1, color: Colors.white12),
                    );
                  }).toList(),
                  ...dayCourses.map((course) {
                    final startStr = (course['startTime'] as String?) ?? '09:00';
                    final endStr = (course['endTime'] as String?) ?? '10:00';

                    final start = _parseTime(startStr);
                    final end = _parseTime(endStr);

                    double startInHour = start.hour + start.minute / 60.0;
                    double endInHour = end.hour + end.minute / 60.0;

                    startInHour = startInHour.clamp(startHour.toDouble(), endHour.toDouble());
                    endInHour = endInHour.clamp(startInHour, endHour.toDouble());

                    final double top = (startInHour - startHour) * hourHeight;
                    final double height = (endInHour - startInHour) * hourHeight;
                    if (height <= 0) return const SizedBox.shrink();

                    return Positioned(
                      top: top,
                      left: 0,
                      right: 0,
                      height: height < 44 ? 44 : height,
                      child: GestureDetector(
                        onTap: () => _navigateToEditCourse(course),
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 2),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: _primaryColor,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.25),
                                blurRadius: 10,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '${course['title'] ?? '강의명 없음'} | ${course['prof'] ?? '-'} | ${course['room'] ?? '-'}',
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
                                      style: GoogleFonts.notoSansKr(fontSize: 11, color: Colors.white70),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                icon: const Icon(Icons.delete_outline, color: Colors.white, size: 18),
                                onPressed: () => _confirmDelete(_courses.indexOf(course)),
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

  Future<String?> _promptText({
    required String title,
    required String hint,
    required String initial,
    required String confirmText,
  }) async {
    final controller = TextEditingController(text: initial);

    final result = await showDialog<String?>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: _cardBackground,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            title,
            style: GoogleFonts.notoSansKr(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: TextField(
            controller: controller,
            style: GoogleFonts.notoSansKr(color: Colors.white),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: GoogleFonts.notoSansKr(color: Colors.white38),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.white10),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.white30),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: Text('취소', style: GoogleFonts.notoSansKr(color: Colors.white70)),
            ),
            TextButton(
              onPressed: () {
                final text = controller.text.trim();
                if (text.isEmpty) return;
                Navigator.pop(context, text);
              },
              child: Text(
                confirmText,
                style: GoogleFonts.notoSansKr(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        );
      },
    );
    return result;
  }
}
