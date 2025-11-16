import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/glass_container.dart';

/// 대시보드 화면 - 홈 화면
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.currentUser;
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(24.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 환영 메시지
            Center(
              child: GlassContainer(
                padding: const EdgeInsets.all(40),
                borderRadius: 30.0,
                blur: 25.0,
                gradientColors: [
                  colorScheme.surface.withOpacity(0.3),
                  colorScheme.surface.withOpacity(0.2),
                ],
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                  Image.asset(
                    'dora.png',
                    height: 120,
                    width: 120,
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
                      blur: 20.0,
                      gradientColors: [
                        colorScheme.primary.withOpacity(0.5),
                        colorScheme.primary.withOpacity(0.4),
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
            ),
            const SizedBox(height: 40),
            // 안내 메시지
            Center(
              child: GlassContainer(
                padding: const EdgeInsets.all(20),
                borderRadius: 20.0,
                blur: 20.0,
                gradientColors: [
                  colorScheme.surface.withOpacity(0.25),
                  colorScheme.surface.withOpacity(0.18),
                ],
                child: Text(
                  '왼쪽 메뉴에서 원하는 기능을 선택하세요.',
                  style: TextStyle(
                    fontSize: 16,
                    color: colorScheme.onSurface.withOpacity(0.9),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

