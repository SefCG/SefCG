import 'package:flutter_test/flutter_test.dart';

import 'package:sefcg/main.dart';

void main() {
  testWidgets('shows the Flutter starter screen', (WidgetTester tester) async {
    await tester.pumpWidget(const SefCgApp());

    expect(find.text('SefCG'), findsOneWidget);
    expect(find.text('SefCG is ready for Flutter'), findsOneWidget);
    expect(
      find.text('Build once in Dart and run on iOS and Android.'),
      findsOneWidget,
    );
  });
}
