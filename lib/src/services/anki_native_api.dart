import 'package:flutter/services.dart';

import '../models/anki_status.dart';
import '../models/card_item.dart';
import '../models/deck_item.dart';

class AnkiNativeApi {
  const AnkiNativeApi();

  static const MethodChannel _channel = MethodChannel('anki_provider');

  Future<AnkiStatus> getStatus() async {
    final map = await _channel.invokeMethod<Map<dynamic, dynamic>>('getStatus');
    return AnkiStatus.fromMap(map ?? const {});
  }

  Future<List<DeckItem>> getDecks() async {
    final list = await _channel.invokeMethod<List<dynamic>>('getDecks');
    final result = <DeckItem>[];
    for (final item in list ?? const []) {
      if (item is Map) result.add(DeckItem.fromMap(item));
    }
    return result;
  }

  Future<List<CardItem>> getTodayNewCards({
    required int deckId,
    int limit = 20,
  }) async {
    final list = await _channel.invokeMethod<List<dynamic>>(
      'getTodayNewCards',
      {'deckId': deckId, 'limit': limit},
    );
    final result = <CardItem>[];
    for (final item in list ?? const []) {
      if (item is Map) result.add(CardItem.fromMap(item));
    }
    return result;
  }

  Future<void> openPlayStore() async {
    await _channel.invokeMethod<void>('openPlayStore');
  }

  Future<void> openAnkiDroid() async {
    await _channel.invokeMethod<void>('openAnkiDroid');
  }

  Future<bool> requestAnkiPermission() async {
    final granted = await _channel.invokeMethod<bool>('requestAnkiPermission');
    return granted == true;
  }

  Future<Map<String, dynamic>> appendToNoteField({
    required int noteId,
    required int modelId,
    required String targetFieldKey,
    required String generatedText,
  }) async {
    final map = await _channel.invokeMethod<Map<dynamic, dynamic>>(
      'appendToNoteField',
      {
        'noteId': noteId,
        'modelId': modelId,
        'targetFieldKey': targetFieldKey,
        'generatedText': generatedText,
      },
    );
    return (map ?? const {}).map(
      (key, value) => MapEntry(key.toString(), value),
    );
  }
}
