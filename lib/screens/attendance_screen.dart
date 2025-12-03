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
  static const int weeklyBonus = 10;

  late DateTime _currentMonth;

  Set<String> _checkedDates = {}; // yyyy-MM-dd
  int _points = 0;
  bool _isLoading = true;

  int _streak = 0; // 연속 출석일
  DateTime? _lastAttendanceDate;

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

  // 데이터 로드 (points + streak + lastAttendanceDate + attendance)
  Future<void> _loadData() async {
    final user = _auth.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final uid = user.uid;

      final userDoc = await _firestore.collection('users').doc(uid).get();
      int points = 0;
      int streak = 0;
      DateTime? lastAttendance;

      if (userDoc.exists) {
        final data = userDoc.data();

        if (data?['points'] is num) {
          points = (data?['points'] as num).toInt();
        }
        if (data?['streak'] is num) {
          streak = (data?['streak'] as num).toInt();
        }
        if (data?['lastAttendanceDate'] is Timestamp) {
          final dt = (data?['lastAttendanceDate'] as Timestamp).toDate();
          lastAttendance = DateTime(dt.year, dt.month, dt.day);
        }
      }

      final attendanceSnap = await _firestore
          .collection('users')
          .doc(uid)
          .collection('attendance')
          .get();

      final checked = <String>{};
      for (var doc in attendanceSnap.docs) {
        if (doc.data()['checked'] == true) {
          checked.add(doc.id);
        }
      }

      setState(() {
        _points = points;
        _streak = streak;
        _lastAttendanceDate = lastAttendance;
        _checkedDates = checked;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  // 출석 체크 + 연속 출석/보너스 처리
  Future<void> _checkToday() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final key = _dateKey(today);

    if (_checkedDates.contains(key)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('오늘은 이미 출석 완료!')),
      );
      return;
    }

    // 연속 출석 계산
    int newStreak;
    if (_lastAttendanceDate != null) {
      final diff = today.difference(_lastAttendanceDate!).inDays;
      if (diff == 1) {
        newStreak = _streak + 1;
      } else if (diff > 1) {
        newStreak = 1;
      } else {
        newStreak = _streak;
      }
    } else {
      newStreak = 1;
    }

    // 포인트 계산
    int addedPoints = dailyReward;
    bool gotBonus = false;
    if (newStreak % 7 == 0) {
      addedPoints += weeklyBonus;
      gotBonus = true;
    }

    setState(() {
      _checkedDates.add(key);
      _points += addedPoints;
      _streak = newStreak;
      _lastAttendanceDate = today;
    });

    try {
      final uid = user.uid;

      await _firestore.collection('users').doc(uid).set(
        {
          'points': _points,
          'streak': newStreak,
          'lastAttendanceDate': Timestamp.fromDate(today),
        },
        SetOptions(merge: true),
      );

      await _firestore
          .collection('users')
          .doc(uid)
          .collection('attendance')
          .doc(key)
          .set({
        'checked': true,
        'checkedAt': FieldValue.serverTimestamp(),
      });

      String msg = '출석 완료! +${dailyReward}P 지급되었습니다.';
      if (gotBonus) {
        msg += ' 🎉 7일 연속 보너스 +$weeklyBonus P!';
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      // 롤백
      setState(() {
        _checkedDates.remove(key);
        _points -= addedPoints;
        _streak = (_streak > 1) ? _streak - 1 : 0;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('오류가 발생했습니다. 다시 시도해주세요.')),
      );
    }
  }

  // 월/연도 변경
  void _changeMonth(int offset) {
    setState(() {
      _currentMonth =
          DateTime(_currentMonth.year, _currentMonth.month + offset, 1);
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

    final now = DateTime.now();
    final todayKey =
    _dateKey(DateTime(now.year, now.month, now.day));
    final alreadyChecked = _checkedDates.contains(todayKey);
    final afterCheckPoints =
    alreadyChecked ? _points : _points + dailyReward;

    return Scaffold(
      appBar: AppBar(
        title: const Text('출석 체크'),
        backgroundColor: const Color(0xFF1F203A),
        elevation: 0,
        actions: [
          _buildPointChip(points: _points),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final calendarHeight = constraints.maxHeight * 0.55;

          return Padding(
            padding: const EdgeInsets.all(14.0),
            child: Column(
              children: [
                // 달력 카드는 고정 비율 높이
                SizedBox(
                  height: calendarHeight,
                  child: _buildCalendarCard(),
                ),
                const SizedBox(height: 12),
                // 보상 카드는 남은 공간에서만
                Expanded(
                  child: _buildRewardSection(
                    alreadyChecked: alreadyChecked,
                    afterCheckPoints: afterCheckPoints,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // 포인트 칩 (메인 화면 스타일과 동일)
  Widget _buildPointChip({required int points}) {
    return Container(
      margin: const EdgeInsets.only(right: 14),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF262744),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white24, width: 0.8),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(
              color: Color(0xFFE9C46A),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.star, size: 14, color: Colors.white),
          ),
          const SizedBox(width: 6),
          Text(
            '$points P',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // -----------------------------------------------------------------
  // 달력 카드
  // -----------------------------------------------------------------
  Widget _buildCalendarCard() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF262744),
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          _buildMonthSelector(),
          if (_isYearPickerOpen) _buildYearPicker(),
          if (_isMonthPickerOpen) _buildMonthPicker(),
          const SizedBox(height: 4),
          _buildWeekDays(),
          const SizedBox(height: 4),
          Expanded(child: _buildCalendarGrid()),
        ],
      ),
    );
  }

  Widget _buildMonthSelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          icon: const Icon(Icons.chevron_left, color: Colors.white70),
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
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Icon(Icons.arrow_drop_down, color: Colors.white),
                ],
              ),
            ),
            const SizedBox(width: 8),
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
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Icon(Icons.arrow_drop_down, color: Colors.white),
                ],
              ),
            ),
          ],
        ),
        IconButton(
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          icon: const Icon(Icons.chevron_right, color: Colors.white70),
          onPressed: () => _changeMonth(1),
        ),
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
              padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
          .map(
            (d) => Expanded(
          child: Center(
            child: Text(
              d,
              style: const TextStyle(
                fontSize: 11,
                color: Colors.white70,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      )
          .toList(),
    );
  }

  Widget _buildCalendarGrid() {
    final firstDay = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final daysInMonth =
    DateUtils.getDaysInMonth(_currentMonth.year, _currentMonth.month);

    int startOffset = firstDay.weekday - 1;
    final totalCells = startOffset + daysInMonth;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      itemCount: totalCells,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisSpacing: 0,
        crossAxisSpacing: 0,
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

        return Container(
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: isChecked ? const Color(0xFF6768F0) : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            border: isToday && !isChecked
                ? Border.all(color: const Color(0xFF6768F0), width: 1.4)
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            '$day',
            style: TextStyle(
              fontSize: 11,
              color: isChecked ? Colors.white : Colors.white70,
              fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        );
      },
    );
  }

  // 하단 보상 카드
  Widget _buildRewardSection({
    required bool alreadyChecked,
    required int afterCheckPoints,
  }) {
    int daysToBonus;
    if (_streak <= 0) {
      daysToBonus = 7;
    } else {
      final mod = _streak % 7;
      daysToBonus = mod == 0 ? 7 : 7 - mod;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF262744), Color(0xFF2E2F5D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 상단: 아이콘 + 타이틀/설명
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.08),
                ),
                child: const Icon(
                  Icons.card_giftcard,
                  size: 22,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      '오늘의 출석 보상',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      '하루 한 번 출석 체크로 포인트를 꾸준히 모아보세요.',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // 중간: streak 요약 + 보너스 정보
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '연속 출석: $_streak일',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '다음 보너스까지 $daysToBonus일 남았어요!',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFB5986D),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '7일 연속 보너스 +$weeklyBonus P',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // 포인트/버튼 요약 라인
          Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: const BoxDecoration(
                    color: Color(0xFFE9C46A),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.star,
                    size: 14,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  '출석 시 +5P',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '출석 후 포인트: $afterCheckPoints P',
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white70,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: alreadyChecked ? null : _checkToday,
              style: ElevatedButton.styleFrom(
                backgroundColor:
                alreadyChecked ? Colors.white24 : const Color(0xFF6768F0),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 11),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
                elevation: 0,
              ),
              child: Text(
                alreadyChecked ? '오늘은 이미 출석 완료!' : '출석 체크하고 포인트 받기',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),

          const SizedBox(height: 4),

          const Text(
            '매일 출석하면 더 빠르게 보상을 모을 수 있어요 ✨',
            style: TextStyle(
              fontSize: 11,
              color: Colors.white54,
            ),
          ),
        ],
      ),
    );
  }
}
