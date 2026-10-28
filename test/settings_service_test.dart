import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_markdown_editor/services/settings_service.dart';
import 'support/fakes.dart';

void main() {
  test(
    'missing or corrupt settings use defaults and valid settings round-trip',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'markdown_settings_',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}\\settings.json');
      final service = JsonSettingsService(file);
      expect((await service.load()).theme, ThemeMode.system);
      await file.writeAsString('{corrupted');
      expect((await service.load()).split, .5);
      await service.save(
        const EditorSettings(theme: ThemeMode.dark, split: .6),
      );
      final restored = await service.load();
      expect(restored.theme, ThemeMode.dark);
      expect(restored.split, .6);
    },
  );
  test('malformed settings fields are clamped or replaced with defaults', () {
    expect(
      EditorSettings.fromJson({'theme': 'unknown', 'split': 'bad'}).theme,
      ThemeMode.system,
    );
    expect(EditorSettings.fromJson({'split': 4}).split, .72);
    expect(EditorSettings.fromJson({'split': double.nan}).split, .5);
  });
  test(
    'setting failure is reported independently and queued saves recover',
    () async {
      final service = MemorySettings()..fail = true;
      final controller = SettingsController(service, const EditorSettings());
      addTearDown(controller.dispose);
      controller.setTheme(ThemeMode.dark);
      await controller.flush();
      expect(controller.error, isNotNull);
      expect(controller.value.theme, ThemeMode.dark);
      service.fail = false;
      controller.clearError();
      controller.setTheme(ThemeMode.light);
      await controller.flush();
      expect(service.value.theme, ThemeMode.light);
      expect(controller.error, isNull);
    },
  );
}
