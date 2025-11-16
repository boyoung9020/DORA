import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/task_provider.dart';
import 'providers/project_provider.dart';
import 'screens/login_screen.dart';
import 'screens/main_layout.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // AuthProvider를 전역적으로 사용할 수 있도록 설정
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        // ProjectProvider를 전역적으로 사용할 수 있도록 설정
        ChangeNotifierProvider(create: (_) => ProjectProvider()),
        // TaskProvider를 전역적으로 사용할 수 있도록 설정
        ChangeNotifierProvider(create: (_) => TaskProvider()),
      ],
      child: MaterialApp(
        title: 'DORA - 프로젝트 관리',
        debugShowCheckedModeBanner: false,
      theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF2196F3), // 파란색 포인트 색상 (로고와 일치)
            brightness: Brightness.light,
          ).copyWith(
            // 더 밝은 흰색 배경
            surface: Colors.white,
            surfaceContainerHighest: const Color(0xFFF5F5F5),
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
        // 초기 화면은 로그인 화면
        // 로그인 상태에 따라 자동으로 홈 화면으로 이동합니다
        home: const AuthWrapper(),
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
        // 로딩 중이면 로딩 화면 표시
        if (authProvider.isLoading) {
          print('[AuthWrapper] 로딩 화면 표시');
          return const Scaffold(
      body: Center(
              child: CircularProgressIndicator(),
            ),
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
