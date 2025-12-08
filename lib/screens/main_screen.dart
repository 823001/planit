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

  // Firestore에서 읽어올 실제 명언 리스트
  List<String> _quotes = [];
  static const List<String> _defaultQuotes = [];
  // 오늘 한 번만 뽑아서 쓰는 문장
  String? _todayQuote;

  // 공통 컬러/테마
  final Color _primaryColor = const Color(0xFF6768F0);
  final Color _backgroundTop = const Color(0xFF191C3D);
  final Color _backgroundBottom = const Color(0xFF101226);
  final Color _cardBackground = const Color(0xFF262744); // 어두운 카드
  final Color _textPrimary = Colors.white; // 카드 안 메인 텍스트
  final Color _textSecondary = Colors.white70; // 카드 안 서브 텍스트

  static const String _quotePrefsDateKey = 'daily_quote_date';
  static const String _quotePrefsTextKey = 'daily_quote_text';

  @override
  void initState() {
    super.initState();
    _loadStoreFeatures();
    _refreshData();
  }

  // Firestore에서 명언 리스트 가져오기
  // 경로: meta/quotes 문서, 필드: list (array<string>)
  Future<void> _loadQuotesFromFirestore() async {
    try {
      final doc = await _firestore.collection('meta').doc('quotes').get();

      if (doc.exists) {
        final data = doc.data();
        final rawList = data?['list'];

        if (rawList is List) {
          final loaded = rawList.whereType<String>().toList();

          if (mounted) {
            setState(() {
              _quotes = loaded;
            });
          }
          return;
        }
      }

      // 명언이 하나도 없는 경우 → 오늘의 문장 기능 비활성화
      setState(() {
        _quotes = [];
      });

    } catch (e) {
      print('오늘의 문구 Firestore 로드 오류: $e');

      // 오류 시에도 기능을 켜지 않도록 empty 유지
      if (mounted) setState(() => _quotes = []);
    }
  }

  // 오늘의 문구 한 번만 선택 (SharedPreferences에 오늘 날짜 기준으로 캐싱)
  Future<void> _initTodayQuote() async {
    if (_quotes.isEmpty) {
      setState(() {
        _todayQuote = null;
      });
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now();
    final todayStr = '${today.year}-${today.month}-${today.day}';

    final savedDate = prefs.getString(_quotePrefsDateKey);
    final savedQuote = prefs.getString(_quotePrefsTextKey);

    if (savedDate == todayStr &&
        savedQuote != null &&
        _quotes.contains(savedQuote)) {
      setState(() => _todayQuote = savedQuote);
      return;
    }
    // 새로 뽑기
    final newQuote = (_quotes..shuffle()).first;

    await prefs.setString(_quotePrefsDateKey, todayStr);
    await prefs.setString(_quotePrefsTextKey, newQuote);

    setState(() => _todayQuote = newQuote);
  }

  // 상점에서 산 기능 정보 로드
  // feature_daily_quote 가지고 있으면 명언 로드 + 오늘 문장 뽑기까지 같이 처리
  Future<void> _loadStoreFeatures() async {
    final prefs = await SharedPreferences.getInstance();
    final owned = prefs.getStringList('ownedStoreItems') ?? [];

    final enabled = owned.contains('feature_daily_quote');

    setState(() {
      _dailyQuoteEnabled = enabled;
    });

    if (enabled) {
      // 오늘의 문구 아이템을 산 경우에만 명언 로드 후 명언 선택
      await _loadQuotesFromFirestore();
      await _initTodayQuote();
    } else {
      // 기능을 안 샀으면 명언 비움
      setState(() {
        _todayQuote = null;
      });
    }
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
                          side: BorderSide(
                              color: _primaryColor.withOpacity(0.4)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding:
                          const EdgeInsets.symmetric(vertical: 12),
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
                          padding:
                          const EdgeInsets.symmetric(vertical: 12),
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
    // 기능을 안 샀거나, 아직 오늘 문구가 없는 경우 -> 안 보여줌
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
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 6),
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
                  leading:
                  const Icon(Icons.exit_to_app, color: Colors.white70),
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
