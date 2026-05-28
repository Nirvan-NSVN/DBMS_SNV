import 'package:flutter_test/flutter_test.dart';
import 'package:dbms/main.dart';

void main() {
  testWidgets('App starts without error', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();
  });
}
