# UI 구현 규칙 (Flutter)

> 이 프로젝트의 UI 는 **Flutter (Dart)** 로 구성되며, Windows Desktop 과 Web 두 플랫폼을 지원한다. 모든 UI 코드는 `lib/` 하위에 둔다.

## 위젯 설계
- UI 는 재사용 가능한 위젯 단위로 구현한다
- 같은 데이터를 표현하는 위젯은 공통 위젯으로 추출하여 재활용 (`lib/widgets/` 또는 스크린별 하위 폴더 `lib/widgets/dashboard/`, `lib/widgets/project_info/`, `lib/widgets/workspace/`)
- 위젯은 단일 책임 원칙을 따르며, 필요 시 **합성(Composition)** 으로 확장 — 상속은 지양
- 300 라인을 넘는 위젯 파일은 기능별로 분리 (예: `task_card.dart` → `task_card_header.dart` + `task_card_body.dart`)
- `StatelessWidget` 을 기본으로, 내부 상태가 명확히 필요한 경우에만 `StatefulWidget`
- 복잡한 상태/비동기 로직은 `Provider` 로 위임하여 위젯을 얇게 유지

## 화면 구조
- 최상위 스크린 파일은 `lib/screens/` 에 둔다 (`dashboard_screen.dart`, `kanban_screen.dart`, `sprint_screen.dart`, `meeting_minutes_screen.dart`, …)
- 탭형 서브 스크린은 `lib/screens/project_info/` 처럼 하위 폴더로 분리 (프로젝트 정보 탭: overview, members, tasks, patch, documents, github, settings)
- 전체 레이아웃 셸은 `lib/screens/main_layout.dart` — Slack 스타일 좌측 사이드바 + 우측 콘텐츠 영역

## 테마 & 색상
- 라이트/다크 테마는 `ThemeProvider` (`lib/providers/theme_provider.dart`) 로 전환
- 색상은 `Theme.of(context).colorScheme` 의 시맨틱 토큰(`primary`, `onPrimary`, `surface`, `onSurface`, `error`, `outline` 등)을 사용
- `Colors.red` 등 하드코딩 색상은 **브랜드 액센트/로고처럼 테마와 무관한 표식에만** 제한적으로 사용. 일반 텍스트/배경/보더는 토큰 사용이 원칙
- `TextStyle` 직접 선언보다 `Theme.of(context).textTheme.*` 를 확장/복제해서 사용

## 폰트
- 기본 폰트: **NanumSquareRound** (weight 300 / 400 / 700 / 800)
- 에셋 경로: `font/nanum-square-round/` (pubspec.yaml 에 등록됨)
- 모든 `TextStyle` 은 이 폰트 패밀리를 상속 (`MaterialApp.theme.textTheme` 에서 기본값 지정)
- 추가로 `google_fonts` 패키지가 설치되어 있어 특수 용도(코드 블록, 숫자 강조 등)에 한해 사용 가능

## 마크다운
- 마크다운 렌더링은 **`flutter_markdown`** 패키지 사용 (회의록, 댓글, AI 요약 등)
- 인라인 코드 / 코드 블록 스타일은 테마에 맞춰 커스터마이즈
- 마크다운 내부 링크는 `url_launcher` 로 외부 브라우저에서 열기

## 파일 업로드 (중요)
- **Windows Desktop 에서는 `dart:io` `File` / `MultipartFile.fromPath()` 를 사용하지 않는다** — 네임스페이스 경로 때문에 `_Namespace` 에러가 발생
- 반드시 `XFile.readAsBytes()` + `http.MultipartFile.fromBytes()` 패턴으로 업로드
- 파일 선택: `image_picker` (크로스플랫폼) + `desktop_drop` (데스크탑 드래그 앤 드롭) + `file_picker` (일반 파일 선택)

## 파일 다운로드
- 플랫폼별 구현을 조건부 임포트로 분기: `lib/utils/file_download_web.dart`, `file_download_io.dart`, `file_download_stub.dart`
- 신규 다운로드 로직을 추가할 때는 3개 파일 모두에 동일 시그니처를 유지

## 창 크롬 (Windows Desktop)
- `bitsdojo_window` 패키지로 커스텀 타이틀바 구현 (`lib/widgets/app_title_bar.dart`)
- 웹 빌드에서는 `lib/bitsdojo_window_stub.dart` 가 자동으로 스텁 처리 (조건부 임포트)
- 타이틀바 색상/구분선은 테마 토큰 기반 (v1.0.4 에서 배경색 구분 및 하단 구분선 추가됨)

## 아이콘
- 기본: Material `Icons.*`
- 커스텀 SVG: `flutter_svg` 사용 (`lib/widgets/fox_logo.dart` 참조)
- 기술 스택 아이콘: `lib/utils/tech_stack_devicon.dart` (devicon 매핑)
- 소셜 로그인 아이콘: `lib/widgets/social_login_button.dart`

## 알림 / 스낵바 / 이모지
- 앱 내 알림(인라인): `notification_inline_message.dart`
- 네이티브 알림: `flutter_local_notifications` (데스크탑 중심) + 플랫폼별 서비스(`windows_notification_service.dart`, `platform_notification_native.dart`, `platform_notification_web.dart`, `platform_notification_stub.dart`)
- 스낵바: `ScaffoldMessenger.of(context).showSnackBar(...)` — 단순 메시지/에러 피드백에 사용
- 이모지 입력: `emoji_picker_flutter` (댓글, 반응)

## Glass / 장식 컴포넌트
- 반투명 컨테이너: `lib/widgets/glass_container.dart` (`BackdropFilter` 래핑)
- 측면 패널: `lib/widgets/expandable_side_panel.dart`
- 로고 애니메이션: `lottie` 패키지 + `logo.json` / `logo.mp4`

## 라우팅
- 현 구조는 URL 기반 라우팅이 아닌 `main_layout.dart` 의 **사이드바 선택 → 콘텐츠 영역 전환** 방식
- 세부 화면 진입은 `Navigator.push` / `Navigator.pop` (스택 기반)
- **신규 화면 추가 시**:
  1. `lib/screens/` 에 스크린 위젯 추가
  2. `main_layout.dart` 의 사이드바 메뉴/콘텐츠 매핑에 등록 (해당되는 경우)
  3. 권한이 필요한 메뉴는 `AuthProvider` 역할 검사 후 노출/숨김 처리

## 상태 관리
- 전역 상태는 `Provider` 로 통일 — `lib/main.dart` 의 `MultiProvider` 에 10개 Provider 등록됨
- 위젯에서 값 구독: `Consumer<T>(builder: (context, value, _) => ...)`
- 한 번만 호출(트리거): `Provider.of<T>(context, listen: false).doSomething()`
- 로컬 UI 상태(토글, 폼 포커스 등)는 `StatefulWidget` 의 `setState` 로 관리
- 스토리지: 토큰/설정은 `SharedPreferences`

## API 호출
- 모든 HTTP 는 `lib/utils/api_client.dart` 의 `ApiClient` 정적 메서드 사용 (`get / post / patch / put / delete`)
- Dart 모델은 반드시 `fromJson(Map<String, dynamic> json)`, `toJson()`, `copyWith(...)` 세 메서드 제공
- 응답 파싱은 `ApiClient.handleResponse<T>` / `handleListResponse<T>` 사용

## 국제화
- 현재 UI 는 한국어 기준으로 작성되어 있다 (하드코딩된 한국어 문자열 허용)
- `intl` 패키지가 설치되어 있으므로, 신규 기능을 구현할 때 **장기적으로 번역 가능한 구조**를 염두에 두고 문자열을 한곳에 몰아 정의하는 것을 권장 (향후 i18n 도입 시 비용 절감)

## 다이얼로그 / 날짜 선택
- 일반 확인 다이얼로그: `showDialog` + `AlertDialog`
- 날짜 범위 선택: `lib/widgets/date_range_picker_dialog.dart` 참조 (공통 위젯)

## 테스트 UI 확인
- Flutter Web: `flutter run -d chrome --web-port=3000` → `http://localhost:3000`
- Windows Desktop: `flutter run -d windows`
- Lint: `flutter analyze`
