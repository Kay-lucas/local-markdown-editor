import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:local_markdown_editor/models/document_state.dart';
import 'package:local_markdown_editor/services/document_file_service.dart';
import 'package:local_markdown_editor/services/editor_interaction.dart';
import 'package:local_markdown_editor/services/link_service.dart';
import 'package:local_markdown_editor/services/settings_service.dart';
import 'package:local_markdown_editor/services/window_service.dart';

class MemoryFiles implements DocumentFileService {
  final data = <String, Uint8List>{};
  bool failRead = false;
  bool failWrite = false;
  Completer<void>? gate;
  void Function()? onWrite;
  int writes = 0;
  @override
  Future<LoadedDocument> read(String path) async {
    if (failRead || !data.containsKey(path)) throw const FileSystemException();
    return LoadedDocument.decode(data[path]!);
  }

  @override
  Future<Uint8List?> diskBytes(String path) async => data[path];
  @override
  Future<void> write(String path, Uint8List bytes) async {
    onWrite?.call();
    await gate?.future;
    if (failWrite) throw const FileSystemException();
    writes++;
    data[path] = Uint8List.fromList(bytes);
  }
}

class FakeInteraction implements EditorInteraction {
  String? openPath;
  String? savePath;
  UnsavedChoice unsaved = UnsavedChoice.cancel;
  ConflictChoice conflict = ConflictChoice.cancel;
  bool overwrite = false;
  int conflicts = 0;
  int warnings = 0;
  int overwritePrompts = 0;
  final errors = <String>[];
  final messages = <String>[];
  Completer<String?>? picker;
  @override
  Future<String?> chooseOpen() async =>
      picker == null ? openPath : picker!.future;
  @override
  Future<String?> chooseSave(String suggestedName) async => savePath;
  @override
  Future<UnsavedChoice> askUnsaved() async {
    warnings++;
    return unsaved;
  }

  @override
  Future<ConflictChoice> askConflict({required bool missing}) async {
    conflicts++;
    return conflict;
  }

  @override
  Future<bool> confirmOverwrite(String path) async {
    overwritePrompts++;
    return overwrite;
  }

  @override
  Future<void> showError(String message) async => errors.add(message);
  @override
  void notify(String message) => messages.add(message);
}

class MemorySettings implements SettingsService {
  EditorSettings value = const EditorSettings();
  bool fail = false;
  @override
  Future<EditorSettings> load() async => value;
  @override
  Future<void> save(EditorSettings settings) async {
    if (fail) throw const FileSystemException();
    value = settings;
  }
}

class FakeWindow implements EditorWindowService {
  Future<void> Function()? onClose;
  bool destroyed = false;
  String title = '';
  @override
  void setCloseHandler(Future<void> Function() handler) => onClose = handler;
  @override
  Future<void> setTitle(String title) async => this.title = title;
  @override
  Future<void> destroy() async => destroyed = true;
  @override
  void dispose() {}
}

class FakeLinks implements LinkService {
  final opened = <Uri>[];
  @override
  Future<bool> open(Uri uri) async {
    opened.add(uri);
    return true;
  }
}
