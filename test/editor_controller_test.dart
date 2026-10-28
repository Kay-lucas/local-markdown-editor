import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_markdown_editor/commands/formatting_commands.dart';
import 'package:local_markdown_editor/controllers/editor_controller.dart';
import 'package:local_markdown_editor/services/content_policy.dart';
import 'package:local_markdown_editor/services/editor_interaction.dart';

import 'support/fakes.dart';

void main() {
  late MemoryFiles files;
  late FakeInteraction ui;
  late EditorController editor;
  const path = r'C:\문서\회의록 (초안).md';
  setUp(() {
    files = MemoryFiles();
    ui = FakeInteraction();
    editor = EditorController(
      files: files,
      paths: LocalPathPolicy(isRemote: (_) => false),
    );
  });
  tearDown(() => editor.dispose());
  void seed(String value) =>
      files.data[path] = Uint8List.fromList(utf8.encode(value));
  Future<void> open(String value) async {
    seed(value);
    ui.openPath = path;
    expect(await editor.openDocument(ui), isTrue);
  }

  test('new document, dirty comparison, undo and redo', () {
    expect(editor.dirty, isFalse);
    editor.text.text = '한글 😀';
    expect(editor.dirty, isTrue);
    editor.undo();
    expect(editor.text.text, '');
    expect(editor.dirty, isFalse);
    editor.redo();
    expect(editor.text.text, '한글 😀');
  });
  test(
    'same-file save updates baseline and undo returns to saved state',
    () async {
      await open('원문');
      editor.text.text = '수정';
      expect(await editor.save(ui), isTrue);
      expect(utf8.decode(files.data[path]!), '수정');
      expect(editor.dirty, isFalse);
      editor.text.text = '추가 수정';
      editor.undo();
      expect(editor.dirty, isFalse);
    },
  );
  test('new save appends extension and save-as changes current path', () async {
    editor.text.text = '본문';
    ui.savePath = r'C:\문서\새 문서';
    expect(await editor.save(ui), isTrue);
    expect(editor.path, r'C:\문서\새 문서.md');
    ui.savePath = r'C:\문서\복사.MARKDOWN';
    expect(await editor.save(ui, saveAs: true), isTrue);
    expect(editor.path, ui.savePath);
    expect(files.data.length, 2);
  });
  test('save-as existing target requires explicit overwrite', () async {
    seed('원본');
    editor.text.text = '새 내용';
    ui.savePath = path;
    expect(await editor.save(ui), isFalse);
    expect(utf8.decode(files.data[path]!), '원본');
    ui.overwrite = true;
    expect(await editor.save(ui), isTrue);
    expect(ui.overwritePrompts, 2);
  });
  test('save dialog cancellation preserves unsaved content and path', () async {
    editor.text.text = '미저장';
    expect(await editor.save(ui), isFalse);
    expect(editor.path, isNull);
    expect(editor.text.text, '미저장');
    expect(editor.dirty, isTrue);
  });
  test('write failure preserves old file, path and dirty state', () async {
    await open('원본');
    editor.text.text = '수정';
    files.failWrite = true;
    expect(await editor.save(ui), isFalse);
    expect(editor.text.text, '수정');
    expect(editor.dirty, isTrue);
    expect(utf8.decode(files.data[path]!), '원본');
    expect(ui.errors, isNotEmpty);
  });
  test('cancelled or failed open preserves the current document', () async {
    editor.text.text = '기존 내용';
    expect(await editor.openDocument(ui), isFalse);
    ui.openPath = path;
    files.failRead = true;
    expect(await editor.openDocument(ui), isFalse);
    expect(editor.text.text, '기존 내용');
  });
  test('invalid UTF-8 is rejected without replacing the document', () async {
    editor.text.text = '보존';
    files.data[path] = Uint8List.fromList([0xc3, 0x28]);
    ui.openPath = path;
    expect(await editor.openDocument(ui), isFalse);
    expect(editor.text.text, '보존');
    expect(ui.errors.single, contains('UTF-8'));
  });
  for (final choice in UnsavedChoice.values) {
    test('new document unsaved branch: ${choice.name}', () async {
      editor.text.text = '미저장';
      ui.unsaved = choice;
      ui.savePath = path;
      final result = await editor.newDocument(ui);
      expect(result, choice != UnsavedChoice.cancel);
      expect(editor.text.text, choice == UnsavedChoice.cancel ? '미저장' : '');
      if (choice == UnsavedChoice.save) {
        expect(utf8.decode(files.data[path]!), '미저장');
      }
    });
  }
  test(
    'close is cancelled when save picker is cancelled or save fails',
    () async {
      editor.text.text = '남길 내용';
      ui.unsaved = UnsavedChoice.save;
      expect(await editor.confirmClose(ui), isFalse);
      ui.savePath = path;
      files.failWrite = true;
      expect(await editor.confirmClose(ui), isFalse);
      expect(editor.text.text, '남길 내용');
    },
  );
  test(
    'window completion stays locked until flush and destruction finish',
    () async {
      final gate = Completer<void>();
      final pending = editor.confirmClose(
        ui,
        onConfirmed: () async {
          expect(editor.busy, isTrue);
          expect(editor.transitionLocked, isTrue);
          await gate.future;
        },
      );
      await Future<void>.delayed(Duration.zero);
      expect(await editor.newDocument(ui), isFalse);
      gate.complete();
      expect(await pending, isTrue);
      expect(editor.busy, isFalse);
    },
  );
  test(
    'editing during save retains dirty state and saves only the snapshot',
    () async {
      editor.text.text = '스냅샷';
      ui.savePath = path;
      files.onWrite = () => editor.text.text = '저장 중 추가 입력';
      expect(await editor.save(ui), isTrue);
      expect(utf8.decode(files.data[path]!), '스냅샷');
      expect(editor.dirty, isTrue);
    },
  );
  test('additional editing during save prevents a requested close', () async {
    editor.text.text = '스냅샷';
    ui.savePath = path;
    ui.unsaved = UnsavedChoice.save;
    files.onWrite = () => editor.text.text = '새 입력';
    expect(await editor.confirmClose(ui), isFalse);
    expect(editor.text.text, '새 입력');
  });
  test(
    'opening the same file after saving does not restore stale content',
    () async {
      await open('이전');
      editor.text.text = '최신';
      ui.unsaved = UnsavedChoice.save;
      expect(await editor.openDocument(ui), isTrue);
      expect(editor.text.text, '최신');
    },
  );
  test(
    'external modification cancel, overwrite and deleted-file recreation',
    () async {
      await open('원본');
      editor.text.text = '앱 수정';
      seed('외부 수정');
      expect(await editor.save(ui), isFalse);
      expect(utf8.decode(files.data[path]!), '외부 수정');
      ui.conflict = ConflictChoice.overwrite;
      expect(await editor.save(ui), isTrue);
      expect(utf8.decode(files.data[path]!), '앱 수정');
      files.data.remove(path);
      expect(await editor.save(ui), isTrue);
      expect(ui.conflicts, 3);
    },
  );
  test('conflict can be saved as a separate file', () async {
    await open('원본');
    editor.text.text = '앱 수정';
    seed('외부 수정');
    ui.conflict = ConflictChoice.saveAs;
    ui.savePath = r'C:\문서\별도.md';
    expect(await editor.save(ui), isTrue);
    expect(editor.path, ui.savePath);
    expect(utf8.decode(files.data[path]!), '외부 수정');
  });
  test('duplicate requests are ignored while a picker is pending', () async {
    ui.picker = Completer<String?>();
    final pending = editor.openDocument(ui);
    expect(await editor.newDocument(ui), isFalse);
    expect(await editor.save(ui), isFalse);
    ui.picker!.complete(null);
    expect(await pending, isFalse);
  });
  test('toolbar edit is a single undo item with the original selection', () {
    editor.text.value = const TextEditingValue(
      text: '한글 😀',
      selection: TextSelection(baseOffset: 0, extentOffset: 2),
    );
    editor.applyEdit(
      FormattingCommands.apply(editor.text.value, FormatCommand.bold),
    );
    expect(editor.text.text, '**한글** 😀');
    editor.undo();
    expect(editor.text.text, '한글 😀');
    expect(editor.text.selection.end, 2);
    editor.redo();
    expect(editor.text.text, '**한글** 😀');
  });
  test('IME composing updates remain intact and form one history step', () {
    editor.text.value = const TextEditingValue(
      text: 'ㅎ',
      selection: TextSelection.collapsed(offset: 1),
      composing: TextRange(start: 0, end: 1),
    );
    editor.text.value = const TextEditingValue(
      text: '한',
      selection: TextSelection.collapsed(offset: 1),
      composing: TextRange(start: 0, end: 1),
    );
    editor.applyEdit(
      FormattingCommands.apply(editor.text.value, FormatCommand.bold),
    );
    expect(editor.text.text, '한');
    expect(editor.composing, isTrue);
    editor.text.value = editor.text.value.copyWith(composing: TextRange.empty);
    editor.undo();
    expect(editor.text.text, '');
    editor.redo();
    expect(editor.text.text, '한');
  });
  test('cursor counts graphemes, not UTF-16 code units', () {
    editor.text.value = const TextEditingValue(
      text: '제목\n한👩‍💻글',
      selection: TextSelection.collapsed(offset: 9),
    );
    expect(editor.cursor, (2, 3));
  });
}
