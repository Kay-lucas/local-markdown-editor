// Reproducible screenshots of the actual Flutter widget tree. Run explicitly:
// flutter test tool/capture_screenshots_test.dart
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart' as q;
import 'package:flutter_test/flutter_test.dart';
import 'package:local_markdown_editor/app.dart';
import 'package:local_markdown_editor/controllers/editor_controller.dart';
import 'package:local_markdown_editor/services/content_policy.dart';
import 'package:local_markdown_editor/services/settings_service.dart';

import '../test/support/fakes.dart';

void main() {
  testWidgets('capture visual edit, GFM preview and dark theme', (
    tester,
  ) async {
    await tester.runAsync(() async {
      for (final family in {
        'Malgun Gothic': ['malgun.ttf', 'malgunbd.ttf'],
        'Consolas': ['consola.ttf', 'consolab.ttf'],
      }.entries) {
        final loader = FontLoader(family.key);
        for (final filename in family.value) {
          loader.addFont(
            File(
              'C:/Windows/Fonts/$filename',
            ).readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
          );
        }
        await loader.load();
      }
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    });

    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    final sourceText = File(
      'test/fixtures/bidirectional-demo.md',
    ).readAsStringSync();
    const path = r'C:\문서\양방향편집-예제.md';
    final files = MemoryFiles()
      ..data[path] = Uint8List.fromList(utf8.encode(sourceText));
    final paths = LocalPathPolicy(isRemote: (_) => false);
    final editor = EditorController(files: files, paths: paths);
    final settings = SettingsController(
      MemorySettings(),
      const EditorSettings(),
    );
    await editor.openDocument(FakeInteraction()..openPath = path);
    final boundaryKey = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundaryKey,
        child: MarkdownEditorApp(
          editor: editor,
          settings: settings,
          window: FakeWindow(),
          policy: ContentPolicy(paths),
          links: FakeLinks(),
          interaction: FakeInteraction(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    Future<void> capture(String name) async {
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        final boundary =
            boundaryKey.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final frame = await boundary.toImage(pixelRatio: 1.5);
        final bytes = await frame.toByteData(format: ui.ImageByteFormat.png);
        final output = File('docs/screenshots/$name');
        await output.parent.create(recursive: true);
        await output.writeAsBytes(bytes!.buffer.asUint8List());
        frame.dispose();
      });
    }

    final visual = tester.widget<q.QuillEditor>(find.byType(q.QuillEditor));
    visual.focusNode.requestFocus();
    await tester.pump();
    final text = visual.controller.document.toPlainText().replaceFirst(
      '읽는 모습 그대로 편집하세요',
      '오른쪽에서 고친 문서 제목',
    );
    tester.testTextInput.updateEditingValue(
      TextEditingValue(
        text: text,
        selection: const TextSelection.collapsed(offset: 14),
      ),
    );
    await tester.pumpAndSettle();
    expect(editor.text.text, startsWith('# 오른쪽에서 고친 문서 제목'));
    expect(editor.text.text, contains('| 기능 | 사용 방법 |'));
    await capture('02-edit-from-right.png');

    await tester.tap(find.byKey(const ValueKey('toggle-visual-preview')));
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const ValueKey('rendered-markdown')),
      const Offset(0, -450),
    );
    await tester.pumpAndSettle();
    await capture('03-gfm-preview.png');

    await tester.tap(find.byKey(const ValueKey('toggle-visual-preview')));
    settings.setTheme(ThemeMode.dark);
    await tester.pumpAndSettle();
    await capture('04-two-way-dark.png');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    editor.dispose();
    settings.dispose();
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
