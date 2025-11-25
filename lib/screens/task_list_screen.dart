import 'package:flutter/material.dart';
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
        appBar: AppBar(
          title: const Text('할 일 목록'),
        ),
        body: const Center(
          child: Text(
            '로그인이 필요합니다.',
            style: TextStyle(fontSize: 18, color: Colors.white70),
          ),
        ),
      );
    }

    final coursesRef = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('courses')
        .orderBy('day')
        .orderBy('startTime');

    return Scaffold(
      appBar: AppBar(
        title: const Text('할 일 목록'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text(
              '강의를 선택해 강의별 할 일을 관리하세요.',
              style: TextStyle(fontSize: 16, color: Colors.white70),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: coursesRef.snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        '강의 목록을 불러오는 중 오류가 발생했습니다.\n${snapshot.error}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 14, color: Colors.white70),
                      ),
                    );
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(
                      child: Text(
                        '등록된 강의가 없습니다.\n시간표에서 강의를 먼저 추가해주세요.',
                        textAlign: TextAlign.center,
                        style:
                        TextStyle(fontSize: 16, color: Colors.white54),
                      ),
                    );
                  }

                  final docs = snapshot.data!.docs;

                  return ListView.separated(
                    itemCount: docs.length,
                    separatorBuilder: (_, __) =>
                    const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final doc = docs[index];
                      final data =
                          doc.data() as Map<String, dynamic>? ?? {};
                      final title = data['title'] as String? ?? '강의명 없음';
                      final prof = data['prof'] as String? ?? '-';
                      final room = data['room'] as String? ?? '-';
                      final day = data['day'] as String? ?? '-';
                      final start = data['startTime'] as String? ?? '';
                      final end = data['endTime'] as String? ?? '';

                      return ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        tileColor:
                        const Color.fromARGB(255, 59, 58, 112),
                        title: Text(
                          title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(
                              '$prof | $room',
                              style: const TextStyle(
                                  fontSize: 13, color: Colors.white70),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$day  $start ~ $end',
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.white54),
                            ),
                          ],
                        ),
                        trailing: const Icon(
                          Icons.chevron_right,
                          color: Colors.white,
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CourseTodoScreen(
                                courseId: doc.id,
                                courseTitle: title,
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

/// 한 강의에 대한 투두리스트 화면
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

  final TextEditingController _taskController = TextEditingController();
  DateTime? _selectedDeadline;
  bool _isAdding = false;

  @override
  void dispose() {
    _taskController.dispose();
    super.dispose();
  }

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

  Future<DateTime?> _pickDeadline(BuildContext context,
      {DateTime? initial}) async {
    final now = DateTime.now();
    final base = initial ?? now.add(const Duration(hours: 1));

    final date = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (date == null) return null;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: base.hour, minute: base.minute),
    );
    if (time == null) return null;

    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _addTask() async {
    final text = _taskController.text.trim();
    if (text.isEmpty) return;

    final user = _auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인이 필요합니다.')),
      );
      return;
    }

    setState(() => _isAdding = true);
    try {
      final data = <String, dynamic>{
        'title': text,
        'isDone': false,
        'createdAt': FieldValue.serverTimestamp(),
      };

      if (_selectedDeadline != null) {
        data['deadline'] = Timestamp.fromDate(_selectedDeadline!);
      }

      final ref = await _tasksRef(user).add(data);

      // 알림 예약
      if (_selectedDeadline != null) {
        await NotificationService.scheduleDeadlineNotification(
          notificationId: ref.id,
          courseTitle: widget.courseTitle,
          taskTitle: text,
          deadline: _selectedDeadline!,
        );
      }

      _taskController.clear();
      setState(() {
        _selectedDeadline = null;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('할 일 추가 중 오류가 발생했습니다 : $e')),
      );
    } finally {
      if (mounted) setState(() => _isAdding = false);
    }
  }

  Future<void> _toggleDone(
      User user, DocumentSnapshot<Map<String, dynamic>> doc) async {
    final data = doc.data();
    if (data == null) return;
    final current = data['isDone'] as bool? ?? false;

    try {
      await _tasksRef(user).doc(doc.id).update({'isDone': !current});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('상태 변경 중 오류가 발생했습니다 : $e')),
      );
    }
  }

  Future<void> _deleteTask(
      User user, DocumentSnapshot<Map<String, dynamic>> doc) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('할 일 삭제'),
        content: Text('‘${doc.data()?['title'] ?? '이 항목'}’ 할 일을 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              '삭제',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _tasksRef(user).doc(doc.id).delete();
      await NotificationService.cancelDeadlineNotification(doc.id);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('삭제 중 오류가 발생했습니다 : $e')),
      );
    }
  }

  /// 할 일 수정 다이얼로그
  Future<void> _editTaskDialog(
      User user,
      DocumentSnapshot<Map<String, dynamic>> doc,
      ) async {
    final data = doc.data();
    if (data == null) return;

    final TextEditingController editController =
    TextEditingController(text: data['title'] as String? ?? '');
    DateTime? editDeadline;
    if (data['deadline'] != null && data['deadline'] is Timestamp) {
      editDeadline = (data['deadline'] as Timestamp).toDate();
    }

    await showDialog(
      context: context,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setInnerState) {
            return AlertDialog(
              title: const Text('할 일 수정'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: editController,
                    decoration: const InputDecoration(
                      labelText: '할 일 내용',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _formatDeadline(editDeadline),
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          final picked = await _pickDeadline(
                            context,
                            initial: editDeadline,
                          );
                          if (picked != null) {
                            setInnerState(() {
                              editDeadline = picked;
                            });
                          }
                        },
                        child: const Text('마감 기한 설정'),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    await _deleteTask(user, doc);
                  },
                  child: const Text(
                    '삭제',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('취소'),
                ),
                TextButton(
                  onPressed: () async {
                    final newTitle = editController.text.trim();
                    if (newTitle.isEmpty) return;

                    final updateData = <String, dynamic>{
                      'title': newTitle,
                    };

                    if (editDeadline != null) {
                      updateData['deadline'] =
                          Timestamp.fromDate(editDeadline!);
                    } else {
                      updateData['deadline'] = null;
                    }

                    await _tasksRef(user)
                        .doc(doc.id)
                        .update(updateData);

                    // 알림 다시 설정
                    await NotificationService
                        .cancelDeadlineNotification(doc.id);
                    if (editDeadline != null) {
                      await NotificationService
                          .scheduleDeadlineNotification(
                        notificationId: doc.id,
                        courseTitle: widget.courseTitle,
                        taskTitle: newTitle,
                        deadline: editDeadline!,
                      );
                    }

                    if (context.mounted) Navigator.pop(context);
                  },
                  child: const Text('저장'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text('${widget.courseTitle} 할 일'),
        ),
        body: const Center(
          child: Text(
            '로그인이 필요합니다.',
            style: TextStyle(fontSize: 18, color: Colors.white70),
          ),
        ),
      );
    }

    final tasksStream = _tasksRef(user)
        .orderBy('deadline', descending: false)
        .orderBy('createdAt', descending: false)
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.courseTitle} 할 일'),
      ),
      body: Column(
        children: [
          const SizedBox(height: 8),
          // 입력 + 마감기한 설정
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _taskController,
                        decoration: const InputDecoration(
                          hintText: '할 일을 입력하세요',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _isAdding
                        ? const SizedBox(
                      width: 24,
                      height: 24,
                      child:
                      CircularProgressIndicator(strokeWidth: 2),
                    )
                        : IconButton(
                      icon: const Icon(Icons.add_circle),
                      onPressed: _addTask,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _formatDeadline(_selectedDeadline),
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.white70,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        final picked =
                        await _pickDeadline(context, initial: null);
                        if (picked != null) {
                          setState(() {
                            _selectedDeadline = picked;
                          });
                        }
                      },
                      child: const Text('마감 기한 설정'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: StreamBuilder<
                QuerySnapshot<Map<String, dynamic>>>(
              stream: tasksStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      '할 일을 불러오는 중 오류가 발생했습니다.\n${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 14, color: Colors.white70),
                    ),
                  );
                }

                final docs = snapshot.data?.docs ?? [];

                if (docs.isEmpty) {
                  return const Center(
                    child: Text(
                      '등록된 할 일이 없습니다.\n위 입력창에서 새로운 할 일을 추가해 보세요.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 14, color: Colors.white54),
                    ),
                  );
                }

                return ListView.separated(
                  itemCount: docs.length,
                  separatorBuilder: (_, __) =>
                  const SizedBox(height: 4),
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data();
                    final title =
                        data['title'] as String? ?? '제목 없음';
                    final isDone =
                        data['isDone'] as bool? ?? false;
                    DateTime? deadline;
                    if (data['deadline'] != null &&
                        data['deadline'] is Timestamp) {
                      deadline =
                          (data['deadline'] as Timestamp).toDate();
                    }

                    return Dismissible(
                      key: ValueKey(doc.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding:
                        const EdgeInsets.symmetric(horizontal: 16),
                        color: Colors.red,
                        child: const Icon(Icons.delete,
                            color: Colors.white),
                      ),
                      confirmDismiss: (_) async {
                        await _deleteTask(user, doc);
                        return false; // 삭제는 _deleteTask에서 처리
                      },
                      child: ListTile(
                        onTap: () =>
                            _editTaskDialog(user, doc), // 👉 수정 다이얼로그
                        leading: Checkbox(
                          value: isDone,
                          onChanged: (_) => _toggleDone(user, doc),
                        ),
                        title: Text(
                          title,
                          style: TextStyle(
                            color: Colors.white,
                            decoration: isDone
                                ? TextDecoration.lineThrough
                                : TextDecoration.none,
                          ),
                        ),
                        subtitle: deadline == null
                            ? null
                            : Text(
                          '마감: ${_formatDeadline(deadline)}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white70,
                          ),
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
    );
  }
}
