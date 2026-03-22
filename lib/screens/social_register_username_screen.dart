import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';

/// Shown after a web social OAuth redirect when mode='register'.
/// The user chooses their username before the account is created.
class SocialRegisterUsernameScreen extends StatefulWidget {
  const SocialRegisterUsernameScreen({super.key});

  @override
  State<SocialRegisterUsernameScreen> createState() =>
      _SocialRegisterUsernameScreenState();
}

class _SocialRegisterUsernameScreenState
    extends State<SocialRegisterUsernameScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  String _providerLabel(String? provider) {
    if (provider == 'kakao') return '카카오';
    return 'Google';
  }

  Future<void> _handleConfirm() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.completeSocialRegistration(
      _usernameController.text.trim(),
    );

    if (!mounted) return;

    if (!success && authProvider.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authProvider.errorMessage!),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  Future<void> _handleCancel() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.cancelSocialRegistration();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final provider = _providerLabel(authProvider.pendingSocialProvider);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFD6B4), Color(0xFFFFC892), Color(0xFFFFBA7C)],
          ),
        ),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 440),
            margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFAF2),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.13),
                  blurRadius: 40,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            padding: const EdgeInsets.fromLTRB(36, 40, 36, 36),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    '실명 입력',
                    style: TextStyle(
                      color: Color(0xFFD86B27),
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$provider 계정으로 회원가입을 완료합니다.\n팀원 식별을 위해 반드시 실명을 입력해주세요.',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF7B5C42),
                      fontWeight: FontWeight.w600,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    '이름 (실명)',
                    style: TextStyle(
                      color: Color(0xFF8A6647),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _usernameController,
                    autofocus: true,
                    style: const TextStyle(
                      color: Color(0xFF322212),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      hintText: '실명을 입력하세요 (예: 홍길동)',
                      hintStyle: const TextStyle(
                        color: Color(0xFFC1A58A),
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                      prefixIcon: const Padding(
                        padding: EdgeInsets.only(left: 14, right: 10),
                        child: Icon(
                          Icons.badge_outlined,
                          size: 18,
                          color: Color(0xFFC09A78),
                        ),
                      ),
                      prefixIconConstraints:
                          const BoxConstraints(minWidth: 42),
                      filled: true,
                      fillColor: const Color(0xFFFFFDFC),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 13,
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
                    onFieldSubmitted: (_) => _handleConfirm(),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return '실명을 입력하세요';
                      }
                      if (v.trim().length < 2) {
                        return '이름은 2자 이상이어야 합니다';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 46,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        gradient: const LinearGradient(
                          colors: [Color(0xFFE3833D), Color(0xFFD86B27)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color:
                                const Color(0xFFD86B27).withValues(alpha: 0.35),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: authProvider.isLoading
                            ? null
                            : _handleConfirm,
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
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : const Text(
                                '회원가입 완료',
                                style: TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed:
                        authProvider.isLoading ? null : _handleCancel,
                    child: const Text(
                      '취소',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF7B5C42),
                        fontWeight: FontWeight.w600,
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
