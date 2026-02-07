import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
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

  /// 인디고/블루/시안 파스텔 그라데이션 배경
  Widget _buildBackground(double t, Size size) {
    final nx = size.width > 0
        ? (_smoothMouse.dx / size.width) * 2 - 1
        : 0.0;
    final ny = size.height > 0
        ? (_smoothMouse.dy / size.height) * 2 - 1
        : 0.0;

    final gx = _isHovering ? nx * 0.15 : 0.0;
    final gy = _isHovering ? ny * 0.15 : 0.0;

    return Stack(
      children: [
        // 메인 그라데이션
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment(-1.0 + t * 0.4 + gx, -1.0 + t * 0.3 + gy),
                end: Alignment(1.0 - t * 0.3 + gx, 1.0 - t * 0.4 + gy),
                colors: const [
                  Color(0xFFDBEAFE), // Blue 100
                  Color(0xFFE0E7FF), // Indigo 100
                  Color(0xFFCFFAFE), // Cyan 100
                  Color(0xFFC7D2FE), // Indigo 200
                ],
                stops: [
                  0.0,
                  0.3 + t * 0.1,
                  0.6 + t * 0.05,
                  1.0,
                ],
              ),
            ),
          ),
        ),

        // 소프트 블롭 1 - 인디고
        _buildSoftBlob(
          centerX: size.width * 0.2 + math.sin(t * math.pi * 2) * 40 + nx * 20,
          centerY: size.height * 0.3 + math.cos(t * math.pi * 2 * 0.7) * 30 + ny * 15,
          radius: 250,
          color: const Color(0xFF818CF8).withValues(alpha: 0.3),
        ),

        // 소프트 블롭 2 - 시안
        _buildSoftBlob(
          centerX: size.width * 0.75 + math.cos(t * math.pi * 2 * 0.8) * 35 + nx * 25,
          centerY: size.height * 0.6 + math.sin(t * math.pi * 2 * 0.6) * 40 + ny * 20,
          radius: 280,
          color: const Color(0xFF22D3EE).withValues(alpha: 0.25),
        ),

        // 소프트 블롭 3 - 블루
        _buildSoftBlob(
          centerX: size.width * 0.5 + math.sin(t * math.pi * 2 * 1.2) * 30 + nx * 15,
          centerY: size.height * 0.15 + math.cos(t * math.pi * 2 * 0.5) * 25 + ny * 10,
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
              // 홀로그래픽 오브
              _buildHolographicOrb(),
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

  /// 홀로그래픽 오브 - 인디고/시안 색 흐름
  Widget _buildHolographicOrb() {
    final t = _bgController.value;
    const double orbSize = 88;

    final slow = t * math.pi * 2;
    final mid = t * math.pi * 2 * 1.7;
    final fast = t * math.pi * 2 * 2.5;

    return SizedBox(
      width: orbSize,
      height: orbSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 외부 글로우
          Container(
            width: orbSize + 16 + math.sin(fast) * 8,
            height: orbSize + 16 + math.sin(fast) * 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Color.lerp(
                    const Color(0xFF818CF8),
                    const Color(0xFF22D3EE),
                    (math.sin(mid) + 1) / 2,
                  )!.withValues(alpha: 0.3),
                  Colors.transparent,
                ],
              ),
            ),
          ),

          // 레이어 1 - 베이스 회전
          ClipOval(
            child: Container(
              width: orbSize,
              height: orbSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: SweepGradient(
                  startAngle: slow,
                  colors: const [
                    Color(0xFFC7D2FE), // Indigo 200
                    Color(0xFFA5B4FC), // Indigo 300
                    Color(0xFFBAE6FD), // Sky 200
                    Color(0xFFA7F3D0), // Emerald 200
                    Color(0xFFDBEAFE), // Blue 100
                    Color(0xFFC7D2FE), // Indigo 200
                  ],
                ),
              ),
            ),
          ),

          // 레이어 2 - 역방향 빠른 회전
          ClipOval(
            child: Container(
              width: orbSize,
              height: orbSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: SweepGradient(
                  startAngle: -mid + math.pi * 0.7,
                  colors: [
                    const Color(0xFF6366F1).withValues(alpha: 0.55),
                    const Color(0xFF06B6D4).withValues(alpha: 0.5),
                    const Color(0xFF818CF8).withValues(alpha: 0.5),
                    const Color(0xFF34D399).withValues(alpha: 0.35),
                    const Color(0xFF6366F1).withValues(alpha: 0.55),
                  ],
                ),
              ),
            ),
          ),

          // 레이어 3 - 빠르게 돌아다니는 하이라이트
          ClipOval(
            child: Container(
              width: orbSize,
              height: orbSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  center: Alignment(
                    math.sin(fast) * 0.5,
                    math.cos(fast * 0.8) * 0.5,
                  ),
                  radius: 0.6,
                  colors: [
                    Colors.white.withValues(alpha: 0.5),
                    Colors.white.withValues(alpha: 0.1),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.35, 1.0],
                ),
              ),
            ),
          ),

          // 레이어 4 - 두 번째 하이라이트 (다른 궤도)
          ClipOval(
            child: Container(
              width: orbSize,
              height: orbSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  center: Alignment(
                    math.cos(mid + 2) * 0.55,
                    math.sin(fast * 0.6 + 1) * 0.55,
                  ),
                  radius: 0.45,
                  colors: [
                    Color.lerp(
                      const Color(0xFFC7D2FE),
                      const Color(0xFFBAE6FD),
                      (math.sin(fast) + 1) / 2,
                    )!.withValues(alpha: 0.45),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // 글래스 반사광 (상단 좌측)
          Positioned(
            top: 10,
            left: 14,
            child: Container(
              width: 28,
              height: 18,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: 0.55),
                    Colors.white.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
        ],
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
