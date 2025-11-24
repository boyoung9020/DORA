import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'providers/auth_provider.dart';
import 'providers/task_provider.dart';
import 'providers/project_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/notification_provider.dart';
import 'screens/login_screen.dart';
import 'screens/main_layout.dart';

void main() {
  runApp(const MyApp());
  
  // Windows 타이틀바 커스터마이징
  doWhenWindowReady(() {
    const initialSize = Size(1200, 800);
    appWindow.minSize = const Size(800, 600);
    appWindow.size = initialSize;
    appWindow.alignment = Alignment.center;
    appWindow.title = 'DORA - 프로젝트 관리';
    appWindow.show();
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // ThemeProvider를 전역적으로 사용할 수 있도록 설정
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        // AuthProvider를 전역적으로 사용할 수 있도록 설정
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        // ProjectProvider를 전역적으로 사용할 수 있도록 설정
        ChangeNotifierProvider(create: (_) => ProjectProvider()),
        // TaskProvider를 전역적으로 사용할 수 있도록 설정
        ChangeNotifierProvider(create: (_) => TaskProvider()),
        // NotificationProvider를 전역적으로 사용할 수 있도록 설정
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            title: 'DORA - 프로젝트 관리',
            debugShowCheckedModeBanner: false,
            themeMode: themeProvider.themeMode,
            theme: ThemeData(
              fontFamily: 'NanumSquareRound',
              scaffoldBackgroundColor: Colors.white, // 전체 배경을 흰색으로 설정
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF2196F3), // 파란색 포인트 색상 (로고와 일치)
                brightness: Brightness.light,
              ).copyWith(
                // 순수 흰색 배경
                surface: Colors.white,
                background: Colors.white,
                surfaceContainerHighest: Colors.white,
                // 밝은 배경에 맞는 어두운 텍스트 색상
                onSurface: const Color(0xFF1F2937), // 어두운 회색
                onSurfaceVariant: const Color(0xFF6B7280), // 중간 회색
                // 파란색 포인트 색상 (로고와 일치)
                primary: const Color(0xFF2196F3), // Material Blue
                primaryContainer: const Color(0xFFE3F2FD), // 매우 밝은 파란색
                onPrimary: Colors.white, // 포인트 색상 위의 흰색 텍스트
                secondary: const Color(0xFF42A5F5), // 밝은 파란색
                secondaryContainer: const Color(0xFFE1F5FE), // 매우 밝은 파란색
              ),
              useMaterial3: true,
            ),
            darkTheme: ThemeData(
              fontFamily: 'NanumSquareRound',
              scaffoldBackgroundColor: const Color(0xFF1A1A1A), // 매우 어두운 회색 배경
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF2196F3),
                brightness: Brightness.dark,
              ).copyWith(
                // 다크 테마 배경 색상
                surface: const Color(0xFF1A1A1A),
                background: const Color(0xFF1A1A1A),
                surfaceContainerHighest: const Color(0xFF2A2A2A),
                // 다크 배경에 맞는 밝은 텍스트 색상
                onSurface: const Color(0xFFE5E5E5), // 밝은 회색
                onSurfaceVariant: const Color(0xFFB0B0B0), // 중간 회색
                // 파란색 포인트 색상 (다크 테마용)
                primary: const Color(0xFF64B5F6), // 밝은 파란색
                primaryContainer: const Color(0xFF1565C0), // 어두운 파란색
                onPrimary: Colors.white,
                secondary: const Color(0xFF90CAF9), // 매우 밝은 파란색
                secondaryContainer: const Color(0xFF0D47A1), // 어두운 파란색
              ),
              useMaterial3: true,
            ),
            // 초기 화면은 로그인 화면
            // 로그인 상태에 따라 자동으로 홈 화면으로 이동합니다
            home: const AuthWrapper(),
          );
        },
      ),
    );
  }
}

/// 인증 상태에 따라 화면을 전환하는 위젯
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        print('[AuthWrapper] 빌드 중 - isLoading: ${authProvider.isLoading}, isAuthenticated: ${authProvider.isAuthenticated}');
        // 로딩 중이면 빈 화면 표시
        if (authProvider.isLoading) {
          print('[AuthWrapper] 로딩 중');
          return const Scaffold(
            body: SizedBox.shrink(),
          );
        }

        // 로그인되어 있으면 메인 레이아웃, 아니면 로그인 화면
        final isAuthenticated = authProvider.isAuthenticated;
        print('[AuthWrapper] 인증 상태: $isAuthenticated, 화면 전환: ${isAuthenticated ? "MainLayout" : "LoginScreen"}');
        return isAuthenticated
            ? const MainLayout()
            : const LoginScreen();
      },
    );
  }
}
