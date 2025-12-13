import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';
import 'attendance_screen.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class StoreScreen extends StatefulWidget {
  const StoreScreen({super.key});

  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

enum StoreCategory {
  theme,
  appIcon,
  feature,
}

class StoreItem {
  StoreItem({
    required this.id,
    required this.title,
    required this.description,
    required this.cost,
    required this.category,
    required this.icon,
    this.isOwned = false,
  });

  final String id;
  final String title;
  final String description;
  final int cost;
  final StoreCategory category;
  final IconData icon;
  bool isOwned;
}

class _StoreScreenState extends State<StoreScreen> {
  bool _isLoading = true;
  int _points = 0;
  Set<String> _ownedItemIds = {};

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _selectedThemeItemId = 'theme_default';
  String _selectedIconItemId = 'icon_default';

  late List<StoreItem> _items;

  final Map<StoreCategory, String> _categoryNames = {
    StoreCategory.theme: '테마',
    StoreCategory.appIcon: '앱 아이콘',
    StoreCategory.feature: '추가 기능',
  };

  static const Color _bgColor = Color(0xFF1B1C3A);
  static const Color _cardBaseColor = Color(0xFF262744);
  static const Color _accentColor = Color(0xFF6768F0);
  static const Color _goldColor = Color(0xFFE9C46A);

  bool get _isDefaultTheme => _selectedThemeItemId == 'theme_default';
  bool get _isLightTheme => _selectedThemeItemId == 'theme_light';
  bool get _isDarkTheme => _selectedThemeItemId == 'theme_dark';

  Color get _scaffoldBackground {
    if (_isLightTheme) return Colors.white;
    if (_isDarkTheme) return Colors.black;
    return _bgColor;
  }

  Color get _appBarBackground {
    if (_isLightTheme) return Colors.white;
    return const Color(0xFF1F203A);
  }

  Color get _appBarForeground {
    if (_isLightTheme) return Colors.black87;
    return Colors.white;
  }

  Color get _cardBackground {
    if (_isLightTheme) return Colors.white;
    return _cardBaseColor;
  }

  Color get _primaryTextColor {
    if (_isLightTheme) return Colors.black87;
    return Colors.white;
  }

  Color get _secondaryTextColor {
    if (_isLightTheme) return Colors.black54;
    return Colors.white70;
  }

  Color get _chipBackground {
    if (_isLightTheme) {
      return Colors.black.withOpacity(0.04);
    }
    return Colors.black.withOpacity(0.18);
  }

  Color get _iconBgColor {
    if (_isLightTheme) {
      return Colors.black.withOpacity(0.04);
    }
    return Colors.white.withOpacity(0.08);
  }

  @override
  void initState() {
    super.initState();
    _initItems();
    _loadData();
  }

  void _initItems() {
    _items = [
      StoreItem(
        id: 'theme_default',
        title: '기본 테마',
        description: '짙은 남색 배경과 카드 스타일의 PlanIT 기본 테마입니다.',
        cost: 0,
        category: StoreCategory.theme,
        icon: Icons.style,
        isOwned: true,
      ),
      StoreItem(
        id: 'theme_light',
        title: '화이트 모드',
        description: '밝은 배경과 어두운 글씨로 낮 시간 사용에 적합한 화이트 모드입니다.',
        cost: 50,
        category: StoreCategory.theme,
        icon: Icons.light_mode,
      ),
      StoreItem(
        id: 'theme_dark',
        title: '다크 모드',
        description: '완전히 어두운 배경으로 눈의 피로를 줄여주는 다크 모드입니다.',
        cost: 50,
        category: StoreCategory.theme,
        icon: Icons.dark_mode,
      ),
      StoreItem(
        id: 'icon_default',
        title: '기본 아이콘',
        description: 'PlanIT의 기본 아이콘을 사용합니다. (무료)',
        cost: 0,
        category: StoreCategory.appIcon,
        icon: Icons.event_note,
        isOwned: true,
      ),
      StoreItem(
        id: 'icon_blue_planet',
        title: '블루 플래닛 아이콘',
        description: '푸른 행성을 모티브로 한 플래너 컨셉 아이콘입니다.',
        cost: 10,
        category: StoreCategory.appIcon,
        icon: Icons.public,
      ),
      StoreItem(
        id: 'icon_minimal',
        title: '미니멀 아이콘',
        description: '얇은 라인으로 그려진 심플한 미니멀 아이콘입니다.',
        cost: 5,
        category: StoreCategory.appIcon,
        icon: Icons.circle_outlined,
      ),
      StoreItem(
        id: 'feature_confetti',
        title: '완료 축하 효과',
        description: '할 일을 완료할 때마다 축하 애니메이션 팝업이 나타납니다.',
        cost: 30,
        category: StoreCategory.feature,
        icon: Icons.celebration,
      ),
      StoreItem(
        id: 'feature_dday',
        title: 'D-Day 위젯',
        description: '중요한 일정을 메인 화면에서 카운트다운하세요.',
        cost: 30,
        category: StoreCategory.feature,
        icon: Icons.timer,
      ),
      StoreItem(
        id: 'feature_daily_quote',
        title: '오늘의 문장 위젯',
        description: '메인 화면 상단에 동기부여 문장을 띄워줍니다.',
        cost: 20,
        category: StoreCategory.feature,
        icon: Icons.format_quote,
      ),
      StoreItem(
        id: 'item_random_box',
        title: '랜덤 포인트 박스',
        description: '10P를 사용해 랜덤박스를 열어보세요!',
        cost: 10,
        category: StoreCategory.feature,
        icon: Icons.card_giftcard,
      ),
    ];
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();

    int pts = 0;
    Set<String> ownedSet = {};

    String savedThemeId =
        prefs.getString('selectedThemeItemId') ?? 'theme_default';
    String savedIconId =
        prefs.getString('selectedIconItemId') ?? 'icon_default';

    final user = _auth.currentUser;
    if (user != null) {
      try {
        final doc = await _firestore.collection('users').doc(user.uid).get();
        final data = doc.data();

        final p = data?['points'];
        if (p is int) {
          pts = p;
        } else if (p is num) {
          pts = p.toInt();
        }

        final List<dynamic>? ownedListFromFirebase = data?['ownedItems'];
        if (ownedListFromFirebase != null) {
          ownedSet.addAll(ownedListFromFirebase.whereType<String>());
        }
      } catch (e) {
        debugPrint('StoreScreen 데이터 로드 오류: $e');
      }
    }

    for (final item in _items.where((e) => e.cost == 0)) {
      ownedSet.add(item.id);
    }

    String themeId = savedThemeId;
    if (!_items.any((e) =>
    e.id == themeId &&
        e.category == StoreCategory.theme &&
        ownedSet.contains(themeId))) {
      themeId = 'theme_default';
    }

    String iconId = savedIconId;
    if (!_items.any((e) =>
    e.id == iconId &&
        e.category == StoreCategory.appIcon &&
        ownedSet.contains(iconId))) {
      iconId = 'icon_default';
    }

    setState(() {
      _points = pts;
      _ownedItemIds = ownedSet;
      _selectedThemeItemId = themeId;
      _selectedIconItemId = iconId;

      for (final item in _items) {
        item.isOwned = _ownedItemIds.contains(item.id);
      }

      _isLoading = false;
    });
  }

  Future<void> _savePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selectedThemeItemId', _selectedThemeItemId);
    await prefs.setString('selectedIconItemId', _selectedIconItemId);
  }

  Future<void> _savePointsToFirestore() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .set({'points': _points}, SetOptions(merge: true));
    } catch (e) {
      debugPrint('StoreScreen 포인트 저장 오류: $e');
    }
  }

  Future<void> _addOwnedItemToFirestore(String itemId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore.collection('users').doc(user.uid).set({
        'ownedItems': FieldValue.arrayUnion([itemId]),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('StoreScreen ownedItems 저장 오류: $e');
    }
  }

  Future<void> _buyItem(StoreItem item) async {
    if (item.id == 'item_random_box') {
      if (_points < item.cost) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('포인트가 부족합니다. 출석 체크로 포인트를 모아보세요!')),
        );
        return;
      }

      setState(() {
        _points -= item.cost;
      });

      final randomPoint = (Random().nextInt(10) + 1) * 5;

      setState(() {
        _points += randomPoint;
      });

      await _savePointsToFirestore();
      await _savePrefs();

      if (mounted) {
        _showGachaResultDialog(randomPoint);
      }
      return;
    }

    if (item.isOwned) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이미 구매한 아이템이에요.')),
      );
      return;
    }

    if (_points < item.cost) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('포인트가 부족합니다. 출석 체크로 포인트를 모아보세요!')),
      );
      return;
    }

    setState(() {
      _points -= item.cost;
      item.isOwned = true;
      _ownedItemIds.add(item.id);

      if (item.category == StoreCategory.theme) {
        _selectedThemeItemId = item.id;
      } else if (item.category == StoreCategory.appIcon) {
        _selectedIconItemId = item.id;
      }
    });

    await _savePointsToFirestore();
    await _addOwnedItemToFirestore(item.id);
    await _savePrefs();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('\'${item.title}\'를(을) 구매했어요!')),
      );
    }
  }

  Future<void> _applyItem(StoreItem item) async {
    if (!item.isOwned) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('먼저 구매 후 사용할 수 있어요.')),
      );
      return;
    }

    if (item.category == StoreCategory.feature) {
      return;
    }

    setState(() {
      if (item.category == StoreCategory.theme) {
        _selectedThemeItemId = item.id;
      } else if (item.category == StoreCategory.appIcon) {
        _selectedIconItemId = item.id;
      }
    });

    await _savePrefs();

    final what = item.category == StoreCategory.theme ? '테마' : '앱 아이콘';
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('\'${item.title}\' $what를 적용했어요.')),
      );
    }
  }

  IconData get _currentIconData {
    switch (_selectedIconItemId) {
      case 'icon_blue_planet':
        return Icons.public;
      case 'icon_minimal':
        return Icons.circle_outlined;
      case 'icon_default':
      default:
        return Icons.event_note;
    }
  }

  String get _currentIconLabel {
    switch (_selectedIconItemId) {
      case 'icon_blue_planet':
        return '블루 플래닛';
      case 'icon_minimal':
        return '미니멀';
      case 'icon_default':
      default:
        return '기본';
    }
  }

  String get _currentThemeLabel {
    switch (_selectedThemeItemId) {
      case 'theme_light':
        return '화이트 모드';
      case 'theme_dark':
        return '다크 모드';
      case 'theme_default':
      default:
        return '기본 테마';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: _scaffoldBackground,
      appBar: AppBar(
        backgroundColor: _appBarBackground,
        foregroundColor: _appBarForeground,
        title: const Text('포인트 상점'),
        elevation: 0,
        actions: [
          _buildPointChip(points: _points),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          children: [
            _buildHeaderCard(),
            const SizedBox(height: 12),
            Expanded(child: _buildItemList()),
          ],
        ),
      ),
    );
  }

  Widget _buildPointChip({required int points}) {
    final isLight = _isLightTheme;

    return Container(
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isLight ? Colors.black.withOpacity(0.04) : const Color(0xFF262744),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: isLight ? Colors.black.withOpacity(0.08) : Colors.white24,
          width: 0.8,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(
              color: _goldColor,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.star,
              size: 14,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '$points P',
            style: TextStyle(
              color: isLight ? Colors.black87 : Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cardBackground,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _iconBgColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              _currentIconData,
              color: _primaryTextColor,
              size: 26,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PlanIT 포인트 상점',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: _primaryTextColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '현재 테마: $_currentThemeLabel\n현재 앱 아이콘: $_currentIconLabel',
                  style: TextStyle(
                    fontSize: 11,
                    color: _secondaryTextColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          TextButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const AttendanceScreen(),
                ),
              );
            },
            style: TextButton.styleFrom(
              foregroundColor: _primaryTextColor,
            ),
            icon: const Icon(Icons.calendar_today_outlined, size: 16),
            label: const Text(
              '출석하기',
              style: TextStyle(fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemList() {
    final sections = <Widget>[];

    for (final category in StoreCategory.values) {
      final categoryItems = _items.where((item) => item.category == category).toList();
      if (categoryItems.isEmpty) continue;

      sections.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 10, 4, 4),
          child: Text(
            _categoryNames[category] ?? '',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: _primaryTextColor,
            ),
          ),
        ),
      );

      sections.addAll(categoryItems.map(_buildItemTile));
    }

    return ListView(children: sections);
  }

  Widget _buildItemTile(StoreItem item) {
    final bool canBuy = _points >= item.cost && !item.isOwned;

    bool isApplied = false;
    if (item.category == StoreCategory.theme) {
      isApplied = (_selectedThemeItemId == item.id);
    } else if (item.category == StoreCategory.appIcon) {
      isApplied = (_selectedIconItemId == item.id);
    }

    Widget trailing;
    if (item.category == StoreCategory.feature) {
      trailing = item.isOwned
          ? _buildOwnedFeatureTrailing(item)
          : _buildBuyTrailing(canBuy, item);
    } else {
      trailing = item.cost == 0
          ? _buildOwnedFreeTrailing(isApplied, item)
          : (item.isOwned
          ? _buildOwnedPaidTrailing(isApplied, item)
          : _buildBuyTrailing(canBuy, item));
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: _cardBackground,
        borderRadius: BorderRadius.circular(18),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _iconBgColor,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            item.icon,
            size: 24,
            color: _primaryTextColor,
          ),
        ),
        title: Text(
          item.title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: _primaryTextColor,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text(
            item.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              color: _secondaryTextColor,
            ),
          ),
        ),
        trailing: trailing,
      ),
    );
  }

  Widget _buildBuyTrailing(bool canBuy, StoreItem item) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          '${item.cost} P',
          style: TextStyle(
            fontSize: 12,
            color: _primaryTextColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 26,
          child: ElevatedButton(
            onPressed: canBuy ? () => _buyItem(item) : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: canBuy ? _accentColor : Colors.grey.shade600,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 0,
            ),
            child: const Text(
              '구매',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOwnedPaidTrailing(bool isApplied, StoreItem item) {
    if (isApplied) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: const [
          Text(
            '적용 중',
            style: TextStyle(
              fontSize: 11,
              color: _goldColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 2),
          Icon(
            Icons.check_circle,
            color: _goldColor,
            size: 18,
          ),
        ],
      );
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          '구매 완료',
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey,
            height: 1.0,
          ),
        ),
        const SizedBox(height: 2),
        SizedBox(
          height: 24,
          child: OutlinedButton(
            onPressed: () => _applyItem(item),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: _accentColor),
              foregroundColor: _accentColor,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              '적용',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOwnedFreeTrailing(bool isApplied, StoreItem item) {
    if (isApplied) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: const [
          Text(
            '적용 중',
            style: TextStyle(
              fontSize: 11,
              color: _goldColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 4),
          Icon(
            Icons.check_circle,
            color: _goldColor,
            size: 18,
          ),
        ],
      );
    }

    return SizedBox(
      height: 26,
      child: OutlinedButton(
        onPressed: () => _applyItem(item),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: _accentColor),
          foregroundColor: _accentColor,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: const Text(
          '적용',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildOwnedFeatureTrailing(StoreItem item) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: const [
        Text(
          '사용 중',
          style: TextStyle(
            fontSize: 11,
            color: _goldColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 4),
        Icon(
          Icons.check_circle,
          color: _goldColor,
          size: 18,
        ),
      ],
    );
  }

  void _showGachaResultDialog(int earnedPoint) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF262744),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Center(
            child: Icon(Icons.stars, size: 48, color: Color(0xFFE9C46A)),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '축하합니다! 🎉',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '$earnedPoint P',
                style: const TextStyle(
                  color: Color(0xFFE9C46A),
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '를 획득했어요!',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('확인', style: TextStyle(color: Color(0xFF6768F0))),
            ),
          ],
        );
      },
    );
  }
}
