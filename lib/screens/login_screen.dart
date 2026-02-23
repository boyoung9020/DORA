import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../widgets/app_title_bar.dart';
import '../widgets/social_login_button.dart';
import 'main_layout.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const String _heroImageAsset = 'assets/main_logo2.png';
  static const String _brandLogoAsset = 'assets/app_logo_resize.png';

  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _rememberMe = false;
  bool _isSocialLoading = false;

  @override
  void initState() {
    super.initState();
    // Show any error left over from a web social redirect (e.g. user not found).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(authProvider.errorMessage!),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
        authProvider.clearError();
      }
    });
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    authProvider.clearError();

    final success = await authProvider.login(
      _usernameController.text.trim(),
      _passwordController.text,
    );

    if (success && mounted) {
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const MainLayout()));
      return;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            authProvider.errorMessage ??
                '\uB85C\uADF8\uC778\uC5D0 \uC2E4\uD328\uD588\uC2B5\uB2C8\uB2E4.',
          ),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  void _showSocialAuthDialog(String provider) {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (ctx) => PopScope(
        canPop: false,
        child: Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 40),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFAF2),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.14),
                  blurRadius: 40,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 44,
                  height: 44,
                  child: CircularProgressIndicator(
                    color: Color(0xFFD86B27),
                    strokeWidth: 3.5,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  '$provider \uB85C\uADF8\uC778 \uC911...',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF3C2A1A),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '\uC778\uC99D \uD398\uC774\uC9C0\uB85C \uC774\uB3D9\uD569\uB2C8\uB2E4',
                  style: TextStyle(fontSize: 13, color: Color(0xFF7B5C42)),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleGoogleLogin() async {
    if (_isSocialLoading) return;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    authProvider.clearError();

    setState(() => _isSocialLoading = true);
    _showSocialAuthDialog('Google');

    final success = await authProvider.loginWithGoogle();
    if (!mounted) return;
    Navigator.of(context).pop(); // ???繹먮굟瑗????Β??????????
    setState(() => _isSocialLoading = false);

    if (success) {
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const MainLayout()));
      return;
    }

    // errorMessage == null means user cancelled the popup ??show nothing
    if (authProvider.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authProvider.errorMessage!),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  Future<void> _handleKakaoLogin() async {
    if (_isSocialLoading) return;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    authProvider.clearError();

    setState(() => _isSocialLoading = true);
    _showSocialAuthDialog('\uCE74\uCE74\uC624');

    final success = await authProvider.loginWithKakao();
    if (!mounted) return;
    Navigator.of(context).pop(); // ???繹먮굟瑗????Β??????????
    setState(() => _isSocialLoading = false);

    if (success) {
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const MainLayout()));
      return;
    }

    if (authProvider.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authProvider.errorMessage!),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
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
          if (!kIsWeb)
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
          colors: [Color(0xFFFFD6B4), Color(0xFFFFC892), Color(0xFFFFBA7C)],
        ),
      ),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1220, maxHeight: 720),
          margin: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFAF2),
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 45,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: Row(
              children: [
                Expanded(flex: 12, child: _buildImagePanel()),
                Container(width: 1, color: const Color(0xFFEEDCC8)),
                Expanded(flex: 9, child: _buildFormPanel(authProvider)),
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
          colors: [Color(0xFFFFD7B5), Color(0xFFFFC796)],
        ),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFFFFAF2),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 32,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                  child: SizedBox(
                    height: 250,
                    width: double.infinity,
                    child: _buildImagePanel(),
                  ),
                ),
                _buildFormPanel(authProvider),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImagePanel() {
    return SizedBox.expand(
      child: Image.asset(
        _heroImageAsset,
        fit: BoxFit.cover,
        alignment: Alignment.center,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: const Color(0xFFF3DECA),
            alignment: Alignment.center,
            child: const Text(
              'assets/app_logo.png',
              style: TextStyle(
                color: Color(0xFF7C5A3B),
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFormPanel(AuthProvider authProvider) {
    return Container(
      color: const Color(0xFFFFFAF2),
      padding: const EdgeInsets.fromLTRB(34, 6, 34, 30),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 112,
                  height: 56,
                  child: Image.asset(
                    _brandLogoAsset,
                    fit: BoxFit.contain,
                    alignment: Alignment.center,
                    filterQuality: FilterQuality.high,
                    errorBuilder: (context, error, stackTrace) {
                      return Image.asset(
                        'assets/app_logo.png',
                        fit: BoxFit.contain,
                        alignment: Alignment.center,
                        filterQuality: FilterQuality.high,
                        errorBuilder: (context, error, stackTrace) {
                          return const Align(
                            alignment: Alignment.center,
                            child: Text(
                              'Sync',
                              style: TextStyle(
                                color: Color(0xFFD86B27),
                                fontSize: 30,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.8,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 64),
            const Text(
              '\uC6CC\uD06C\uC2A4\uD398\uC774\uC2A4\uC5D0 \uB85C\uADF8\uC778\uD558\uC138\uC694',
              style: TextStyle(
                color: Color(0xFF7B5C42),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 26),
            const Text(
              'EMAIL',
              style: TextStyle(
                color: Color(0xFF8A6647),
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 8),
            _buildInputField(
              controller: _usernameController,
              hint: '\uC774\uBA54\uC77C \uC785\uB825',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              onSubmitted: (_) => FocusScope.of(context).nextFocus(),
              validator: (v) => v == null || v.isEmpty
                  ? '\uC774\uBA54\uC77C\uC744 \uC785\uB825\uD558\uC138\uC694'
                  : null,
            ),
            const SizedBox(height: 16),
            const Text(
              'PASSWORD',
              style: TextStyle(
                color: Color(0xFF8A6647),
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 8),
            _buildInputField(
              controller: _passwordController,
              hint: '\uBE44\uBC00\uBC88\uD638 \uC785\uB825',
              icon: Icons.lock_outline_rounded,
              obscureText: _obscurePassword,
              onSubmitted: (_) => _handleLogin(),
              suffix: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: 19,
                  color: const Color(0xFFB89C83),
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
              validator: (v) => v == null || v.isEmpty
                  ? '\uBE44\uBC00\uBC88\uD638\uB97C \uC785\uB825\uD558\uC138\uC694'
                  : null,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: Checkbox(
                    value: _rememberMe,
                    onChanged: (v) => setState(() => _rememberMe = v ?? false),
                    side: const BorderSide(
                      color: Color(0xFFD6B796),
                      width: 1.3,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                    activeColor: const Color(0xFFD86B27),
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  '\uB85C\uADF8\uC778 \uC0C1\uD0DC \uC720\uC9C0',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Color(0xFF86654A),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () {},
                  style: TextButton.styleFrom(
                    minimumSize: Size.zero,
                    padding: EdgeInsets.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    '\uBE44\uBC00\uBC88\uD638 \uCC3E\uAE30',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: Color(0xFF2C9271),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _buildSignInButton(authProvider),
            const SizedBox(height: 18),
            _buildSocialLoginButtons(authProvider),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  '\uACC4\uC815\uC774 \uC5C6\uC73C\uC2E0\uAC00\uC694? ',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF6F5640),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      PageRouteBuilder(
                        pageBuilder: (_, __, ___) => const RegisterScreen(),
                        transitionDuration: Duration.zero,
                        reverseTransitionDuration: Duration.zero,
                      ),
                    );
                  },
                  style: TextButton.styleFrom(
                    minimumSize: Size.zero,
                    padding: EdgeInsets.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    '\uD68C\uC6D0\uAC00\uC785',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF2C9271),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSocialLoginButtons(AuthProvider authProvider) {
    final disabled = _isSocialLoading || authProvider.isLoading;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: const [
            Expanded(child: Divider(color: Color(0xFFE4C8AD))),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                '\uB610\uB294',
                style: TextStyle(
                  color: Color(0xFF8A6647),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Expanded(child: Divider(color: Color(0xFFE4C8AD))),
          ],
        ),
        const SizedBox(height: 12),
        SocialLoginButton(
          provider: SocialProvider.google,
          label: disabled ? '\uB85C\uADF8\uC778 \uC911...' : 'Google\uB85C \uACC4\uC18D\uD558\uAE30',
          onPressed: disabled ? null : _handleGoogleLogin,
        ),
        const SizedBox(height: 8),
        SocialLoginButton(
          provider: SocialProvider.kakao,
          label: disabled ? '\uB85C\uADF8\uC778 \uC911...' : '\uCE74\uCE74\uC624\uB85C \uACC4\uC18D\uD558\uAE30',
          onPressed: disabled ? null : _handleKakaoLogin,
        ),
      ],
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscureText = false,
    TextInputType? keyboardType,
    Widget? suffix,
    String? Function(String?)? validator,
    void Function(String)? onSubmitted,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      onFieldSubmitted: onSubmitted,
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
          fontWeight: FontWeight.w500,
          fontSize: 14,
        ),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 14, right: 10),
          child: Icon(icon, size: 18, color: const Color(0xFFC09A78)),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 42),
        suffixIcon: suffix,
        filled: true,
        fillColor: const Color(0xFFFFFDFC),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 13,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE4C8AD), width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE4C8AD), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFD86B27), width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1.5),
        ),
        errorStyle: const TextStyle(color: Color(0xFFDC2626), fontSize: 12),
      ),
    );
  }

  Widget _buildSignInButton(AuthProvider authProvider) {
    return SizedBox(
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
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFD86B27).withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: authProvider.isLoading ? null : _handleLogin,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            shadowColor: Colors.transparent,
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
                  'Login',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.35,
                  ),
                ),
        ),
      ),
    );
  }
}
