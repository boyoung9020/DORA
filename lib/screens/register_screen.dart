import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/glass_container.dart';

/// 회원가입 화면 - Liquid Glass 디자인
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (_formKey.currentState!.validate()) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      
      final success = await authProvider.register(
        username: _usernameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (success && mounted) {
        showDialog(
          context: context,
          builder: (context) {
            final dialogColorScheme = Theme.of(context).colorScheme;
            return Dialog(
              backgroundColor: Colors.transparent,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: GlassContainer(
                  padding: const EdgeInsets.all(24),
                  borderRadius: 20.0,
                  blur: 25.0,
                  gradientColors: [
                    dialogColorScheme.surface.withOpacity(0.6),
                    dialogColorScheme.surface.withOpacity(0.5),
                  ],
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '회원가입 완료',
                        style: TextStyle(
                          color: dialogColorScheme.onSurface,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '회원가입이 완료되었습니다.\n관리자 승인 후 로그인할 수 있습니다.',
                        style: TextStyle(
                          color: dialogColorScheme.onSurface.withOpacity(0.8),
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                              Navigator.of(context).pop();
                            },
                            style: TextButton.styleFrom(
                              backgroundColor: dialogColorScheme.primary.withOpacity(0.2),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            ),
                            child: Text(
                              '확인',
                              style: TextStyle(
                                color: dialogColorScheme.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
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
          },
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(authProvider.errorMessage ?? '회원가입에 실패했습니다.'),
            backgroundColor: Colors.red.withOpacity(0.8),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Container(
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 24),
                  
                  // 제목
                  GlassContainer(
                    padding: const EdgeInsets.all(20),
                    borderRadius: 20.0,
                    blur: 25.0,  // 더 강한 블러
                    gradientColors: [
                      colorScheme.surface.withOpacity(0.3),  // Material surface
                      colorScheme.surface.withOpacity(0.2),  // Material surface
                    ],
                    child: Text(
                      '회원가입',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.brightness == Brightness.dark
                            ? Colors.white
                            : colorScheme.onSurface,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // 사용자 이름 입력
                  GlassTextField(
                    controller: _usernameController,
                    labelText: '사용자 이름',
                    prefixIcon: const Icon(Icons.person_outline),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '사용자 이름을 입력하세요';
                      }
                      if (value.length < 3) {
                        return '사용자 이름은 3자 이상이어야 합니다';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  // 이메일 입력
                  GlassTextField(
                    controller: _emailController,
                    labelText: '이메일',
                    keyboardType: TextInputType.emailAddress,
                    prefixIcon: const Icon(Icons.email_outlined),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '이메일을 입력하세요';
                      }
                      if (!value.contains('@')) {
                        return '올바른 이메일 형식이 아닙니다';
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
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '비밀번호를 입력하세요';
                      }
                      if (value.length < 6) {
                        return '비밀번호는 6자 이상이어야 합니다';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  // 비밀번호 확인
                  GlassTextField(
                    controller: _confirmPasswordController,
                    labelText: '비밀번호 확인',
                    obscureText: _obscureConfirmPassword,
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirmPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureConfirmPassword = !_obscureConfirmPassword;
                        });
                      },
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '비밀번호 확인을 입력하세요';
                      }
                      if (value != _passwordController.text) {
                        return '비밀번호가 일치하지 않습니다';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),

                  // 안내 메시지
                  GlassContainer(
                    padding: const EdgeInsets.all(16),
                    borderRadius: 15.0,
                    blur: 20.0,  // 더 강한 블러
                    gradientColors: [
                      colorScheme.primaryContainer.withOpacity(0.4),  // Material primary container
                      colorScheme.primaryContainer.withOpacity(0.3),  // Material primary container
                    ],
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: colorScheme.onPrimaryContainer, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '회원가입 후 관리자 승인이 필요합니다.',
                            style: TextStyle(
                              fontSize: 13,
                              color: colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 회원가입 버튼 - Material Design 색상
                  GlassButton(
                    text: '회원가입',
                    onPressed: authProvider.isLoading ? null : _handleRegister,
                    isLoading: authProvider.isLoading,
                    gradientColors: [
                      colorScheme.primary.withOpacity(0.5),  // 포인트 색상 강조
                      colorScheme.primary.withOpacity(0.4),  // 포인트 색상 강조
                    ],
                  ),
                  const SizedBox(height: 20),

                  // 로그인 링크
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                      child: Text(
                        '이미 계정이 있으신가요? 로그인',
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
    );
  }
}
