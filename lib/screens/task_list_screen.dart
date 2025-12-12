import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';

import '../notification_service.dart';

class TaskListScreen extends StatefulWidget {
  const TaskListScreen({super.key});

  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  final Color _primaryColor = const Color(0xFF6768F0);
  final Color _backgroundTop = const Color(0xFF191C3D);
  final Color _backgroundBottom = const Color(0xFF101226);
  final Color _cardBackground = const Color(0xFF262744);

  static const String _prefsSelectedTimetableKey = 'selected_timetable_id';

  bool _loadingTimetables = true;
  List<Map<String, dynamic>> _timetables = [];
  String? _selectedTimetableId;

  @override
  void initState() {
    super.initState();
    _initTimetables();
  }

  Future<void> _initTimetables() async {
    final user = _auth.currentUser;
    if (user == null) {
      if (!mounted) return;
      setState(() => _loadingTimetables = false);
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefsSelectedTimetableKey);

      final snap = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('timetables')
          .orderBy('createdAt', descending: false)
          .get();

      final list = snap.docs.map((d) {
        final data = d.data();
        data['id'] = d.id;
        return data;
      }).toList();

      String? selected;
      if (list.isNotEmpty) {
        if (saved != null && list.any((t) => t['id'] == saved)) {
          selected = saved;
        } else {
          selected = list.first['id'] as String;
          await prefs.setString(_prefsSelectedTimetableKey, selected);
        }
      }

      if (!mounted) return;
      setState(() {
        _timetables = list;
        _selectedTimetableId = selected;
        _loadingTimetables = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingTimetables = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('시간표 목록 로딩 오류: $e')),
      );
    }
  }

  Future<void> _selectTimetable(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsSelectedTimetableKey, id);
    if (!mounted) return;
    setState(() {
      _selectedTimetableId = id;
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    if (user == null) {
      return _wrapScaffold(
        title: '할 일 목록',
        body: Center(
          child: Text(
            '로그인이 필요합니다.',
            style: GoogleFonts.notoSansKr(fontSize: 16, color: Colors.white70),
          ),
        ),
      );
    }

    if (_loadingTimetables) {
      return _wrapScaffold(
        title: '할 일 목록',
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_timetables.isEmpty || _selectedTimetableId == null) {
      return _wrapScaffold(
        title: '할 일 목록',
        body: Center(
          child: Text(
            '시간표가 없습니다.\n시간표 화면에서 먼저 시간표를 생성해 주세요.',
            textAlign: TextAlign.center,
            style: GoogleFonts.notoSansKr(fontSize: 14, color: Colors.white54),
          ),
        ),
      );
    }

    final selected = _timetables.firstWhere(
          (t) => t['id'] == _selectedTimetableId,
      orElse: () => _timetables.first,
    );
    final selectedName = (selected['name'] ?? '시간표') as String;

    final coursesRef = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('timetables')
        .doc(_selectedTimetableId)
        .collection('courses')
        .orderBy('day')
        .orderBy('startTime');

    return _wrapScaffold(
      title: '할 일 목록',
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
                        _selectTimetable(v);
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: _cardBackground,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: _primaryColor.withOpacity(0.2),
                    ),
                    child: const Icon(Icons.checklist, size: 18, color: Colors.white),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '시간표를 선택한 뒤 강의를 눌러 강의별 할 일을 관리하세요.',
                      style: GoogleFonts.notoSansKr(fontSize: 13, color: Colors.white70),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: coursesRef.snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(
                      child: Text(
                        '등록된 강의가 없습니다.\n선택한 시간표에 강의를 먼저 추가해 주세요.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.notoSansKr(fontSize: 14, color: Colors.white54),
                      ),
                    );
                  }

                  final docs = snapshot.data!.docs;

                  return ListView.separated(
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final doc = docs[index];
                      final data = doc.data() as Map<String, dynamic>? ?? {};

                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CourseTodoScreen(
                                timetableId: _selectedTimetableId!,
                                courseId: doc.id,
                                courseTitle: data['title'] ?? '강의명 없음',
                              ),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: _cardBackground,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  color: Colors.white.withOpacity(0.08),
                                ),
                                child: const Icon(Icons.book_outlined, color: Colors.white, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      data['title'] ?? '강의명 없음',
                                      style: GoogleFonts.notoSansKr(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${data['prof'] ?? '-'} · ${data['room'] ?? '-'}',
                                      style: GoogleFonts.notoSansKr(fontSize: 12, color: Colors.white70),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right, color: Colors.white70),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _wrapScaffold({required String title, required Widget body}) {
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
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(
            title,
            style: GoogleFonts.notoSansKr(fontSize: 18, fontWeight: FontWeight.w700),
          ),
        ),
        body: body,
      ),
    );
  }
}

class CourseTodoScreen extends StatefulWidget {
  final String timetableId;
  final String courseId;
  final String courseTitle;

  const CourseTodoScreen({
    super.key,
    required this.timetableId,
    required this.courseId,
    required this.courseTitle,
  });

  @override
  State<CourseTodoScreen> createState() => _CourseTodoScreenState();
}

class _CourseTodoScreenState extends State<CourseTodoScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  bool _confettiEnabled = false;

  final Color _primaryColor = const Color(0xFF6768F0);
  final Color _backgroundTop = const Color(0xFF191C3D);
  final Color _backgroundBottom = const Color(0xFF101226);
  final Color _cardBackground = const Color(0xFF262744);

  @override
  void initState() {
    super.initState();
    _loadFeatureFlags();
  }

  Future<void> _loadFeatureFlags() async {
    final prefs = await SharedPreferences.getInstance();
    final owned = prefs.getStringList('ownedStoreItems') ?? [];
    if (!mounted) return;
    setState(() {
      _confettiEnabled = owned.contains('feature_confetti');
    });
  }

  CollectionReference<Map<String, dynamic>> _tasksRef(User user) {
    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('timetables')
        .doc(widget.timetableId)
        .collection('courses')
        .doc(widget.courseId)
        .collection('tasks');
  }

  String _formatDeadline(DateTime? dt) {
    if (dt == null) return '마감 기한 없음';
    return '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _toggleDone(
      User user,
      DocumentSnapshot<Map<String, dynamic>> doc,
      ) async {
    final data = doc.data() ?? {};
    final current = data['isDone'] as bool? ?? false;
    final newValue = !current;

    await _tasksRef(user).doc(doc.id).update({'isDone': newValue});

    if (newValue && _confettiEnabled && mounted) {
      final title = data['title'] as String? ?? '할 일';
      _showCompleteDialog(title);
    }
  }

  void _showCompleteDialog(String title) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _cardBackground,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.celebration, size: 48, color: Color(0xFFFFD54F)),
                const SizedBox(height: 16),
                Text(
                  '축하합니다!',
                  style: GoogleFonts.notoSansKr(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '\'$title\' 할 일을 완료했어요.\n수고했어요 👏',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.notoSansKr(fontSize: 14, color: Colors.white70),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                  ),
                  child: Text(
                    '닫기',
                    style: GoogleFonts.notoSansKr(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                )
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showDeleteDialog(
      User user,
      DocumentSnapshot<Map<String, dynamic>> doc,
      ) async {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _cardBackground,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.delete_forever, size: 48, color: Colors.redAccent),
                const SizedBox(height: 16),
                Text(
                  '삭제하시겠습니까?',
                  style: GoogleFonts.notoSansKr(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '삭제한 할 일은 복구할 수 없습니다.',
                  style: GoogleFonts.notoSansKr(fontSize: 13, color: Colors.white60),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('취소', style: GoogleFonts.notoSansKr(color: Colors.white70)),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        await _tasksRef(user).doc(doc.id).delete();
                        await NotificationService.cancelDeadlineNotification(doc.id);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryColor,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                      ),
                      child: Text(
                        '삭제',
                        style: GoogleFonts.notoSansKr(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _navigateToEdit(DocumentSnapshot<Map<String, dynamic>> doc) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditTaskScreen(
          timetableId: widget.timetableId,
          courseId: widget.courseId,
          courseTitle: widget.courseTitle,
          taskDoc: doc,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    if (user == null) return const Scaffold();

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
            widget.courseTitle,
            style: GoogleFonts.notoSansKr(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AddTaskScreen(
                  timetableId: widget.timetableId,
                  courseId: widget.courseId,
                  courseTitle: widget.courseTitle,
                ),
              ),
            );
          },
          backgroundColor: _primaryColor,
          shape: const CircleBorder(),
          child: const Icon(Icons.add, color: Colors.white),
        ),
        body: Column(
          children: [
            const SizedBox(height: 8),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _tasksRef(user)
                    .orderBy('deadline', descending: false)
                    .orderBy('createdAt', descending: false)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final docs = snapshot.data!.docs;
                  if (docs.isEmpty) {
                    return Center(
                      child: Text(
                        '등록된 할 일이 없습니다.\n오른쪽 아래 + 버튼을 눌러 추가해보세요.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.notoSansKr(fontSize: 14, color: Colors.white54),
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final doc = docs[index];
                      final data = doc.data();
                      final title = data['title'] ?? '제목 없음';
                      final isDone = data['isDone'] ?? false;
                      DateTime? deadline;
                      if (data['deadline'] is Timestamp) {
                        deadline = (data['deadline'] as Timestamp).toDate();
                      }

                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: _cardBackground,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Transform.scale(
                              scale: 1.2,
                              child: Checkbox(
                                value: isDone,
                                activeColor: _primaryColor,
                                shape: const CircleBorder(),
                                side: const BorderSide(color: Colors.white54),
                                onChanged: (_) => _toggleDone(user, doc),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: InkWell(
                                onTap: () => _navigateToEdit(doc),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      title,
                                      style: GoogleFonts.notoSansKr(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                        decoration: isDone ? TextDecoration.lineThrough : TextDecoration.none,
                                      ),
                                    ),
                                    if (deadline != null) ...[
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          const Icon(Icons.calendar_today, size: 12, color: Colors.white70),
                                          const SizedBox(width: 4),
                                          Text(
                                            _formatDeadline(deadline),
                                            style: GoogleFonts.notoSansKr(fontSize: 11, color: Colors.white70),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                            PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert, color: Colors.white70),
                              color: _cardBackground,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              onSelected: (value) {
                                if (value == 'edit') {
                                  _navigateToEdit(doc);
                                } else if (value == 'delete') {
                                  _showDeleteDialog(user, doc);
                                }
                              },
                              itemBuilder: (context) => [
                                PopupMenuItem(
                                  value: 'edit',
                                  child: Row(
                                    children: [
                                      const Icon(Icons.edit, size: 18, color: Colors.white),
                                      const SizedBox(width: 8),
                                      Text(
                                        '수정하기',
                                        style: GoogleFonts.notoSansKr(color: Colors.white, fontSize: 13),
                                      ),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      const Icon(Icons.delete, size: 18, color: Colors.redAccent),
                                      const SizedBox(width: 8),
                                      Text(
                                        '삭제하기',
                                        style: GoogleFonts.notoSansKr(color: Colors.redAccent, fontSize: 13),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AddTaskScreen extends StatefulWidget {
  final String timetableId;
  final String courseId;
  final String courseTitle;

  const AddTaskScreen({
    super.key,
    required this.timetableId,
    required this.courseId,
    required this.courseTitle,
  });

  @override
  State<AddTaskScreen> createState() => _AddTaskScreenState();
}

class _AddTaskScreenState extends State<AddTaskScreen> {
  final _contentController = TextEditingController();
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  bool _isSaving = false;
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  final Color _primaryColor = const Color(0xFF6768F0);
  final Color _backgroundTop = const Color(0xFF191C3D);
  final Color _backgroundBottom = const Color(0xFF101226);
  final Color _cardBackground = const Color(0xFF262744);
  final Color _fieldBackground = const Color(0xFF262744);

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF6768F0),
              surface: Color(0xFF262744),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime() async {
    final initTime = _selectedTime ?? TimeOfDay.now();
    final now = DateTime.now();
    final initialDateTime = DateTime(now.year, now.month, now.day, initTime.hour, initTime.minute);

    await showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF2D2C59),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext builder) {
        return SizedBox(
          height: 250,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: const BoxDecoration(
                  color: Color(0xFF25254A),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        '완료',
                        style: GoogleFonts.notoSansKr(color: Colors.white, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: CupertinoTheme(
                  data: const CupertinoThemeData(brightness: Brightness.dark),
                  child: CupertinoDatePicker(
                    mode: CupertinoDatePickerMode.time,
                    initialDateTime: initialDateTime,
                    use24hFormat: false,
                    onDateTimeChanged: (newDate) {
                      setState(() {
                        _selectedTime = TimeOfDay(hour: newDate.hour, minute: newDate.minute);
                      });
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _saveTask() async {
    final title = _contentController.text.trim();
    if (title.isEmpty) return;

    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '마감 기한을 선택해 주세요.',
            style: GoogleFonts.notoSansKr(fontSize: 13),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final user = _auth.currentUser;
    if (user == null) return;
    setState(() => _isSaving = true);

    try {
      final time = _selectedTime ?? const TimeOfDay(hour: 23, minute: 59);
      final deadline = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        time.hour,
        time.minute,
      );

      final data = <String, dynamic>{
        'title': title,
        'isDone': false,
        'createdAt': FieldValue.serverTimestamp(),
        'deadline': Timestamp.fromDate(deadline),
      };

      final ref = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('timetables')
          .doc(widget.timetableId)
          .collection('courses')
          .doc(widget.courseId)
          .collection('tasks')
          .add(data);

      await NotificationService.scheduleDeadlineNotification(
        notificationId: ref.id,
        courseTitle: widget.courseTitle,
        taskTitle: title,
        deadline: deadline,
      );

      if (mounted) Navigator.pop(context);
    } catch (e) {
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    String dateStr = _selectedDate == null
        ? '날짜 선택'
        : '${_selectedDate!.year}-${_selectedDate!.month}-${_selectedDate!.day}';
    String timeStr = _selectedTime == null
        ? '시간 선택'
        : '${_selectedTime!.hour}:${_selectedTime!.minute.toString().padLeft(2, '0')}';

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
            '할 일 추가',
            style: GoogleFonts.notoSansKr(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: _cardBackground,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.list, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      '할 일 정보',
                      style: GoogleFonts.notoSansKr(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text('내용', style: GoogleFonts.notoSansKr(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 8),
                TextField(
                  controller: _contentController,
                  style: GoogleFonts.notoSansKr(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: '할 일을 입력하세요.',
                    hintStyle: GoogleFonts.notoSansKr(color: Colors.white38, fontSize: 13),
                    filled: true,
                    fillColor: _fieldBackground,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: Colors.white10),
                    ),
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
                const SizedBox(height: 24),
                Row(
                  children: [
                    const Icon(Icons.calendar_today, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      '마감 기한',
                      style: GoogleFonts.notoSansKr(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('날짜 및 시간', style: GoogleFonts.notoSansKr(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: _pickDate,
                        child: Container(
                          height: 48,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: _fieldBackground,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              dateStr,
                              style: GoogleFonts.notoSansKr(
                                color: _selectedDate == null ? Colors.white38 : Colors.white,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: _pickTime,
                        child: Container(
                          height: 48,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: _fieldBackground,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              timeStr,
                              style: GoogleFonts.notoSansKr(
                                color: _selectedTime == null ? Colors.white38 : Colors.white,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    const Icon(Icons.book, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      '강의 연동',
                      style: GoogleFonts.notoSansKr(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('강의 선택', style: GoogleFonts.notoSansKr(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    color: _fieldBackground,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Text(
                    widget.courseTitle,
                    style: GoogleFonts.notoSansKr(color: Colors.white70, fontSize: 14),
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _saveTask,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryColor,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                        : Text(
                      '추가하기',
                      style: GoogleFonts.notoSansKr(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class EditTaskScreen extends StatefulWidget {
  final String timetableId;
  final String courseId;
  final String courseTitle;
  final DocumentSnapshot<Map<String, dynamic>> taskDoc;

  const EditTaskScreen({
    super.key,
    required this.timetableId,
    required this.courseId,
    required this.courseTitle,
    required this.taskDoc,
  });

  @override
  State<EditTaskScreen> createState() => _EditTaskScreenState();
}

class _EditTaskScreenState extends State<EditTaskScreen> {
  late TextEditingController _contentController;
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  bool _isSaving = false;

  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  final Color _primaryColor = const Color(0xFF6768F0);
  final Color _backgroundTop = const Color(0xFF191C3D);
  final Color _backgroundBottom = const Color(0xFF101226);
  final Color _cardBackground = const Color(0xFF262744);
  final Color _fieldBackground = const Color(0xFF262744);

  @override
  void initState() {
    super.initState();
    final data = widget.taskDoc.data()!;
    _contentController = TextEditingController(text: data['title'] as String? ?? '');

    if (data['deadline'] != null && data['deadline'] is Timestamp) {
      final dt = (data['deadline'] as Timestamp).toDate();
      _selectedDate = dt;
      _selectedTime = TimeOfDay(hour: dt.hour, minute: dt.minute);
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF6768F0),
              surface: Color(0xFF262744),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime() async {
    final initTime = _selectedTime ?? TimeOfDay.now();
    final now = DateTime.now();
    final initialDateTime = DateTime(now.year, now.month, now.day, initTime.hour, initTime.minute);

    await showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF2D2C59),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext builder) {
        return SizedBox(
          height: 250,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: const BoxDecoration(
                  color: Color(0xFF25254A),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        '완료',
                        style: GoogleFonts.notoSansKr(color: Colors.white, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: CupertinoTheme(
                  data: const CupertinoThemeData(brightness: Brightness.dark),
                  child: CupertinoDatePicker(
                    mode: CupertinoDatePickerMode.time,
                    initialDateTime: initialDateTime,
                    use24hFormat: false,
                    onDateTimeChanged: (newDate) {
                      setState(() {
                        _selectedTime = TimeOfDay(hour: newDate.hour, minute: newDate.minute);
                      });
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _updateTask() async {
    final title = _contentController.text.trim();
    if (title.isEmpty) return;

    final user = _auth.currentUser;
    if (user == null) return;
    setState(() => _isSaving = true);

    try {
      DateTime? deadline;
      if (_selectedDate != null) {
        final time = _selectedTime ?? const TimeOfDay(hour: 23, minute: 59);
        deadline = DateTime(
          _selectedDate!.year,
          _selectedDate!.month,
          _selectedDate!.day,
          time.hour,
          time.minute,
        );
      }

      final updateData = <String, dynamic>{'title': title};
      updateData['deadline'] = deadline != null ? Timestamp.fromDate(deadline) : null;

      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('timetables')
          .doc(widget.timetableId)
          .collection('courses')
          .doc(widget.courseId)
          .collection('tasks')
          .doc(widget.taskDoc.id)
          .update(updateData);

      await NotificationService.cancelDeadlineNotification(widget.taskDoc.id);
      if (deadline != null) {
        await NotificationService.scheduleDeadlineNotification(
          notificationId: widget.taskDoc.id,
          courseTitle: widget.courseTitle,
          taskTitle: title,
          deadline: deadline,
        );
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    String dateStr = _selectedDate == null
        ? '날짜 선택'
        : '${_selectedDate!.year}-${_selectedDate!.month}-${_selectedDate!.day}';
    String timeStr = _selectedTime == null
        ? '시간 선택'
        : '${_selectedTime!.hour}:${_selectedTime!.minute.toString().padLeft(2, '0')}';

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
            '할 일 수정',
            style: GoogleFonts.notoSansKr(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: _cardBackground,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.list, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      '할 일 정보',
                      style: GoogleFonts.notoSansKr(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text('내용', style: GoogleFonts.notoSansKr(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 8),
                TextField(
                  controller: _contentController,
                  style: GoogleFonts.notoSansKr(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: '할 일을 입력하세요.',
                    hintStyle: GoogleFonts.notoSansKr(color: Colors.white38, fontSize: 13),
                    filled: true,
                    fillColor: _fieldBackground,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: Colors.white10),
                    ),
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
                const SizedBox(height: 24),
                Row(
                  children: [
                    const Icon(Icons.calendar_today, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      '마감 기한',
                      style: GoogleFonts.notoSansKr(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('날짜 및 시간', style: GoogleFonts.notoSansKr(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: _pickDate,
                        child: Container(
                          height: 48,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: _fieldBackground,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              dateStr,
                              style: GoogleFonts.notoSansKr(
                                color: _selectedDate == null ? Colors.white38 : Colors.white,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: _pickTime,
                        child: Container(
                          height: 48,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: _fieldBackground,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              timeStr,
                              style: GoogleFonts.notoSansKr(
                                color: _selectedTime == null ? Colors.white38 : Colors.white,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    const Icon(Icons.book, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      '강의 연동',
                      style: GoogleFonts.notoSansKr(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('강의 선택', style: GoogleFonts.notoSansKr(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    color: _fieldBackground,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Text(
                    widget.courseTitle,
                    style: GoogleFonts.notoSansKr(color: Colors.white70, fontSize: 14),
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _updateTask,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryColor,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                        : Text(
                      '수정 완료',
                      style: GoogleFonts.notoSansKr(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
