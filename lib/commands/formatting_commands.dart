import 'package:characters/characters.dart';
import 'package:flutter/services.dart';

enum FormatCommand {
  h1,
  h2,
  h3,
  bold,
  italic,
  strike,
  inlineCode,
  codeBlock,
  bullet,
  number,
  task,
  quote,
  rule,
  table,
  indent,
}

class FormattingCommands {
  static TextSelection selection(TextEditingValue value) {
    if (!value.selection.isValid) {
      return TextSelection.collapsed(offset: value.text.length);
    }
    final a = value.selection.start.clamp(0, value.text.length);
    final b = value.selection.end.clamp(0, value.text.length);
    final boundaries = <int>[0];
    for (final char in value.text.characters) {
      boundaries.add(boundaries.last + char.length);
    }
    final start = boundaries.lastWhere((n) => n <= a);
    final end = a == b ? start : boundaries.firstWhere((n) => n >= b);
    return TextSelection(baseOffset: start, extentOffset: end);
  }

  static TextEditingValue _replace(
    TextEditingValue value,
    int start,
    int end,
    String inserted, {
    int? selectStart,
    int? selectEnd,
  }) => TextEditingValue(
    text: value.text.replaceRange(start, end, inserted),
    selection: TextSelection(
      baseOffset: start + (selectStart ?? inserted.length),
      extentOffset: start + (selectEnd ?? selectStart ?? inserted.length),
    ),
  );

  static TextEditingValue _wrap(
    TextEditingValue value,
    String marker,
    String example,
  ) {
    final range = selection(value);
    final content = range.isCollapsed ? example : range.textInside(value.text);
    return _replace(
      value,
      range.start,
      range.end,
      '$marker$content$marker',
      selectStart: marker.length,
      selectEnd: marker.length + content.length,
    );
  }

  static TextEditingValue _lines(
    TextEditingValue value,
    String Function(String line, int index) transform,
  ) {
    final range = selection(value);
    final start = range.start == 0
        ? 0
        : value.text.lastIndexOf('\n', range.start - 1) + 1;
    var endPosition = range.end;
    if (!range.isCollapsed &&
        endPosition > 0 &&
        value.text[endPosition - 1] == '\n') {
      endPosition--;
    }
    final nextNewline = value.text.indexOf('\n', endPosition);
    final end = nextNewline < 0 ? value.text.length : nextNewline;
    final lines = value.text.substring(start, end).split('\n');
    final result = [
      for (var i = 0; i < lines.length; i++) transform(lines[i], i),
    ].join('\n');
    return _replace(
      value,
      start,
      end,
      result,
      selectStart: 0,
      selectEnd: result.length,
    );
  }

  static TextEditingValue _block(TextEditingValue value, String block) {
    final range = selection(value);
    final before = value.text.substring(0, range.start);
    final after = value.text.substring(range.end);
    final prefix = before.isEmpty || before.endsWith('\n\n')
        ? ''
        : before.endsWith('\n')
        ? '\n'
        : '\n\n';
    final suffix = after.isEmpty || after.startsWith('\n\n')
        ? ''
        : after.startsWith('\n')
        ? '\n'
        : '\n\n';
    return _replace(
      value,
      range.start,
      range.end,
      '$prefix$block$suffix',
      selectStart: prefix.length,
      selectEnd: prefix.length + block.length,
    );
  }

  static TextEditingValue apply(TextEditingValue value, FormatCommand command) {
    final range = selection(value);
    final chosen = range.textInside(value.text);
    switch (command) {
      case FormatCommand.bold:
        return _wrap(value, '**', '텍스트');
      case FormatCommand.italic:
        return _wrap(value, '*', '텍스트');
      case FormatCommand.strike:
        return _wrap(value, '~~', '텍스트');
      case FormatCommand.inlineCode:
        final content = chosen.isEmpty ? '코드' : chosen;
        final runs = RegExp(
          '`+',
        ).allMatches(content).map((m) => m.group(0)!.length);
        final longest = runs.fold(0, (a, b) => a > b ? a : b);
        final marker = '`' * (longest + 1);
        final padding = content.startsWith('`') || content.endsWith('`')
            ? ' '
            : '';
        return _replace(
          value,
          range.start,
          range.end,
          '$marker$padding$content$padding$marker',
          selectStart: marker.length + padding.length,
          selectEnd: marker.length + padding.length + content.length,
        );
      case FormatCommand.h1:
      case FormatCommand.h2:
      case FormatCommand.h3:
        final level = command.index + 1;
        return _lines(
          value,
          (line, _) =>
              '${'#' * level} ${line.replaceFirst(RegExp(r'^ {0,3}#{1,6}(?:[ \t]+|$)'), '')}',
        );
      case FormatCommand.bullet:
        return _lines(value, (line, _) => '- $line');
      case FormatCommand.number:
        return _lines(value, (line, i) => '${i + 1}. $line');
      case FormatCommand.task:
        return _lines(value, (line, _) => '- [ ] $line');
      case FormatCommand.quote:
        return _lines(value, (line, _) => '> $line');
      case FormatCommand.codeBlock:
        final content = chosen.isEmpty ? '코드를 입력하세요' : chosen;
        final longest = RegExp('`+')
            .allMatches(content)
            .fold(
              2,
              (int a, match) =>
                  a > match.group(0)!.length ? a : match.group(0)!.length,
            );
        final fence = '`' * (longest + 1);
        return _block(
          value,
          '$fence\n$content${content.endsWith('\n') ? '' : '\n'}$fence',
        );
      case FormatCommand.rule:
        return _block(value, '---');
      case FormatCommand.table:
        return _block(value, '| 제목 1 | 제목 2 |\n| --- | --- |\n| 내용 | 내용 |');
      case FormatCommand.indent:
        return _replace(value, range.start, range.end, '  ');
    }
  }

  static TextEditingValue link(
    TextEditingValue value,
    String label,
    String address, {
    bool image = false,
  }) {
    final range = selection(value);
    final escapedLabel = label
        .replaceAll(r'\', r'\\')
        .replaceAll('[', r'\[')
        .replaceAll(']', r'\]')
        .replaceAll('\n', ' ');
    final destination = address
        .trim()
        .replaceAll(r'\', '/')
        .replaceAll(' ', '%20')
        .replaceAll('(', '%28')
        .replaceAll(')', '%29')
        .replaceAll('<', '%3C')
        .replaceAll('>', '%3E')
        .replaceAll('\n', '')
        .replaceAll('\r', '');
    return _replace(
      value,
      range.start,
      range.end,
      '${image ? '!' : ''}[$escapedLabel]($destination)',
    );
  }
}
