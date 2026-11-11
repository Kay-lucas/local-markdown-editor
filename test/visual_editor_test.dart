import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart' as q;
import 'package:flutter_test/flutter_test.dart';
import 'package:local_markdown_editor/app.dart';
import 'package:local_markdown_editor/controllers/editor_controller.dart';
import 'package:local_markdown_editor/controllers/visual_editor_controller.dart';
import 'package:local_markdown_editor/services/content_policy.dart';
import 'package:local_markdown_editor/services/editor_interaction.dart';
import 'package:local_markdown_editor/services/settings_service.dart';

import 'support/fakes.dart';

class _NoNetwork extends HttpOverrides {
  int attempts = 0;
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    attempts++;
    throw StateError('Remote resource access during visual editing');
  }
}

void main() {
  late EditorController source;
  late LocalPathPolicy paths;
  setUp(() {
    paths = LocalPathPolicy(isRemote: (_) => false);
    source = EditorController(files: MemoryFiles(), paths: paths);
  });
  tearDown(() => source.dispose());

  test(
    'visual edits update Markdown before an immediate save and share undo',
    () async {
      source.text.text = '# 제목\n\n__보존__';
      final bridge = VisualEditorController(source)..active = true;
      addTearDown(bridge.dispose);
      bridge.quill.replaceText(
        2,
        0,
        ' 수정',
        const TextSelection.collapsed(offset: 5),
      );
      expect(source.text.text, '# 제목 수정\n\n__보존__');
      expect(source.dirty, isTrue);
      final ui = FakeInteraction()..savePath = r'C:\문서\편집.md';
      expect(await source.save(ui), isTrue);
      expect(source.dirty, isFalse);
      source.undo();
      expect(source.text.text, '# 제목\n\n__보존__');
      expect(bridge.quill.document.toPlainText(), '제목\n보존\n');
      source.redo();
      expect(bridge.quill.document.toPlainText(), '제목 수정\n보존\n');
    },
  );

  test('new document cancels pending old-source sync and old undo', () async {
    final bridge = VisualEditorController(source);
    source.text.text = '이전 문서';
    await source.newDocument(
      FakeInteraction()..unsaved = UnsavedChoice.discard,
    );
    bridge.synchronize();
    expect(bridge.quill.document.toPlainText(), '\n');
    expect(source.canUndo, isFalse);
    bridge.quill.replaceText(0, 0, '새 문서', null);
    expect(source.text.text, '새 문서');
    bridge.dispose();
  });

  Future<q.QuillEditor> mount(WidgetTester tester, String markdown) async {
    source.text.text = markdown;
    final settings = SettingsController(
      MemorySettings(),
      const EditorSettings(),
    );
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(
      MarkdownEditorApp(
        editor: source,
        settings: settings,
        window: FakeWindow(),
        policy: ContentPolicy(paths),
        links: FakeLinks(),
        interaction: FakeInteraction(),
      ),
    );
    await tester.pumpAndSettle();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      settings.dispose();
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    return tester.widget<q.QuillEditor>(find.byType(q.QuillEditor));
  }

  testWidgets('first click focuses right editor after source synchronization', (
    tester,
  ) async {
    final visual = await mount(tester, '');
    source.text.text = '왼쪽에서 붙여 넣은 문장';
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();
    await tester.tapAt(
      tester.getTopLeft(find.byType(q.QuillEditor)) + const Offset(80, 30),
    );
    await tester.pump();
    expect(visual.focusNode.hasFocus, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'right pane native text input updates left and keyboard undo/redo',
    (tester) async {
      final visual = await mount(tester, '# 회의록');
      visual.focusNode.requestFocus();
      await tester.pump();
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: '주간 회의록\n',
          selection: TextSelection.collapsed(offset: 6),
        ),
      );
      await tester.pump();
      expect(source.text.text, '# 주간 회의록');
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(source.text.text, '# 회의록');
      expect(visual.controller.document.toPlainText(), '회의록\n');
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyY);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(source.text.text, '# 주간 회의록');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('visual selection toolbar applies formatting to the right pane', (
    tester,
  ) async {
    final visual = await mount(tester, '선택한 문장');
    visual.focusNode.requestFocus();
    visual.controller.updateSelection(
      const TextSelection(baseOffset: 0, extentOffset: 3),
      q.ChangeSource.local,
    );
    await tester.pump();
    await tester.tap(find.byTooltip('굵게 (Ctrl+B)'));
    await tester.pumpAndSettle();
    expect(source.text.text, '**선택한** 문장');
    expect(visual.focusNode.hasFocus, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Korean IME composition survives without rebuilding visual document',
    (tester) async {
      final visual = await mount(tester, '');
      final document = visual.controller.document;
      visual.focusNode.requestFocus();
      await tester.pump();
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: 'ㅎ\n',
          selection: TextSelection.collapsed(offset: 1),
          composing: TextRange(start: 0, end: 1),
        ),
      );
      await tester.pump();
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: '하\n',
          selection: TextSelection.collapsed(offset: 1),
          composing: TextRange(start: 0, end: 1),
        ),
      );
      await tester.pump();
      expect(source.composing, isTrue);
      expect(source.canUndo, isFalse);
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: '한\n',
          selection: TextSelection.collapsed(offset: 1),
        ),
      );
      await tester.pumpAndSettle();
      expect(source.text.text, '한');
      expect(visual.controller.document, same(document));
      expect(source.composing, isFalse);
      source.undo();
      await tester.pumpAndSettle();
      expect(source.text.text, '');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'protected table and remote image survive neighboring edit offline',
    (tester) async {
      final network = _NoNetwork();
      final old = HttpOverrides.current;
      HttpOverrides.global = network;
      addTearDown(() => HttpOverrides.global = old);
      const tail =
          '\n\n| A | B |\n| --- | --- |\n| 1 | 2 |\n\n![원격](https://example.com/x.png)';
      final visual = await mount(tester, '제목$tail');
      visual.controller.replaceText(0, 2, '수정', null);
      await tester.pumpAndSettle();
      expect(source.text.text, '수정$tail');
      expect(network.attempts, 0);
      expect(find.text('원문 보존 블록'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );
}
