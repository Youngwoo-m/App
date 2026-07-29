// Photo3D 기본 스모크 테스트.

import 'package:flutter_test/flutter_test.dart';

import 'package:photo3d/main.dart';

void main() {
  testWidgets('앱이 실행되고 홈 타이틀이 표시된다', (WidgetTester tester) async {
    await tester.pumpWidget(const Photo3DApp());
    await tester.pump();

    expect(find.text('Photo3D'), findsOneWidget);
  });
}
