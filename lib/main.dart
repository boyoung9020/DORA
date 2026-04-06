import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'services/workspace_service.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/task_provider.dart';
import 'providers/project_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/workspace_provider.dart';
import 'providers/sprint_provider.dart';
import 'providers/github_provider.dart';
import 'services/windows_notification_service.dart';
import 'screens/login_screen.dart';
import 'screens/main_layout.dart';
import 'screens/social_register_username_screen.dart';
import 'screens/workspace_select_screen.dart';

// ?뱀씠 ?꾨땺 ?뚮쭔 bitsdojo_window import
import 'package:bitsdojo_window/bitsdojo_window.dart'
    if (dart.library.html) 'bitsdojo_window_stub.dart'
    as bitsdojo;

/// ???꾩껜 ?띿뒪??媛?낆꽦: 湲곕낯蹂대떎 ???④퀎??吏꾪븯寃??곸슜
TextStyle? _ts(TextStyle? base, FontWeight weight) {
  return base?.copyWith(fontWeight: weight);
}

/// 앱 텍스트 테마 구성:
/// - display/headline/title: w700 (제목류 굵게 유지)
/// - body/label: w400~w500 (입력 텍스트 가독성)
/// NotoSansKR (google_fonts)를 base로 받아 weight만 오버라이드
TextTheme _buildAppTextTheme(TextTheme base) {
  return TextTheme(
    displayLarge: _ts(base.displayLarge, FontWeight.w700),
    displayMedium: _ts(base.displayMedium, FontWeight.w700),
    displaySmall: _ts(base.displaySmall, FontWeight.w700),
    headlineLarge: _ts(base.headlineLarge, FontWeight.w700),
    headlineMedium: _ts(base.headlineMedium, FontWeight.w700),
    headlineSmall: _ts(base.headlineSmall, FontWeight.w700),
    titleLarge: _ts(base.titleLarge, FontWeight.w700),
    titleMedium: _ts(base.titleMedium, FontWeight.w700),
    titleSmall: _ts(base.titleSmall, FontWeight.w700),
    bodyLarge: _ts(base.bodyLarge, FontWeight.w500),
    bodyMedium: _ts(base.bodyMedium, FontWeight.w400),
    bodySmall: _ts(base.bodySmall, FontWeight.w400),
    labelLarge: _ts(base.labelLarge, FontWeight.w500),
    labelMedium: _ts(base.labelMedium, FontWeight.w400),
    labelSmall: _ts(base.labelSmall, FontWeight.w400),
  );
}

/// 앱 시작 시 /join/{token} URL에서 파싱한 초대 토큰을 보관
class PendingInvite {
  static String? token;
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 웹에서 /join/{token} URL로 접근한 경우 토큰 추출
  if (kIsWeb) {
    final path = Uri.base.path;
    final match = RegExp(r'^/join/(.+)$').firstMatch(path);
    if (match != null) {
      PendingInvite.token = match.group(1);
    }
  }
  const kakaoNativeAppKey = String.fromEnvironment('KAKAO_NATIVE_APP_KEY');
  const kakaoJavascriptAppKey = String.fromEnvironment(
    'KAKAO_JAVASCRIPT_APP_KEY',
  );
  if (kakaoNativeAppKey.isNotEmpty || kakaoJavascriptAppKey.isNotEmpty) {
    KakaoSdk.init(
      nativeAppKey: kakaoNativeAppKey.isNotEmpty ? kakaoNativeAppKey : null,
      javaScriptAppKey: kakaoJavascriptAppKey.isNotEmpty
          ? kakaoJavascriptAppKey
          : null,
    );
  }

  // Windows ?뚮┝ ?쒕퉬??珥덇린??(?뱀뿉?쒕뒗 ?먮룞?쇰줈 ?ㅽ궢??
  await WindowsNotificationService.initialize();

  runApp(const MyApp());

  // Windows ??댄?諛?而ㅼ뒪?곕쭏?댁쭠 (?뱀씠 ?꾨땺 ?뚮쭔)
  if (!kIsWeb) {
    bitsdojo.doWhenWindowReady(() {
      const initialSize = Size(1200, 800);
      bitsdojo.appWindow.minSize = const Size(800, 600);
      bitsdojo.appWindow.size = initialSize;
      bitsdojo.appWindow.alignment = Alignment.center;
      bitsdojo.appWindow.title = 'Sync - 프로젝트 관리';
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
        // ThemeProvider瑜??꾩뿭?곸쑝濡??ъ슜?????덈룄濡??ㅼ젙
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        // AuthProvider瑜??꾩뿭?곸쑝濡??ъ슜?????덈룄濡??ㅼ젙
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        // ProjectProvider瑜??꾩뿭?곸쑝濡??ъ슜?????덈룄濡??ㅼ젙
        ChangeNotifierProvider(create: (_) => ProjectProvider()),
        // TaskProvider瑜??꾩뿭?곸쑝濡??ъ슜?????덈룄濡??ㅼ젙
        ChangeNotifierProvider(create: (_) => TaskProvider()),
        // NotificationProvider瑜??꾩뿭?곸쑝濡??ъ슜?????덈룄濡??ㅼ젙
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        // ChatProvider瑜??꾩뿭?곸쑝濡??ъ슜?????덈룄濡??ㅼ젙
        ChangeNotifierProvider(create: (_) => ChatProvider()),
        // WorkspaceProvider
        ChangeNotifierProvider(create: (_) => WorkspaceProvider()),
        ChangeNotifierProvider(create: (_) => SprintProvider()),
        ChangeNotifierProvider(create: (_) => GitHubProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            title: 'Sync - 프로젝트 관리',
            debugShowCheckedModeBanner: false,
            themeMode: themeProvider.themeMode,
            // ?? Light Theme: Clean Indigo ??
            theme: ThemeData(
              fontFamily: GoogleFonts.notoSansKr().fontFamily,
              textTheme: _buildAppTextTheme(
                GoogleFonts.notoSansKrTextTheme(
                  Typography.material2021().black,
                ),
              ),
              scaffoldBackgroundColor: Colors.white,
              colorScheme:
                  ColorScheme.fromSeed(
                    seedColor: const Color(0xFFD86B27),
                    brightness: Brightness.light,
                  ).copyWith(
                    surface: Colors.white,
                    surfaceContainerHighest: Colors.white,
                    onSurface: const Color(
                      0xFF3C2A1A,
                    ), // Indigo 950 ??源딆? ?몃뵒怨?釉붾옓
                    onSurfaceVariant: const Color(
                      0xFF8A6647,
                    ), // ?몃뵒怨????쒕툕 ?띿뒪??
                    primary: const Color(0xFFD86B27),
                    primaryContainer: const Color(0xFFF3DECA), // Indigo 100
                    onPrimary: Colors.white,
                    secondary: const Color(0xFF2C9271),
                    secondaryContainer: const Color(0xFFD8F0E7),
                    error: const Color(0xFFDC2626),
                    outline: const Color(0xFFDADDE2),
                  ),
              useMaterial3: true,
            ),
            // ?? Dark Theme: Deep Indigo ??
            darkTheme: ThemeData(
              fontFamily: GoogleFonts.notoSansKr().fontFamily,
              textTheme: _buildAppTextTheme(
                GoogleFonts.notoSansKrTextTheme(
                  Typography.material2021().white,
                ),
              ),
              scaffoldBackgroundColor: const Color(0xFF17120F),
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFFD86B27),
                brightness: Brightness.dark,
              ).copyWith(
                // Surface 계층 (M3 tone 기준, 5단계)
                surface:                 const Color(0xFF17120F),
                surfaceContainerLowest:  const Color(0xFF110D0A),
                surfaceContainerLow:     const Color(0xFF1E1916),
                surfaceContainer:        const Color(0xFF242019),
                surfaceContainerHigh:    const Color(0xFF2E2822),
                surfaceContainerHighest: const Color(0xFF38312B),
                // 텍스트 / 아이콘
                onSurface:        const Color(0xFFEDE0D9),
                onSurfaceVariant: const Color(0xFFCDB8AF),
                // 브랜드 오렌지 (기존 유지)
                primary:            const Color(0xFFE3833D),
                onPrimary:          Colors.white,
                primaryContainer:   const Color(0xFF6A3A19),
                onPrimaryContainer: const Color(0xFFFFDCC8),
                // 보조 색상 (초록)
                secondary:            const Color(0xFF5CC8A5),
                onSecondary:          Colors.white,
                secondaryContainer:   const Color(0xFF1B4A3A),
                onSecondaryContainer: const Color(0xFFA0EDD5),
                // 테두리
                outline:        const Color(0xFF9A8480),
                outlineVariant: const Color(0xFF4C4140),
                // 에러
                error:            const Color(0xFFFFB4AB),
                onError:          const Color(0xFF690005),
                errorContainer:   const Color(0xFF93000A),
                onErrorContainer: const Color(0xFFFFDAD6),
                // elevation tint 비활성화 (파란빛 오버레이 제거)
                surfaceTint: Colors.transparent,
              ),
              // Card elevation tint 전역 제거
              cardTheme: const CardThemeData(
                surfaceTintColor: Colors.transparent,
                elevation: 0,
              ),
              useMaterial3: true,
            ),
            // 珥덇린 ?붾㈃? 濡쒓렇???붾㈃
            // 濡쒓렇???곹깭???곕씪 ?먮룞?쇰줈 ???붾㈃?쇰줈 ?대룞?⑸땲??
            // 웹에서 OS 화면 배율에 따른 텍스트 과확대 방지
            builder: kIsWeb
                ? (context, child) => MediaQuery(
                      data: MediaQuery.of(context).copyWith(
                        textScaler: TextScaler.noScaling,
                      ),
                      child: child!,
                    )
                : null,
            home: const AuthWrapper(),
          );
        },
      ),
    );
  }
}

/// ?몄쬆 ?곹깭???곕씪 ?붾㈃???꾪솚?섎뒗 ?꾩젽
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isJoiningWorkspace = false;

  Future<void> _tryAutoJoinWorkspace(WorkspaceProvider wsProvider) async {
    final token = PendingInvite.token;
    if (token == null) return;
    PendingInvite.token = null; // 중복 실행 방지

    setState(() => _isJoiningWorkspace = true);
    try {
      await WorkspaceService().joinByToken(token);
      await wsProvider.loadWorkspaces();
    } catch (e) {
      // 이미 가입된 경우 등 무시하고 계속 진행
      debugPrint('[PendingInvite] join error: $e');
    } finally {
      if (mounted) setState(() => _isJoiningWorkspace = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        if (authProvider.isLoading || _isJoiningWorkspace) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // Web social register: OAuth complete, need username input.
        if (authProvider.hasPendingSocialRegistration) {
          return const SocialRegisterUsernameScreen();
        }

        return authProvider.isAuthenticated
            ? Consumer<WorkspaceProvider>(
                builder: (context, wsProvider, _) {
                  if (!wsProvider.hasLoaded) {
                    if (!wsProvider.isLoading) {
                      WidgetsBinding.instance.addPostFrameCallback((_) async {
                        await wsProvider.loadWorkspaces();
                        // 로그인 후 초대 URL로 접근한 경우 자동 가입
                        if (mounted && PendingInvite.token != null) {
                          await _tryAutoJoinWorkspace(wsProvider);
                        }
                      });
                    }
                    return const Scaffold(
                      body: Center(child: CircularProgressIndicator()),
                    );
                  }

                  // 워크스페이스 로드 완료 후에도 대기 중인 초대 토큰이 있으면 처리
                  if (PendingInvite.token != null) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _tryAutoJoinWorkspace(wsProvider);
                    });
                  }

                  if (wsProvider.currentWorkspace != null) {
                    return const MainLayout();
                  }
                  return const WorkspaceSelectScreen();
                },
              )
            : const LoginScreen();
      },
    );
  }
}
