import 'package:flutter/material.dart';

class RegisterScreen extends StatelessWidget {
  const RegisterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('회원가입'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              const Text(
                '새 계정을 생성하세요',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.white70),
              ),
              const SizedBox(height: 40),

              const TextField(
                decoration: InputDecoration(
                  labelText: '아이디',
                  hintText: '아이디 입력',
                ),
              ),
              const SizedBox(height: 12),

              TextButton(
                onPressed: () {
                },
                style: TextButton.styleFrom(
                  backgroundColor: const Color.fromARGB(255, 59, 58, 112),
                  foregroundColor: Colors.white,
                ),
                child: const Text('아이디 중복 확인'),
              ),
              const SizedBox(height: 24),

              const TextField(
                obscureText: true,
                decoration: InputDecoration(
                  labelText: '비밀번호',
                  hintText: '비밀번호 입력',
                  helperText: '영문, 숫자, 특수문자 조합 8자 이상 필요', // [V-81]
                ),
              ),
              const SizedBox(height: 16),

              const TextField(
                obscureText: true,
                decoration: InputDecoration(
                  labelText: '비밀번호 확인',
                  hintText: '비밀번호 재입력',
                ),
              ),
              const SizedBox(height: 40),

              ElevatedButton(
                onPressed: () {
                },
                child: const Text('가입 완료하기'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}