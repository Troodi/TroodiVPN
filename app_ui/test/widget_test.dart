import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xray_desktop_ui/main.dart';

void main() {
  testWidgets('renders dashboard shell', (WidgetTester tester) async {
    await tester.pumpWidget(const TroodiVpnApp());

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byType(Scaffold), findsOneWidget);
  });
}
