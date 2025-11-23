import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  static const int dailyReward = 5;

  late DateTime _currentMonth;
  Set<String> _checkedDates = {}; // 'yyyy-MM-dd'
  int _points = 0;
  bool _isLoading = true;

  bool _isYearPickerOpen = false;
  bool _isMonthPickerOpen = false;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _currentMonth = DateTime.now();
    _loadData();
  }

  String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _loadData() async {
    final user = _auth.currentUser;

    if (user == null) {
      // 로그인 안 되어 있으면 안내만 하고 종료
      setState(() {
        _isLoading = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('출석 기능을 이용하려면 먼저 로그인 해주세요.')),
        );
      });
      return;
    }

    try {
      final uid = user.uid;

      // 유저 포인트 불러오기
      final userDoc = await _firestore.collection('users').doc(uid).get();
      int points = 0;
      if (userDoc.exists) {
        final data = userDoc.data();
        final p = data?['points'];
        if (p is int) {
          points = p;
        } else if (p is num) {
          points = p.toInt();
        }
      }

      // 출석 내역 전체 불러오기
      final attendanceSnap = await _firestore
          .collection('users')
          .doc(uid)
          .collection('attendance')
          .get();

      final checked = <String>{};
      for (var doc in attendanceSnap.docs) {
        final data = doc.data();
        if (data['checked'] == true) {
          checked.add(doc.id); // 문서 ID를 날짜 키로 사용
        }
      }

      setState(() {
        _points = points;
        _checkedDates = checked;
        _isLoading = false;
      });
    } catch (e) {
      print('출석 데이터 로드 에러: $e');
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('출석 정보를 불러오는 중 오류가 발생했습니다.')),
      );
    }
  }

  Future<void> _checkToday() async {
    final user = _auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('먼저 로그인해주세요.')),
      );
      return;
    }

    final today = DateTime.now();
    final key = _dateKey(today);

    if (_checkedDates.contains(key)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('오늘은 이미 출석 체크를 했어요.')),
      );
      return;
    }

    setState(() {
      _checkedDates.add(key);
      _points += dailyReward;
    });

    try {
      final uid = user.uid;

      // 포인트 업데이트
      await _firestore.collection('users').doc(uid).set({
        'points': _points,
      }, SetOptions(merge: true));

      // 오늘 출석 기록
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('attendance')
          .doc(key)
          .set({
        'checked': true,
        'checkedAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('출석 완료! 5P가 적립되었습니다.')),
      );
    } catch (e) {
      print('출석 저장 에러: $e');

      // 실패 시 UI 롤백
      setState(() {
        _checkedDates.remove(key);
        _points -= dailyReward;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('출석 저장 중 오류가 발생했습니다. 다시 시도해주세요.')),
      );
    }
  }

  void _changeMonth(int offset) {
    setState(() {
      _currentMonth = DateTime(
        _currentMonth.year,
        _currentMonth.month + offset,
        1,
      );
    });
  }

  void _selectYear(int year) {
    setState(() {
      _currentMonth = DateTime(year, _currentMonth.month, 1);
      _isYearPickerOpen = false;
    });
  }

  void _selectMonth(int month) {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, month, 1);
      _isMonthPickerOpen = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final today = DateTime.now();
    final todayKey = _dateKey(today);
    final bool alreadyChecked = _checkedDates.contains(todayKey);
    final int afterCheckPoints =
    alreadyChecked ? _points : _points + dailyReward;

    return Scaffold(
      appBar: AppBar(
        title: const Text('출석 체크'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: Center(
              child: Chip(
                backgroundColor: Colors.black.withOpacity(0.25),
                label: Text(
                  '$_points P',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Expanded(
              flex: 11,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFF25254A),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  children: [
                    _buildMonthArea(),
                    const SizedBox(height: 0),
                    _buildWeekDays(),
                    const SizedBox(height: 0),
                    Expanded(child: _buildCalendarGrid()),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 8),

            Expanded(
              flex: 9,
              child: _buildRewardSection(
                alreadyChecked: alreadyChecked,
                afterCheckPoints: afterCheckPoints,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 연/월 선택 영역
  Widget _buildMonthArea() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: const Icon(Icons.chevron_left, color: Colors.white, size: 20),
              onPressed: () => _changeMonth(-1),
            ),
            Row(
              children: [
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _isYearPickerOpen = !_isYearPickerOpen;
                      if (_isYearPickerOpen) _isMonthPickerOpen = false;
                    });
                  },
                  child: Row(
                    children: [
                      Text(
                        '${_currentMonth.year}년',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const Icon(Icons.arrow_drop_down,
                          color: Colors.white, size: 18),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _isMonthPickerOpen = !_isMonthPickerOpen;
                      if (_isMonthPickerOpen) _isYearPickerOpen = false;
                    });
                  },
                  child: Row(
                    children: [
                      Text(
                        '${_currentMonth.month}월',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const Icon(Icons.arrow_drop_down,
                          color: Colors.white, size: 18),
                    ],
                  ),
                ),
              ],
            ),
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: const Icon(Icons.chevron_right, color: Colors.white, size: 20),
              onPressed: () => _changeMonth(1),
            ),
          ],
        ),
        if (_isYearPickerOpen) _buildYearPicker(),
        if (_isMonthPickerOpen) _buildMonthPicker(),
      ],
    );
  }

  Widget _buildYearPicker() {
    final currentYear = DateTime.now().year;
    final years = List<int>.generate(11, (i) => currentYear - 5 + i);

    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: years.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          final year = years[index];
          final bool isSelected = year == _currentMonth.year;

          return GestureDetector(
            onTap: () => _selectYear(year),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF6768F0)
                    : Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Center(
                child: Text(
                  '$year',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white,
                    fontWeight:
                    isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMonthPicker() {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: List.generate(12, (index) {
        final month = index + 1;
        final bool isSelected = month == _currentMonth.month;

        return GestureDetector(
          onTap: () => _selectMonth(month),
          child: Container(
            width: 46,
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFF6768F0)
                  : Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                '$month월',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white,
                  fontWeight:
                  isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildWeekDays() {
    const days = ['월', '화', '수', '목', '금', '토', '일'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: days
          .map((d) => Expanded(
        child: Center(
          child: Text(
            d,
            style: const TextStyle(
              fontSize: 10,
              color: Colors.white70,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ))
          .toList(),
    );
  }

  Widget _buildCalendarGrid() {
    final firstDay = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final daysInMonth =
    DateUtils.getDaysInMonth(_currentMonth.year, _currentMonth.month);

    int startOffset = firstDay.weekday - 1;
    final totalCells = startOffset + daysInMonth;

    final today = DateTime.now();

    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: totalCells,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisSpacing: 0,
        crossAxisSpacing: 0,
        childAspectRatio: 1.3,
      ),
      itemBuilder: (context, index) {
        if (index < startOffset) {
          return const SizedBox.shrink();
        }

        final day = index - startOffset + 1;
        final date = DateTime(_currentMonth.year, _currentMonth.month, day);
        final key = _dateKey(date);

        final bool isToday =
            date.year == today.year &&
                date.month == today.month &&
                date.day == today.day;

        final bool isChecked = _checkedDates.contains(key);

        Color bgColor;
        Color textColor = Colors.white;

        if (isChecked) {
          bgColor = const Color(0xFF6768F0);
        } else if (isToday) {
          bgColor = Colors.transparent;
        } else {
          bgColor = Colors.transparent;
          textColor = Colors.white70;
        }

        return Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(999),
            border: isToday && !isChecked
                ? Border.all(color: const Color(0xFF6768F0), width: 1.3)
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            '$day',
            style: TextStyle(
              fontSize: 11,
              color: textColor,
              fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        );
      },
    );
  }

  Widget _buildRewardSection({
    required bool alreadyChecked,
    required int afterCheckPoints,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF25254A),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.card_giftcard,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '오늘의 출석 보상',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFB5986D),
              borderRadius: BorderRadius.circular(30),
            ),
            child: const Text(
              '출석 시 +5P 지급',
              style: TextStyle(
                fontSize: 13,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '출석 후 보유 포인트: $afterCheckPoints P',
            style: const TextStyle(
              fontSize: 13,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: alreadyChecked ? null : _checkToday,
              style: ElevatedButton.styleFrom(
                backgroundColor:
                alreadyChecked ? Colors.white30 : const Color(0xFF6768F0),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                alreadyChecked ? '오늘은 이미 출석 완료!' : '출석 체크하기',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
