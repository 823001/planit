// add_course_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AddCourseScreen extends StatefulWidget {
  const AddCourseScreen({super.key});

  @override
  State<AddCourseScreen> createState() => _AddCourseScreenState();
}

class _AddCourseScreenState extends State<AddCourseScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _roomController = TextEditingController();
  final TextEditingController _profController = TextEditingController();

  String? _selectedDay;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;

  final List<String> _daysList = ['월', '화', '수', '목', '금'];

  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  bool _isSaving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _roomController.dispose();
    _profController.dispose();
    super.dispose();
  }

  String _formatTime(TimeOfDay time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  Future<void> _pickTime(bool isStart) async {
    final initTime = isStart
        ? (_startTime ?? const TimeOfDay(hour: 9, minute: 0))
        : (_endTime ?? const TimeOfDay(hour: 10, minute: 30));

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
                      child: const Text(
                        '완료',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: CupertinoTheme(
                  data: const CupertinoThemeData(
                    brightness: Brightness.dark,
                  ),
                  child: CupertinoDatePicker(
                    mode: CupertinoDatePickerMode.time,
                    initialDateTime: DateTime(
                      2023,
                      1,
                      1,
                      initTime.hour,
                      initTime.minute,
                    ),
                    use24hFormat: false,
                    onDateTimeChanged: (DateTime newDate) {
                      setState(() {
                        final t = TimeOfDay(
                          hour: newDate.hour,
                          minute: newDate.minute,
                        );
                        if (isStart) {
                          _startTime = t;
                        } else {
                          _endTime = t;
                        }
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

  Future<void> _saveClass() async {
    if (_titleController.text.isEmpty ||
        _roomController.text.isEmpty ||
        _profController.text.isEmpty ||
        _selectedDay == null ||
        _startTime == null ||
        _endTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('강의 정보를 모두 입력해주세요!')),
      );
      return;
    }

    final user = _auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인이 필요합니다.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('courses')
          .add({
        'title': _titleController.text,
        'room': _roomController.text,
        'prof': _profController.text,
        'day': _selectedDay,
        'startTime': _formatTime(_startTime!),
        'endTime': _formatTime(_endTime!),
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('강의가 성공적으로 추가되었습니다.')),
      );
      Navigator.pop(context, true); // true 넘겨서 시간표 화면에서 새로고침
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('강의 저장 중 오류가 발생했습니다 : $e')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('강의 추가'),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
        leading: Container(),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _inputField(
                label: '강의명',
                hint: '강의명을 입력하세요',
                controller: _titleController,
              ),
              const SizedBox(height: 24),

              _inputField(
                label: '강의실',
                hint: '강의실 번호를 입력하세요',
                controller: _roomController,
              ),
              const SizedBox(height: 24),

              Row(
                children: [
                  Expanded(
                    child: _inputField(
                      label: '담당 교수',
                      hint: '교수명',
                      controller: _profController,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _dropdownField(),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              Row(
                children: [
                  Expanded(
                    child: _timeButton(
                      label: '시작 시간',
                      time: _startTime,
                      isStart: true,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _timeButton(
                      label: '종료 시간',
                      time: _endTime,
                      isStart: false,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 48),

              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                        const Color.fromARGB(255, 59, 58, 112),
                        elevation: 0,
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        '취소하기',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveClass,
                      child: _isSaving
                          ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                          : const Text(
                        '강의 추가',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _inputField({
    required String label,
    required String hint,
    required TextEditingController controller,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(hintText: hint),
        ),
      ],
    );
  }

  Widget _dropdownField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '요일',
          style: TextStyle(
            fontSize: 16,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: const Color.fromARGB(255, 59, 58, 112),
            borderRadius: BorderRadius.circular(15),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedDay,
              hint: const Text(
                '선택',
                style: TextStyle(color: Colors.white54),
              ),
              dropdownColor: const Color(0xFF2D2C59),
              icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
              isExpanded: true,
              items: _daysList.map((day) {
                return DropdownMenuItem(
                  value: day,
                  child: Text(
                    day,
                    style: const TextStyle(color: Colors.white),
                  ),
                );
              }).toList(),
              onChanged: (val) => setState(() => _selectedDay = val),
            ),
          ),
        ),
      ],
    );
  }

  Widget _timeButton({
    required String label,
    required TimeOfDay? time,
    required bool isStart,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => _pickTime(isStart),
          child: Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: const Color.fromARGB(255, 59, 58, 112),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  time != null ? time.format(context) : '선택',
                  style: TextStyle(
                    color: time != null ? Colors.white : Colors.white54,
                  ),
                ),
                const Icon(Icons.access_time,
                    color: Colors.white70, size: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
