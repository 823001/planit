import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _passwordCheckController =
  TextEditingController();

  bool _isLoading = false;

  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 공통 컬러 (LoginScreen / MainScreen과 동일 톤)
  final Color _primaryColor = const Color(0xFF6768F0);
  final Color _backgroundTop = const Color(0xFF191C3D);
  final Color _backgroundBottom = const Color(0xFF101226);
  final Color _cardBackground = const Color(0xFF262744);
  final Color _fieldBackground = const Color(0xFF262744);

  /// 비밀번호 유효성 검사
  /// - 최소 8자
  /// - 영문 1개 이상
  /// - 숫자 1개 이상
  /// - 특수문자 1개 이상 (@$!%*#?& 중 하나)
  bool _isValidPassword(String password) {
    final regex = RegExp(r'^(?=.*[A-Za-z])(?=.*\d)(?=.*[@$!%*#?&]).{8,}$');
    return regex.hasMatch(password);
  }

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
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_backgroundTop, _backgroundBottom],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
          title: Text(
            '회원가입',
            style: GoogleFonts.notoSansKr(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          centerTitle: false,
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  Text(
                    '새로운 PlanIT 계정을 만들어볼까요?',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.notoSansKr(
                      fontSize: 13,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(18.0),
                    decoration: BoxDecoration(
                      color: _cardBackground,
                      borderRadius: BorderRadius.circular(20.0),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          '기본 정보 입력',
                          style: GoogleFonts.notoSansKr(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '로그인에 사용할 이메일과 비밀번호를 설정해주세요.',
                          style: GoogleFonts.notoSansKr(
                            fontSize: 12,
                            color: Colors.white60,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // 아이디 (이메일)
                        Text(
                          '아이디 (이메일)',
                          style: GoogleFonts.notoSansKr(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white70,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          style: GoogleFonts.notoSansKr(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                          cursorColor: Colors.white70,
                          decoration: InputDecoration(
                            hintText: '이메일 입력',
                            hintStyle: GoogleFonts.notoSansKr(
                              color: Colors.white38,
                              fontSize: 13,
                            ),
                            filled: true,
                            fillColor: _fieldBackground,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: Colors.white10),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: Colors.white30),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // 비밀번호
                        Text(
                          '비밀번호',
                          style: GoogleFonts.notoSansKr(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white70,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _passwordController,
                          obscureText: true,
                          style: GoogleFonts.notoSansKr(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                          cursorColor: Colors.white70,
                          decoration: InputDecoration(
                            hintText: '비밀번호 입력',
                            hintStyle: GoogleFonts.notoSansKr(
                              color: Colors.white38,
                              fontSize: 13,
                            ),
                            helperText: '영문, 숫자, 특수문자 포함 8자 이상 필요',
                            helperStyle: GoogleFonts.notoSansKr(
                              color: Colors.white38,
                              fontSize: 11,
                            ),
                            filled: true,
                            fillColor: _fieldBackground,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: Colors.white10),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: Colors.white30),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // 비밀번호 확인
                        Text(
                          '비밀번호 확인',
                          style: GoogleFonts.notoSansKr(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white70,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _passwordCheckController,
                          obscureText: true,
                          style: GoogleFonts.notoSansKr(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                          cursorColor: Colors.white70,
                          decoration: InputDecoration(
                            hintText: '비밀번호 재입력',
                            hintStyle: GoogleFonts.notoSansKr(
                              color: Colors.white38,
                              fontSize: 13,
                            ),
                            filled: true,
                            fillColor: _fieldBackground,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: Colors.white10),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: Colors.white30),
                            ),
                          ),
                        ),
                        const SizedBox(height: 26),

                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _register,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _primaryColor,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(
                                vertical: 14,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                                : Text(
                              '가입 완료하기',
                              style: GoogleFonts.notoSansKr(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),
                  Text(
                    '이미 계정이 있으신가요? 상단 뒤로가기를 눌러 로그인 화면으로 돌아갈 수 있어요.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.notoSansKr(
                      fontSize: 11,
                      color: Colors.white54,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
