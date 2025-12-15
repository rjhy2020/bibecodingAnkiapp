import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/model_study_settings.dart';

class StudySettingsController extends ChangeNotifier {
  StudySettingsController() {
    _load();
  }

  static const String _prefsKey = 'study_settings_v1';

  final Map<int, ModelStudySettings> _byModelId = {};
  SharedPreferences? _prefs;
  bool _loaded = false;

  bool get loaded => _loaded;

  ModelStudySettings settingsForModel(int modelId) {
    return _byModelId[modelId] ?? const ModelStudySettings();
  }

  Future<void> saveModelSettings(int modelId, ModelStudySettings settings) async {
    final normalizedHidden = settings.hiddenFieldKeys
        .map((e) => normalizeFieldKey(e))
        .where((e) => e.isNotEmpty)
        .toSet();
    _byModelId[modelId] = settings.copyWith(hiddenFieldKeys: normalizedHidden);
    notifyListeners();
    await _persist();
  }

  Future<void> resetModelSettings(int modelId) async {
    _byModelId.remove(modelId);
    notifyListeners();
    await _persist();
  }

  static String normalizeFieldKey(String name) {
    return name.trim().toLowerCase();
  }

  Future<void> _load() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      final raw = _prefs!.getString(_prefsKey);
      if (raw == null || raw.trim().isEmpty) {
        _loaded = true;
        notifyListeners();
        return;
      }

      final decoded = jsonDecode(raw);
      final modelsRaw = (decoded is Map<String, dynamic>) ? decoded['models'] : null;
      if (modelsRaw is Map) {
        for (final entry in modelsRaw.entries) {
          final key = entry.key;
          final value = entry.value;
          final modelId = int.tryParse(key.toString());
          if (modelId == null) continue;
          if (value is Map) {
            _byModelId[modelId] = ModelStudySettings.fromJson(
              value.map((k, v) => MapEntry(k.toString(), v)),
            );
          }
        }
      }
    } catch (_) {
      // ignore corrupted preferences
    } finally {
      _loaded = true;
      notifyListeners();
    }
  }

  Future<void> _persist() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      final payload = <String, dynamic>{
        'models': _byModelId.map(
          (key, value) => MapEntry(key.toString(), value.toJson()),
        ),
      };
      await _prefs!.setString(_prefsKey, jsonEncode(payload));
    } catch (_) {
      // ignore
    }
  }
}
