import 'package:flutter/material.dart';

import 'timetable_screen.dart';
import 'task_list_screen.dart';
import 'attendance_screen.dart';
import 'store_screen.dart';


class MainScreen extends StatelessWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PlanIT'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Chip(
              backgroundColor: Colors.black.withOpacity(0.2),
              label: const Text(
                '0P', 
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          IconButton(onPressed: () {}, icon: const Icon(Icons.menu)),
        ],
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 16,
                crossAxisSpacing: 16, 
                childAspectRatio: 0.9, 
                children: [
                  _buildMenuButton(
                    context: context,
                    icon: Icons.calendar_today,
                    title: '시간표',
                    subtitle: '강의 일정 관리',
                    targetScreen: const TimetableScreen(),
                  ),
                  _buildMenuButton(
                    context: context,
                    icon: Icons.checklist,
                    title: '할 일 목록',
                    subtitle: '업무 관리 및 추적',
                    targetScreen: const TaskListScreen(),
                  ),
                  _buildMenuButton(
                    context: context,
                    icon: Icons.check_circle_outline,
                    title: '출석 체크',
                    subtitle: '매일 포인트 획득',
                    targetScreen: const AttendanceScreen(),
                  ),
                  _buildMenuButton(
                    context: context,
                    icon: Icons.storefront,
                    title: '포인트 상점',
                    subtitle: '포인트로 아이템 구매',
                    targetScreen: const StoreScreen(),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              _buildStatsSection(),
            ],
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
    bool isNew = false,
  }) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => targetScreen),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: const Color(0xFF6768F0).withOpacity(0.2), 
          borderRadius: BorderRadius.circular(20.0),
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 40, color: Colors.white),
                const SizedBox(height: 20),
                Text(
                  title,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 14, color: Colors.white70),
                ),
              ],
            ),
            if (isNew) 
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.yellow[700],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'NEW',
                    style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12),
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
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: const Color(0xFF6768F0).withOpacity(0.2),
        borderRadius: BorderRadius.circular(20.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '이번주 학습 통계',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 20),
          _buildStatBar(title: '계획 진행률', value: 0.0, displayText: '0% 완료'),
          const SizedBox(height: 16),
          _buildStatBar(title: '출석률', value: 0.0, displayText: '0/7일 (0%)'),
          const SizedBox(height: 16),
          _buildStatBar(title: '과제 완료율', value: 0.0, displayText: '0% 완료'),
        ],
      ),
    );
  }

  Widget _buildStatBar({
    required String title,
    required double value,
    required String displayText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, color: Colors.white70),
            ),
            Text(
              displayText,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect( 
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: value,
            minHeight: 10,
            backgroundColor: Colors.black.withOpacity(0.3),
            color: const Color(0xFF6768F0),
          ),
        ),
      ],
    );
  }
}