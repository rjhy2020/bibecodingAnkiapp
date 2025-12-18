import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/anki_status.dart';
import '../models/card_item.dart';
import '../models/deck_item.dart';
import '../services/anki_native_api.dart';

class HomeController extends ChangeNotifier {
  HomeController(this._api);

  final AnkiNativeApi _api;
  static const String _prefsRecentDeckKey = 'recent_deck_id_v1';
  SharedPreferences? _prefs;
  int? _recentDeckId;

  Future<SharedPreferences> _getPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  Future<int?> _getRecentDeckId() async {
    if (_recentDeckId != null) return _recentDeckId;
    final prefs = await _getPrefs();
    final id = prefs.getInt(_prefsRecentDeckKey);
    if (id == null || id <= 0) return null;
    _recentDeckId = id;
    return id;
  }

  Future<void> markDeckStarted(int deckId) async {
    if (deckId <= 0) return;
    _recentDeckId = deckId;
    try {
      final prefs = await _getPrefs();
      await prefs.setInt(_prefsRecentDeckKey, deckId);
    } catch (_) {
      // ignore
    }

    selectedDeckId = deckId;
    if (decks.isNotEmpty) {
      final list = List<DeckItem>.from(decks);
      final idx = list.indexWhere((d) => d.deckId == deckId);
      if (idx > 0) {
        final d = list.removeAt(idx);
        list.insert(0, d);
        decks = list;
      }
    }
    notifyListeners();
  }

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
      final ordered = List<DeckItem>.from(list);
      int? nextSelected;
      final recent = await _getRecentDeckId();
      if (recent != null) {
        final idx = ordered.indexWhere((d) => d.deckId == recent);
        if (idx >= 0) {
          nextSelected = recent;
          if (idx > 0) {
            final d = ordered.removeAt(idx);
            ordered.insert(0, d);
          }
        }
      }

      final currentSelected = selectedDeckId;
      final stillExists =
          currentSelected != null && ordered.any((d) => d.deckId == currentSelected);
      if (nextSelected == null && stillExists) {
        nextSelected = currentSelected;
      }

      if (nextSelected == null && ordered.isNotEmpty) {
        var best = ordered.first;
        for (final d in ordered) {
          if ((d.newCount ?? 0) > (best.newCount ?? 0)) best = d;
        }
        nextSelected = best.deckId;
      }

      decks = ordered;
      selectedDeckId = nextSelected;
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
