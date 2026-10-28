import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../models/document_state.dart';
import '../services/content_policy.dart';
import '../services/document_file_service.dart';
import '../services/editor_interaction.dart';

class EditorController extends ChangeNotifier {
  EditorController({required this.files, required this.paths}) {
    text.addListener(_edited);
  }
  final DocumentFileService files;
  final LocalPathPolicy paths;
  final TextEditingController text = TextEditingController();
  final List<TextEditingValue> _past = [];
  final List<TextEditingValue> _future = [];
  TextEditingValue _previous = TextEditingValue.empty;
  TextEditingValue? _compositionStart;
  bool _applying = false;
  String? path;
  String savedText = '';
  DocumentFormat format = const DocumentFormat();
  Uint8List? diskBaseline;
  int revision = 0;
  int documentId = 0;
  bool busy = false;
  bool transitionLocked = false;
  String status = '새 문서';
  bool get dirty => text.text != savedText;
  bool get composing =>
      text.value.composing.isValid && !text.value.composing.isCollapsed;
  bool get canUndo => _past.isNotEmpty && !composing;
  bool get canRedo => _future.isNotEmpty && !composing;
  String get filename =>
      path == null ? '제목 없음' : LocalPathPolicy.windows.basename(path!);
  String get title => '$filename${dirty ? ' *' : ''} — 로컬 Markdown 에디터';

  (int, int) get cursor {
    final offset = text.selection.isValid ? text.selection.extentOffset : 0;
    final before = text.text.substring(0, offset.clamp(0, text.text.length));
    final lines = before.split('\n');
    return (lines.length, lines.last.characters.length + 1);
  }

  void _edited() {
    final next = text.value;
    if (!_applying) {
      if (composing) {
        _compositionStart ??= _previous;
      } else if (_compositionStart != null) {
        final start = _compositionStart!;
        _compositionStart = null;
        if (start.text != next.text) {
          _remember(start.copyWith(composing: TextRange.empty));
          _future.clear();
        }
      } else if (_previous.text != next.text) {
        _remember(_previous.copyWith(composing: TextRange.empty));
        _future.clear();
      }
    }
    if (_previous.text != next.text) {
      revision++;
      status = dirty ? '수정됨' : '저장됨';
    }
    _previous = next;
    notifyListeners();
  }

  void applyEdit(TextEditingValue value) {
    if (composing || transitionLocked || value.text == text.text) return;
    _remember(text.value.copyWith(composing: TextRange.empty));
    _future.clear();
    _setValue(value);
  }

  void _setValue(TextEditingValue value) {
    _applying = true;
    text.value = value.copyWith(composing: TextRange.empty);
    _applying = false;
  }

  void _remember(TextEditingValue value) {
    _past.add(value);
    var units = _past.fold(0, (int count, entry) => count + entry.text.length);
    while (_past.length > 100 ||
        (units > 8 * 1024 * 1024 && _past.length > 1)) {
      units -= _past.removeAt(0).text.length;
    }
  }

  void undo() {
    if (!canUndo || transitionLocked) return;
    _future.add(text.value.copyWith(composing: TextRange.empty));
    _setValue(_past.removeLast());
  }

  void redo() {
    if (!canRedo || transitionLocked) return;
    _remember(text.value.copyWith(composing: TextRange.empty));
    _setValue(_future.removeLast());
  }

  void _replace(String? nextPath, LoadedDocument? loaded) {
    path = nextPath;
    savedText = loaded?.text ?? '';
    format = loaded?.format ?? const DocumentFormat();
    diskBaseline = loaded?.bytes;
    _compositionStart = null;
    _past.clear();
    _future.clear();
    documentId++;
    _setValue(
      TextEditingValue(
        text: savedText,
        selection: const TextSelection.collapsed(offset: 0),
      ),
    );
    status = loaded == null ? '새 문서' : '파일을 열었습니다';
    notifyListeners();
  }

  Future<bool> _operation(Future<bool> Function() action) async {
    if (busy) return false;
    busy = true;
    notifyListeners();
    try {
      return await action();
    } finally {
      busy = false;
      transitionLocked = false;
      notifyListeners();
    }
  }

  Future<bool> _allowTransition(EditorInteraction ui) async {
    if (!dirty) return true;
    switch (await ui.askUnsaved()) {
      case UnsavedChoice.discard:
        return true;
      case UnsavedChoice.cancel:
        return false;
      case UnsavedChoice.save:
        return await _save(ui) && !dirty;
    }
  }

  Future<bool> newDocument(EditorInteraction ui) => _operation(() async {
    transitionLocked = true;
    if (!await _allowTransition(ui)) return false;
    _replace(null, null);
    return true;
  });

  Future<bool> openDocument(EditorInteraction ui) => _operation(() async {
    transitionLocked = true;
    try {
      final selected = await ui.chooseOpen();
      if (selected == null) return false;
      final nextPath = paths.markdownPath(selected);
      var loaded = await files.read(nextPath);
      final hadChanges = dirty;
      if (!await _allowTransition(ui)) return false;
      // Saving during the prompt may have updated the very file being opened.
      if (hadChanges) loaded = await files.read(nextPath);
      _replace(nextPath, loaded);
      if (loaded.mixed) {
        ui.notify('줄바꿈이 섞여 있습니다. 저장 시 ${format.newlineLabel}로 통일합니다.');
      }
      return true;
    } catch (error) {
      await ui.showError(_error('열기', error));
      return false;
    }
  });

  Future<bool> save(EditorInteraction ui, {bool saveAs = false}) =>
      _operation(() => _save(ui, saveAs: saveAs));

  Future<bool> confirmClose(
    EditorInteraction ui, {
    Future<void> Function()? onConfirmed,
  }) => _operation(() async {
    transitionLocked = true;
    if (!await _allowTransition(ui)) return false;
    await onConfirmed?.call();
    return true;
  });

  Future<bool> _save(EditorInteraction ui, {bool saveAs = false}) async {
    try {
      String? target = path;
      bool selectedTarget = saveAs || target == null;
      if (selectedTarget) {
        final selected = await ui.chooseSave(
          path == null ? '제목 없음.md' : filename,
        );
        if (selected == null) return false;
        target = paths.savePath(selected);
      }
      target = paths.savePath(target);
      var currentBytes = await files.diskBytes(target);
      final samePath =
          path != null && LocalPathPolicy.windows.equals(target, path!);
      if (samePath && !listEquals(currentBytes, diskBaseline)) {
        final choice = await ui.askConflict(missing: currentBytes == null);
        if (choice == ConflictChoice.cancel) return false;
        if (choice == ConflictChoice.saveAs) return _save(ui, saveAs: true);
        selectedTarget =
            false; // Conflict prompt is explicit overwrite approval.
      } else if (selectedTarget && !samePath && currentBytes != null) {
        if (!await ui.confirmOverwrite(target)) return false;
      }
      final snapshot = text.text;
      final snapshotRevision = revision;
      final bytes = format.encode(snapshot);
      status = '저장 중';
      notifyListeners();
      await files.write(target, bytes);
      path = target;
      savedText = snapshot;
      diskBaseline = bytes;
      status = revision == snapshotRevision ? '저장됨' : '수정됨';
      notifyListeners();
      return true;
    } catch (error) {
      status = '저장 실패';
      notifyListeners();
      await ui.showError(_error('저장', error));
      return false;
    }
  }

  String _error(String action, Object error) {
    if (error is DocumentWriteException) return error.toString();
    if (error is FormatException) {
      return action == '열기' &&
              !error.message.contains('경로') &&
              !error.message.contains('파일') &&
              !error.message.contains('드라이브')
          ? 'UTF-8 형식의 파일을 열어 주세요. 현재 문서는 유지됩니다.'
          : error.message;
    }
    return '$action 작업에 실패했습니다. 파일 권한·잠금·경로·저장 공간을 확인해 주세요. 현재 편집 내용은 유지됩니다.';
  }

  @override
  void dispose() {
    text.removeListener(_edited);
    text.dispose();
    super.dispose();
  }
}
