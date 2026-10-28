import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_windows/path_provider_windows.dart';

import 'app.dart';
import 'controllers/editor_controller.dart';
import 'services/content_policy.dart';
import 'services/document_file_service.dart';
import 'services/link_service.dart';
import 'services/settings_service.dart';
import 'services/window_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final window = NativeEditorWindowService();
  await window.initialize();
  Directory settingsDirectory;
  try {
    final supportPath = await PathProviderWindows().getApplicationSupportPath();
    if (supportPath == null) throw const FileSystemException();
    settingsDirectory = Directory(supportPath);
  } catch (_) {
    settingsDirectory = Directory(
      p.join(
        Platform.environment['LOCALAPPDATA'] ?? Directory.systemTemp.path,
        'LocalMarkdownEditor',
      ),
    );
  }
  final service = JsonSettingsService(
    File(p.join(settingsDirectory.path, 'settings.json')),
  );
  final settings = SettingsController(service, await service.load());
  final paths = LocalPathPolicy();
  final editor = EditorController(
    files: LocalDocumentFileService(paths),
    paths: paths,
  );
  runApp(
    MarkdownEditorApp(
      editor: editor,
      settings: settings,
      window: window,
      policy: ContentPolicy(paths),
      links: BrowserLinkService(),
    ),
  );
  unawaited(window.show());
}
