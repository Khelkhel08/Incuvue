import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:incubvue_app/main.dart';

void main() {
  testWidgets('login form renders required credentials fields', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

    expect(find.text('Welcome back!'), findsOneWidget);
    expect(find.text('Login'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(2));
  });
}
