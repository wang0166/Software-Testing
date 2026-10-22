import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile/main.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('启动后显示潘多拉登录页', (tester) async {
    await tester.pumpWidget(const PandoraApp());
    await tester.pumpAndSettle();
    expect(find.text('PANDORA  ·  潘多拉'), findsOneWidget);
    expect(find.byKey(const Key('login_username')), findsOneWidget);
    expect(find.byKey(const Key('login_password')), findsOneWidget);
  });

  testWidgets('空账号显示表单校验', (tester) async {
    await tester.pumpWidget(const PandoraApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('login_button')));
    await tester.pump();
    expect(find.text('请填写账号'), findsOneWidget);
  });

  testWidgets('演示账号登录后显示工作空间', (tester) async {
    await tester.pumpWidget(const PandoraApp());
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('login_username')), 'demo001');
    await tester.enterText(find.byKey(const Key('login_password')), 'demo123456');
    await tester.tap(find.byKey(const Key('login_button')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(find.textContaining('林小满'), findsWidgets);
    expect(find.text('四大信息面板'), findsOneWidget);
  });
}
