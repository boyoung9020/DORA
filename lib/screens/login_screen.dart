import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/glass_container.dart';
import '../widgets/app_title_bar.dart';
import 'register_screen.dart';
import 'main_layout.dart';

/// 로그인 화면 - Liquid Glass 디자인
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    print('[LoginScreen] _handleLogin 호출');
    if (_formKey.currentState!.validate()) {
      print('[LoginScreen] 폼 검증 통과');
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      
      // 이전 에러 메시지 초기화
      authProvider.clearError();
      print('[LoginScreen] 에러 메시지 초기화 완료');
      
      print('[LoginScreen] 로그인 시도: ${_usernameController.text.trim()}');
      final success = await authProvider.login(
        _usernameController.text.trim(),
        _passwordController.text,
      );
      print('[LoginScreen] 로그인 결과: $success');
      print('[LoginScreen] isAuthenticated: ${authProvider.isAuthenticated}');
      print('[LoginScreen] errorMessage: ${authProvider.errorMessage}');

      if (success && mounted) {
        print('[LoginScreen] 로그인 성공, MainLayout으로 이동');
        // Flutter 웹에서 Consumer 리빌드가 즉시 반영되지 않을 수 있으므로
        // 명시적으로 화면을 전환합니다
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MainLayout()),
        );
      } else if (mounted) {
        print('[LoginScreen] 로그인 실패, 에러 메시지 표시: ${authProvider.errorMessage}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(authProvider.errorMessage ?? '로그인에 실패했습니다.'),
            backgroundColor: Colors.red.withOpacity(0.8),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else {
      print('[LoginScreen] 폼 검증 실패');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Consumer를 제거하고 Provider.of만 사용
    // AuthWrapper가 상태 변경을 감지하여 화면을 전환합니다
    final authProvider = Provider.of<AuthProvider>(context);
    return _buildLoginUI(context, authProvider);
  }

  Widget _buildLoginUI(BuildContext context, AuthProvider authProvider) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Column(
        children: [
          // 커스텀 타이틀바
          AppTitleBar(
            backgroundColor: Colors.transparent,
            extraHeight: 8,
          ),
          // 메인 컨텐츠
          Expanded(
            child: Container(
              // 다크 테마일 때는 단색 배경, 라이트 테마일 때는 그라데이션
              decoration: BoxDecoration(
                color: colorScheme.brightness == Brightness.dark
                    ? colorScheme.background  // 다크 테마: 단색 배경
                    : null,  // 라이트 테마: 그라데이션 사용
                gradient: colorScheme.brightness == Brightness.dark
                    ? null  // 다크 테마: 그라데이션 없음
                    : LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white,                                    // 순수 흰색
                          const Color(0xFFF8F9FA),                        // 매우 밝은 회색
                          colorScheme.primaryContainer.withOpacity(0.3),  // 포인트 색상 (아주 약하게)
                        ],
                      ),
              ),
              child: SafeArea(
                child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 40),
                    
                    // 앱 로고/제목 - 구분 없이 배경과 통합
                    Column(
                      children: [
                        Image.asset(
                          'dora.png',
                          height: 120,
                          width: 120,
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'DORA',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 42,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.brightness == Brightness.dark
                                ? Colors.white
                                : colorScheme.onSurface,
                            letterSpacing: 3,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '프로젝트 관리 시스템',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            color: colorScheme.brightness == Brightness.dark
                                ? Colors.white.withOpacity(0.8)
                                : colorScheme.onSurface.withOpacity(0.7),
                            fontWeight: FontWeight.w300,
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 60),

                    // 사용자 이름 입력
                    GlassTextField(
                      controller: _usernameController,
                      labelText: '사용자 이름',
                      prefixIcon: const Icon(Icons.person_outline),
                      onFieldSubmitted: (_) {
                        // 사용자 이름 입력 후 엔터 시 비밀번호 필드로 포커스 이동
                        FocusScope.of(context).nextFocus();
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return '사용자 이름을 입력하세요';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    // 비밀번호 입력
                    GlassTextField(
                      controller: _passwordController,
                      labelText: '비밀번호',
                      obscureText: _obscurePassword,
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                      onFieldSubmitted: (_) {
                        // 비밀번호 입력 후 엔터 시 로그인 실행
                        _handleLogin();
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return '비밀번호를 입력하세요';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 32),

                    // 로그인 버튼 - Material Design 색상
                    GlassButton(
                      text: '로그인',
                      onPressed: authProvider.isLoading ? null : _handleLogin,
                      isLoading: authProvider.isLoading,
                      gradientColors: [
                        colorScheme.primary.withOpacity(0.5),  // 포인트 색상 강조
                        colorScheme.primary.withOpacity(0.4),  // 포인트 색상 강조
                      ],
                    ),
                    const SizedBox(height: 20),

                    // 회원가입 링크
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const RegisterScreen(),
                          ),
                        );
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text(
                        '계정이 없으신가요? 회원가입',
                        style: TextStyle(
                          color: colorScheme.brightness == Brightness.dark
                              ? Colors.white.withOpacity(0.8)
                              : colorScheme.onSurface.withOpacity(0.7),
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          decoration: TextDecoration.underline,
                          decorationColor: colorScheme.primary.withOpacity(0.5),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
