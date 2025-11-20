import 'package:flutter/material.dart';

class AddCourseScreen extends StatelessWidget {
  const AddCourseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('강의 추가'),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
        leading: Container(),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildTextField(label: '강의명', hint: '강의명을 입력하세요'),
              const SizedBox(height: 24),
              _buildTextField(label: '강의실', hint: '강의실 번호를 입력하세요'),
              const SizedBox(height: 24),

              Row(
                children: [
                  Expanded(
                    child: _buildTextField(label: '담당 교수', hint: '교수명을 입력하세요'),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildDropdownField(label: '요일', hint: '요일 선택'),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              Row(
                children: [
                  Expanded(
                    child: _buildTimePicker(label: '시작 시간', hint: '오전 09:00'),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildTimePicker(label: '종료 시간', hint: '오전 10:30'),
                  ),
                ],
              ),
              const SizedBox(height: 48),

              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color.fromARGB(255, 59, 58, 112),
                        elevation: 0,
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        '취소하기',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                      },
                      child: const Text(
                        '강의 추가',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({required String label, required String hint}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        TextField(
          decoration: InputDecoration(
            hintText: hint,
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField({required String label, required String hint}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        InputDecorator(
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: null,
              hint: Text(hint, style: const TextStyle(color: Colors.white54)),
              icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
              onChanged: (String? newValue) {
              },
              items: const [
                DropdownMenuItem(value: '월', child: Text('월요일')),
                DropdownMenuItem(value: '화', child: Text('화요일')),
                DropdownMenuItem(value: '수', child: Text('수요일')),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimePicker({required String label, required String hint}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () {
          },
          child: InputDecorator( 
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(hint, style: const TextStyle(color: Colors.white54)),
                const Icon(Icons.access_time, color: Colors.white70, size: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }
}