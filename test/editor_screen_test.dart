import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_markdown_editor/app.dart';
import 'package:local_markdown_editor/controllers/editor_controller.dart';
import 'package:local_markdown_editor/services/content_policy.dart';
import 'package:local_markdown_editor/services/settings_service.dart';
import 'package:local_markdown_editor/widgets/markdown_preview.dart';
import 'package:markdown/markdown.dart' as md;

import 'support/fakes.dart';

class NoNetwork extends HttpOverrides {
  int attempts = 0;
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    attempts++;
    throw StateError('No network allowed in Markdown preview');
  }
}

void main() {
  late EditorController editor;
  late SettingsController settings;
  late FakeWindow window;
  late FakeLinks links;
  late LocalPathPolicy paths;
  setUp(() {
    paths = LocalPathPolicy(isRemote: (_) => false);
    editor = EditorController(files: MemoryFiles(), paths: paths);
    settings = SettingsController(MemorySettings(), const EditorSettings());
    window = FakeWindow();
    links = FakeLinks();
  });

  Future<void> mount(
    WidgetTester tester, {
    bool realDialogs = false,
    Size size = const Size(1280, 800),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(
      MarkdownEditorApp(
        editor: editor,
        settings: settings,
        window: window,
        policy: ContentPolicy(paths),
        links: links,
        interaction: realDialogs ? null : FakeInteraction(),
      ),
    );
    await tester.pumpAndSettle();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      editor.dispose();
      settings.dispose();
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  testWidgets(
    'typing renders live Markdown without replacing editor controller',
    (tester) async {
      await mount(tester);
      final original = tester
          .widget<EditableText>(find.byType(EditableText))
          .controller;
      await tester.enterText(find.byType(EditableText), '# 안녕하세요\n\n**굵은 글씨**');
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text('안녕하세요', findRichText: true), findsWidgets);
      expect(find.text('굵은 글씨', findRichText: true), findsWidgets);
      expect(window.title, contains('*'));
      expect(
        tester.widget<EditableText>(find.byType(EditableText).first).controller,
        same(original),
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('toolbar preserves selection and a single undo restores text', (
    tester,
  ) async {
    await mount(tester);
    editor.text.value = const TextEditingValue(
      text: '한글 😀',
      selection: TextSelection(baseOffset: 0, extentOffset: 2),
    );
    await tester.pump();
    await tester.tap(find.byTooltip('굵게 (Ctrl+B)'));
    await tester.pump();
    expect(editor.text.text, '**한글** 😀');
    final field = tester.widget<EditableText>(find.byType(EditableText).first);
    expect(field.focusNode.hasFocus, isTrue);
    await tester.tap(find.byTooltip('실행 취소 (Ctrl+Z)'));
    await tester.pump();
    expect(editor.text.text, '한글 😀');
  });
  testWidgets('Ctrl+B and Ctrl+Z invoke document commands', (tester) async {
    await mount(tester);
    editor.text.value = const TextEditingValue(
      text: '선택',
      selection: TextSelection(baseOffset: 0, extentOffset: 2),
    );
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyB);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    expect(editor.text.text, '**선택**');
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    expect(editor.text.text, '선택');
  });
  testWidgets('minimum layout and dark mode have no overflow', (tester) async {
    await mount(tester, size: const Size(900, 600));
    settings.setTheme(ThemeMode.dark);
    await tester.pumpAndSettle();
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.dark,
    );
    expect(find.byTooltip('표'), findsOneWidget);
    await tester.drag(
      find.byKey(const ValueKey('split-divider')),
      const Offset(70, 0),
    );
    await tester.pumpAndSettle();
    expect(settings.value.split, greaterThan(.5));
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'native close callback offers cancel and discard in a real dialog',
    (tester) async {
      await mount(tester, realDialogs: true);
      editor.text.text = '저장하지 않은 문서';
      await tester.pump();
      unawaited(window.onClose!());
      await tester.pumpAndSettle();
      expect(find.text('저장하지 않은 변경 사항이 있습니다'), findsOneWidget);
      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();
      expect(window.destroyed, isFalse);
      expect(editor.text.text, '저장하지 않은 문서');
      unawaited(window.onClose!());
      await tester.pumpAndSettle();
      await tester.tap(find.text('버리기'));
      await tester.pumpAndSettle();
      expect(window.destroyed, isTrue);
    },
  );
  testWidgets('Escape cancels a warning without losing content', (
    tester,
  ) async {
    await mount(tester, realDialogs: true);
    editor.text.text = '남길 문서';
    await tester.pump();
    unawaited(window.onClose!());
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(editor.text.text, '남길 문서');
    expect(window.destroyed, isFalse);
  });
  testWidgets(
    'link dialog Escape preserves text and blocks document shortcuts',
    (tester) async {
      await mount(tester);
      editor.text.value = const TextEditingValue(
        text: '원문',
        selection: TextSelection(baseOffset: 0, extentOffset: 2),
      );
      await tester.pump();
      await tester.tap(find.byTooltip('링크 (Ctrl+K)'));
      await tester.pumpAndSettle();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyN);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      expect(editor.text.text, '원문');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 300));
      expect(editor.text.text, '원문');
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('GFM and raw HTML display without fetching remote images', (
    tester,
  ) async {
    final guard = NoNetwork();
    final old = HttpOverrides.current;
    HttpOverrides.global = guard;
    addTearDown(() => HttpOverrides.global = old);
    await mount(tester);
    editor.text.text =
        '| 항목 | 상태 |\n| :--- | ---: |\n| 한글 | 정상 |\n\n- [x] 완료\n\n~~취소~~\n\nhttps://example.com\n\n![원격](https://example.com/a.png)\n\n<script>alert(1)</script>';
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(find.byType(Table), findsWidgets);
    expect(find.byIcon(Icons.check_box_outlined), findsWidgets);
    expect(find.textContaining('원격 이미지는', findRichText: true), findsWidgets);
    expect(find.textContaining('<script>', findRichText: true), findsWidgets);
    expect(guard.attempts, 0);
    expect(links.opened, isEmpty);
    expect(tester.takeException(), isNull);
  });

  test('GFM AST includes table alignment, tasks, strikethrough and autolink', () {
    final source =
        '| A | B |\n| :--- | ---: |\n| 1 | 2 |\n\n- [x] 완료\n\n~~취소~~\n\nhttps://example.com';
    final html = md.markdownToHtml(
      source,
      extensionSet: editorMarkdownExtensions,
    );
    expect(html, contains('<table>'));
    expect(html, contains('align="right"'));
    expect(html, contains('type="checkbox"'));
    expect(html, contains('<del>취소</del>'));
    expect(html, contains('href="https://example.com"'));
  });
}
