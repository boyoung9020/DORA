// Smoke test: 앱이 기동·프레임 렌더까지 되는지 확인합니다.

import 'package:flutter_test/flutter_test.dart';
import 'package:sync_project_manager/main.dart';

void main() {
  testWidgets('MyApp starts without throwing', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump();

    // 로그인 화면 또는 로딩 등 최상위가 마운트되었는지 확인
    expect(find.byType(MyApp), findsOneWidget);
  });
}
