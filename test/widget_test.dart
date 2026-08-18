import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sefcg/main.dart';

void main() {
  testWidgets('search shows exact printings and card prices', (tester) async {
    await tester.pumpWidget(const SefCgApp());

    expect(find.text('TCG Price Checker'), findsOneWidget);
    expect(find.text('Pikachu ex'), findsOneWidget);
    expect(find.text('Surging Sparks - 057/191'), findsOneWidget);
    expect(find.text('SGD 12.40'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'charizard 151');
    await tester.pump();

    expect(find.text('Charizard ex'), findsOneWidget);
    expect(find.text('Pokemon 151 - 006/165'), findsOneWidget);
  });

  testWidgets('game selector switches search catalogue', (tester) async {
    await tester.pumpWidget(const SefCgApp());

    await tester.tap(find.text('Riftbound'));
    await tester.pumpAndSettle();

    expect(find.text('Jinx, Loose Cannon'), findsOneWidget);
    expect(find.text('Pikachu ex'), findsNothing);
  });

  testWidgets('scanner ranks OCR candidates by exact collector number', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ScannerScreen(
            selectedGame: TcgGame.pokemon,
            onGameChanged: (_) {},
            onOpenCard: (_) {},
          ),
        ),
      ),
    );

    await tester.drag(find.byType(ListView), const Offset(0, -360));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextField).first,
      'Pikachu ex 057/191 Double Rare',
    );
    await tester.tap(find.text('Match Card'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -280));
    await tester.pumpAndSettle();

    expect(find.text('Likely match'), findsOneWidget);
    expect(find.text('Pikachu ex'), findsOneWidget);
    expect(find.textContaining('Confidence score'), findsOneWidget);
  });

  testWidgets('collection tab shows private portfolio estimate', (
    tester,
  ) async {
    await tester.pumpWidget(const SefCgApp());

    await tester.tap(find.byKey(const Key('collection_nav')));
    await tester.pumpAndSettle();

    expect(find.text('Collection Portfolio'), findsOneWidget);
    expect(find.text('Estimated Value'), findsOneWidget);
    expect(find.text('Unrealised Gain/Loss'), findsOneWidget);
    expect(find.text('Charizard ex'), findsOneWidget);
  });
}
