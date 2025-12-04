import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';

import 'timetable_screen.dart';
import 'task_list_screen.dart';
import 'attendance_screen.dart';
import 'store_screen.dart';
import 'login_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _points = 0;

  double _taskProgress = 0.0;
  double _assignmentRate = 0.0;
  double _attendanceRate = 0.0;
  int _attendanceDays = 0;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _dailyQuoteEnabled = false;
  final List<String> _quotes = const [
    '오늘의 한 걸음이 내일의 나를 만든다.',
    '완벽보다 완료가 더 중요하다.',
    '작은 습관이 큰 변화를 만든다.',
    '미루지 말고 지금 시작하자',
    '꿈을 계속 간직하고 있으면 반드시 실현할 때가 온다.',
    '내일이란 오늘의 다른 이름일 뿐이다.',
    '시간은 우리 각자가 가진 고유의 재산이요, 유일한 재산이다.',
    '오늘이라는 날은 두 번 다시 오지 않는다는 것을 잊지 말라.',
    '계획이란 미래에 대한 현재의 결정이다.',
    '고난이 지나면 반드시 기쁨이 스며든다.',
    '시간은 말로써 나타낼 수 없을 만큼 멋진 만물의 소재이다.',
    '시간을 선택하는 것은 시간을 절약하는 것이다.',
    '시간을 잘 붙잡는 사람은 모든 것을 얻을 수 있다.',
    '부지런히 노력하는 사람이 결국 많은 대가를 얻는다.',
    '그대의 하루하루를 그대의 마지막 날이라고 생각하라.',
    '내일은 시련에 대응하는 새로운 힘을 가져다줄 것이다.',
    '승자는 시간을 관리하며 살고, 패자는 시간에 끌려 산다.',
    '시간과 정성을 들이지 않고 얻을 수 있는 결실은 없다.',
    '하루하루를 우리의 마지막 날인 듯이 보내야 한다.',
    '시간의 참된 가치를 알라. 그것을 붙잡아라. 억류하라.',
    '일은 그것이 쓰일 수 있는 시간이 있는 만큼 팽창한다.',
    '끝을 맺기를 처음과 같이 하면 실패가 없다.',
    '오늘 할 수 있는 일에만 전력을 쏟으라.',
    '좋은 희망을 품는 것은 그것을 이룰 수 있는 지름길이다.',
    '사람은 자기가 한 약속을 지킬만한 좋은 기억력을 가져야 한다.',
    '중요한 건 당신이 어떻게 시작했는가가 아니리라 어떻게 끝내는 가이다.',
    '문제는 목적지에 얼마나 빨리 가느냐가 아니라 그 목적지가 어디냐는 것이다.',
    '한 번 실패와 영원한 실패를 혼동하지 마라.',
    '인생에 뜻을 세우는 데 있어 늦은 때라곤 없다',
  ];

  // 오늘 한 번만 뽑아서 쓰는 문장
  String? _todayQuote;

  // 공통 컬러/테마
  final Color _primaryColor = const Color(0xFF6768F0);
  final Color _backgroundTop = const Color(0xFF191C3D);
  final Color _backgroundBottom = const Color(0xFF101226);
  final Color _cardBackground = const Color(0xFF262744); // 어두운 카드
  final Color _textPrimary = Colors.white; // 카드 안 메인 텍스트
  final Color _textSecondary = Colors.white70; // 카드 안 서브 텍스트

  @override
  void initState() {
    super.initState();
    _pickTodayQuote();      // 오늘 문장 한 번만 선택(계속 바뀌는 문제 개선)
    _refreshData();
    _loadStoreFeatures();
  }

  // 오늘의 문장 한 번만 랜덤으로 선택
  void _pickTodayQuote() {
    if (_quotes.isEmpty) return;
    final shuffled = List<String>.from(_quotes)..shuffle();
    _todayQuote = shuffled.first;
  }

  Future<void> _loadStoreFeatures() async {
    final prefs = await SharedPreferences.getInstance();
    final owned = prefs.getStringList('ownedStoreItems') ?? [];

    setState(() {
      _dailyQuoteEnabled = owned.contains('feature_daily_quote');
    });
  }

  Future<void> _refreshData() async {
    await _loadPoints();
    await _loadTaskStats();
    await _loadAttendanceStats();
  }

  Future<void> _loadPoints() async {
    final user = _auth.currentUser;

    if (user == null) {
      setState(() {
        _points = 0;
      });
      return;
    }

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();

      int points = 0;
      if (doc.exists) {
        final data = doc.data();
        final p = data?['points'];
        if (p is int) {
          points = p;
        } else if (p is num) {
          points = p.toInt();
        }
      }

      setState(() {
        _points = points;
      });
    } catch (e) {
      print('포인트 로드 오류: $e');
      setState(() {
        _points = 0;
      });
    }
  }

  Future<void> _loadTaskStats() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      int totalTasks = 0;
      int completedTasks = 0;

      final coursesSnap = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('courses')
          .get();

      for (var courseDoc in coursesSnap.docs) {
        final tasksSnap = await courseDoc.reference.collection('tasks').get();

        for (var taskDoc in tasksSnap.docs) {
          totalTasks++;
          final isDone = taskDoc.data()['isDone'] as bool? ?? false;
          if (isDone) completedTasks++;
        }
      }

      double rate = 0.0;
      if (totalTasks > 0) {
        rate = completedTasks / totalTasks;
      }

      if (mounted) {
        setState(() {
          _taskProgress = rate;
          _assignmentRate = rate;
        });
      }
    } catch (e) {
      print('할 일 통계 로드 오류: $e');
    }
  }

  Future<void> _loadAttendanceStats() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final now = DateTime.now();
      final monday = now.subtract(Duration(days: now.weekday - 1));
      final startOfWeek = DateTime(monday.year, monday.month, monday.day);

      int checkedCount = 0;

      final attendanceSnap = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('attendance')
          .get();

      for (var doc in attendanceSnap.docs) {
        final dateKey = doc.id;
        final parts = dateKey.split('-');
        if (parts.length == 3) {
          final date = DateTime(
            int.parse(parts[0]),
            int.parse(parts[1]),
            int.parse(parts[2]),
          );

          if (date.isAtSameMomentAs(startOfWeek) || date.isAfter(startOfWeek)) {
            final diff = date.difference(startOfWeek).inDays;
            if (diff < 7) {
              checkedCount++;
            }
          }
        }
      }

      if (mounted) {
        setState(() {
          _attendanceDays = checkedCount;
          _attendanceRate = checkedCount / 7.0;
          if (_attendanceRate > 1.0) _attendanceRate = 1.0;
        });
      }
    } catch (e) {
      print('출석 통계 로드 오류: $e');
    }
  }

  void _showExitDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _cardBackground,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.close, color: Colors.grey),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '앱을 종료하시겠어요?',
                  style: GoogleFonts.notoSansKr(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: _textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '로그아웃 후 종료하거나,\n그냥 앱만 종료할 수 있어요.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.notoSansKr(
                    fontSize: 13,
                    color: _textSecondary,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          Navigator.pop(context);
                          await _auth.signOut();
                          if (mounted) {
                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const LoginScreen(),
                              ),
                                  (route) => false,
                            );
                          }
                        },
                        style: OutlinedButton.styleFrom(
                          side:
                          BorderSide(color: _primaryColor.withOpacity(0.4)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text(
                          '로그아웃',
                          style: GoogleFonts.notoSansKr(
                            color: _primaryColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          try {
                            SystemNavigator.pop();
                          } catch (e) {}
                          exit(0);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primaryColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          elevation: 0,
                        ),
                        child: Text(
                          '그냥 종료',
                          style: GoogleFonts.notoSansKr(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
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

  Widget _buildDailyQuoteCard() {
    // 기능을 안 산 경우 or 오늘 문구가 없는 경우 -> 안 보여줌
    if (!_dailyQuoteEnabled || _todayQuote == null) {
      return const SizedBox.shrink();
    }

    final quote = _todayQuote!;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: _cardBackground,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _primaryColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Text('✨', style: TextStyle(fontSize: 20)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '오늘의 문장',
                  style: GoogleFonts.notoSansKr(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  quote,
                  style: GoogleFonts.notoSansKr(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: _textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
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
        key: _scaffoldKey,
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          systemOverlayStyle: SystemUiOverlayStyle.light,
          title: Text(
            'PlanIT',
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          centerTitle: false,
          actions: [
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: Colors.white.withOpacity(0.18),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.stars, size: 18, color: Colors.amber),
                  const SizedBox(width: 6),
                  Text(
                    '$_points P',
                    style: GoogleFonts.notoSansKr(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () {
                _scaffoldKey.currentState?.openEndDrawer();
              },
              icon: const Icon(Icons.menu_rounded),
            ),
          ],
          automaticallyImplyLeading: false,
        ),
        endDrawer: Drawer(
          backgroundColor: const Color(0xFF242548),
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  title: Text(
                    '설정 & 기타',
                    style: GoogleFonts.notoSansKr(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Text(
                    'PlanIT을 더 편하게 사용해보세요.',
                    style: GoogleFonts.notoSansKr(
                      color: Colors.white.withOpacity(0.7),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Divider(color: Colors.white24),
                const Spacer(),
                const Divider(color: Colors.white24),
                ListTile(
                  leading: const Icon(Icons.exit_to_app, color: Colors.white70),
                  title: Text(
                    '종료하기',
                    style: GoogleFonts.notoSansKr(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _showExitDialog();
                  },
                ),
                const SizedBox(height: 28),
              ],
            ),
          ),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '오늘 할 일을\nPlanIT에서 정리해볼까요?',
                    style: GoogleFonts.notoSansKr(
                      fontSize: 20,
                      height: 1.3,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 18),
                  _buildDailyQuoteCard(),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    childAspectRatio: 0.9,
                    children: [
                      _buildMenuButton(
                        context: context,
                        icon: Icons.calendar_today_rounded,
                        title: '시간표',
                        subtitle: '강의 일정 한눈에',
                        targetScreen: const TimetableScreen(),
                      ),
                      _buildMenuButton(
                        context: context,
                        icon: Icons.checklist_rounded,
                        title: '할 일 목록',
                        subtitle: '해야 할 일 정리',
                        targetScreen: const TaskListScreen(),
                        onReturned: _refreshData,
                      ),
                      _buildMenuButton(
                        context: context,
                        icon: Icons.check_circle_outline_rounded,
                        title: '출석 체크',
                        subtitle: '출석하면 포인트!',
                        targetScreen: const AttendanceScreen(),
                        onReturned: _refreshData,
                      ),
                      _buildMenuButton(
                        context: context,
                        icon: Icons.storefront_rounded,
                        title: '포인트 상점',
                        subtitle: '아이템 모으기',
                        targetScreen: const StoreScreen(),
                        onReturned: () async {
                          await _loadStoreFeatures();
                          await _refreshData();
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildStatsSection(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMenuButton({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget targetScreen,
    VoidCallback? onReturned,
    bool isNew = false,
  }) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => targetScreen),
        ).then((_) {
          if (onReturned != null) onReturned();
        });
      },
      child: Container(
        decoration: BoxDecoration(
          color: _cardBackground,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16.0),
        child: Stack(
          children: [
            Positioned(
              right: -10,
              top: -10,
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      _primaryColor.withOpacity(0.16),
                      Colors.pinkAccent.withOpacity(0.12),
                    ],
                  ),
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: _primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, size: 24, color: _primaryColor),
                ),
                const SizedBox(height: 14),
                Text(
                  title,
                  style: GoogleFonts.notoSansKr(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.notoSansKr(
                    fontSize: 13,
                    color: _textSecondary,
                  ),
                ),
              ],
            ),
            if (isNew)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.pinkAccent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'NEW',
                    style: GoogleFonts.notoSansKr(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 10,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsSection() {
    return Container(
      padding: const EdgeInsets.all(18.0),
      decoration: BoxDecoration(
        color: _cardBackground,
        borderRadius: BorderRadius.circular(22.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '이번 주 학습 통계',
            style: GoogleFonts.notoSansKr(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: _textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '한 주의 패턴을 한눈에 확인해보세요.',
            style: GoogleFonts.notoSansKr(
              fontSize: 12,
              color: _textSecondary,
            ),
          ),
          const SizedBox(height: 18),
          _buildStatBar(
            title: '계획 진행률',
            value: _taskProgress,
            displayText: '${(_taskProgress * 100).toInt()}% 완료',
          ),
          const SizedBox(height: 16),
          _buildStatBar(
            title: '출석률',
            value: _attendanceRate,
            displayText:
            '$_attendanceDays/7일 (${(_attendanceRate * 100).toInt()}%)',
          ),
          const SizedBox(height: 16),
          _buildStatBar(
            title: '과제 완료율',
            value: _assignmentRate,
            displayText: '${(_assignmentRate * 100).toInt()}% 완료',
          ),
        ],
      ),
    );
  }

  Widget _buildStatBar({
    required String title,
    required double value,
    required String displayText,
  }) {
    final safeValue = value.clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: GoogleFonts.notoSansKr(
                fontSize: 14,
                color: _textSecondary,
              ),
            ),
            Text(
              displayText,
              style: GoogleFonts.notoSansKr(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: _textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: safeValue,
            minHeight: 8,
            backgroundColor: const Color(0xFFF0F1F5),
            color: _primaryColor,
          ),
        ),
      ],
    );
  }
}
