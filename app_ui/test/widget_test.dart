import 'package:flutter_test/flutter_test.dart';
import 'package:xray_desktop_ui/main.dart';

void main() {
  testWidgets('renders dashboard shell', (WidgetTester tester) async {
    await tester.pumpWidget(const XrayDesktopApp());

    expect(find.text('XR UI'), findsOneWidget);
    expect(find.text('Server profiles'), findsOneWidget);
    expect(find.text('DNS and routing'), findsOneWidget);
  });
}
