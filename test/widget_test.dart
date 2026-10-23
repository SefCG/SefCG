import 'dart:io';

import 'package:sefcg/collection_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sefcg/main.dart';

void main() {
  test(
    'file storage restores full collection and replaces older snapshots',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'sefcg_collection_test_',
      );
      addTearDown(() => directory.delete(recursive: true));
      FileCollectionStore store() =>
          FileCollectionStore(directory: () async => directory);
      expect(await store().load(), isEmpty);
      final entry = CollectionEntry(
        card: _FakeCardPriceRepository._cards.first,
        quantity: 3,
        purchasePrice: 8.5,
        condition: 'Near Mint',
      );
      await store().save([entry, entry]);
      final restored = await store().load();
      expect(restored, hasLength(2));
      expect(restored.first.quantity, 3);
      expect(restored.first.purchasePrice, 8.5);
      expect(restored.first.card.id, entry.card.id);
      expect(restored.first.card.price.currency, 'USD');
      expect(restored.first.card.price.marketPrice, 12.4);
      expect(restored.first.gainLoss, closeTo(11.7, 0.001));
      await store().save([entry]);
      expect(await store().load(), hasLength(1));
      await store().save([]);
      expect(await store().load(), isEmpty);
    },
  );

  test('corrupt saved data is reported and preserved', () async {
    final directory = await Directory.systemTemp.createTemp(
      'sefcg_corrupt_test_',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/collection.json');
    await file.writeAsString('invalid json');
    final store = FileCollectionStore(directory: () async => directory);
    await expectLater(store.load(), throwsFormatException);
    expect(await file.readAsString(), 'invalid json');
  });

  testWidgets(
    'saved edits survive a new app and failed saves preserve old values',
    (tester) async {
      final store = _MemoryStore();
      store.entries = [
        CollectionEntry(
          card: _FakeCardPriceRepository._cards.first,
          quantity: 2,
          purchasePrice: 10,
          condition: 'Near Mint',
        ),
      ];
      Future<void> openCollection() async {
        await tester.pumpWidget(
          SefCgApp(
            repository: _FakeCardPriceRepository(),
            collectionStore: store,
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('collection_nav')));
        await tester.pumpAndSettle();
      }

      await openCollection();
      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Edit purchase'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('purchase_price')), '9');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(store.entries.single.purchasePrice, 9);
      await tester.pumpWidget(const SizedBox());
      await openCollection();
      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pumpAndSettle();
      expect(find.textContaining('Bought: USD 9.00 each'), findsOneWidget);
      store.failSave = true;
      await tester.tap(find.byTooltip('Edit purchase'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('purchase_price')), '20');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(store.entries.single.purchasePrice, 9);
      expect(find.textContaining('Could not save collection.'), findsOneWidget);
    },
  );

  test('portfolio accounts for quantities, losses, gifts and currencies', () {
    final card = _FakeCardPriceRepository._cards.first;
    final entries = [
      CollectionEntry(
        card: card,
        quantity: 2,
        purchasePrice: 10,
        condition: 'Near Mint',
      ),
      CollectionEntry(
        card: card,
        quantity: 1,
        purchasePrice: 20,
        condition: 'Near Mint',
      ),
    ];
    final summary = PortfolioSummary.fromEntries(entries, 'USD');
    expect(summary.currentValue, closeTo(37.2, 0.001));
    expect(summary.acquisitionCost, 40);
    expect(summary.gainLoss, closeTo(-2.8, 0.001));
    expect(entries.first.gainLoss, closeTo(4.8, 0.001));
    expect(
      PortfolioSummary.fromEntries([
        CollectionEntry(
          card: card,
          quantity: 1,
          purchasePrice: 0,
          condition: 'Near Mint',
        ),
      ], 'USD').returnRate,
      isNull,
    );
  });

  testWidgets(
    'purchase form validates input and saves custom price and quantity',
    (tester) async {
      CollectionEntry? saved;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  saved = await showDialog<CollectionEntry>(
                    context: context,
                    builder: (_) => CollectionEntryDialog(
                      card: _FakeCardPriceRepository._cards.first,
                    ),
                  );
                },
                child: const Text('Add'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('purchase_price')), '-1');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(
        find.text('Enter a non-negative amount with up to 2 decimals.'),
        findsOneWidget,
      );
      await tester.enterText(find.byKey(const Key('purchase_price')), '8.50');
      await tester.enterText(find.byKey(const Key('purchase_quantity')), '3');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(saved?.purchasePrice, 8.5);
      expect(saved?.quantity, 3);
      expect(saved?.gainLoss, closeTo(11.7, 0.001));
    },
  );

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
        collectionStore: _MemoryStore(),
        repository: _ThrowingCardPriceRepository(
          const CardApiException(
            'TCG API requires an X-PAYMENT authorization.',
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'jinx');
    await tester.tap(find.byIcon(Icons.arrow_forward));
    await tester.pumpAndSettle();

    expect(find.text('API credentials required'), findsOneWidget);
  });

  testWidgets('search shows exact printings and card prices', (tester) async {
    await tester.pumpWidget(
      SefCgApp(
        collectionStore: _MemoryStore(),
        repository: _FakeCardPriceRepository(),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('TCG Price Checker'), findsOneWidget);
    expect(find.text('Search live card prices'), findsOneWidget);

    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'pikachu 057');
    await tester.tap(find.byIcon(Icons.arrow_forward));
    await tester.pumpAndSettle();

    expect(find.text('Pikachu ex'), findsOneWidget);
    expect(find.text('Surging Sparks - 057/191'), findsOneWidget);
    expect(find.text('USD 12.40'), findsOneWidget);
  });

  testWidgets('game selector switches search provider', (tester) async {
    await tester.pumpWidget(
      SefCgApp(
        collectionStore: _MemoryStore(),
        repository: _FakeCardPriceRepository(),
      ),
    );

    await tester.pumpAndSettle();
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
    await tester.pumpWidget(
      SefCgApp(
        collectionStore: _MemoryStore(),
        repository: _FakeCardPriceRepository(),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('collection_nav')));
    await tester.pumpAndSettle();

    expect(find.text('Collection Portfolio'), findsOneWidget);
    expect(find.text('Collection Net Worth'), findsOneWidget);
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

class _MemoryStore implements CollectionStore {
  List<CollectionEntry> entries = [];
  bool failSave = false;
  @override
  Future<List<CollectionEntry>> load() async => List.of(entries);
  @override
  Future<void> save(List<CollectionEntry> values) async {
    if (failSave) throw const FileSystemException('Test write failure');
    entries = List.of(values);
  }
}
