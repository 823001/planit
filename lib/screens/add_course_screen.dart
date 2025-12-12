import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';

class AddCourseScreen extends StatefulWidget {
  final String timetableId;

  final Map<String, dynamic>? course;
  final String? courseId;

  const AddCourseScreen({
    super.key,
    required this.timetableId,
    this.course,
    this.courseId,
  });

  bool get isEdit => course != null && courseId != null;

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

  final Color _primaryColor = const Color(0xFF6768F0);
  final Color _backgroundTop = const Color(0xFF191C3D);
  final Color _backgroundBottom = const Color(0xFF101226);
  final Color _cardBackground = const Color(0xFF262744);
  final Color _fieldBackground = const Color(0xFF262744);

  @override
  void initState() {
    super.initState();

    if (widget.isEdit) {
      final c = widget.course!;
      _titleController.text = (c['title'] ?? '') as String;
      _roomController.text = (c['room'] ?? '') as String;
      _profController.text = (c['prof'] ?? '') as String;
      _selectedDay = c['day'] as String?;
      if (c['startTime'] != null) _startTime = _parseTime(c['startTime'] as String);
      if (c['endTime'] != null) _endTime = _parseTime(c['endTime'] as String);
    }
  }

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

  TimeOfDay _parseTime(String str) {
    final parts = str.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);
    return TimeOfDay(hour: hour, minute: minute);
  }

  Future<void> _pickTime(bool isStart) async {
    final initTime = isStart
        ? (_startTime ?? const TimeOfDay(hour: 9, minute: 0))
        : (_endTime ?? const TimeOfDay(hour: 10, minute: 30));

    await showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF2D2C59),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext builder) {
        return SizedBox(
          height: 260,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: const BoxDecoration(
                  color: Color(0xFF25254A),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isStart ? '시작 시간 선택' : '종료 시간 선택',
                      style: GoogleFonts.notoSansKr(color: Colors.white70, fontSize: 14),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        '완료',
                        style: GoogleFonts.notoSansKr(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
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
                    initialDateTime: DateTime(2023, 1, 1, initTime.hour, initTime.minute),
                    use24hFormat: false,
                    onDateTimeChanged: (DateTime newDate) {
                      setState(() {
                        final t = TimeOfDay(hour: newDate.hour, minute: newDate.minute);
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

    final isEdit = widget.isEdit;

    final data = {
      'title': _titleController.text,
      'room': _roomController.text,
      'prof': _profController.text,
      'day': _selectedDay,
      'startTime': _formatTime(_startTime!),
      'endTime': _formatTime(_endTime!),
      'updatedAt': FieldValue.serverTimestamp(),
      if (!isEdit) 'createdAt': FieldValue.serverTimestamp(),
    };

    try {
      final ref = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('timetables')
          .doc(widget.timetableId)
          .collection('courses');

      if (isEdit) {
        await ref.doc(widget.courseId!).update(data);
      } else {
        await ref.add(data);
      }

      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('timetables')
          .doc(widget.timetableId)
          .update({'updatedAt': FieldValue.serverTimestamp()});

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isEdit ? '강의가 수정되었습니다.' : '강의가 성공적으로 추가되었습니다.'),
        ),
      );
      Navigator.pop(context, true);
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
    final isEdit = widget.isEdit;

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
          elevation: 0,
          backgroundColor: Colors.transparent,
          title: Text(
            isEdit ? '강의 수정' : '강의 추가',
            style: GoogleFonts.notoSansKr(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          centerTitle: false,
          leadingWidth: 0,
          leading: const SizedBox.shrink(),
          actions: [
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: SingleChildScrollView(
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: _cardBackground,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      isEdit ? '강의 정보를 수정하세요' : '새 강의를 등록해볼까요?',
                      style: GoogleFonts.notoSansKr(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 20),

                    _inputField(
                      label: '강의명',
                      hint: '예) 고급모바일프로그래밍',
                      controller: _titleController,
                    ),
                    const SizedBox(height: 16),

                    _inputField(
                      label: '강의실',
                      hint: '예) 공학관 302호',
                      controller: _roomController,
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: _inputField(
                            label: '담당 교수',
                            hint: '예) 홍길동',
                            controller: _profController,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(child: _dropdownField()),
                      ],
                    ),
                    const SizedBox(height: 20),

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

                    const SizedBox(height: 28),

                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: Colors.white24),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            onPressed: () => Navigator.pop(context),
                            child: Text(
                              '취소하기',
                              style: GoogleFonts.notoSansKr(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.white70,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _primaryColor,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
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
                                : Text(
                              isEdit ? '강의 저장' : '강의 추가',
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
                  ],
                ),
              ),
            ),
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
          style: GoogleFonts.notoSansKr(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.white70,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          style: GoogleFonts.notoSansKr(color: Colors.white, fontSize: 14),
          cursorColor: Colors.white70,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.notoSansKr(color: Colors.white38, fontSize: 13),
            filled: true,
            fillColor: _fieldBackground,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
      ],
    );
  }

  Widget _dropdownField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '요일',
          style: GoogleFonts.notoSansKr(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.white70,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: _fieldBackground,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white10),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedDay,
              hint: Text('선택', style: GoogleFonts.notoSansKr(color: Colors.white38, fontSize: 13)),
              dropdownColor: const Color(0xFF2D2C59),
              icon: const Icon(Icons.arrow_drop_down, color: Colors.white70),
              isExpanded: true,
              items: _daysList
                  .map((day) => DropdownMenuItem(
                value: day,
                child: Text(day, style: GoogleFonts.notoSansKr(color: Colors.white, fontSize: 14)),
              ))
                  .toList(),
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
          style: GoogleFonts.notoSansKr(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.white70,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => _pickTime(isStart),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: _fieldBackground,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  time != null ? time.format(context) : '선택',
                  style: GoogleFonts.notoSansKr(
                    color: time != null ? Colors.white : Colors.white38,
                    fontSize: 14,
                  ),
                ),
                const Icon(Icons.access_time, color: Colors.white70, size: 18),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
