import 'package:flutter/material.dart';

class TaskListScreen extends StatelessWidget {
  const TaskListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('할 일 목록'),
      ),
      body: const Center(
        child: Text(
          '할 일 목록 조회 화면',
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}