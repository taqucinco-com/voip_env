import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:voip_env/page/login_page.dart';

void main() {
  testWidgets('LoginPageにGoogleログインボタンが表示される', (WidgetTester tester) async {
    // HomePage/AuthGateはFirebase初期化を前提とするため、
    // Firebase呼び出しを伴わずに描画できるLoginPageを直接pumpする。
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: LoginPage()),
      ),
    );

    expect(find.text('ログインが必要です'), findsOneWidget);
    expect(find.text('Googleでログイン'), findsOneWidget);
  });
}
