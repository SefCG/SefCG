import 'package:flutter/material.dart';

void main() {
  runApp(const SefCgApp());
}

enum TcgGame {
  pokemon('pokemon', 'Pokemon'),
  riftbound('riftbound', 'Riftbound');

  const TcgGame(this.code, this.label);

  final String code;
  final String label;
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
    required this.palette,
  });

  final String id;
  final TcgGame game;
  final String name;
  final String setName;
  final String collectorNumber;
  final String rarity;
  final String variant;
  final PriceInfo price;
  final List<Color> palette;
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

const sampleCards = <TradingCard>[
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
      currency: 'SGD',
      source: 'Backend price cache',
      freshness: 'Updated 2h ago',
    ),
    palette: [Color(0xFFFFD447), Color(0xFF2F6FDB)],
  ),
  TradingCard(
    id: 'pkm-025-165',
    game: TcgGame.pokemon,
    name: 'Pikachu',
    setName: 'Pokemon 151',
    collectorNumber: '025/165',
    rarity: 'Common',
    variant: 'Reverse Holo',
    price: PriceInfo(
      marketPrice: 3.10,
      currency: 'SGD',
      source: 'Backend price cache',
      freshness: 'Updated today',
    ),
    palette: [Color(0xFFFFE26B), Color(0xFF4B5563)],
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
      currency: 'SGD',
      source: 'Backend price cache',
      freshness: 'Updated 45m ago',
    ),
    palette: [Color(0xFFE85D04), Color(0xFF7C2D12)],
  ),
  TradingCard(
    id: 'pkm-199-197',
    game: TcgGame.pokemon,
    name: 'Charizard ex',
    setName: 'Obsidian Flames',
    collectorNumber: '199/197',
    rarity: 'Special Illustration Rare',
    variant: 'Holofoil',
    price: PriceInfo(
      marketPrice: 84.50,
      currency: 'SGD',
      source: 'Backend price cache',
      freshness: 'Updated yesterday',
    ),
    palette: [Color(0xFFEF4444), Color(0xFF111827)],
  ),
  TradingCard(
    id: 'rift-yasuo-024',
    game: TcgGame.riftbound,
    name: 'Yasuo, Unforgiven',
    setName: 'Origins',
    collectorNumber: '024/298',
    rarity: 'Champion',
    variant: 'Standard',
    price: PriceInfo(
      marketPrice: 18.80,
      currency: 'SGD',
      source: 'Backend price cache',
      freshness: 'Updated 3h ago',
    ),
    palette: [Color(0xFF14B8A6), Color(0xFF0F172A)],
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
      currency: 'SGD',
      source: 'Backend price cache',
      freshness: 'Updated today',
    ),
    palette: [Color(0xFFEC4899), Color(0xFF2563EB)],
  ),
  TradingCard(
    id: 'rift-ahri-112',
    game: TcgGame.riftbound,
    name: 'Ahri, Nine-Tailed Fox',
    setName: 'Spirit Bonds',
    collectorNumber: '112/240',
    rarity: 'Epic',
    variant: 'Standard',
    price: PriceInfo(
      marketPrice: 9.75,
      currency: 'SGD',
      source: 'Backend price cache',
      freshness: 'Updated 6h ago',
    ),
    palette: [Color(0xFFA855F7), Color(0xFF0891B2)],
  ),
];

class SefCgApp extends StatelessWidget {
  const SefCgApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SefCG',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2563EB)),
        useMaterial3: true,
      ),
      home: const AppShell(),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  var _selectedIndex = 0;
  var _selectedGame = TcgGame.pokemon;
  final _collection = <CollectionEntry>[
    CollectionEntry(
      card: sampleCards[2],
      quantity: 1,
      purchasePrice: 120,
      condition: 'Near Mint',
    ),
  ];

  void _openCard(TradingCard card) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) =>
            CardDetailScreen(card: card, onAddToCollection: _addToCollection),
      ),
    );
  }

  void _addToCollection(TradingCard card) {
    setState(() {
      _collection.add(
        CollectionEntry(
          card: card,
          quantity: 1,
          purchasePrice: card.price.marketPrice,
          condition: 'Near Mint',
        ),
      );
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('${card.name} added to collection')));
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      SearchScreen(
        selectedGame: _selectedGame,
        onGameChanged: (game) => setState(() => _selectedGame = game),
        onOpenCard: _openCard,
      ),
      ScannerScreen(
        selectedGame: _selectedGame,
        onGameChanged: (game) => setState(() => _selectedGame = game),
        onOpenCard: _openCard,
      ),
      CollectionScreen(entries: _collection, onOpenCard: _openCard),
    ];

    return Scaffold(
      body: screens[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) =>
            setState(() => _selectedIndex = index),
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
    required this.selectedGame,
    required this.onGameChanged,
    required this.onOpenCard,
  });

  final TcgGame selectedGame;
  final ValueChanged<TcgGame> onGameChanged;
  final ValueChanged<TradingCard> onOpenCard;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _queryController = TextEditingController();

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  List<TradingCard> get _results {
    final query = _queryController.text.trim().toLowerCase();
    return sampleCards.where((card) {
      if (card.game != widget.selectedGame) {
        return false;
      }
      if (query.isEmpty) {
        return true;
      }
      final haystack = '${card.name} ${card.collectorNumber} ${card.setName}'
          .toLowerCase();
      return query
          .split(RegExp(r'\s+'))
          .where((token) => token.isNotEmpty)
          .every(haystack.contains);
    }).toList();
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
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              labelText: 'Search name, number, or set',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '${_results.length} matching cards',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          for (final card in _results)
            CardTile(card: card, onTap: () => widget.onOpenCard(card)),
        ],
      ),
    );
  }
}

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({
    super.key,
    required this.selectedGame,
    required this.onGameChanged,
    required this.onOpenCard,
  });

  final TcgGame selectedGame;
  final ValueChanged<TcgGame> onGameChanged;
  final ValueChanged<TradingCard> onOpenCard;

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final _ocrController = TextEditingController();
  List<CandidateMatch> _candidates = const [];
  bool _hasScanned = false;

  @override
  void dispose() {
    _ocrController.dispose();
    super.dispose();
  }

  void _useSampleScan() {
    _ocrController.text = widget.selectedGame == TcgGame.pokemon
        ? 'Pikachu ex 057/191 Double Rare'
        : 'Jinx Loose Cannon 041/298 Champion';
    _runRecognition();
  }

  void _runRecognition() {
    final evidence = _ocrController.text.trim().toLowerCase();
    final matches =
        sampleCards
            .where((card) => card.game == widget.selectedGame)
            .map(
              (card) =>
                  CandidateMatch(card: card, score: _score(card, evidence)),
            )
            .where((match) => match.score > 0)
            .toList()
          ..sort((a, b) => b.score.compareTo(a.score));

    setState(() {
      _hasScanned = true;
      _candidates = matches.take(5).toList();
    });
  }

  int _score(TradingCard card, String evidence) {
    var score = 0;
    if (evidence.contains(card.collectorNumber.toLowerCase())) {
      score += 70;
    }
    if (evidence.contains(card.setName.toLowerCase())) {
      score += 20;
    }
    for (final token in card.name.toLowerCase().split(RegExp(r'[\s,]+'))) {
      if (token.length > 2 && evidence.contains(token)) {
        score += 12;
      }
    }
    if (evidence.contains(card.rarity.toLowerCase())) {
      score += 8;
    }
    return score;
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
            subtitle: 'OCR-first matching ranks exact numbers before artwork.',
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
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _runRecognition,
                  icon: const Icon(Icons.manage_search),
                  label: const Text('Match Card'),
                ),
              ),
              const SizedBox(width: 12),
              IconButton.filledTonal(
                tooltip: 'Use sample scan',
                onPressed: _useSampleScan,
                icon: const Icon(Icons.auto_fix_high),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_hasScanned && _candidates.isEmpty)
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
}

class CollectionScreen extends StatelessWidget {
  const CollectionScreen({
    super.key,
    required this.entries,
    required this.onOpenCard,
  });

  final List<CollectionEntry> entries;
  final ValueChanged<TradingCard> onOpenCard;

  @override
  Widget build(BuildContext context) {
    final acquisitionCost = entries.fold<double>(
      0,
      (total, entry) => total + entry.acquisitionCost,
    );
    final currentValue = entries.fold<double>(
      0,
      (total, entry) => total + entry.currentValue,
    );
    final gainLoss = currentValue - acquisitionCost;
    final returnRate = acquisitionCost == 0 ? 0.0 : gainLoss / acquisitionCost;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          const AppHeader(
            title: 'Collection Portfolio',
            subtitle: 'Private estimated values and unrealised gain/loss.',
          ),
          const SizedBox(height: 16),
          PortfolioSummary(
            acquisitionCost: acquisitionCost,
            currentValue: currentValue,
            gainLoss: gainLoss,
            returnRate: returnRate,
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
              CollectionTile(entry: entry, onTap: () => onOpenCard(entry.card)),
          const SizedBox(height: 12),
          Text(
            'Values are estimates based on reference market pricing.',
            style: Theme.of(context).textTheme.bodySmall,
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
            colors: card.palette,
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
  });

  final double acquisitionCost;
  final double currentValue;
  final double gainLoss;
  final double returnRate;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            MetricRow(
              label: 'Estimated Value',
              value: 'SGD ${currentValue.toStringAsFixed(2)}',
            ),
            MetricRow(
              label: 'Acquisition Cost',
              value: 'SGD ${acquisitionCost.toStringAsFixed(2)}',
            ),
            MetricRow(
              label: 'Unrealised Gain/Loss',
              value: 'SGD ${gainLoss.toStringAsFixed(2)}',
            ),
            MetricRow(
              label: 'Estimated Return',
              value: '${(returnRate * 100).toStringAsFixed(1)}%',
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
  const CollectionTile({super.key, required this.entry, required this.onTap});

  final CollectionEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        onTap: onTap,
        leading: CardPreview(card: entry.card, height: 56),
        title: Text(entry.card.name),
        subtitle: Text(
          '${entry.quantity}x - ${entry.condition} - Cost SGD ${entry.purchasePrice.toStringAsFixed(2)}',
        ),
        trailing: Text('SGD ${entry.currentValue.toStringAsFixed(2)}'),
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
