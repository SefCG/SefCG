import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import 'collection_store.dart';

void main() {
  runApp(SefCgApp(repository: RealCardPriceRepository()));
}

enum TcgGame {
  pokemon('pokemon', 'Pokemon'),
  riftbound('riftbound', 'Riftbound');

  const TcgGame(this.code, this.label);

  final String code;
  final String label;
}

class ApiConfig {
  const ApiConfig({
    this.pokemonTcgApiKey = const String.fromEnvironment('POKEMON_TCG_API_KEY'),
    this.tcgApiKey = const String.fromEnvironment('TCG_API_KEY'),
  });

  final String pokemonTcgApiKey;
  final String tcgApiKey;
}

class PriceInfo {
  const PriceInfo({
    required this.marketPrice,
    required this.currency,
    required this.source,
    required this.freshness,
  });

  final double marketPrice;
  final String currency;
  final String source;
  final String freshness;
}

class TradingCard {
  const TradingCard({
    required this.id,
    required this.game,
    required this.name,
    required this.setName,
    required this.collectorNumber,
    required this.rarity,
    required this.variant,
    required this.price,
    this.imageUrl,
  });

  final String id;
  final TcgGame game;
  final String name;
  final String setName;
  final String collectorNumber;
  final String rarity;
  final String variant;
  final PriceInfo price;
  final String? imageUrl;
}

class CollectionEntry {
  const CollectionEntry({
    required this.card,
    required this.quantity,
    required this.purchasePrice,
    required this.condition,
  });

  final TradingCard card;
  final int quantity;
  final double purchasePrice;
  final String condition;

  double get currentValue => card.price.marketPrice * quantity;

  double get acquisitionCost => purchasePrice * quantity;

  double get gainLoss => currentValue - acquisitionCost;
}

class CandidateMatch {
  const CandidateMatch({required this.card, required this.score});

  final TradingCard card;
  final int score;
}

abstract class CardPriceRepository {
  Future<List<TradingCard>> searchCards(TcgGame game, String query);

  Future<List<CandidateMatch>> identifyCard(TcgGame game, String evidence);
}

class CardApiException implements Exception {
  const CardApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

typedef JsonGetter =
    Future<Map<String, Object?>> Function(
      Uri uri, {
      Map<String, String> headers,
    });

class RealCardPriceRepository implements CardPriceRepository {
  RealCardPriceRepository({
    ApiConfig config = const ApiConfig(),
    PokemonTcgClient? pokemonClient,
    TcgApiClient? tcgApiClient,
  }) : _pokemonClient = pokemonClient ?? PokemonTcgClient(config),
       _tcgApiClient = tcgApiClient ?? TcgApiClient(config);

  final PokemonTcgClient _pokemonClient;
  final TcgApiClient _tcgApiClient;

  @override
  Future<List<TradingCard>> searchCards(TcgGame game, String query) {
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) {
      return Future.value(const []);
    }

    return switch (game) {
      TcgGame.pokemon => _pokemonClient.searchCards(trimmedQuery),
      TcgGame.riftbound => _tcgApiClient.searchCards(game, trimmedQuery),
    };
  }

  @override
  Future<List<CandidateMatch>> identifyCard(
    TcgGame game,
    String evidence,
  ) async {
    final query = _queryFromEvidence(evidence);
    final cards = await searchCards(game, query);
    final lowerEvidence = evidence.toLowerCase();
    final matches =
        cards
            .map(
              (card) => CandidateMatch(
                card: card,
                score: _score(card, lowerEvidence),
              ),
            )
            .where((match) => match.score > 0)
            .toList()
          ..sort((a, b) => b.score.compareTo(a.score));
    return matches.take(5).toList();
  }

  String _queryFromEvidence(String evidence) {
    final collectorNumber = RegExp(r'\b\d{1,4}/\d{1,4}\b').firstMatch(evidence);
    if (collectorNumber != null) {
      return evidence;
    }

    final words = evidence
        .split(RegExp(r'[^A-Za-z0-9]+'))
        .where((word) => word.length > 2)
        .take(5);
    return words.join(' ');
  }

  int _score(TradingCard card, String evidence) {
    var score = 0;
    if (evidence.contains(card.collectorNumber.toLowerCase())) {
      score += 70;
    }
    final printedNumber = card.collectorNumber.split('/').first;
    if (printedNumber.isNotEmpty &&
        evidence.contains(printedNumber.toLowerCase())) {
      score += 28;
    }
    if (evidence.contains(card.setName.toLowerCase())) {
      score += 20;
    }
    for (final token in card.name.toLowerCase().split(RegExp(r'[\s,.-]+'))) {
      if (token.length > 2 && evidence.contains(token)) {
        score += 12;
      }
    }
    if (evidence.contains(card.rarity.toLowerCase())) {
      score += 8;
    }
    return score.clamp(0, 100);
  }
}

class PokemonTcgClient {
  PokemonTcgClient(this._config, {JsonGetter getJson = _getJson})
    : _getJsonClient = getJson;

  final ApiConfig _config;
  final JsonGetter _getJsonClient;

  Future<List<TradingCard>> searchCards(String query) async {
    CardApiException? lastError;
    var hasSuccessfulRequest = false;
    final seenCardIds = <String>{};
    final matches = <TradingCard>[];
    for (final pokemonQuery in _pokemonQueries(query)) {
      try {
        final cards = await _searchAllPokemonPages(pokemonQuery);
        hasSuccessfulRequest = true;
        final matchingCards = cards.where(
          (card) => _cardMatchesQuery(card, query),
        );
        for (final card in matchingCards) {
          if (seenCardIds.add(card.id)) {
            matches.add(card);
          }
        }
        if (matches.isNotEmpty) {
          return matches;
        }
      } on CardApiException catch (error) {
        lastError = error;
        if (!error.toString().contains('server error')) {
          rethrow;
        }
      }
    }
    if (lastError != null) {
      if (!hasSuccessfulRequest) {
        throw lastError;
      }
    }
    return matches;
  }

  Future<List<TradingCard>> _searchAllPokemonPages(String pokemonQuery) async {
    const pageSize = 250;
    var page = 1;
    var totalCount = 0;
    final cards = <TradingCard>[];

    while (true) {
      final uri = Uri.https('api.pokemontcg.io', '/v2/cards', {
        'q': pokemonQuery,
        'page': '$page',
        'pageSize': '$pageSize',
      });
      final response = await _getJsonClient(
        uri,
        headers: _config.pokemonTcgApiKey.isEmpty
            ? const {}
            : {'X-Api-Key': _config.pokemonTcgApiKey},
      );
      final data = response['data'];
      if (data is! List) {
        throw const CardApiException(
          'Pokemon TCG API returned an invalid response.',
        );
      }
      final pageCards = data
          .whereType<Map<String, Object?>>()
          .map(_parsePokemonCard)
          .where((card) => card.price.marketPrice > 0)
          .toList();
      cards.addAll(pageCards);

      totalCount = _asInt(response['totalCount']) ?? totalCount;
      if (data.length < pageSize ||
          (totalCount > 0 && page * pageSize >= totalCount)) {
        return cards;
      }
      page += 1;
    }
  }

  List<String> _pokemonQueries(String query) {
    final words = query
        .toLowerCase()
        .split(RegExp(r'[^a-z]+'))
        .where((word) => word.length > 1)
        .toList();
    final queryNames = <String>{};
    for (var length = words.length.clamp(0, 4); length > 0; length -= 1) {
      for (var start = 0; start + length <= words.length; start += 1) {
        final candidate = words.skip(start).take(length).toList();
        if (candidate.every(_genericPokemonNameTerms.contains)) {
          continue;
        }
        queryNames.add(candidate.join(' '));
      }
    }

    for (final name in queryNames.toList()) {
      final broaderName = _escapeLucenePhrase(
        name
            .split(' ')
            .where((word) => !_genericPokemonNameTerms.contains(word))
            .join(' '),
      );
      if (broaderName.isNotEmpty && broaderName != name) {
        queryNames.add(broaderName);
      }
    }

    return queryNames.isEmpty
        ? const ['name:"pokemon"']
        : [
            for (final name in queryNames)
              'name:"${_escapeLucenePhrase(name)}"',
          ];
  }

  bool _cardMatchesQuery(TradingCard card, String query) {
    final haystack =
        '${card.name} ${card.setName} ${card.collectorNumber} ${card.rarity} ${card.variant}'
            .toLowerCase();
    final normalizedNumber = card.collectorNumber.replaceFirst(
      RegExp(r'^0+(?=\d)'),
      '',
    );
    final terms = query
        .toLowerCase()
        .split(RegExp(r'[^a-z0-9]+'))
        .where((term) => term.isNotEmpty)
        .toList();
    return terms.every((term) {
      if (haystack.contains(term)) {
        return true;
      }
      final normalizedTerm = term.replaceFirst(RegExp(r'^0+(?=\d)'), '');
      return normalizedTerm.isNotEmpty &&
          normalizedNumber.contains(normalizedTerm);
    });
  }

  TradingCard _parsePokemonCard(Map<String, Object?> json) {
    final tcgplayer = _asMap(json['tcgplayer']);
    final cardmarket = _asMap(json['cardmarket']);
    final tcgPrice = _bestTcgPlayerPrice(_asMap(tcgplayer['prices']));
    final cardmarketPrice = _asDouble(
      _asMap(cardmarket['prices'])['averageSellPrice'],
    );
    final set = _asMap(json['set']);
    final printedTotal = set['printedTotal']?.toString();
    final number = json['number']?.toString() ?? '';
    final collectorNumber = printedTotal == null || printedTotal.isEmpty
        ? number
        : '$number/$printedTotal';
    final price = tcgPrice.$1 ?? cardmarketPrice ?? 0;
    final currency = tcgPrice.$1 == null && cardmarketPrice != null
        ? 'EUR'
        : 'USD';
    final updatedAt =
        tcgplayer['updatedAt']?.toString() ??
        cardmarket['updatedAt']?.toString();

    return TradingCard(
      id: json['id']?.toString() ?? '',
      game: TcgGame.pokemon,
      name: json['name']?.toString() ?? 'Unknown Pokemon card',
      setName: set['name']?.toString() ?? 'Unknown set',
      collectorNumber: collectorNumber,
      rarity: json['rarity']?.toString() ?? 'Unknown rarity',
      variant: tcgPrice.$2,
      price: PriceInfo(
        marketPrice: price,
        currency: currency,
        source: currency == 'EUR'
            ? 'Pokemon TCG API Cardmarket'
            : 'Pokemon TCG API TCGPlayer',
        freshness: updatedAt == null
            ? 'Freshness unavailable'
            : 'Updated $updatedAt',
      ),
      imageUrl: _asMap(json['images'])['small']?.toString(),
    );
  }

  (double?, String) _bestTcgPlayerPrice(Map<String, Object?> prices) {
    const preference = [
      'holofoil',
      'reverseHolofoil',
      'normal',
      '1stEditionHolofoil',
      '1stEditionNormal',
    ];
    for (final key in preference) {
      final priceMap = _asMap(prices[key]);
      final market =
          _asDouble(priceMap['market']) ?? _asDouble(priceMap['mid']);
      if (market != null) {
        return (market, _variantLabel(key));
      }
    }
    return (null, 'Market');
  }

  String _variantLabel(String key) {
    return switch (key) {
      'reverseHolofoil' => 'Reverse Holofoil',
      '1stEditionHolofoil' => '1st Edition Holofoil',
      '1stEditionNormal' => '1st Edition Normal',
      _ => key[0].toUpperCase() + key.substring(1),
    };
  }

  String _escapeLucenePhrase(String input) {
    return input
        .replaceAll(RegExp(r'[^A-Za-z0-9 ]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}

const _genericPokemonNameTerms = {'ex', 'gx', 'v', 'vmax', 'vstar'};

class TcgApiClient {
  TcgApiClient(this._config, {JsonGetter getJson = _getJson})
    : _getJsonClient = getJson;

  final ApiConfig _config;
  final JsonGetter _getJsonClient;

  Future<List<TradingCard>> searchCards(TcgGame game, String query) async {
    final uri = Uri.https('api.tcgapi.dev', '/v1/search', {
      'q': query,
      'game': game.code,
    });
    final response = await _getJsonClient(
      uri,
      headers: _config.tcgApiKey.isEmpty
          ? const {}
          : {'X-API-Key': _config.tcgApiKey},
    );
    final data = response['data'];
    if (data is! List) {
      throw const CardApiException('TCG API returned an invalid response.');
    }
    return data
        .whereType<Map<String, Object?>>()
        .map((json) => _parseTcgApiCard(game, json))
        .where((card) => card.price.marketPrice > 0)
        .toList();
  }

  TradingCard _parseTcgApiCard(TcgGame game, Map<String, Object?> json) {
    final prices = _asMap(json['prices']);
    final price =
        _asDouble(json['price']) ??
        _asDouble(json['market_price']) ??
        _asDouble(prices['market']) ??
        0;
    final set = _asMap(json['set']);

    return TradingCard(
      id: json['id']?.toString() ?? json['card_id']?.toString() ?? '',
      game: game,
      name: json['name']?.toString() ?? 'Unknown card',
      setName:
          json['set_name']?.toString() ??
          set['name']?.toString() ??
          'Unknown set',
      collectorNumber:
          json['collector_number']?.toString() ??
          json['number']?.toString() ??
          '',
      rarity: json['rarity']?.toString() ?? 'Unknown rarity',
      variant:
          json['printing']?.toString() ??
          json['variant']?.toString() ??
          'Market',
      price: PriceInfo(
        marketPrice: price,
        currency: json['currency']?.toString() ?? 'USD',
        source: prices.isEmpty ? 'TCG API' : 'TCG API market price',
        freshness:
            json['last_updated_at']?.toString() ??
            json['last_updated']?.toString() ??
            'Freshness unavailable',
      ),
      imageUrl: json['image_url']?.toString() ?? json['image']?.toString(),
    );
  }
}

Future<Map<String, Object?>> _getJson(
  Uri uri, {
  Map<String, String> headers = const {},
}) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
  try {
    final request = await client.getUrl(uri);
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    request.headers.set(HttpHeaders.userAgentHeader, 'SefCG/1.0');
    for (final entry in headers.entries) {
      request.headers.set(entry.key, entry.value);
    }
    final response = await request.close().timeout(const Duration(seconds: 20));
    final body = await utf8.decodeStream(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CardApiException(_apiFailureMessage(response.statusCode, body));
    }
    final decoded = jsonDecode(body);
    if (decoded is Map<String, Object?>) {
      return decoded;
    }
    throw const CardApiException('API returned an invalid JSON payload.');
  } on SocketException catch (error) {
    throw CardApiException('Network error: ${error.message}');
  } on HttpException catch (error) {
    throw CardApiException('HTTP error: ${error.message}');
  } on TimeoutException {
    throw const CardApiException('API request timed out.');
  } on FormatException {
    throw const CardApiException('API returned malformed JSON.');
  } finally {
    client.close(force: true);
  }
}

String _apiFailureMessage(int statusCode, String body) {
  if (statusCode == 402 && body.contains('X-PAYMENT')) {
    return 'TCG API requires an X-PAYMENT authorization for search. Use Pokemon search without TCG credentials, or run Riftbound search through a backend that can attach the required payment header.';
  }
  if (statusCode == 401 || statusCode == 403) {
    return 'API request is not authorized. Check the configured API key or backend credentials.';
  }
  if (statusCode >= 500) {
    return 'API server error ($statusCode). Try again later.';
  }
  return 'API request failed ($statusCode). $body';
}

Map<String, Object?> _asMap(Object? value) {
  if (value is Map) {
    return value.map((key, value) => MapEntry(key.toString(), value));
  }
  return const {};
}

double? _asDouble(Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    return double.tryParse(value);
  }
  return null;
}

int? _asInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value);
  }
  return null;
}

class SefCgApp extends StatelessWidget {
  const SefCgApp({super.key, required this.repository, this.collectionStore});

  final CollectionStore? collectionStore;

  final CardPriceRepository repository;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SefCG',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2563EB)),
        useMaterial3: true,
      ),
      home: AppShell(repository: repository, collectionStore: collectionStore),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.repository, this.collectionStore});

  final CollectionStore? collectionStore;

  final CardPriceRepository repository;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  var _selectedIndex = 0;
  var _selectedGame = TcgGame.pokemon;
  final _collection = <CollectionEntry>[];

  late final CollectionStore _store =
      widget.collectionStore ?? FileCollectionStore();
  bool _loading = true;
  bool _saving = false;
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    _loadCollection();
  }

  Future<void> _loadCollection() async {
    setState(() {
      _loading = true;
      _loadFailed = false;
    });
    try {
      final entries = await _store.load();
      if (!mounted) return;
      setState(() {
        _collection.clear();
        _collection.addAll(entries);
      });
    } catch (_) {
      if (mounted) setState(() => _loadFailed = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<bool> _saveCollection(List<CollectionEntry> entries) async {
    setState(() => _saving = true);
    try {
      await _store.save(entries);
      if (!mounted) return false;
      setState(() {
        _collection.clear();
        _collection.addAll(entries);
      });
      return true;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not save collection. Your previous collection is unchanged. Please try again.',
            ),
          ),
        );
      }
      return false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _openCard(TradingCard card) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) =>
            CardDetailScreen(card: card, onAddToCollection: _addToCollection),
      ),
    );
  }

  Future<void> _addToCollection(TradingCard card) async {
    if (_saving || _refreshing) return;
    final entry = await showDialog<CollectionEntry>(
      context: context,
      builder: (_) => CollectionEntryDialog(card: card),
    );
    if (entry == null || !mounted) return;
    if (!await _saveCollection([..._collection, entry]) || !mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('${card.name} added to collection')));
  }

  Future<void> _editEntry(CollectionEntry entry) async {
    final updated = await showDialog<CollectionEntry>(
      context: context,
      builder: (_) => CollectionEntryDialog(card: entry.card, entry: entry),
    );
    if (updated == null || !mounted) return;
    final index = _collection.indexOf(entry);
    if (index >= 0) {
      final entries = List<CollectionEntry>.of(_collection);
      entries[index] = updated;
      await _saveCollection(entries);
    }
  }

  bool _refreshing = false;

  Future<void> _refreshPrices() async {
    setState(() => _refreshing = true);
    var failures = 0;
    final updatedEntries = List<CollectionEntry>.of(_collection);
    for (final entry in List<CollectionEntry>.of(_collection)) {
      try {
        final cards = await widget.repository.searchCards(
          entry.card.game,
          entry.card.name,
        );
        final matches = cards.where(
          (card) =>
              card.id == entry.card.id &&
              card.variant == entry.card.variant &&
              card.price.currency == entry.card.price.currency &&
              card.price.marketPrice.isFinite &&
              card.price.marketPrice >= 0,
        );
        if (matches.isEmpty) {
          failures++;
          continue;
        }
        if (!mounted) return;
        final index = _collection.indexOf(entry);
        if (index >= 0) {
          updatedEntries[index] = CollectionEntry(
            card: matches.first,
            quantity: entry.quantity,
            purchasePrice: entry.purchasePrice,
            condition: entry.condition,
          );
        }
      } catch (_) {
        failures++;
      }
    }
    if (!mounted) return;
    final saved = await _saveCollection(updatedEntries);
    if (!mounted) return;
    setState(() => _refreshing = false);
    if (!saved) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          failures == 0
              ? 'Market prices updated'
              : '$failures prices could not be updated. Previous values retained.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _loadFailed) {
      return Scaffold(
        body: Center(
          child: _loading
              ? const CircularProgressIndicator()
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Could not load your saved collection. Saved data has been left untouched.',
                    ),
                    TextButton(
                      onPressed: _loadCollection,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
        ),
      );
    }
    final screens = [
      SearchScreen(
        repository: widget.repository,
        selectedGame: _selectedGame,
        onGameChanged: (game) => setState(() => _selectedGame = game),
        onOpenCard: _openCard,
      ),
      ScannerScreen(
        repository: widget.repository,
        selectedGame: _selectedGame,
        onGameChanged: (game) => setState(() => _selectedGame = game),
        onOpenCard: _openCard,
      ),
      CollectionScreen(
        entries: _collection,
        onOpenCard: _openCard,
        onEditEntry: _refreshing ? null : _editEntry,
        onRefresh: _refreshPrices,
        refreshing: _refreshing,
      ),
    ];

    return Scaffold(
      body: Stack(
        children: [
          screens[_selectedIndex],
          if (_saving || _refreshing) ...[
            const ModalBarrier(dismissible: false, color: Colors.black26),
            const Center(child: CircularProgressIndicator()),
          ],
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _saving || _refreshing
            ? null
            : (index) => setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.search), label: 'Search'),
          NavigationDestination(
            icon: Icon(Icons.center_focus_strong, key: Key('scan_nav')),
            label: 'Scan',
          ),
          NavigationDestination(
            icon: Icon(Icons.collections_bookmark, key: Key('collection_nav')),
            label: 'Collection',
          ),
        ],
      ),
    );
  }
}

class SearchScreen extends StatefulWidget {
  const SearchScreen({
    super.key,
    required this.repository,
    required this.selectedGame,
    required this.onGameChanged,
    required this.onOpenCard,
  });

  final CardPriceRepository repository;
  final TcgGame selectedGame;
  final ValueChanged<TcgGame> onGameChanged;
  final ValueChanged<TradingCard> onOpenCard;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _queryController = TextEditingController();
  List<TradingCard> _results = const [];
  Object? _error;
  var _isLoading = false;
  var _requestId = 0;

  @override
  void didUpdateWidget(SearchScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedGame != widget.selectedGame) {
      _search();
    }
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _queryController.text.trim();
    final requestId = ++_requestId;
    if (query.isEmpty) {
      setState(() {
        _results = const [];
        _error = null;
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final results = await widget.repository.searchCards(
        widget.selectedGame,
        query,
      );
      if (!mounted || requestId != _requestId) {
        return;
      }
      setState(() {
        _results = results;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted || requestId != _requestId) {
        return;
      }
      setState(() {
        _results = const [];
        _error = error;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          const AppHeader(
            title: 'TCG Price Checker',
            subtitle: 'Find the exact printing before relying on a price.',
          ),
          const SizedBox(height: 16),
          GameSelector(
            selectedGame: widget.selectedGame,
            onChanged: widget.onGameChanged,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _queryController,
            onSubmitted: (_) => _search(),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                tooltip: 'Search',
                onPressed: _search,
                icon: const Icon(Icons.arrow_forward),
              ),
              labelText: 'Search name, number, or set',
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_error != null)
            EmptyState(
              icon: Icons.cloud_off,
              title: _errorTitle(_error),
              message: _error.toString(),
            )
          else if (_queryController.text.trim().isEmpty)
            const EmptyState(
              icon: Icons.manage_search,
              title: 'Search live card prices',
              message: 'Enter a card name, collector number, or set.',
            )
          else if (_results.isEmpty)
            const EmptyState(
              icon: Icons.search_off,
              title: 'No cards found',
              message: 'Try a broader name or number.',
            )
          else ...[
            Text(
              '${_results.length} matching cards',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            for (final card in _results)
              CardTile(card: card, onTap: () => widget.onOpenCard(card)),
          ],
        ],
      ),
    );
  }

  String _errorTitle(Object? error) {
    final message = error.toString();
    if (message.contains('X-PAYMENT') ||
        message.contains('not authorized') ||
        message.contains('API key')) {
      return 'API credentials required';
    }
    if (message.contains('server error')) {
      return 'Price API error';
    }
    return 'Price API unavailable';
  }
}

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({
    super.key,
    required this.repository,
    required this.selectedGame,
    required this.onGameChanged,
    required this.onOpenCard,
  });

  final CardPriceRepository repository;
  final TcgGame selectedGame;
  final ValueChanged<TcgGame> onGameChanged;
  final ValueChanged<TradingCard> onOpenCard;

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final _ocrController = TextEditingController();
  List<CandidateMatch> _candidates = const [];
  Object? _error;
  bool _hasScanned = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _ocrController.dispose();
    super.dispose();
  }

  Future<void> _runRecognition() async {
    final evidence = _ocrController.text.trim();
    if (evidence.isEmpty) {
      return;
    }

    setState(() {
      _isLoading = true;
      _hasScanned = true;
      _error = null;
    });

    try {
      final candidates = await widget.repository.identifyCard(
        widget.selectedGame,
        evidence,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _candidates = candidates;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _candidates = const [];
        _error = error;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final topScore = _candidates.isEmpty ? 0 : _candidates.first.score;
    final secondScore = _candidates.length < 2 ? 0 : _candidates[1].score;
    final hasLikelyMatch = topScore >= 80 && topScore - secondScore >= 20;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          const AppHeader(
            title: 'Card Scanner',
            subtitle: 'Paste OCR text to match live priced printings.',
          ),
          const SizedBox(height: 16),
          GameSelector(
            selectedGame: widget.selectedGame,
            onChanged: widget.onGameChanged,
          ),
          const SizedBox(height: 16),
          const ScannerFrame(),
          const SizedBox(height: 16),
          TextField(
            controller: _ocrController,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.document_scanner),
              labelText: 'Recognized OCR text',
              hintText: 'Example: Pikachu ex 057/191',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _isLoading ? null : _runRecognition,
            icon: const Icon(Icons.manage_search),
            label: const Text('Match Card'),
          ),
          const SizedBox(height: 20),
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_error != null)
            EmptyState(
              icon: Icons.cloud_off,
              title: _errorTitle(_error),
              message: _error.toString(),
            )
          else if (_hasScanned && _candidates.isEmpty)
            const EmptyState(
              icon: Icons.error_outline,
              title: 'No confident candidates',
              message:
                  'Manual search remains available when recognition fails.',
            )
          else if (hasLikelyMatch)
            LikelyMatchCard(
              match: _candidates.first,
              onOpenCard: widget.onOpenCard,
            )
          else if (_candidates.isNotEmpty) ...[
            Text(
              'Choose the exact printing',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            for (final match in _candidates)
              CardTile(
                card: match.card,
                trailing: Text('${match.score}%'),
                onTap: () => widget.onOpenCard(match.card),
              ),
          ],
        ],
      ),
    );
  }

  String _errorTitle(Object? error) {
    final message = error.toString();
    if (message.contains('X-PAYMENT') ||
        message.contains('not authorized') ||
        message.contains('API key')) {
      return 'API credentials required';
    }
    if (message.contains('server error')) {
      return 'Price API error';
    }
    return 'Price API unavailable';
  }
}

class CollectionEntryDialog extends StatefulWidget {
  const CollectionEntryDialog({super.key, required this.card, this.entry});
  final TradingCard card;
  final CollectionEntry? entry;

  @override
  State<CollectionEntryDialog> createState() => _CollectionEntryDialogState();
}

class _CollectionEntryDialogState extends State<CollectionEntryDialog> {
  final _form = GlobalKey<FormState>();
  late final _price = TextEditingController(
    text: widget.entry?.purchasePrice.toStringAsFixed(2) ?? '',
  );
  late final _quantity = TextEditingController(
    text: '${widget.entry?.quantity ?? 1}',
  );

  @override
  void dispose() {
    _price.dispose();
    _quantity.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.entry == null ? 'Add to collection' : 'Edit purchase'),
    content: SingleChildScrollView(
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.card.name),
            TextFormField(
              key: const Key('purchase_price'),
              controller: _price,
              decoration: InputDecoration(
                labelText:
                    'Bought price per card (${widget.card.price.currency})',
                helperText: 'Enter 0 for a gift or free card.',
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              validator: (value) {
                final price = double.tryParse(value?.trim() ?? '');
                if (price == null ||
                    !price.isFinite ||
                    price < 0 ||
                    !RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(value!.trim())) {
                  return 'Enter a non-negative amount with up to 2 decimals.';
                }
                return null;
              },
            ),
            TextFormField(
              key: const Key('purchase_quantity'),
              controller: _quantity,
              decoration: const InputDecoration(labelText: 'Quantity'),
              keyboardType: TextInputType.number,
              validator: (value) {
                final quantity = int.tryParse(value ?? '');
                return quantity == null || quantity < 1 || quantity > 1000000
                    ? 'Enter a quantity from 1 to 1000000.'
                    : null;
              },
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          if (!_form.currentState!.validate()) return;
          Navigator.pop(
            context,
            CollectionEntry(
              card: widget.card,
              quantity: int.parse(_quantity.text),
              purchasePrice: double.parse(_price.text.trim()),
              condition: widget.entry?.condition ?? 'Near Mint',
            ),
          );
        },
        child: const Text('Save'),
      ),
    ],
  );
}

class CollectionScreen extends StatelessWidget {
  const CollectionScreen({
    super.key,
    required this.entries,
    required this.onOpenCard,
    this.onEditEntry,
    this.onRefresh,
    this.refreshing = false,
  });

  final List<CollectionEntry> entries;
  final ValueChanged<TradingCard> onOpenCard;
  final ValueChanged<CollectionEntry>? onEditEntry;
  final VoidCallback? onRefresh;
  final bool refreshing;

  @override
  Widget build(BuildContext context) {
    final currencies = entries
        .map((entry) => entry.card.price.currency)
        .toSet();
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          const AppHeader(
            title: 'Collection Portfolio',
            subtitle: 'Your card net worth and unrealised profit or loss.',
          ),
          const SizedBox(height: 16),
          if (entries.isEmpty)
            const PortfolioSummary(
              acquisitionCost: 0,
              currentValue: 0,
              gainLoss: 0,
              returnRate: null,
              currency: 'USD',
            ),
          for (final currency in currencies)
            PortfolioSummary.fromEntries(
              entries
                  .where((entry) => entry.card.price.currency == currency)
                  .toList(),
              currency,
            ),
          if (entries.isNotEmpty)
            TextButton.icon(
              onPressed: refreshing ? null : onRefresh,
              icon: const Icon(Icons.refresh),
              label: Text(
                refreshing ? 'Refreshing prices?' : 'Refresh market prices',
              ),
            ),
          const Text(
            'Net worth = current card values. Profit/loss = current values minus bought prices. Totals include quantity.',
          ),
          if (currencies.length > 1)
            const Text(
              'Currencies are shown separately; no exchange-rate conversion is applied.',
            ),
          const SizedBox(height: 16),
          Text(
            'Personal Collection',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          if (entries.isEmpty)
            const EmptyState(
              icon: Icons.inventory_2_outlined,
              title: 'No cards yet',
              message: 'Add exact printings from card details.',
            )
          else
            for (final entry in entries)
              CollectionTile(
                entry: entry,
                onTap: () => onOpenCard(entry.card),
                onEdit: onEditEntry == null ? null : () => onEditEntry!(entry),
              ),
          const SizedBox(height: 12),
          const Text(
            'Prices are market estimates. Use Refresh market prices to fetch the latest available values. Collection is saved automatically on this device.',
          ),
        ],
      ),
    );
  }
}

class CardDetailScreen extends StatelessWidget {
  const CardDetailScreen({
    super.key,
    required this.card,
    required this.onAddToCollection,
  });

  final TradingCard card;
  final ValueChanged<TradingCard> onAddToCollection;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(card.name)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            CardPreview(card: card, height: 260),
            const SizedBox(height: 20),
            Text(card.name, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                InfoChip(label: card.game.label),
                InfoChip(label: card.setName),
                InfoChip(label: card.collectorNumber),
                InfoChip(label: card.rarity),
                InfoChip(label: card.variant),
              ],
            ),
            const SizedBox(height: 20),
            PricePanel(price: card.price),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => onAddToCollection(card),
              icon: const Icon(Icons.add),
              label: const Text('Add to Collection'),
            ),
          ],
        ),
      ),
    );
  }
}

class AppHeader extends StatelessWidget {
  const AppHeader({super.key, required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 6),
        Text(subtitle, style: Theme.of(context).textTheme.bodyLarge),
      ],
    );
  }
}

class GameSelector extends StatelessWidget {
  const GameSelector({
    super.key,
    required this.selectedGame,
    required this.onChanged,
  });

  final TcgGame selectedGame;
  final ValueChanged<TcgGame> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<TcgGame>(
      segments: const [
        ButtonSegment(
          value: TcgGame.pokemon,
          icon: Icon(Icons.catching_pokemon),
          label: Text('Pokemon'),
        ),
        ButtonSegment(
          value: TcgGame.riftbound,
          icon: Icon(Icons.shield),
          label: Text('Riftbound'),
        ),
      ],
      selected: {selectedGame},
      onSelectionChanged: (selection) => onChanged(selection.first),
    );
  }
}

class CardTile extends StatelessWidget {
  const CardTile({
    super.key,
    required this.card,
    required this.onTap,
    this.trailing,
  });

  final TradingCard card;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        onTap: onTap,
        leading: CardPreview(card: card, height: 56),
        title: Text(card.name),
        subtitle: Text('${card.setName} - ${card.collectorNumber}'),
        trailing:
            trailing ??
            Text(
              '${card.price.currency} ${card.price.marketPrice.toStringAsFixed(2)}',
            ),
      ),
    );
  }
}

class CardPreview extends StatelessWidget {
  const CardPreview({super.key, required this.card, required this.height});

  final TradingCard card;
  final double height;

  @override
  Widget build(BuildContext context) {
    final width = height * 0.72;
    final imageUrl = card.imageUrl;
    if (imageUrl != null && imageUrl.isNotEmpty) {
      return Semantics(
        label: '${card.name} card image',
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            imageUrl,
            width: width,
            height: height,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) =>
                _CardPlaceholder(card: card, height: height),
          ),
        ),
      );
    }
    return _CardPlaceholder(card: card, height: height);
  }
}

class _CardPlaceholder extends StatelessWidget {
  const _CardPlaceholder({required this.card, required this.height});

  final TradingCard card;
  final double height;

  @override
  Widget build(BuildContext context) {
    final width = height * 0.72;
    final compact = height < 80;
    return Semantics(
      label: '${card.name} card image placeholder',
      child: Container(
        width: width,
        height: height,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: card.game == TcgGame.pokemon
                ? const [Color(0xFFFFD447), Color(0xFF2F6FDB)]
                : const [Color(0xFF14B8A6), Color(0xFF0F172A)],
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x26000000),
              blurRadius: 12,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.all(compact ? 4 : 10),
          child: compact
              ? Icon(
                  card.game == TcgGame.pokemon
                      ? Icons.catching_pokemon
                      : Icons.shield,
                  color: Colors.white,
                  size: height * 0.42,
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      card.game.label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Icon(
                      card.game == TcgGame.pokemon
                          ? Icons.catching_pokemon
                          : Icons.shield,
                      color: Colors.white,
                      size: height * 0.18,
                    ),
                    Text(
                      card.collectorNumber,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class ScannerFrame extends StatelessWidget {
  const ScannerFrame({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AspectRatio(
      aspectRatio: 1.2,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: AspectRatio(
            aspectRatio: 0.72,
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: colorScheme.primary, width: 3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.camera_alt,
                color: colorScheme.primary,
                size: 44,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class LikelyMatchCard extends StatelessWidget {
  const LikelyMatchCard({
    super.key,
    required this.match,
    required this.onOpenCard,
  });

  final CandidateMatch match;
  final ValueChanged<TradingCard> onOpenCard;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Likely match',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            CardTile(card: match.card, onTap: () => onOpenCard(match.card)),
            const SizedBox(height: 8),
            Text('Confidence score: ${match.score}%'),
          ],
        ),
      ),
    );
  }
}

class PricePanel extends StatelessWidget {
  const PricePanel({super.key, required this.price});

  final PriceInfo price;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Reference market price',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              '${price.currency} ${price.marketPrice.toStringAsFixed(2)}',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text('${price.source} - ${price.freshness}'),
          ],
        ),
      ),
    );
  }
}

class PortfolioSummary extends StatelessWidget {
  const PortfolioSummary({
    super.key,
    required this.acquisitionCost,
    required this.currentValue,
    required this.gainLoss,
    required this.returnRate,
    required this.currency,
  });

  final double acquisitionCost;
  final double currentValue;
  final double gainLoss;
  final double? returnRate;
  final String currency;

  factory PortfolioSummary.fromEntries(
    List<CollectionEntry> entries,
    String currency,
  ) {
    final cost = entries.fold<double>(
      0,
      (total, entry) => total + entry.acquisitionCost,
    );
    final value = entries.fold<double>(
      0,
      (total, entry) => total + entry.currentValue,
    );
    return PortfolioSummary(
      acquisitionCost: cost,
      currentValue: value,
      gainLoss: value - cost,
      returnRate: cost == 0 ? null : (value - cost) / cost,
      currency: currency,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            MetricRow(
              label: 'Collection Net Worth',
              value: '$currency ${currentValue.toStringAsFixed(2)}',
            ),
            MetricRow(
              label: 'Acquisition Cost',
              value: '$currency ${acquisitionCost.toStringAsFixed(2)}',
            ),
            MetricRow(
              label: 'Unrealised Gain/Loss',
              value:
                  '${gainLoss > 0 ? '+' : ''}$currency ${gainLoss.toStringAsFixed(2)}',
            ),
            MetricRow(
              label: 'Estimated Return',
              value: returnRate == null
                  ? 'N/A'
                  : '${(returnRate! * 100).toStringAsFixed(1)}%',
            ),
          ],
        ),
      ),
    );
  }
}

class MetricRow extends StatelessWidget {
  const MetricRow({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class CollectionTile extends StatelessWidget {
  const CollectionTile({
    super.key,
    required this.entry,
    required this.onTap,
    this.onEdit,
  });

  final CollectionEntry entry;
  final VoidCallback onTap;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        onTap: onTap,
        leading: CardPreview(card: entry.card, height: 56),
        title: Text(entry.card.name),
        subtitle: Text(
          '${entry.quantity}x - ${entry.condition}\n'
          'Bought: ${entry.card.price.currency} ${entry.purchasePrice.toStringAsFixed(2)} each\n'
          'Market: ${entry.card.price.currency} ${entry.card.price.marketPrice.toStringAsFixed(2)} each\n'
          'Value: ${entry.card.price.currency} ${entry.currentValue.toStringAsFixed(2)}\n'
          '${entry.gainLoss > 0
              ? 'Profit'
              : entry.gainLoss < 0
              ? 'Loss'
              : 'Break even'}: ${entry.card.price.currency} ${entry.gainLoss.toStringAsFixed(2)}',
        ),
        trailing: onEdit == null
            ? null
            : IconButton(
                tooltip: 'Edit purchase',
                onPressed: onEdit,
                icon: const Icon(Icons.edit),
              ),
      ),
    );
  }
}

class InfoChip extends StatelessWidget {
  const InfoChip({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(label: Text(label));
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Icon(icon, size: 44),
          const SizedBox(height: 12),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(message, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
