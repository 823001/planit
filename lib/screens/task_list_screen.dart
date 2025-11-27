import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../notification_service.dart';

class TaskListScreen extends StatefulWidget {
  const TaskListScreen({super.key});

  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('할 일 목록')),
        body: const Center(
            child: Text('로그인이 필요합니다.',
                style: TextStyle(fontSize: 18, color: Colors.white70))),
      );
    }

    final coursesRef = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('courses')
        .orderBy('day')
        .orderBy('startTime');

    return Scaffold(
      appBar: AppBar(title: const Text('할 일 목록')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text('강의를 선택해 강의별 할 일을 관리하세요.',
                style: TextStyle(fontSize: 16, color: Colors.white70)),
            const SizedBox(height: 16),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: coursesRef.snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(
                        child: Text('등록된 강의가 없습니다.',
                            style: TextStyle(color: Colors.white54)));
                  }

                  final docs = snapshot.data!.docs;

                  return ListView.separated(
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final doc = docs[index];
                      final data = doc.data() as Map<String, dynamic>? ?? {};
                      return ListTile(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        tileColor: const Color.fromARGB(255, 59, 58, 112),
                        title: Text(data['title'] ?? '강의명 없음',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white)),
                        subtitle: Text(
                            '${data['prof'] ?? '-'} | ${data['room'] ?? '-'}',
                            style: const TextStyle(
                                fontSize: 13, color: Colors.white70)),
                        trailing: const Icon(Icons.chevron_right,
                            color: Colors.white),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CourseTodoScreen(
                                courseId: doc.id,
                                courseTitle: data['title'] ?? '강의명 없음',
                              ),
                            ),
                          );
                        },
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



class CourseTodoScreen extends StatefulWidget {
  final String courseId;
  final String courseTitle;

  const CourseTodoScreen({
    super.key,
    required this.courseId,
    required this.courseTitle,
  });

  @override
  State<CourseTodoScreen> createState() => _CourseTodoScreenState();
}

class _CourseTodoScreenState extends State<CourseTodoScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> _tasksRef(User user) {
    return _firestore
        .collection('users')
        .doc(user.uid)
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
      User user, DocumentSnapshot<Map<String, dynamic>> doc) async {
    final current = doc.data()?['isDone'] as bool? ?? false;
    await _tasksRef(user).doc(doc.id).update({'isDone': !current});
  }

  Future<void> _showDeleteDialog(
      User user, DocumentSnapshot<Map<String, dynamic>> doc) async {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.delete_forever,
                    size: 48, color: Colors.black54),
                const SizedBox(height: 16),
                const Text('삭제하시겠습니까?',
                    style:
                    TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text('삭제한 할 일은 복구할 수 없습니다.',
                    style: TextStyle(fontSize: 14, color: Colors.grey)),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12)),
                      child: const Text('취소',
                          style: TextStyle(color: Colors.black)),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        await _tasksRef(user).doc(doc.id).delete();
                        await NotificationService.cancelDeadlineNotification(
                            doc.id);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6768F0),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                      ),
                      child: const Text('삭제',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
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

    return Scaffold(
      appBar: AppBar(title: Text(widget.courseTitle)),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddTaskScreen(
                courseId: widget.courseId,
                courseTitle: widget.courseTitle,
              ),
            ),
          );
        },
        backgroundColor: const Color(0xFF6768F0),
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
                  return const Center(
                      child: Text('등록된 할 일이 없습니다.\n+ 버튼을 눌러 추가해보세요.',
                          style: TextStyle(color: Colors.white54)));
                }

                return ListView.separated(
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 4),
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data();
                    final title = data['title'] ?? '제목 없음';
                    final isDone = data['isDone'] ?? false;
                    DateTime? deadline;
                    if (data['deadline'] is Timestamp) {
                      deadline = (data['deadline'] as Timestamp).toDate();
                    }

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                      leading: Transform.scale(
                        scale: 1.2,
                        child: Checkbox(
                          value: isDone,
                          activeColor: const Color(0xFF6768F0),
                          shape: const CircleBorder(),
                          side: const BorderSide(color: Colors.white54),
                          onChanged: (_) => _toggleDone(user, doc),
                        ),
                      ),
                      title: Text(
                        title,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          decoration: isDone
                              ? TextDecoration.lineThrough
                              : TextDecoration.none,
                        ),
                      ),
                      subtitle: deadline == null
                          ? null
                          : Row(
                        children: [
                          const Icon(Icons.calendar_today,
                              size: 12, color: Colors.white70),
                          const SizedBox(width: 4),
                          Text(_formatDeadline(deadline),
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.white70)),
                        ],
                      ),
                      trailing: PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, color: Colors.white),
                        color: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        onSelected: (value) {
                          if (value == 'edit') {
                            _navigateToEdit(doc);
                          } else if (value == 'delete') {
                            _showDeleteDialog(user, doc);
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit, size: 20, color: Colors.black),
                                SizedBox(width: 8),
                                Text('수정하기'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete,
                                    size: 20, color: Colors.red),
                                SizedBox(width: 8),
                                Text('삭제하기',
                                    style: TextStyle(color: Colors.red)),
                              ],
                            ),
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
    );
  }
}


class AddTaskScreen extends StatefulWidget {
  final String courseId;
  final String courseTitle;

  const AddTaskScreen(
      {super.key, required this.courseId, required this.courseTitle});

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

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime() async {
    final initTime = _selectedTime ?? TimeOfDay.now();
    final now = DateTime.now();
    final initialDateTime = DateTime(
        now.year, now.month, now.day, initTime.hour, initTime.minute);

    await showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF2D2C59),
      builder: (BuildContext builder) {
        return SizedBox(
          height: 250,
          child: Column(
            children: [
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: const Color(0xFF25254A),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('완료',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
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
                        _selectedTime = TimeOfDay(
                            hour: newDate.hour, minute: newDate.minute);
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

    final user = _auth.currentUser;
    if (user == null) return;
    setState(() => _isSaving = true);

    try {
      DateTime? deadline;
      if (_selectedDate != null) {
        final time = _selectedTime ?? const TimeOfDay(hour: 23, minute: 59);
        deadline = DateTime(_selectedDate!.year, _selectedDate!.month,
            _selectedDate!.day, time.hour, time.minute);
      }

      final data = <String, dynamic>{
        'title': title,
        'isDone': false,
        'createdAt': FieldValue.serverTimestamp(),
        'deadline': deadline != null ? Timestamp.fromDate(deadline) : null,
      };

      final ref = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('courses')
          .doc(widget.courseId)
          .collection('tasks')
          .add(data);

      if (deadline != null) {
        await NotificationService.scheduleDeadlineNotification(
            notificationId: ref.id,
            courseTitle: widget.courseTitle,
            taskTitle: title,
            deadline: deadline);
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

    return Scaffold(
      appBar: AppBar(title: const Text('할 일 추가')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. 할 일 정보
            const Row(
              children: [
                Icon(Icons.list, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text('할 일 정보',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
              ],
            ),
            const SizedBox(height: 8),
            const Text('내용', style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 8),
            TextField(
              controller: _contentController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: '할 일을 입력하세요.',
                hintStyle: const TextStyle(color: Colors.white54),
                filled: true,
                fillColor: const Color(0xFF3B3A70),
                border:
                OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 32),


            const Row(
              children: [
                Icon(Icons.calendar_today, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text('마감 기한',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
              ],
            ),
            const SizedBox(height: 8),
            const Text('날짜 및 시간', style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: _pickDate,
                    child: Container(
                      height: 50,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                          color: const Color(0xFF3B3A70),
                          borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(dateStr,
                              style: TextStyle(
                                  color: _selectedDate == null
                                      ? Colors.white54
                                      : Colors.white)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: _pickTime,
                    child: Container(
                      height: 50,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                          color: const Color(0xFF3B3A70),
                          borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(timeStr,
                              style: TextStyle(
                                  color: _selectedTime == null
                                      ? Colors.white54
                                      : Colors.white)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),


            const Row(
              children: [
                Icon(Icons.book, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text('강의 연동',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
              ],
            ),
            const SizedBox(height: 8),
            const Text('강의 선택', style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                  color: const Color(0xFF3B3A70),
                  borderRadius: BorderRadius.circular(12)),
              child: Text(widget.courseTitle,
                  style: const TextStyle(color: Colors.white54)),
            ),
            const SizedBox(height: 48),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveTask,
                child: _isSaving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('추가하기',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class EditTaskScreen extends StatefulWidget {
  final String courseId;
  final String courseTitle;
  final DocumentSnapshot<Map<String, dynamic>> taskDoc;

  const EditTaskScreen({
    super.key,
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

  @override
  void initState() {
    super.initState();
    final data = widget.taskDoc.data()!;
    _contentController =
        TextEditingController(text: data['title'] as String? ?? '');

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
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime() async {
    final initTime = _selectedTime ?? TimeOfDay.now();
    final now = DateTime.now();
    final initialDateTime = DateTime(
        now.year, now.month, now.day, initTime.hour, initTime.minute);

    await showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF2D2C59),
      builder: (BuildContext builder) {
        return SizedBox(
          height: 250,
          child: Column(
            children: [
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: const Color(0xFF25254A),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('완료',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
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
                        _selectedTime = TimeOfDay(
                            hour: newDate.hour, minute: newDate.minute);
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
        deadline = DateTime(_selectedDate!.year, _selectedDate!.month,
            _selectedDate!.day, time.hour, time.minute);
      }

      final updateData = <String, dynamic>{'title': title};
      updateData['deadline'] =
      deadline != null ? Timestamp.fromDate(deadline) : null;

      await _firestore
          .collection('users')
          .doc(user.uid)
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
            deadline: deadline);
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

    return Scaffold(
      appBar: AppBar(title: const Text('할 일 수정')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.list, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text('할 일 정보',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
              ],
            ),
            const SizedBox(height: 8),
            const Text('내용', style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 8),
            TextField(
              controller: _contentController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: '할 일을 입력하세요.',
                hintStyle: const TextStyle(color: Colors.white54),
                filled: true,
                fillColor: const Color(0xFF3B3A70),
                border:
                OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 32),


            const Row(
              children: [
                Icon(Icons.calendar_today, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text('마감 기한',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
              ],
            ),
            const SizedBox(height: 8),
            const Text('날짜 및 시간', style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: _pickDate,
                    child: Container(
                      height: 50,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                          color: const Color(0xFF3B3A70),
                          borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(dateStr,
                              style: TextStyle(
                                  color: _selectedDate == null
                                      ? Colors.white54
                                      : Colors.white)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: _pickTime,
                    child: Container(
                      height: 50,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                          color: const Color(0xFF3B3A70),
                          borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(timeStr,
                              style: TextStyle(
                                  color: _selectedTime == null
                                      ? Colors.white54
                                      : Colors.white)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),


            const Row(
              children: [
                Icon(Icons.book, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text('강의 연동',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
              ],
            ),
            const SizedBox(height: 8),
            const Text('강의 선택', style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                  color: const Color(0xFF3B3A70),
                  borderRadius: BorderRadius.circular(12)),
              child: Text(widget.courseTitle,
                  style: const TextStyle(color: Colors.white54)),
            ),
            const SizedBox(height: 48),


            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _updateTask,
                child: _isSaving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('수정 완료',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}