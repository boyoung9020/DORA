import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/task_provider.dart';
import 'providers/project_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/chat_provider.dart';
import 'services/windows_notification_service.dart';
import 'screens/login_screen.dart';
import 'screens/main_layout.dart';

// 웹이 아닐 때만 bitsdojo_window import
import 'package:bitsdojo_window/bitsdojo_window.dart' if (dart.library.html) 'bitsdojo_window_stub.dart' as bitsdojo;

/// 앱 전체 텍스트 가독성: 기본보다 한 단계씩 진하게 적용
TextTheme _buildAppTextTheme(TextTheme base) {
  return TextTheme(
    displayLarge: base.displayLarge?.copyWith(fontWeight: FontWeight.w700),
    displayMedium: base.displayMedium?.copyWith(fontWeight: FontWeight.w700),
    displaySmall: base.displaySmall?.copyWith(fontWeight: FontWeight.w700),
    headlineLarge: base.headlineLarge?.copyWith(fontWeight: FontWeight.w700),
    headlineMedium: base.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
    headlineSmall: base.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
    titleLarge: base.titleLarge?.copyWith(fontWeight: FontWeight.w700),
    titleMedium: base.titleMedium?.copyWith(fontWeight: FontWeight.w700),
    titleSmall: base.titleSmall?.copyWith(fontWeight: FontWeight.w700),
    bodyLarge: base.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
    bodyMedium: base.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
    bodySmall: base.bodySmall?.copyWith(fontWeight: FontWeight.w700),
    labelLarge: base.labelLarge?.copyWith(fontWeight: FontWeight.w700),
    labelMedium: base.labelMedium?.copyWith(fontWeight: FontWeight.w700),
    labelSmall: base.labelSmall?.copyWith(fontWeight: FontWeight.w700),
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Windows 알림 서비스 초기화 (웹에서는 자동으로 스킵됨)
  await WindowsNotificationService.initialize();
  
  runApp(const MyApp());
  
  // Windows 타이틀바 커스터마이징 (웹이 아닐 때만)
  if (!kIsWeb) {
    bitsdojo.doWhenWindowReady(() {
      const initialSize = Size(1200, 800);
      bitsdojo.appWindow.minSize = const Size(800, 600);
      bitsdojo.appWindow.size = initialSize;
      bitsdojo.appWindow.alignment = Alignment.center;
      bitsdojo.appWindow.title = 'DORA - 프로젝트 관리';
      bitsdojo.appWindow.show();
    });
  }
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
        // ChatProvider를 전역적으로 사용할 수 있도록 설정
        ChangeNotifierProvider(create: (_) => ChatProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            title: 'DORA - 프로젝트 관리',
            debugShowCheckedModeBanner: false,
            themeMode: themeProvider.themeMode,
            // ── Light Theme: Clean Indigo ──
            theme: ThemeData(
              fontFamily: 'NanumSquareRound',
              textTheme: _buildAppTextTheme(Typography.material2021().black),
              scaffoldBackgroundColor: const Color(0xFFF5F3FF), // Violet 50 — 인디고 톤
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF4F46E5),
                brightness: Brightness.light,
              ).copyWith(
                surface: const Color(0xFFF5F3FF), // Violet 50 — 인디고 톤
                surfaceContainerHighest: const Color(0xFFFCFCFF), // 인디고 화이트
                onSurface: const Color(0xFF1E1B4B), // Indigo 950 — 깊은 인디고 블랙
                onSurfaceVariant: const Color(0xFF6C63AC), // 인디고 톤 서브 텍스트
                primary: const Color(0xFF4F46E5),
                primaryContainer: const Color(0xFFE0E7FF), // Indigo 100
                onPrimary: Colors.white,
                secondary: const Color(0xFF0EA5E9),
                secondaryContainer: const Color(0xFFE0F2FE),
                error: const Color(0xFFDC2626),
                outline: const Color(0xFFC7D2FE), // Indigo 200 — 인디고 톤 아웃라인
              ),
              useMaterial3: true,
            ),
            // ── Dark Theme: Deep Indigo ──
            darkTheme: ThemeData(
              fontFamily: 'NanumSquareRound',
              textTheme: _buildAppTextTheme(Typography.material2021().white),
              scaffoldBackgroundColor: const Color(0xFF0B0E14),
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF4F46E5),
                brightness: Brightness.dark,
              ).copyWith(
                surface: const Color(0xFF0B0E14),
                surfaceContainerHighest: const Color(0xFF161B2E),
                onSurface: const Color(0xFFE2E8F0),
                onSurfaceVariant: const Color(0xFF94A3B8),
                primary: const Color(0xFF818CF8),
                primaryContainer: const Color(0xFF312E81),
                onPrimary: Colors.white,
                secondary: const Color(0xFF38BDF8),
                secondaryContainer: const Color(0xFF0C4A6E),
                error: const Color(0xFFF87171),
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
        // 로딩 중이면 로딩 화면 표시
        if (authProvider.isLoading) {
          print('[AuthWrapper] 로딩 중');
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
