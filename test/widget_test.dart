import 'package:flutter_test/flutter_test.dart';
import 'package:pass_managers/main.dart';

void main() {
  testWidgets('Pass Managers app test', (WidgetTester tester) async {
    await tester.pumpWidget(const PassManagersApp());

    expect(find.text('Pass Managers'), findsOneWidget);
    expect(find.text('Pass Managers Build Test OK'), findsOneWidget);
  });
}
