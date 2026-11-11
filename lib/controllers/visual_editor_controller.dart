import 'dart:async';

import 'package:dart_quill_delta/dart_quill_delta.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_quill/flutter_quill.dart' as q;

import '../commands/formatting_commands.dart';
import '../services/visual_markdown_codec.dart';
import 'editor_controller.dart';

/// One Markdown save/undo history, with a separate visual selection.
class VisualEditorController {
  VisualEditorController(this.source) {
    _codec = VisualMarkdownCodec(source.text.text);
    _lastSource = source.text.text;
    _document = source.documentId;
    quill = q.QuillController(
      document: q.Document.fromDelta(_codec.delta),
      selection: const TextSelection.collapsed(offset: 0),
      config: const q.QuillControllerConfig(
        // Quill is pinned; review this experimental API when upgrading.
        // ignore: experimental_member_use
        clipboardConfig: q.QuillClipboardConfig(enableExternalRichPaste: false),
      ),
    );
    _lastDelta = quill.document.toDelta();
    quill.addListener(_visualChanged);
    source.addListener(_sourceChanged);
  }

  final EditorController source;
  late final q.QuillController quill;
  late VisualMarkdownCodec _codec;
  late Delta _lastDelta;
  Timer? _timer;
  late String _lastSource;
  late int _document;
  bool _applying = false;
  bool _disposed = false;
  bool active = false;
  final Map<String, TextSelection> _selections = {};
  int get protectedBlocks => _codec.protectedBlocks;

  void _visualChanged() {
    if (_disposed || _applying || source.transitionLocked) return;
    final current = quill.document.toDelta();
    if (current == _lastDelta) {
      return;
    }
    _codec.track(_lastDelta.diff(current));
    _lastDelta = current;
    final next = _codec.encode(current);
    _lastSource = next;
    _selections[next] = quill.selection;
    var units = _selections.keys.fold(0, (int n, text) => n + text.length);
    while (_selections.length > 110 ||
        (units > 8 * 1024 * 1024 && _selections.length > 1)) {
      final oldest = _selections.keys.first;
      units -= oldest.length;
      _selections.remove(oldest);
    }
    _applying = true;
    try {
      source.applyVisualEdit(next);
    } finally {
      _applying = false;
    }
  }

  void _sourceChanged() {
    quill.readOnly = source.transitionLocked;
    if (_applying || _disposed) return;
    if (_lastSource == source.text.text && _document == source.documentId) {
      return;
    }
    _timer?.cancel();
    if (active && !source.composing) {
      synchronize();
      return;
    }
    // External undo/new/open must be reflected even while the visual pane owns
    // focus. Ordinary source typing is debounced and never resets its own IME.
    _timer = Timer(const Duration(milliseconds: 200), synchronize);
  }

  void synchronize() {
    _timer?.cancel();
    if (_disposed ||
        (_lastSource == source.text.text && _document == source.documentId)) {
      return;
    }
    final sameDocument = _document == source.documentId;
    if (!sameDocument) _selections.clear();
    final selection = sameDocument
        ? (_selections[source.text.text] ?? quill.selection)
        : const TextSelection.collapsed(offset: 0);
    _document = source.documentId;
    _lastSource = source.text.text;
    _codec = VisualMarkdownCodec(_lastSource);
    _applying = true;
    final previous = quill.document;
    quill
      ..ignoreFocusOnTextChange = true
      ..document = q.Document.fromDelta(_codec.delta);
    final max = quill.document.length - 1;
    quill.updateSelection(
      TextSelection(
        baseOffset: selection.baseOffset.clamp(0, max),
        extentOffset: selection.extentOffset.clamp(0, max),
      ),
      q.ChangeSource.remote,
    );
    quill.ignoreFocusOnTextChange = false;
    _lastDelta = quill.document.toDelta();
    _applying = false;
    previous.close();
  }

  void format(FormatCommand command) {
    if (source.transitionLocked || source.composing) return;
    synchronize();
    final style = quill.getSelectionStyle().attributes;
    q.Attribute? attribute;
    switch (command) {
      case FormatCommand.h1:
      case FormatCommand.h2:
      case FormatCommand.h3:
        attribute = q.HeaderAttribute(level: command.index + 1);
      case FormatCommand.bold:
        attribute = q.Attribute.bold;
      case FormatCommand.italic:
        attribute = q.Attribute.italic;
      case FormatCommand.strike:
        attribute = q.Attribute.strikeThrough;
      case FormatCommand.inlineCode:
        attribute = q.Attribute.inlineCode;
      case FormatCommand.bullet:
        attribute = q.Attribute.ul;
      case FormatCommand.number:
        attribute = q.Attribute.ol;
      case FormatCommand.task:
        attribute = q.Attribute.unchecked;
      case FormatCommand.quote:
        attribute = q.Attribute.blockQuote;
      case FormatCommand.indent:
        quill.indentSelection(true);
        return;
      case FormatCommand.rule:
        insertMarkdown('---');
        return;
      case FormatCommand.table:
        insertMarkdown('| 제목 1 | 제목 2 |\n| --- | --- |\n| 내용 | 내용 |');
        return;
      case FormatCommand.codeBlock:
        final text = selectedText;
        final longest = RegExp('`+')
            .allMatches(text)
            .fold(2, (int n, m) => n > m[0]!.length ? n : m[0]!.length);
        final fence = '`' * (longest + 1);
        insertMarkdown('$fence\n${text.isEmpty ? '코드를 입력하세요' : text}\n$fence');
        return;
    }
    final current = style[attribute.key];
    quill.formatSelection(
      current?.value == attribute.value
          ? q.Attribute.clone(attribute, null)
          : attribute,
    );
  }

  String get selectedText {
    final selection = quill.selection;
    return selection.textInside(quill.document.toPlainText());
  }

  void link(String label, String address, {bool image = false}) {
    if (source.transitionLocked || source.composing) return;
    if (image) {
      final markdown = FormattingCommands.link(
        TextEditingValue.empty,
        label,
        address,
        image: true,
      ).text;
      insertMarkdown(markdown);
      return;
    }
    final selection = quill.selection;
    final text = label.isEmpty ? address : label;
    quill.replaceText(
      selection.start,
      selection.end - selection.start,
      text,
      TextSelection(
        baseOffset: selection.start,
        extentOffset: selection.start + text.length,
      ),
    );
    quill.formatText(
      selection.start,
      text.length,
      q.LinkAttribute(address.trim()),
    );
  }

  void insertMarkdown(String markdown) {
    final selection = quill.selection;
    var index = selection.start;
    final plain = quill.document.toPlainText();
    if (index > 0 && plain[index - 1] != '\n') {
      quill.replaceText(index, 0, '\n', null);
      index++;
    }
    quill.replaceText(
      index,
      selection.end - selection.start,
      q.BlockEmbed(VisualMarkdownCodec.embedType, markdown),
      null,
    );
    quill.replaceText(
      index + 1,
      0,
      '\n',
      TextSelection.collapsed(offset: index + 2),
    );
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    source.removeListener(_sourceChanged);
    quill.removeListener(_visualChanged);
    quill.dispose();
    quill.document.close();
  }
}
