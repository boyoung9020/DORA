import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/app_title_bar.dart';
import 'register_screen.dart';
import 'main_layout.dart';

/// 로그인 화면 - Clean Indigo 테마
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _rememberMe = false;

  late AnimationController _bgController;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late AnimationController _logoController;
  late Animation<double> _logoAnimation;

  // 마우스 인터랙션
  Offset _mousePosition = Offset.zero;
  Offset _smoothMouse = Offset.zero;
  bool _isHovering = false;

  @override
  void initState() {
    super.initState();
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    // logo.json: 192프레임 @ 48fps ≈ 4초 → 2초로 재생, easeInOut으로 보간 부드럽게
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
    // 선형 보간으로 처음~끝 일정 속도 재생 (easeInOut은 시작/끝이 느려져 끊겨 보임)
    _logoAnimation = CurvedAnimation(
      parent: _logoController,
      curve: Curves.linear,
    );

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _fadeController.forward();

    _bgController.addListener(_onTick);
  }

  void _onTick() {
    setState(() {
      _smoothMouse = Offset(
        _smoothMouse.dx + (_mousePosition.dx - _smoothMouse.dx) * 0.05,
        _smoothMouse.dy + (_mousePosition.dy - _smoothMouse.dy) * 0.05,
      );
    });
  }

  @override
  void dispose() {
    _bgController.removeListener(_onTick);
    _usernameController.dispose();
    _passwordController.dispose();
    _bgController.dispose();
    _fadeController.dispose();
    _logoController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      authProvider.clearError();

      final success = await authProvider.login(
        _usernameController.text.trim(),
        _passwordController.text,
      );

      if (success && mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MainLayout()),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(authProvider.errorMessage ?? '로그인에 실패했습니다.'),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Column(
        children: [
          AppTitleBar(
            backgroundColor: Colors.transparent,
            extraHeight: 8,
          ),
          Expanded(
            child: MouseRegion(
              onEnter: (_) => setState(() => _isHovering = true),
              onExit: (_) => setState(() => _isHovering = false),
              onHover: (e) => _mousePosition = e.localPosition,
              child: AnimatedBuilder(
                animation: _bgController,
                builder: (context, _) {
                  final t = _bgController.value;

                  return Stack(
                    children: [
                      // 인디고/블루 그라데이션 배경
                      _buildBackground(t, size),

                      // 센터 로그인 카드
                      Center(
                        child: FadeTransition(
                          opacity: _fadeAnimation,
                          child: _buildLoginCard(authProvider),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 인디고/블루/시안 파스텔 그라데이션 배경 (루프 시 끊김 없도록 주기 함수 사용)
  Widget _buildBackground(double t, Size size) {
    final nx = size.width > 0
        ? (_smoothMouse.dx / size.width) * 2 - 1
        : 0.0;
    final ny = size.height > 0
        ? (_smoothMouse.dy / size.height) * 2 - 1
        : 0.0;

    final gx = _isHovering ? nx * 0.15 : 0.0;
    final gy = _isHovering ? ny * 0.15 : 0.0;

    // t=0과 t=1에서 같은 값이 되도록 sin(2πt) 사용 → 루프 끊김 제거
    final tau = t * math.pi * 2;
    final sx = math.sin(tau);
    final cx = math.cos(tau);

    return Stack(
      children: [
        // 메인 그라데이션 (주기적: begin/end/stops가 한 주기 끝에서 처음과 동일)
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment(-1.0 + sx * 0.4 + gx, -1.0 + cx * 0.3 + gy),
                end: Alignment(1.0 - cx * 0.3 + gx, 1.0 - sx * 0.4 + gy),
                colors: const [
                  Color(0xFFDBEAFE), // Blue 100
                  Color(0xFFE0E7FF), // Indigo 100
                  Color(0xFFCFFAFE), // Cyan 100
                  Color(0xFFC7D2FE), // Indigo 200
                ],
                stops: [
                  0.0,
                  0.3 + sx * 0.05 + 0.05,
                  0.6 + cx * 0.025 + 0.025,
                  1.0,
                ],
              ),
            ),
          ),
        ),

        // 소프트 블롭 1 - 인디고 (sin/cos는 이미 주기적)
        _buildSoftBlob(
          centerX: size.width * 0.2 + sx * 40 + nx * 20,
          centerY: size.height * 0.3 + math.cos(tau * 0.7) * 30 + ny * 15,
          radius: 250,
          color: const Color(0xFF818CF8).withValues(alpha: 0.3),
        ),

        // 소프트 블롭 2 - 시안
        _buildSoftBlob(
          centerX: size.width * 0.75 + math.cos(tau * 0.8) * 35 + nx * 25,
          centerY: size.height * 0.6 + math.sin(tau * 0.6) * 40 + ny * 20,
          radius: 280,
          color: const Color(0xFF22D3EE).withValues(alpha: 0.25),
        ),

        // 소프트 블롭 3 - 블루
        _buildSoftBlob(
          centerX: size.width * 0.5 + math.sin(tau * 1.2) * 30 + nx * 15,
          centerY: size.height * 0.15 + math.cos(tau * 0.5) * 25 + ny * 10,
          radius: 200,
          color: const Color(0xFF6366F1).withValues(alpha: 0.2),
        ),

        // 블러 레이어
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
            child: Container(color: Colors.transparent),
          ),
        ),
      ],
    );
  }

  /// 소프트 블롭
  Widget _buildSoftBlob({
    required double centerX,
    required double centerY,
    required double radius,
    required Color color,
  }) {
    return Positioned(
      left: centerX - radius,
      top: centerY - radius,
      child: Container(
        width: radius * 2,
        height: radius * 2,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
        ),
      ),
    );
  }

  /// 센터 로그인 카드
  Widget _buildLoginCard(AuthProvider authProvider) {
    return SingleChildScrollView(
      child: Container(
        width: 420,
        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 44),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4F46E5).withValues(alpha: 0.07),
              blurRadius: 60,
              spreadRadius: 10,
              offset: const Offset(0, 20),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.7),
            width: 1.5,
          ),
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 앱 로고 (Lottie)
              _buildLogo(),
              const SizedBox(height: 24),

              // Sign In
              const Text(
                'Sign In',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 32),

              // 사용자 이름
              _buildInputField(
                controller: _usernameController,
                hint: 'Username',
                icon: Icons.person_outline_rounded,
                onSubmitted: (_) => FocusScope.of(context).nextFocus(),
                validator: (v) =>
                    v == null || v.isEmpty ? '사용자 이름을 입력하세요' : null,
              ),
              const SizedBox(height: 14),

              // 비밀번호
              _buildInputField(
                controller: _passwordController,
                hint: 'Password',
                icon: Icons.lock_outline_rounded,
                obscureText: _obscurePassword,
                onSubmitted: (_) => _handleLogin(),
                suffix: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 18,
                    color: const Color(0xFF94A3B8),
                  ),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
                validator: (v) =>
                    v == null || v.isEmpty ? '비밀번호를 입력하세요' : null,
              ),
              const SizedBox(height: 16),

              // Remember me
              Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: Checkbox(
                      value: _rememberMe,
                      onChanged: (v) => setState(() => _rememberMe = v ?? false),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      side: const BorderSide(
                        color: Color(0xFFCBD5E1),
                        width: 1.5,
                      ),
                      activeColor: const Color(0xFF4F46E5),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Remember me',
                    style: TextStyle(
                      fontSize: 13,
                      color: const Color(0xFF64748B).withValues(alpha: 0.8),
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // 로그인 버튼
              _buildSignInButton(authProvider),
              const SizedBox(height: 28),

              // 회원가입 링크
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Need an account?  ',
                    style: TextStyle(
                      fontSize: 13,
                      color: const Color(0xFF64748B).withValues(alpha: 0.7),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const RegisterScreen(),
                        ),
                      );
                    },
                    child: const Text(
                      'Sign up',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF4338CA),
                        fontWeight: FontWeight.w600,
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

  /// 앱 로고 (logo.json Lottie) - 테마 색상 적용, 2배속 재생
  Widget _buildLogo() {
    const double logoHeight = 100;
    const double logoWidth = 64; // 470/744 비율
    final themeColor = Theme.of(context).colorScheme.primary;

    return SizedBox(
      width: logoWidth,
      height: logoHeight,
      child: ColorFiltered(
        colorFilter: ColorFilter.mode(themeColor, BlendMode.srcIn),
        child: Lottie.asset(
          'logo.json',
          fit: BoxFit.contain,
          controller: _logoAnimation,
        ),
      ),
    );
  }

  /// 입력 필드
  Widget _buildInputField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscureText = false,
    Widget? suffix,
    String? Function(String?)? validator,
    void Function(String)? onSubmitted,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      onFieldSubmitted: onSubmitted,
      validator: validator,
      style: const TextStyle(
        color: Color(0xFF0F172A),
        fontSize: 14,
        fontWeight: FontWeight.w400,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(
          color: Color(0xFF94A3B8),
          fontWeight: FontWeight.w400,
          fontSize: 14,
        ),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 14, right: 10),
          child: Icon(
            icon,
            size: 18,
            color: const Color(0xFF94A3B8),
          ),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 42),
        suffixIcon: suffix,
        filled: true,
        fillColor: const Color(0xFFF1F5F9),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: Color(0xFFE2E8F0),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: Color(0xFFE2E8F0),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: Color(0xFF818CF8),
            width: 1.5,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: Color(0xFFDC2626),
            width: 1,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: Color(0xFFDC2626),
            width: 1.5,
          ),
        ),
        errorStyle: const TextStyle(
          color: Color(0xFFDC2626),
          fontSize: 12,
        ),
      ),
    );
  }

  /// 로그인 버튼
  Widget _buildSignInButton(AuthProvider authProvider) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: authProvider.isLoading ? null : _handleLogin,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF4F46E5),
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFF4F46E5).withValues(alpha: 0.5),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: authProvider.isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Text(
                'Sign In',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
      ),
    );
  }
}
