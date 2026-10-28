import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_markdown_editor/commands/formatting_commands.dart';

TextEditingValue selected(String text, int start, int end) => TextEditingValue(
  text: text,
  selection: TextSelection(baseOffset: start, extentOffset: end),
);

void main() {
  test('inline formats wrap Korean and emoji without damaging text', () {
    final value = selected('한글 😀', 0, 5);
    expect(
      FormattingCommands.apply(value, FormatCommand.bold).text,
      '**한글 😀**',
    );
    expect(
      FormattingCommands.apply(value, FormatCommand.italic).text,
      '*한글 😀*',
    );
    expect(
      FormattingCommands.apply(value, FormatCommand.strike).text,
      '~~한글 😀~~',
    );
  });
  test('no selection inserts and selects a placeholder', () {
    final result = FormattingCommands.apply(
      selected('', 0, 0),
      FormatCommand.bold,
    );
    expect(result.text, '**텍스트**');
    expect(result.selection.textInside(result.text), '텍스트');
  });
  test('selection inside a surrogate pair expands to a valid grapheme', () {
    final result = FormattingCommands.apply(
      selected('😀', 1, 2),
      FormatCommand.bold,
    );
    expect(result.text, '**😀**');
  });
  test('multiline list excludes the line starting at selection end', () {
    final result = FormattingCommands.apply(
      selected('하나\n둘\n셋', 0, 5),
      FormatCommand.number,
    );
    expect(result.text, '1. 하나\n2. 둘\n셋');
  });
  test('heading changes existing heading level on each selected line', () {
    final result = FormattingCommands.apply(
      selected('# 하나\n### 둘', 0, 10),
      FormatCommand.h2,
    );
    expect(result.text, '## 하나\n## 둘');
  });
  test('collapsed line formatting operates on the full current line', () {
    expect(
      FormattingCommands.apply(
        selected('첫 줄\n둘째 줄', 6, 6),
        FormatCommand.quote,
      ).text,
      '첫 줄\n> 둘째 줄',
    );
  });
  test('code fences grow beyond backticks in selected content', () {
    final result = FormattingCommands.apply(
      selected('```\nx\n```', 0, 9),
      FormatCommand.codeBlock,
    );
    expect(result.text, '````\n```\nx\n```\n````');
  });
  test('inline code uses padding when its content starts with a backtick', () {
    expect(
      FormattingCommands.apply(
        selected('`x`', 0, 3),
        FormatCommand.inlineCode,
      ).text,
      '`` `x` ``',
    );
  });
  test('blocks get blank lines without discarding surrounding text', () {
    final result = FormattingCommands.apply(
      selected('앞뒤', 1, 1),
      FormatCommand.rule,
    );
    expect(result.text, '앞\n\n---\n\n뒤');
  });
  test('link labels and spaced parentheses in paths are escaped', () {
    final result = FormattingCommands.link(
      selected('원문', 0, 2),
      '[한글]',
      'images/사진 (1).png',
      image: true,
    );
    expect(result.text, r'![\[한글\]](images/사진%20%281%29.png)');
  });
  test('all toolbar commands produce nonempty valid selections', () {
    for (final command in FormatCommand.values) {
      final result = FormattingCommands.apply(selected('', 0, 0), command);
      expect(result.text, isNotEmpty, reason: command.name);
      expect(result.selection.isValid, isTrue, reason: command.name);
      expect(result.selection.end, lessThanOrEqualTo(result.text.length));
    }
  });
}
