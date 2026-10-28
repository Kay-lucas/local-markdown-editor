import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

class EditorSettings {
  const EditorSettings({this.theme = ThemeMode.system, this.split = .5});
  final ThemeMode theme;
  final double split;
  Map<String, Object> toJson() => {'theme': theme.name, 'split': split};
  factory EditorSettings.fromJson(Map<String, dynamic> json) {
    final theme = ThemeMode.values.firstWhere(
      (t) => t.name == json['theme'],
      orElse: () => ThemeMode.system,
    );
    final raw = json['split'];
    final split = raw is num && raw.isFinite
        ? raw.toDouble().clamp(.28, .72)
        : .5;
    return EditorSettings(theme: theme, split: split);
  }
}

abstract class SettingsService {
  Future<EditorSettings> load();
  Future<void> save(EditorSettings settings);
}

class JsonSettingsService implements SettingsService {
  JsonSettingsService(this.file);
  final File file;
  @override
  Future<EditorSettings> load() async {
    try {
      return EditorSettings.fromJson(
        jsonDecode(await file.readAsString()) as Map<String, dynamic>,
      );
    } catch (_) {
      return const EditorSettings();
    }
  }

  @override
  Future<void> save(EditorSettings settings) async {
    await file.parent.create(recursive: true);
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(jsonEncode(settings.toJson()), flush: true);
    await temp.rename(file.path);
  }
}

class SettingsController extends ChangeNotifier {
  SettingsController(this.service, this.value);
  final SettingsService service;
  EditorSettings value;
  String? error;
  Future<void>? _pending;
  void setTheme(ThemeMode mode) {
    value = EditorSettings(theme: mode, split: value.split);
    notifyListeners();
    persist();
  }

  void setSplit(double ratio) {
    value = EditorSettings(theme: value.theme, split: ratio.clamp(.28, .72));
    notifyListeners();
  }

  void persist() {
    final snapshot = value;
    _pending = (_pending ?? Future<void>.value()).then((_) async {
      try {
        await service.save(snapshot);
      } catch (_) {
        error = '앱 설정을 저장하지 못했습니다. 문서 저장은 계속 사용할 수 있습니다.';
        notifyListeners();
      }
    });
  }

  Future<void> flush() => _pending ?? Future<void>.value();
  void clearError() => error = null;
}
