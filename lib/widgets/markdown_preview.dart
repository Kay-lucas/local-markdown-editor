import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;

import '../controllers/editor_controller.dart';
import '../services/content_policy.dart';

final editorMarkdownExtensions = md.ExtensionSet(
  md.ExtensionSet.gitHubFlavored.blockSyntaxes,
  md.ExtensionSet.gitHubFlavored.inlineSyntaxes
      .where((s) => s is! md.InlineHtmlSyntax)
      .toList(),
);

class MarkdownPreview extends StatefulWidget {
  const MarkdownPreview({
    super.key,
    required this.editor,
    required this.policy,
    required this.onLink,
  });
  final EditorController editor;
  final ContentPolicy policy;
  final void Function(String) onLink;
  @override
  State<MarkdownPreview> createState() => _MarkdownPreviewState();
}

class _MarkdownPreviewState extends State<MarkdownPreview> {
  final _scroll = ScrollController();
  Timer? _timer;
  String _data = '';
  String _requested = '';
  String? _path;
  int _document = -1;
  String? _error;
  @override
  void initState() {
    super.initState();
    _data = widget.editor.text.text;
    _requested = _data;
    _document = widget.editor.documentId;
    _path = widget.editor.path;
    widget.editor.addListener(_changed);
  }

  void _changed() {
    final editor = widget.editor;
    if (_requested == editor.text.text &&
        _path == editor.path &&
        _document == editor.documentId) {
      return;
    }
    final reset = _document != editor.documentId;
    _requested = editor.text.text;
    _path = editor.path;
    _document = editor.documentId;
    _timer?.cancel();
    final revision = editor.revision;
    final document = editor.documentId;
    final requested = _requested;
    _timer = Timer(const Duration(milliseconds: 200), () {
      if (!mounted ||
          revision != editor.revision ||
          document != editor.documentId) {
        return;
      }
      try {
        // Validate before rebuilding, so a parser error stays inside this pane.
        md.Document(
          extensionSet: editorMarkdownExtensions,
          encodeHtml: false,
        ).parse(requested);
        setState(() {
          _data = requested;
          _error = null;
        });
      } catch (_) {
        setState(() => _error = '미리보기를 표시하지 못했습니다. 원문을 계속 편집할 수 있습니다.');
      }
      if (reset && _scroll.hasClients) _scroll.jumpTo(0);
    });
  }

  Widget _placeholder(String text, String? alt) => Container(
    padding: const EdgeInsets.all(12),
    margin: const EdgeInsets.symmetric(vertical: 8),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainer,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.image_outlined, size: 20),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            '${alt?.isNotEmpty == true ? '$alt · ' : ''}$text',
            style: const TextStyle(fontSize: 13),
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (_error != null) return Center(child: Text(_error!));
    if (_data.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.article_outlined,
              size: 38,
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            const SizedBox(height: 14),
            Text(
              '작성한 문서가 여기에 표시됩니다',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }
    final colors = Theme.of(context).colorScheme;
    return Markdown(
      key: const ValueKey('rendered-markdown'),
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 48),
      data: _data,
      selectable: true,
      extensionSet: editorMarkdownExtensions,
      softLineBreak: false,
      styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
        p: TextStyle(fontSize: 16, height: 1.75, color: colors.onSurface),
        h1: TextStyle(
          fontSize: 30,
          height: 1.4,
          fontWeight: FontWeight.w700,
          color: colors.onSurface,
        ),
        h2: TextStyle(
          fontSize: 24,
          height: 1.5,
          fontWeight: FontWeight.w700,
          color: colors.onSurface,
        ),
        code: TextStyle(
          fontFamily: 'Consolas',
          fontFamilyFallback: const ['Malgun Gothic'],
          fontSize: 14,
          color: colors.onSurface,
          backgroundColor: colors.surfaceContainer,
        ),
        codeblockDecoration: BoxDecoration(
          color: colors.surfaceContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        blockquoteDecoration: BoxDecoration(
          color: colors.surfaceContainer,
          border: Border(left: BorderSide(width: 3, color: colors.primary)),
        ),
        tableBorder: TableBorder.all(color: colors.outlineVariant),
        horizontalRuleDecoration: BoxDecoration(
          border: Border(top: BorderSide(color: colors.outlineVariant)),
        ),
        a: TextStyle(
          color: colors.primary,
          decoration: TextDecoration.underline,
        ),
      ),
      checkboxBuilder: (checked) => Icon(
        checked ? Icons.check_box_outlined : Icons.check_box_outline_blank,
        size: 18,
        color: colors.primary,
      ),
      onTapLink: (_, href, _) {
        if (href != null) widget.onLink(href);
      },
      imageBuilder: (uri, title, alt) {
        final location = widget.policy.image(uri.toString(), _path);
        if (location.path == null) return _placeholder(location.message!, alt);
        return Semantics(
          label: alt ?? '로컬 이미지',
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 400),
            child: Image.file(
              File(location.path!),
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => _placeholder('이미지를 불러올 수 없습니다.', alt),
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    widget.editor.removeListener(_changed);
    _timer?.cancel();
    _scroll.dispose();
    super.dispose();
  }
}
