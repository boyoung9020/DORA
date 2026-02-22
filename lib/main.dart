import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/task_provider.dart';
import 'providers/project_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/workspace_provider.dart';
import 'services/windows_notification_service.dart';
import 'screens/login_screen.dart';
import 'screens/main_layout.dart';
import 'screens/social_register_username_screen.dart';
import 'screens/workspace_select_screen.dart';

// ?뱀씠 ?꾨땺 ?뚮쭔 bitsdojo_window import
import 'package:bitsdojo_window/bitsdojo_window.dart' if (dart.library.html) 'bitsdojo_window_stub.dart' as bitsdojo;

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
    displayLarge:   _ts(base.displayLarge,   FontWeight.w700),
    displayMedium:  _ts(base.displayMedium,  FontWeight.w700),
    displaySmall:   _ts(base.displaySmall,   FontWeight.w700),
    headlineLarge:  _ts(base.headlineLarge,  FontWeight.w700),
    headlineMedium: _ts(base.headlineMedium, FontWeight.w700),
    headlineSmall:  _ts(base.headlineSmall,  FontWeight.w700),
    titleLarge:     _ts(base.titleLarge,     FontWeight.w700),
    titleMedium:    _ts(base.titleMedium,    FontWeight.w700),
    titleSmall:     _ts(base.titleSmall,     FontWeight.w700),
    bodyLarge:      _ts(base.bodyLarge,      FontWeight.w500),
    bodyMedium:     _ts(base.bodyMedium,     FontWeight.w400),
    bodySmall:      _ts(base.bodySmall,      FontWeight.w400),
    labelLarge:     _ts(base.labelLarge,     FontWeight.w500),
    labelMedium:    _ts(base.labelMedium,    FontWeight.w400),
    labelSmall:     _ts(base.labelSmall,     FontWeight.w400),
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const kakaoNativeAppKey = String.fromEnvironment('KAKAO_NATIVE_APP_KEY');
  const kakaoJavascriptAppKey = String.fromEnvironment('KAKAO_JAVASCRIPT_APP_KEY');
  if (kakaoNativeAppKey.isNotEmpty || kakaoJavascriptAppKey.isNotEmpty) {
    KakaoSdk.init(
      nativeAppKey: kakaoNativeAppKey.isNotEmpty ? kakaoNativeAppKey : null,
      javaScriptAppKey: kakaoJavascriptAppKey.isNotEmpty ? kakaoJavascriptAppKey : null,
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
                GoogleFonts.notoSansKrTextTheme(Typography.material2021().black),
              ),
              scaffoldBackgroundColor: Colors.white,
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFFD86B27),
                brightness: Brightness.light,
              ).copyWith(
                surface: Colors.white,
                surfaceContainerHighest: Colors.white,
                onSurface: const Color(0xFF3C2A1A), // Indigo 950 ??源딆? ?몃뵒怨?釉붾옓
                onSurfaceVariant: const Color(0xFF8A6647), // ?몃뵒怨????쒕툕 ?띿뒪??
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
                GoogleFonts.notoSansKrTextTheme(Typography.material2021().white),
              ),
              scaffoldBackgroundColor: const Color(0xFF1A120C),
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFFD86B27),
                brightness: Brightness.dark,
              ).copyWith(
                surface: const Color(0xFF1A120C),
                surfaceContainerHighest: const Color(0xFF2A1B12),
                onSurface: const Color(0xFFF7EBDD),
                onSurfaceVariant: const Color(0xFFD3B79E),
                primary: const Color(0xFFE3833D),
                primaryContainer: const Color(0xFF6A3A19),
                onPrimary: Colors.white,
                secondary: const Color(0xFF5FC5A0),
                secondaryContainer: const Color(0xFF1E4D3D),
                error: const Color(0xFFF87171),
              ),
              useMaterial3: true,
            ),
            // 珥덇린 ?붾㈃? 濡쒓렇???붾㈃
            // 濡쒓렇???곹깭???곕씪 ?먮룞?쇰줈 ???붾㈃?쇰줈 ?대룞?⑸땲??
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
  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        if (authProvider.isLoading) {
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


