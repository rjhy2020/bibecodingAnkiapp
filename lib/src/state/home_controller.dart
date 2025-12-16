import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/anki_status.dart';
import '../models/card_item.dart';
import '../models/deck_item.dart';
import '../services/anki_native_api.dart';

class HomeController extends ChangeNotifier {
  HomeController(this._api);

  final AnkiNativeApi _api;

  AnkiStatus? status;
  bool loadingStatus = false;
  bool loadingCards = false;
  bool requestingPermission = false;
  bool loadingDecks = false;

  String? lastErrorCode;
  String? lastErrorMessage;

  int todayLimit = 20;

  List<DeckItem> decks = const [];
  int? selectedDeckId;

  DeckItem? get selectedDeck {
    final id = selectedDeckId;
    if (id == null) return null;
    for (final d in decks) {
      if (d.deckId == id) return d;
    }
    return null;
  }

  Future<void> refreshStatus() async {
    loadingStatus = true;
    lastErrorCode = null;
    lastErrorMessage = null;
    notifyListeners();

    try {
      status = await _api.getStatus();
      lastErrorCode = status?.lastErrorCode;
      lastErrorMessage = status?.lastErrorMessage;
      if (status?.providerAccessible == true) {
        await refreshDecks();
      }
    } on PlatformException catch (e) {
      debugPrint(
        'Anki getStatus failed: code=${e.code} message=${e.message} details=${e.details}',
      );
      lastErrorCode = e.code;
      lastErrorMessage = e.message ?? e.details?.toString();
    } catch (e) {
      lastErrorCode = 'UNKNOWN';
      lastErrorMessage = e.toString();
    } finally {
      loadingStatus = false;
      notifyListeners();
    }
  }

  Future<void> refreshDecks() async {
    loadingDecks = true;
    lastErrorCode = null;
    lastErrorMessage = null;
    notifyListeners();

    try {
      final list = await _api.getDecks();
      decks = list;

      if (decks.isNotEmpty) {
        final currentSelected = selectedDeckId;
        final stillExists =
            currentSelected != null &&
            decks.any((d) => d.deckId == currentSelected);
        if (!stillExists) {
          // Default: deck with the largest newCount, otherwise first.
          decks = List<DeckItem>.from(decks)
            ..sort((a, b) {
              final an = a.newCount ?? 0;
              final bn = b.newCount ?? 0;
              return bn.compareTo(an);
            });
          selectedDeckId = decks.first.deckId;
        }
      } else {
        selectedDeckId = null;
      }
    } on PlatformException catch (e) {
      debugPrint(
        'Anki getDecks failed: code=${e.code} message=${e.message} details=${e.details}',
      );
      lastErrorCode = e.code;
      lastErrorMessage = e.message ?? e.details?.toString();
    } finally {
      loadingDecks = false;
      notifyListeners();
    }
  }

  void selectDeck(int deckId) {
    selectedDeckId = deckId;
    notifyListeners();
  }

  Future<List<CardItem>> loadTodayCards({required int deckId, int? limit}) async {
    final effectiveLimit = limit ?? todayLimit;
    if (effectiveLimit <= 0) {
      lastErrorCode = null;
      lastErrorMessage = null;
      return const <CardItem>[];
    }

    loadingCards = true;
    lastErrorCode = null;
    lastErrorMessage = null;
    notifyListeners();

    try {
      return await _api.getTodayNewCards(deckId: deckId, limit: effectiveLimit);
    } on PlatformException catch (e) {
      debugPrint(
        'Anki getTodayNewCards failed: code=${e.code} message=${e.message} details=${e.details}',
      );
      lastErrorCode = e.code;
      lastErrorMessage = e.message ?? e.details?.toString();
      rethrow;
    } finally {
      loadingCards = false;
      notifyListeners();
    }
  }

  Future<void> openPlayStore() => _api.openPlayStore();
  Future<void> openAnkiDroid() => _api.openAnkiDroid();

  Future<bool> requestAnkiPermission() async {
    requestingPermission = true;
    notifyListeners();
    try {
      return await _api.requestAnkiPermission();
    } finally {
      requestingPermission = false;
      notifyListeners();
      await refreshStatus();
    }
  }
}
