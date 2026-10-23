import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'main.dart' show CollectionEntry, TradingCard, PriceInfo, TcgGame;

abstract class CollectionStore {
  Future<List<CollectionEntry>> load();
  Future<void> save(List<CollectionEntry> entries);
}

/// Stores a versioned snapshot in app-private documents, replacing it only
/// after the complete new snapshot has been written and flushed.
class FileCollectionStore implements CollectionStore {
  FileCollectionStore({Future<Directory> Function()? directory})
    : _directory = directory ?? getApplicationDocumentsDirectory;

  final Future<Directory> Function() _directory;

  Future<File> _file() async {
    final directory = await _directory();
    await directory.create(recursive: true);
    return File('${directory.path}/collection.json');
  }

  @override
  Future<List<CollectionEntry>> load() async {
    final file = await _file();
    if (!await file.exists()) return [];
    final data = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    if (data['version'] != 1) {
      throw const FormatException('Unsupported collection version');
    }
    return (data['entries'] as List).map((value) {
      final entry = value as Map<String, dynamic>;
      final card = entry['card'] as Map<String, dynamic>;
      final price = card['price'] as Map<String, dynamic>;
      final quantity = entry['quantity'] as int;
      final bought = (entry['purchasePrice'] as num).toDouble();
      final market = (price['marketPrice'] as num).toDouble();
      if (quantity < 1 ||
          quantity > 1000000 ||
          !bought.isFinite ||
          bought < 0 ||
          !market.isFinite ||
          market < 0) {
        throw const FormatException('Invalid collection values');
      }
      return CollectionEntry(
        quantity: quantity,
        purchasePrice: bought,
        condition: entry['condition'] as String,
        card: TradingCard(
          id: card['id'] as String,
          game: TcgGame.values.byName(card['game'] as String),
          name: card['name'] as String,
          setName: card['setName'] as String,
          collectorNumber: card['collectorNumber'] as String,
          rarity: card['rarity'] as String,
          variant: card['variant'] as String,
          imageUrl: card['imageUrl'] as String?,
          price: PriceInfo(
            marketPrice: market,
            currency: price['currency'] as String,
            source: price['source'] as String,
            freshness: price['freshness'] as String,
          ),
        ),
      );
    }).toList();
  }

  @override
  Future<void> save(List<CollectionEntry> entries) async {
    final encoded = jsonEncode({
      'version': 1,
      'entries': [
        for (final entry in entries)
          {
            'quantity': entry.quantity,
            'purchasePrice': entry.purchasePrice,
            'condition': entry.condition,
            'card': {
              'id': entry.card.id,
              'game': entry.card.game.name,
              'name': entry.card.name,
              'setName': entry.card.setName,
              'collectorNumber': entry.card.collectorNumber,
              'rarity': entry.card.rarity,
              'variant': entry.card.variant,
              'imageUrl': entry.card.imageUrl,
              'price': {
                'marketPrice': entry.card.price.marketPrice,
                'currency': entry.card.price.currency,
                'source': entry.card.price.source,
                'freshness': entry.card.price.freshness,
              },
            },
          },
      ],
    });
    final file = await _file();
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(encoded, flush: true);
    await temporary.rename(file.path);
  }
}
