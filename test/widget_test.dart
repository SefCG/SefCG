import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sefcg/main.dart';

void main() {
  test('TCG API client searches without an API key', () async {
    Uri? requestedUri;
    Map<String, String>? requestedHeaders;
    final client = TcgApiClient(
      const ApiConfig(),
      getJson: (uri, {headers = const {}}) async {
        requestedUri = uri;
        requestedHeaders = headers;
        return {
          'data': [
            {
              'id': 'rift-jinx-041',
              'name': 'Jinx, Loose Cannon',
              'set_name': 'Origins',
              'collector_number': '041/298',
              'rarity': 'Champion',
              'printing': 'Foil',
              'price': 22.60,
              'currency': 'USD',
            },
          ],
        };
      },
    );

    final results = await client.searchCards(TcgGame.riftbound, 'jinx');

    expect(requestedUri?.host, 'api.tcgapi.dev');
    expect(requestedUri?.queryParameters['q'], 'jinx');
    expect(requestedUri?.queryParameters.containsKey('limit'), isFalse);
    expect(requestedHeaders, isEmpty);
    expect(results.single.name, 'Jinx, Loose Cannon');
  });

  test('Pokemon TCG client uses quoted name queries', () async {
    final requestedQueries = <String>[];
    final client = PokemonTcgClient(
      const ApiConfig(),
      getJson: (uri, {headers = const {}}) async {
        requestedQueries.add(uri.queryParameters['q']!);
        return {'data': <Object>[]};
      },
    );

    await client.searchCards('pikachu ex 057');

    expect(requestedQueries.first, 'name:"pikachu ex"');
  });

  test('Pokemon TCG client ignores search capitalization', () async {
    final requestedQueries = <String>[];
    final client = PokemonTcgClient(
      const ApiConfig(),
      getJson: (uri, {headers = const {}}) async {
        requestedQueries.add(uri.queryParameters['q']!);
        return {'data': <Object>[]};
      },
    );

    await client.searchCards('RayQuAzA EX');

    expect(requestedQueries.first, 'name:"rayquaza ex"');
  });

  test('Pokemon TCG client matches card set and number combinations', () async {
    final requestedQueries = <String>[];
    final client = PokemonTcgClient(
      const ApiConfig(),
      getJson: (uri, {headers = const {}}) async {
        final query = uri.queryParameters['q']!;
        requestedQueries.add(query);
        if (query != 'name:"pikachu ex"') {
          return {'data': <Object>[]};
        }
        return {
          'data': [
            {
              'id': 'pkm-057-191',
              'name': 'Pikachu ex',
              'set': {'name': 'Surging Sparks', 'printedTotal': 191},
              'number': '057',
              'rarity': 'Double Rare',
              'tcgplayer': {
                'prices': {
                  'holofoil': {'market': 12.40},
                },
              },
            },
            {
              'id': 'pkm-063-193',
              'name': 'Pikachu ex',
              'set': {'name': 'Paldea Evolved', 'printedTotal': 193},
              'number': '063',
              'rarity': 'Double Rare',
              'tcgplayer': {
                'prices': {
                  'holofoil': {'market': 3.20},
                },
              },
            },
          ],
        };
      },
    );

    final results = await client.searchCards('pikachu ex surging sparks 57');

    expect(requestedQueries, contains('name:"pikachu ex"'));
    expect(results.single.collectorNumber, '057/191');
  });

  test('Pokemon TCG client matches combinations in different order', () async {
    final client = PokemonTcgClient(
      const ApiConfig(),
      getJson: (uri, {headers = const {}}) async {
        if (uri.queryParameters['q'] != 'name:"pikachu"') {
          return {'data': <Object>[]};
        }
        return {
          'data': [
            {
              'id': 'pkm-057-191',
              'name': 'Pikachu ex',
              'set': {'name': 'Surging Sparks', 'printedTotal': 191},
              'number': '057',
              'rarity': 'Double Rare',
              'tcgplayer': {
                'prices': {
                  'holofoil': {'market': 12.40},
                },
              },
            },
          ],
        };
      },
    );

    final results = await client.searchCards('surging sparks pikachu 57');

    expect(results.single.name, 'Pikachu ex');
  });

  test('Pokemon TCG client paginates through all matching cards', () async {
    final requestedPages = <String>[];
    final client = PokemonTcgClient(
      const ApiConfig(),
      getJson: (uri, {headers = const {}}) async {
        requestedPages.add(uri.queryParameters['page']!);
        final page = int.parse(uri.queryParameters['page']!);
        return {
          'totalCount': 251,
          'data': [
            for (var i = 0; i < (page == 1 ? 250 : 1); i++)
              {
                'id': 'pkm-$page-$i',
                'name': 'Test Pokemon',
                'number': '$i',
                'rarity': 'Common',
                'tcgplayer': {
                  'prices': {
                    'normal': {'market': 1.0},
                  },
                },
              },
          ],
        };
      },
    );

    final results = await client.searchCards('test pokemon');

    expect(requestedPages, ['1', '2']);
    expect(results, hasLength(251));
  });

  test(
    'Pokemon TCG client falls back when exact query has server error',
    () async {
      final requestedQueries = <String>[];
      final client = PokemonTcgClient(
        const ApiConfig(),
        getJson: (uri, {headers = const {}}) async {
          final query = uri.queryParameters['q']!;
          requestedQueries.add(query);
          if (query == 'name:"gardevoir ex"') {
            throw const CardApiException(
              'API server error (500). Try again later.',
            );
          }
          return {'data': <Object>[]};
        },
      );

      await client.searchCards('gardevoir ex');

      expect(requestedQueries, ['name:"gardevoir ex"', 'name:"gardevoir"']);
    },
  );

  testWidgets('search shows credential title for TCG payment failure', (
    tester,
  ) async {
    await tester.pumpWidget(
      SefCgApp(
        repository: _ThrowingCardPriceRepository(
          const CardApiException(
            'TCG API requires an X-PAYMENT authorization.',
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField).first, 'jinx');
    await tester.tap(find.byIcon(Icons.arrow_forward));
    await tester.pumpAndSettle();

    expect(find.text('API credentials required'), findsOneWidget);
  });

  testWidgets('search shows exact printings and card prices', (tester) async {
    await tester.pumpWidget(SefCgApp(repository: _FakeCardPriceRepository()));

    expect(find.text('TCG Price Checker'), findsOneWidget);
    expect(find.text('Search live card prices'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'pikachu 057');
    await tester.tap(find.byIcon(Icons.arrow_forward));
    await tester.pumpAndSettle();

    expect(find.text('Pikachu ex'), findsOneWidget);
    expect(find.text('Surging Sparks - 057/191'), findsOneWidget);
    expect(find.text('USD 12.40'), findsOneWidget);
  });

  testWidgets('game selector switches search provider', (tester) async {
    await tester.pumpWidget(SefCgApp(repository: _FakeCardPriceRepository()));

    await tester.enterText(find.byType(TextField).first, 'jinx');
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
            repository: _FakeCardPriceRepository(),
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

  testWidgets('collection tab starts empty without mock portfolio data', (
    tester,
  ) async {
    await tester.pumpWidget(SefCgApp(repository: _FakeCardPriceRepository()));

    await tester.tap(find.byKey(const Key('collection_nav')));
    await tester.pumpAndSettle();

    expect(find.text('Collection Portfolio'), findsOneWidget);
    expect(find.text('Estimated Value'), findsOneWidget);
    expect(find.text('Unrealised Gain/Loss'), findsOneWidget);
    expect(find.text('No cards yet'), findsOneWidget);
  });
}

class _ThrowingCardPriceRepository implements CardPriceRepository {
  const _ThrowingCardPriceRepository(this.error);

  final Object error;

  @override
  Future<List<CandidateMatch>> identifyCard(
    TcgGame game,
    String evidence,
  ) async {
    throw error;
  }

  @override
  Future<List<TradingCard>> searchCards(TcgGame game, String query) async {
    throw error;
  }
}

class _FakeCardPriceRepository implements CardPriceRepository {
  static const _cards = [
    TradingCard(
      id: 'pkm-057-191',
      game: TcgGame.pokemon,
      name: 'Pikachu ex',
      setName: 'Surging Sparks',
      collectorNumber: '057/191',
      rarity: 'Double Rare',
      variant: 'Holofoil',
      price: PriceInfo(
        marketPrice: 12.40,
        currency: 'USD',
        source: 'Fake API',
        freshness: 'Updated today',
      ),
    ),
    TradingCard(
      id: 'pkm-006-165',
      game: TcgGame.pokemon,
      name: 'Charizard ex',
      setName: 'Pokemon 151',
      collectorNumber: '006/165',
      rarity: 'Special Illustration Rare',
      variant: 'Holofoil',
      price: PriceInfo(
        marketPrice: 165.00,
        currency: 'USD',
        source: 'Fake API',
        freshness: 'Updated today',
      ),
    ),
    TradingCard(
      id: 'rift-jinx-041',
      game: TcgGame.riftbound,
      name: 'Jinx, Loose Cannon',
      setName: 'Origins',
      collectorNumber: '041/298',
      rarity: 'Champion',
      variant: 'Foil',
      price: PriceInfo(
        marketPrice: 22.60,
        currency: 'USD',
        source: 'Fake API',
        freshness: 'Updated today',
      ),
    ),
  ];

  @override
  Future<List<CandidateMatch>> identifyCard(
    TcgGame game,
    String evidence,
  ) async {
    final results = await searchCards(game, evidence);
    return [
      for (final card in results)
        CandidateMatch(
          card: card,
          score: evidence.contains(card.collectorNumber) ? 92 : 30,
        ),
    ];
  }

  @override
  Future<List<TradingCard>> searchCards(TcgGame game, String query) async {
    final tokens = query.toLowerCase().split(RegExp(r'\s+'));
    return _cards.where((card) {
      if (card.game != game) {
        return false;
      }
      final haystack =
          '${card.name} ${card.setName} ${card.collectorNumber} ${card.rarity}'
              .toLowerCase();
      return tokens.every(haystack.contains);
    }).toList();
  }
}
