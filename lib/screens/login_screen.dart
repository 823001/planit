import 'package:flutter/material.dart';
import 'package:planit/screens/register_screen.dart';
import 'package:planit/screens/main_screen.dart';


class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0), 
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 60),

                const Text(
                  'PlanIT 로그인',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),

                const Text(
                  '할 일을 효율적으로 관리하세요',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 48),

                const Text(
                  '아이디',
                  style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),

                const TextField(
                  decoration: InputDecoration(
                    hintText: '사용자 아이디 입력',
                  ),
                ),
                const SizedBox(height: 24),

                const Text(
                  '비밀번호',
                  style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),

                const TextField(
                  obscureText: true,
                  decoration: InputDecoration(
                    hintText: '비밀번호 입력',
                    helperText: '영문, 숫자, 특수문자 조합 8자 이상',
                  ),
                ),
                const SizedBox(height: 32),

                ElevatedButton(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => const MainScreen()),
                    );
                  },
                  child: const Text(
                    '로그인하기',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 16),

                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 59, 58, 112), 
                    elevation: 0,
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const RegisterScreen()),
                    );
                  },
                  child: const Text(
                    '회원가입',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),

                const SizedBox(height: 40),

                _buildPermissionBox(), 

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPermissionBox() {
    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 59, 58, 112).withOpacity(0.5), 
        borderRadius: BorderRadius.circular(15.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: const [
              Icon(Icons.notifications_active_outlined, color: Colors.white),
              SizedBox(width: 12),
              Text(
                '알림 권한 설정',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            '마감 기한 알림 기능을 위해 "PlanIT"이 알림을 보낼 수 있도록 권한을 허용해주세요',
            style: TextStyle(fontSize: 14, color: Colors.white70),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
            
            },
            child: const Text(
              '✓ 알림 허용하기',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}