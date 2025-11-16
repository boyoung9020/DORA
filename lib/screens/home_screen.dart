import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/glass_container.dart';
import 'login_screen.dart';
import 'admin_approval_screen.dart';
import 'kanban_screen.dart';

/// 홈 화면 - Liquid Glass 디자인
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.currentUser;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
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
          child: Column(
            children: [
              // AppBar
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: GlassContainer(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  borderRadius: 20.0,
                  blur: 25.0,  // 더 강한 블러
                  gradientColors: [
                    colorScheme.surface.withOpacity(0.3),  // Material surface
                    colorScheme.surface.withOpacity(0.2),  // Material surface
                  ],
                  child: Row(
                    children: [
                      Text(
                        'DORA',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                          letterSpacing: 2,
                        ),
                      ),
                      const Spacer(),
                      if (authProvider.isAdmin)
                        IconButton(
                          icon: Icon(Icons.admin_panel_settings, color: colorScheme.onSurface),
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const AdminApprovalScreen(),
                              ),
                            );
                          },
                          tooltip: '회원가입 승인 관리',
                        ),
                      IconButton(
                        icon: Icon(Icons.logout, color: colorScheme.onSurface),
                        onPressed: () async {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            barrierColor: Colors.black.withOpacity(0.2),  // 더 밝은 배경
                            builder: (context) {
                              final dialogColorScheme = Theme.of(context).colorScheme;
                              return Dialog(
                                backgroundColor: Colors.transparent,
                                elevation: 0,
                                child: GlassContainer(
                                  padding: const EdgeInsets.all(0),
                                  borderRadius: 24.0,
                                  blur: 25.0,
                                  gradientColors: [
                                    dialogColorScheme.surface.withOpacity(0.6),  // 더 밝게
                                    dialogColorScheme.surface.withOpacity(0.5),  // 더 밝게
                                  ],
                                  child: Padding(
                                    padding: const EdgeInsets.all(24.0),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // 제목
                                        Text(
                                          '로그아웃',
                                          style: TextStyle(
                                            fontSize: 24,
                                            fontWeight: FontWeight.bold,
                                            color: dialogColorScheme.onSurface,
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        // 내용
                                        Text(
                                          '로그아웃하시겠습니까?',
                                          style: TextStyle(
                                            fontSize: 16,
                                            color: dialogColorScheme.onSurface.withOpacity(0.8),
                                          ),
                                        ),
                                        const SizedBox(height: 24),
                                        // 버튼들
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.end,
                                          children: [
                                            TextButton(
                                              onPressed: () => Navigator.of(context).pop(false),
                                              child: Text(
                                                '취소',
                                                style: TextStyle(
                                                  color: dialogColorScheme.onSurface.withOpacity(0.7),
                                                  fontSize: 16,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            TextButton(
                                              onPressed: () => Navigator.of(context).pop(true),
                                              style: TextButton.styleFrom(
                                                backgroundColor: dialogColorScheme.primary.withOpacity(0.2),
                                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                              ),
                                              child: Text(
                                                '로그아웃',
                                                style: TextStyle(
                                                  color: dialogColorScheme.primary,
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
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

                          if (confirmed == true && context.mounted) {
                            await authProvider.logout();
                            if (context.mounted) {
                              Navigator.of(context).pushReplacement(
                                MaterialPageRoute(builder: (_) => const LoginScreen()),
                              );
                            }
                          }
                        },
                        tooltip: '로그아웃',
                      ),
                    ],
                  ),
                ),
              ),

              // 메인 컨텐츠
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // 환영 메시지 카드
                        GlassContainer(
                          padding: const EdgeInsets.all(40),
                          borderRadius: 30.0,
                          blur: 25.0,  // 더 강한 블러
                          gradientColors: [
                            colorScheme.surface.withOpacity(0.3),  // Material surface
                            colorScheme.surface.withOpacity(0.2),  // Material surface
                          ],
                          child: Column(
                            children: [
                              Image.asset(
                                'dora.png',
                                height: 150,
                                width: 150,
                                fit: BoxFit.contain,
                              ),
                              const SizedBox(height: 24),
                              Text(
                                '환영합니다, ${user?.username ?? '사용자'}님!',
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.onSurface,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                user?.email ?? '',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: colorScheme.onSurface.withOpacity(0.7),
                                ),
                              ),
                              const SizedBox(height: 32),
                              if (authProvider.isAdmin)
                                GlassContainer(
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                  borderRadius: 15.0,
                                  blur: 20.0,  // 더 강한 블러
                                  gradientColors: [
                                    colorScheme.primary.withOpacity(0.5),  // 포인트 색상 강조
                                    colorScheme.primary.withOpacity(0.4),  // 포인트 색상 강조
                                  ],
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.admin_panel_settings, color: colorScheme.onPrimary, size: 20),
                                      const SizedBox(width: 8),
                                      Text(
                                        '관리자 계정',
                                        style: TextStyle(
                                          color: colorScheme.onPrimary,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 40),
                        // 칸반 보드 버튼
                        GlassButton(
                          text: '칸반 보드 열기',
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const KanbanScreen(),
                              ),
                            );
                          },
                          gradientColors: [
                            colorScheme.primary.withOpacity(0.5),
                            colorScheme.primary.withOpacity(0.4),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
