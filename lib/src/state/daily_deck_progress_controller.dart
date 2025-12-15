import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/daily_deck_progress.dart';

class DailyDeckProgressController extends ChangeNotifier {
  DailyDeckProgressController() {
    _load();
  }

  static const String _prefsKey = 'daily_deck_progress_v1';

  final Map<int, DailyDeckProgress> _byDeckId = {};
  SharedPreferences? _prefs;
  bool _loaded = false;
  String _dateKey = '';

  bool get loaded => _loaded;
  String get dateKey => _dateKey;

  DailyDeckProgress progressForDeck(int deckId) {
    return _byDeckId[deckId] ?? const DailyDeckProgress.empty();
  }

  bool hasGoalForDeck(int deckId) {
    return progressForDeck(deckId).goalRounds > 0;
  }

  Future<void> setGoalForDeck(int deckId, int goalRounds) async {
    final safeGoal = goalRounds.clamp(1, 99);
    final prev = progressForDeck(deckId);
    _byDeckId[deckId] = prev.copyWith(goalRounds: safeGoal);
    notifyListeners();
    await _persist();
  }

  Future<void> incrementCompletedRounds(int deckId) async {
    final prev = progressForDeck(deckId);
    _byDeckId[deckId] = prev.copyWith(roundsCompleted: prev.roundsCompleted + 1);
    notifyListeners();
    await _persist();
  }

  Future<void> _load() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      final today = _todayKey();

      final raw = _prefs!.getString(_prefsKey);
      if (raw == null || raw.trim().isEmpty) {
        _dateKey = today;
        _loaded = true;
        notifyListeners();
        await _persist();
        return;
      }

      final decoded = jsonDecode(raw);
      final map = decoded is Map ? decoded.map((k, v) => MapEntry(k.toString(), v)) : null;
      final storedDate = map?['date']?.toString();

      if (storedDate != today) {
        _byDeckId.clear();
        _dateKey = today;
        _loaded = true;
        notifyListeners();
        await _persist();
        return;
      }

      _dateKey = storedDate ?? today;
      final decks = map?['decks'];
      if (decks is Map) {
        for (final entry in decks.entries) {
          final deckId = int.tryParse(entry.key.toString());
          if (deckId == null) continue;
          final value = entry.value;
          if (value is Map) {
            _byDeckId[deckId] = DailyDeckProgress.fromJson(
              value.map((k, v) => MapEntry(k.toString(), v)),
            );
          }
        }
      }
    } catch (_) {
      _byDeckId.clear();
      _dateKey = _todayKey();
    } finally {
      _loaded = true;
      notifyListeners();
    }
  }

  Future<void> _persist() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      final payload = <String, dynamic>{
        'date': _dateKey.isEmpty ? _todayKey() : _dateKey,
        'decks': _byDeckId.map((k, v) => MapEntry(k.toString(), v.toJson())),
      };
      await _prefs!.setString(_prefsKey, jsonEncode(payload));
    } catch (_) {
      // ignore
    }
  }

  String _todayKey() {
    final now = DateTime.now();
    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}

