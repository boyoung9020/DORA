import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../widgets/app_title_bar.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  static const String _heroImageAsset = 'assets/main_logo2.png';

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
    if (!_formKey.currentState!.validate()) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    final success = await authProvider.register(
      username: _usernameController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );

    if (success && mounted) {
      await showDialog<void>(
        context: context,
        builder: (context) {
          final colorScheme = Theme.of(context).colorScheme;
          return AlertDialog(
            title: const Text('회원가입 완료'),
            content: const Text('회원가입이 완료되었습니다.\n바로 로그인하세요!'),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  '확인',
                  style: TextStyle(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          );
        },
      );
      if (mounted) Navigator.of(context).pop();
      return;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authProvider.errorMessage ?? '회원가입에 실패했습니다.'),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      body: Column(
        children: [
          const AppTitleBar(
            backgroundColor: Colors.transparent,
            extraHeight: 8,
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth >= 1000) {
                  return _buildDesktopLayout(authProvider);
                }
                return _buildMobileLayout(authProvider);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout(AuthProvider authProvider) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFD9BD), Color(0xFFFFC999), Color(0xFFFFBF88)],
        ),
      ),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1220, maxHeight: 720),
          margin: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFAF3),
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.13),
                blurRadius: 45,
                offset: const Offset(0, 20),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: Row(
              children: [
                Expanded(flex: 12, child: _buildHeroPanel()),
                Container(width: 1, color: const Color(0xFFEED7BF)),
                Expanded(
                  flex: 9,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 470),
                      child: _buildFormCard(authProvider, isDesktop: true),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileLayout(AuthProvider authProvider) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFD9BD), Color(0xFFFFC999)],
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(14),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFFFFFAF3),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 30,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                child: SizedBox(
                  height: 220,
                  width: double.infinity,
                  child: _buildHeroPanel(),
                ),
              ),
              _buildFormCard(authProvider, isDesktop: false),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroPanel() {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          _heroImageAsset,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              color: const Color(0xFFF3DECA),
              alignment: Alignment.center,
              child: const Text(
                'assets/main_logo2.png',
                style: TextStyle(
                  color: Color(0xFF7C5A3B),
                  fontWeight: FontWeight.w700,
                ),
              ),
            );
          },
        ),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.black.withValues(alpha: 0.26),
              ],
            ),
          ),
        ),
        const Positioned(
          left: 26,
          bottom: 24,
          right: 26,
          child: Text(
            'JOIN Sync\n팀 협업을 시작해보세요',
            style: TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w800,
              height: 1.2,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFormCard(AuthProvider authProvider, {required bool isDesktop}) {
    final titleSize = isDesktop ? 36.0 : 31.0;
    final padding = isDesktop
        ? const EdgeInsets.fromLTRB(36, 36, 36, 30)
        : const EdgeInsets.fromLTRB(22, 26, 22, 24);

    return Padding(
      padding: padding,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '회원가입',
              style: TextStyle(
                color: const Color(0xFFD86B27),
                fontSize: titleSize,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '새 계정을 만들고 워크스페이스에 참여하세요',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF7B5C42),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 24),
            _buildInputField(
              controller: _emailController,
              label: '이메일',
              hint: '이메일 입력',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value == null || value.isEmpty) return '이메일을 입력하세요';
                if (!value.contains('@')) return '올바른 이메일 형식이 아닙니다';
                return null;
              },
            ),
            const SizedBox(height: 14),
            _buildInputField(
              controller: _usernameController,
              label: '사용자 이름',
              hint: '이름 또는 아이디 입력',
              icon: Icons.person_outline,
              validator: (value) {
                if (value == null || value.isEmpty) return '사용자 이름을 입력하세요';
                if (value.length < 3) return '사용자 이름은 3자 이상이어야 합니다';
                return null;
              },
            ),
            const SizedBox(height: 14),
            _buildInputField(
              controller: _passwordController,
              label: '비밀번호',
              hint: '비밀번호 입력',
              icon: Icons.lock_outline,
              obscureText: _obscurePassword,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) return '비밀번호를 입력하세요';
                if (value.length < 6) return '비밀번호는 6자 이상이어야 합니다';
                return null;
              },
            ),
            const SizedBox(height: 14),
            _buildInputField(
              controller: _confirmPasswordController,
              label: '비밀번호 확인',
              hint: '비밀번호 다시 입력',
              icon: Icons.lock_outline,
              obscureText: _obscureConfirmPassword,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirmPassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
                onPressed: () => setState(
                  () => _obscureConfirmPassword = !_obscureConfirmPassword,
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) return '비밀번호 확인을 입력하세요';
                if (value != _passwordController.text) return '비밀번호가 일치하지 않습니다';
                return null;
              },
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  gradient: const LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [Color(0xFFE3833D), Color(0xFFD86B27)],
                  ),
                ),
                child: ElevatedButton(
                  onPressed: authProvider.isLoading ? null : _handleRegister,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  child: authProvider.isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.1,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          '회원가입',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  '이미 계정이 있으신가요? 로그인',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF7B5C42),
                    decoration: TextDecoration.underline,
                    decorationColor: Color(0xFFD2A27C),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF8A6647),
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          validator: validator,
          style: const TextStyle(
            color: Color(0xFF322212),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
              color: Color(0xFFC1A58A),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            prefixIcon: Icon(icon, color: const Color(0xFFC09A78), size: 19),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: const Color(0xFFFFFDFC),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                color: Color(0xFFE4C8AD),
                width: 1,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                color: Color(0xFFE4C8AD),
                width: 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                color: Color(0xFFD86B27),
                width: 1.6,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                color: Color(0xFFDC2626),
                width: 1,
              ),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
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
        ),
      ],
    );
  }
}
