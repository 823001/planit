import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// TODO: 경로 프로젝트에 맞게 수정
import 'attendance_screen.dart';

class StoreScreen extends StatefulWidget {
  const StoreScreen({super.key});

  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

enum StoreCategory {
  theme,
  appIcon,
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

  final String id; // SharedPreferences에 저장할 때 사용할 고유 ID
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

  // 선택된 테마/아이콘 (아이템 id 기준)
  String _selectedThemeItemId = 'theme_default';
  String _selectedIconItemId = 'icon_default';

  late List<StoreItem> _items;

  final Map<StoreCategory, String> _categoryNames = {
    StoreCategory.theme: '테마',
    StoreCategory.appIcon: '앱 아이콘',
  };

  // 출석 탭과 동일하게 쓸 색상들
  static const Color _cardBaseColor = Color(0xFF25254A);
  static const Color _accentColor = Color(0xFF6768F0);
  static const Color _goldColor = Color(0xFFB5986D);

  bool get _isDefaultTheme => _selectedThemeItemId == 'theme_default';
  bool get _isLightTheme => _selectedThemeItemId == 'theme_light';
  bool get _isDarkTheme => _selectedThemeItemId == 'theme_dark';

  // ======= 색상 계산 (기본 모드는 출석 체크 스타일 그대로) =======
  Color get _scaffoldBackground {
    if (_isLightTheme) return Colors.white;
    if (_isDarkTheme) return Colors.black;
    return Theme.of(context).scaffoldBackgroundColor;
  }

  Color get _appBarBackground {
    if (_isLightTheme) return Colors.white;
    return _cardBaseColor;
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
      return Colors.black.withOpacity(0.06);
    }
    return Colors.black.withOpacity(0.25);
  }

  Color get _iconBgColor {
    if (_isLightTheme) {
      return Colors.black.withOpacity(0.05);
    }
    return Colors.white.withOpacity(0.1);
  }

  @override
  void initState() {
    super.initState();
    _initItems();
    _loadData();
  }

  void _initItems() {
    _items = [
      // ===== 테마 =====
      StoreItem(
        id: 'theme_default',
        title: '기본 테마',
        description: '출석 체크 탭에서 쓰는 진한 남색 카드 스타일의 기본 테마입니다.',
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
        description: '전체 배경을 어둡게 해서 밤에도 눈에 부담을 줄여주는 다크 모드입니다.',
        cost: 50,
        category: StoreCategory.theme,
        icon: Icons.dark_mode,
      ),

      // ===== 앱 아이콘 =====
      StoreItem(
        id: 'icon_default',
        title: '기본 아이콘',
        description: '기본 PlanIT 아이콘을 사용합니다. (무료)',
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
        description: '얇은 라인으로 그려진 심플한 아이콘입니다.',
        cost: 5,
        category: StoreCategory.appIcon,
        icon: Icons.circle_outlined,
      ),
    ];
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();

    final pts = prefs.getInt('points') ?? 0; // 출석 체크랑 동일 키
    final ownedList = prefs.getStringList('ownedStoreItems') ?? [];
    final savedThemeId = prefs.getString('selectedThemeItemId');
    final savedIconId = prefs.getString('selectedIconItemId');

    // 무료 아이템은 항상 소유 처리
    final ownedSet = ownedList.toSet();
    for (final item in _items.where((e) => e.cost == 0)) {
      ownedSet.add(item.id);
    }

    String themeId = savedThemeId ?? 'theme_default';
    if (!_items.any((e) => e.id == themeId && e.category == StoreCategory.theme)) {
      themeId = 'theme_default';
    }

    String iconId = savedIconId ?? 'icon_default';
    if (!_items.any((e) => e.id == iconId && e.category == StoreCategory.appIcon)) {
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

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('points', _points);
    await prefs.setStringList('ownedStoreItems', _ownedItemIds.toList());
    await prefs.setString('selectedThemeItemId', _selectedThemeItemId);
    await prefs.setString('selectedIconItemId', _selectedIconItemId);
  }

  Future<void> _buyItem(StoreItem item) async {
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

      // 테마/아이콘은 구매와 동시에 적용
      if (item.category == StoreCategory.theme) {
        _selectedThemeItemId = item.id;
      } else if (item.category == StoreCategory.appIcon) {
        _selectedIconItemId = item.id;
      }
    });

    await _saveData();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('\'${item.title}\'를(을) 구매했어요!')),
    );
  }

  Future<void> _applyItem(StoreItem item) async {
    if (!item.isOwned) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('먼저 구매 후 사용할 수 있어요.')),
      );
      return;
    }

    setState(() {
      if (item.category == StoreCategory.theme) {
        _selectedThemeItemId = item.id;
      } else if (item.category == StoreCategory.appIcon) {
        _selectedIconItemId = item.id;
      }
    });

    await _saveData();

    final what =
    item.category == StoreCategory.theme ? '테마' : '앱 아이콘';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('\'${item.title}\' $what를 적용했어요.')),
    );
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
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: Center(
              child: Chip(
                backgroundColor: _chipBackground,
                label: Text(
                  '$_points P',
                  style: TextStyle(
                    color: _isLightTheme ? Colors.black : Colors.white,
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
            _buildHeaderCard(context),
            const SizedBox(height: 10),
            Expanded(
              child: _buildItemList(),
            ),
          ],
        ),
      ),
    );
  }

  // ===== 현재 선택된 아이콘/테마 라벨 =====
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

  Widget _buildHeaderCard(BuildContext context) {
    final headerColor = _isLightTheme ? Colors.white : _cardBaseColor;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: headerColor,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _iconBgColor,
              borderRadius: BorderRadius.circular(14),
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
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: () {
              // 출석하기 → AttendanceScreen으로 이동
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const AttendanceScreen(),
                ),
              );
            },
            icon: Icon(
              Icons.calendar_today_outlined,
              size: 16,
              color: _primaryTextColor,
            ),
            label: Text(
              '출석하기',
              style: TextStyle(fontSize: 11, color: _primaryTextColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemList() {
    final sections = <Widget>[];

    for (final category in StoreCategory.values) {
      final categoryItems =
      _items.where((item) => item.category == category).toList();
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

      sections.addAll(
        categoryItems.map((item) => _buildItemTile(item)),
      );
    }

    return ListView(
      children: sections,
    );
  }

  Widget _buildItemTile(StoreItem item) {
    final bool canBuy = _points >= item.cost && !item.isOwned;

    bool isApplied = false;
    if (item.category == StoreCategory.theme) {
      isApplied = (_selectedThemeItemId == item.id);
    } else if (item.category == StoreCategory.appIcon) {
      isApplied = (_selectedIconItemId == item.id);
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: _cardBackground,
        borderRadius: BorderRadius.circular(14),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _iconBgColor,
            borderRadius: BorderRadius.circular(12),
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
        trailing: item.cost == 0
            ? _buildOwnedFreeTrailing(isApplied, item)
            : (item.isOwned
            ? _buildOwnedPaidTrailing(isApplied, item)
            : _buildBuyTrailing(canBuy, item)),
      ),
    );
  }

  Widget _buildBuyTrailing(bool canBuy, StoreItem item) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          '${item.cost} P',
          style: TextStyle(
            fontSize: 12,
            color: _primaryTextColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4), // 🔽 6 → 4
        SizedBox(
          height: 26, // 🔽 28 → 26
          child: ElevatedButton(
            onPressed: canBuy ? () => _buyItem(item) : null,
            style: ElevatedButton.styleFrom(
              backgroundColor:
              canBuy ? _accentColor : Colors.grey.shade500,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
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

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          '구매 완료',
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 28,
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
        ),
      ],
    );
  }

  Widget _buildOwnedFreeTrailing(bool isApplied, StoreItem item) {
    if (isApplied) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
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
      height: 28,
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
}
