import 'package:dart_quill_delta/dart_quill_delta.dart';
import 'package:markdown/markdown.dart' as md;

/// A conservative Markdown bridge. Untouched source blocks are reused verbatim;
/// unsupported blocks travel as opaque embeds, never through an HTML converter.
class VisualMarkdownCodec {
  VisualMarkdownCodec(this.source) {
    _decode();
  }

  static const embedType = 'preserved-markdown';
  final String source;
  final Delta delta = Delta();
  final List<_SourceBlock> _blocks = [];
  String _leading = '';
  bool _changed = false;
  int protectedBlocks = 0;

  void _decode() {
    final lines = source.split('\n');
    var i = 0;
    var visualOffset = 0;
    while (i < lines.length) {
      if (lines[i].trim().isEmpty) {
        final blank = lines[i] + (i < lines.length - 1 ? '\n' : '');
        if (_blocks.isEmpty) {
          _leading += blank;
        } else {
          _blocks.last.raw += blank;
        }
        i++;
        continue;
      }
      final start = i;
      final fence = RegExp(r'^ {0,3}(`{3,}|~{3,})').firstMatch(lines[i]);
      if (fence != null) {
        final marker = fence[1]!;
        i++;
        while (i < lines.length) {
          final close = lines[i].trim();
          i++;
          if (RegExp(
            '^${RegExp.escape(marker[0])}{${marker.length},} *\$',
          ).hasMatch(close)) {
            break;
          }
        }
      } else if (_isSingleLineBlock(lines[i])) {
        i++;
        // List continuation/nesting belongs to the item, not a new paragraph.
        if (_list.hasMatch(lines[start])) {
          while (i < lines.length &&
              lines[i].trim().isNotEmpty &&
              RegExp(r'^[ \t]+\S').hasMatch(lines[i])) {
            i++;
          }
        }
      } else {
        i++;
        while (i < lines.length &&
            lines[i].trim().isNotEmpty &&
            !_isSingleLineBlock(lines[i]) &&
            !RegExp(r'^ {0,3}(`{3,}|~{3,})').hasMatch(lines[i])) {
          i++;
        }
      }
      final content = lines.sublist(start, i).join('\n');
      final raw = content + (i < lines.length ? '\n' : '');
      final blockDelta = _decodeBlock(content);
      final begin = visualOffset;
      for (final op in blockDelta.toList()) {
        delta.push(op);
        visualOffset += op.length!;
      }
      _blocks.add(_SourceBlock(begin, visualOffset, raw));
    }
    if (delta.isEmpty) delta.insert('\n');
  }

  static final _list = RegExp(r'^ {0,3}(?:[-+*]|\d+[.)])\s+');
  static bool _isSingleLineBlock(String line) =>
      RegExp(r'^ {0,3}#{1,6}(?:\s|$)').hasMatch(line) ||
      _list.hasMatch(line) ||
      RegExp(r'^ {0,3}>').hasMatch(line);

  Delta _decodeBlock(String content) {
    if (RegExp(r'^ {0,3}\[[^\]]+\]:', multiLine: true).hasMatch(source) &&
        content.contains('[')) {
      return _protected(content);
    }
    final result = Delta();
    final attrs = <String, dynamic>{};
    var text = content;
    final heading = RegExp(
      r'^ {0,3}(#{1,6})(?:[ \t]+|$)(.*)$',
    ).firstMatch(text);
    final list = RegExp(r'^( {0,3})([-+*]|\d+[.)])\s+(.*)$').firstMatch(text);
    if (heading != null) {
      attrs['header'] = heading[1]!.length;
      text = heading[2]!.replaceFirst(RegExp(r'\s+#+\s*$'), '');
    } else if (list != null && !text.contains('\n')) {
      attrs['list'] = RegExp(r'^\d').hasMatch(list[2]!) ? 'ordered' : 'bullet';
      // Nonstandard starting numbers are preserved until this item is edited.
      text = list[3]!;
      final task = RegExp(r'^\[([ xX])\]\s+(.*)$').firstMatch(text);
      if (task != null) {
        attrs['list'] = task[1] == ' ' ? 'unchecked' : 'checked';
        text = task[2]!;
      }
    } else if (RegExp(r'^ {0,3}> ?[^>]').hasMatch(text) &&
        !text.contains('\n')) {
      attrs['blockquote'] = true;
      text = text.replaceFirst(RegExp(r'^ {0,3}> ?'), '');
    } else {
      // Only a genuine paragraph is editable here. Fences, tables, reference
      // definitions, HTML, setext headings and complex lists stay source-backed.
      final nodes = md.Document(
        extensionSet: md.ExtensionSet.gitHubFlavored,
        encodeHtml: false,
      ).parse(content);
      if (nodes.length != 1 ||
          nodes.single is! md.Element ||
          (nodes.single as md.Element).tag != 'p' ||
          RegExp(r'^\s*(?:<|\[[^\]]+\]:|---\s*$|\+\+\+)').hasMatch(content)) {
        return _protected(content);
      }
    }
    // Soft-wrapped paragraphs display as one paragraph. Explicit hard breaks
    // keep their exact source in a protected block.
    if (text.contains('\n')) {
      if (RegExp(r'(?: {2,}|\\)\n').hasMatch(text)) return _protected(content);
      text = text.replaceAll('\n', ' ');
    }
    try {
      final nodes = md.Document(
        extensionSet: md.ExtensionSet.gitHubFlavored,
        encodeHtml: false,
      ).parseInline(text);
      _inline(nodes, result, const {});
    } on UnsupportedError {
      return _protected(content);
    }
    result.insert('\n', attrs.isEmpty ? null : attrs);
    return result;
  }

  Delta _protected(String content) {
    protectedBlocks++;
    return Delta()
      ..insert({embedType: content})
      ..insert('\n');
  }

  void _inline(List<md.Node> nodes, Delta out, Map<String, dynamic> attrs) {
    for (final node in nodes) {
      if (node is md.Text) {
        out.insert(node.text, attrs.isEmpty ? null : attrs);
        continue;
      }
      final element = node as md.Element;
      final next = Map<String, dynamic>.from(attrs);
      switch (element.tag) {
        case 'strong':
          next['bold'] = true;
        case 'em':
          next['italic'] = true;
        case 'del':
          next['strike'] = true;
        case 'code':
          next['code'] = true;
        case 'a':
          next['link'] = element.attributes['href'];
        default:
          throw UnsupportedError(element.tag);
      }
      _inline(element.children ?? [], out, next);
    }
  }

  /// Track changes in Quill coordinates, not by text matching (duplicate
  /// paragraphs may have different original Markdown spellings).
  void track(Delta change) {
    if (change.isEmpty) return;
    _changed = true;
    for (final block in _blocks) {
      if (block.touched) continue;
      var offset = 0;
      for (final op in change.toList()) {
        final length = op.length!;
        if (op.isInsert) {
          if (offset >= block.start && offset < block.end) block.touched = true;
        } else {
          if ((op.isDelete || op.attributes?.isNotEmpty == true) &&
              offset < block.end &&
              offset + length > block.start) {
            block.touched = true;
          }
          offset += length;
        }
      }
      block.start = change.transformPosition(block.start);
      block.end = change.transformPosition(block.end, force: false);
    }
  }

  String encode(Delta current) {
    if (!_changed) return source;
    final reusable = {
      for (final b in _blocks)
        if (!b.touched) b.start: b,
    };
    final lines = _lines(current);
    final out = StringBuffer(_leading);
    var index = 0;
    while (index < lines.length) {
      final line = lines[index];
      final original = reusable[line.start];
      if (original != null) {
        out.write(original.raw);
        while (index < lines.length && lines[index].start < original.end) {
          index++;
        }
        continue;
      }
      // Embeds carry their exact Markdown, including unsupported syntax.
      final embeds = line.content.where((op) => op.data is Map).toList();
      if (embeds.isNotEmpty) {
        for (final op in line.content) {
          if (op.data is Map) {
            out.write((op.data as Map)[embedType] ?? '');
          } else {
            out.write(_inlineMarkdown([op]));
          }
        }
        out.write('\n\n');
      } else {
        var body = _inlineMarkdown(line.content);
        final attrs = line.attributes;
        final header = attrs['header'];
        final list = attrs['list'];
        final indent = (attrs['indent'] as int? ?? 0).clamp(0, 8);
        if (header is int && header >= 1 && header <= 6) {
          body = '${'#' * header} $body';
        } else if (list != null) {
          final prefix = switch (list) {
            'ordered' => '1. ',
            'checked' => '- [x] ',
            'unchecked' => '- [ ] ',
            _ => '- ',
          };
          body = '${'  ' * indent}$prefix$body';
        } else if (attrs['blockquote'] == true) {
          body = '> $body';
        } else if (attrs['code-block'] != null) {
          body = '```\n${line.content.map((o) => o.data).join()}\n```';
        }
        out.write(body);
        final next = index + 1 < lines.length ? lines[index + 1] : null;
        out.write(
          list != null && next?.attributes['list'] != null ? '\n' : '\n\n',
        );
      }
      index++;
    }
    // Preserve the original final-newline convention for a normal edited block.
    var result = out.toString();
    if (result.endsWith('\n\n') &&
        (lines.isEmpty || !reusable.containsKey(lines.last.start))) {
      result = result.substring(0, result.length - 2);
      if (source.endsWith('\n')) result += '\n';
    }
    return result;
  }

  static String _escape(String text) => text
      .replaceAll(r'\', r'\\')
      .replaceAll('&', '&amp;')
      .replaceAllMapped(RegExp(r'[\`*_{}\[\]<>#|~!+\-.]'), (m) => '\\${m[0]}');

  static String _inlineMarkdown(List<Operation> operations) {
    final out = StringBuffer();
    for (final op in operations) {
      if (op.data is! String) continue;
      final attrs = op.attributes ?? const <String, dynamic>{};
      final raw = op.data as String;
      var text = _escape(raw);
      if (attrs['code'] == true) {
        final longest = RegExp('`+')
            .allMatches(raw)
            .fold(0, (int n, m) => n > m[0]!.length ? n : m[0]!.length);
        final fence = '`' * (longest + 1);
        final pad =
            raw.startsWith('`') ||
                raw.endsWith('`') ||
                (raw.startsWith(' ') && raw.endsWith(' '))
            ? ' '
            : '';
        text = '$fence$pad$raw$pad$fence';
      } else {
        // Whitespace outside markers avoids invalid '** text **' delimiters.
        final leading = RegExp(r'^\s*').stringMatch(text)!;
        final trailing = RegExp(r'\s*$').stringMatch(text)!;
        var middle = text.trim();
        if (middle.isNotEmpty) {
          if (attrs['bold'] == true) middle = '**$middle**';
          if (attrs['italic'] == true) middle = '*$middle*';
          if (attrs['strike'] == true) middle = '~~$middle~~';
          text = '$leading$middle$trailing';
        }
      }
      final link = attrs['link'];
      if (link is String) {
        final url = link
            .replaceAll(' ', '%20')
            .replaceAll('(', '%28')
            .replaceAll(')', '%29')
            .replaceAll('\n', '')
            .replaceAll('\r', '')
            .replaceAll('<', '%3C')
            .replaceAll('>', '%3E');
        text = '[$text]($url)';
      }
      out.write(text);
    }
    return out.toString();
  }

  static List<_VisualLine> _lines(Delta delta) {
    final result = <_VisualLine>[];
    var content = <Operation>[];
    var start = 0;
    var offset = 0;
    for (final op in delta.toList()) {
      if (op.data is! String) {
        content.add(op);
        offset++;
        continue;
      }
      final parts = (op.data as String).split('\n');
      for (var i = 0; i < parts.length; i++) {
        if (parts[i].isNotEmpty) {
          content.add(Operation.insert(parts[i], op.attributes));
          offset += parts[i].length;
        }
        if (i < parts.length - 1) {
          result.add(_VisualLine(start, content, op.attributes ?? {}));
          offset++;
          start = offset;
          content = [];
        }
      }
    }
    return result;
  }
}

class _SourceBlock {
  _SourceBlock(this.start, this.end, this.raw);
  int start;
  int end;
  String raw;
  bool touched = false;
}

class _VisualLine {
  _VisualLine(this.start, this.content, this.attributes);
  final int start;
  final List<Operation> content;
  final Map<String, dynamic> attributes;
}
