import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _passwordCheckController = TextEditingController();

  bool _isLoading = false;

  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// 비밀번호 유효성 검사
  /// - 최소 8자
  /// - 영문 1개 이상
  /// - 숫자 1개 이상
  /// - 특수문자 1개 이상 (@$!%*#?& 중 하나)
  bool _isValidPassword(String password) {
    final regex = RegExp(r'^(?=.*[A-Za-z])(?=.*\d)(?=.*[@$!%*#?&]).{8,}$');
    return regex.hasMatch(password);
  }

  // 회원가입 처리
  Future<void> _register() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final passwordCheck = _passwordCheckController.text.trim();

    if (email.isEmpty || password.isEmpty || passwordCheck.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('모든 칸을 입력해주세요.')),
      );
      return;
    }

    // 비밀번호 규칙 검사 (8자 이상 + 영문 + 숫자 + 특수문자)
    if (!_isValidPassword(password)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('비밀번호는 8자 이상, 영문+숫자+특수문자를 모두 포함해야 합니다.'),
        ),
      );
      return;
    }

    if (password != passwordCheck) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('비밀번호가 일치하지 않습니다.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('회원가입이 완료되었습니다. 로그인 화면으로 이동합니다.')),
      );

      Navigator.pop(context); // 로그인 화면으로 돌아가기
    } on FirebaseAuthException catch (e) {
      String message = '회원가입 중 오류가 발생했습니다.';

      if (e.code == 'email-already-in-use') {
        message = '이미 사용 중인 아이디(이메일)입니다.';
      } else if (e.code == 'weak-password') {
        // 이 경우도 있지만, 우리 쪽에서 이미 강하게 검사하고 있으니 거의 안 뜰 거야
        message = '비밀번호가 너무 약합니다.';
      } else if (e.code == 'invalid-email') {
        message = '올바른 이메일 형식이 아닙니다.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('알 수 없는 오류가 발생했습니다: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passwordCheckController.dispose();
    super.dispose();
  }

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

              // 아이디 (이메일)
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: '아이디 (이메일)',
                  hintText: '이메일 입력',
                ),
              ),
              const SizedBox(height: 24),

              // 비밀번호
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: '비밀번호',
                  hintText: '비밀번호 입력',
                  helperText: '영문, 숫자, 특수문자 포함 8자 이상 필요',
                ),
              ),
              const SizedBox(height: 16),

              // 비밀번호 확인
              TextField(
                controller: _passwordCheckController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: '비밀번호 확인',
                  hintText: '비밀번호 재입력',
                ),
              ),
              const SizedBox(height: 40),

              ElevatedButton(
                onPressed: _isLoading ? null : _register,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('가입 완료하기'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
