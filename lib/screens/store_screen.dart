import 'package:flutter/material.dart';

class StoreScreen extends StatelessWidget {
  const StoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('포인트 상점'),
      ),
      body: const Center(
        child: Text(
          '포인트 상점 화면',
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}