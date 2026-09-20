import 'package:flutter_test/flutter_test.dart';
import 'package:class_729/main.dart';

void main() {
  testWidgets('729 app renders', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump();

    expect(find.text('729'), findsWidgets);
    expect(find.text('提醒'), findsWidgets);
  });
}
