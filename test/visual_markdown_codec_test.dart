import 'package:dart_quill_delta/dart_quill_delta.dart';
import 'package:flutter_quill/flutter_quill.dart' as q;
import 'package:flutter_test/flutter_test.dart';
import 'package:local_markdown_editor/services/visual_markdown_codec.dart';
import 'package:markdown/markdown.dart' as md;

void main() {
  test(
    'visual text decodes Markdown entities and preserves Unicode literally',
    () {
      final codec = VisualMarkdownCodec('한글 😀 &amp; A & B');
      final doc = q.Document.fromDelta(codec.delta);
      expect(doc.toPlainText(), '한글 😀 & A & B\n');
      doc.close();
    },
  );

  test(
    'soft-wrapped paragraph is editable while hard breaks are preserved',
    () {
      final soft = VisualMarkdownCodec('첫 줄\n다음 줄');
      expect(soft.protectedBlocks, 0);
      final doc = q.Document.fromDelta(soft.delta);
      expect(doc.toPlainText(), '첫 줄 다음 줄\n');
      doc.close();
      expect(VisualMarkdownCodec('첫 줄  \n다음 줄').protectedBlocks, 1);
    },
  );
  test('partially overlapping inline formats survive a visual edit', () {
    final codec = VisualMarkdownCodec('**앞뒤** 끝');
    final edit = Delta()
      ..retain(1)
      ..retain(1, {'italic': true});
    codec.track(edit);
    final result = codec.encode(codec.delta.compose(edit));
    final html = md.markdownToHtml(result);
    expect(html, contains('<strong>앞'));
    expect(html, contains('<em><strong>뒤</strong></em>'));
    expect(html, contains(' 끝'));
  });
  test('opening and saving all source spellings is byte-for-byte unchanged', () {
    const samples = [
      '',
      '\n\n',
      '# 제목\n\n__굵게__  *기울임*\n',
      '제목\n====\n\n첫 줄  \n다음 줄\n',
      '+ 첫째\n+ 둘째\n\n7) 일곱\n\n> 인용\n',
      '```dart\nprint("한글");\n```\n\n| A | B |\n| --- | --- |\n| 1 | 2 |\n',
      '- [X] 완료\n\n![그림](images/한글.png)\n\n[참고][a]\n\n[a]: https://example.com\n',
      '- 부모\n  - 자식\n\n<div>HTML</div>\n',
    ];
    for (final sample in samples) {
      final codec = VisualMarkdownCodec(sample);
      final doc = q.Document.fromDelta(codec.delta);
      expect(codec.encode(doc.toDelta()), sample, reason: sample);
      doc.close();
    }
  });

  test(
    'editing one heading preserves unrelated exact source including tables',
    () {
      const source =
          '# 제목\n\n__보존__\n\n| A | B |\n| :--- | ---: |\n| 1 | 2 |\n';
      final codec = VisualMarkdownCodec(source);
      final edit = Delta()
        ..retain(2)
        ..insert(' 수정');
      codec.track(edit);
      final result = codec.encode(codec.delta.compose(edit));
      expect(
        result,
        '# 제목 수정\n\n__보존__\n\n| A | B |\n| :--- | ---: |\n| 1 | 2 |\n',
      );
    },
  );

  test('identical visual paragraphs retain their own original spelling', () {
    final codec = VisualMarkdownCodec('**같음**\n\n__같음__\n\n끝');
    final edit = Delta()..insert('새 ');
    codec.track(edit);
    final result = codec.encode(codec.delta.compose(edit));
    expect(result, contains('\n\n__같음__\n\n끝'));
  });

  test('formatting serializes bold and keeps literal punctuation escaped', () {
    final codec = VisualMarkdownCodec('문장');
    final edit = Delta()..retain(2, {'bold': true});
    codec.track(edit);
    expect(codec.encode(codec.delta.compose(edit)), '**문장**');
    final next = Delta()
      ..retain(2)
      ..insert(' *기호* & <한글>');
    codec.track(next);
    final result = codec.encode(codec.delta.compose(edit).compose(next));
    final html = md.markdownToHtml(result);
    expect(html, contains('<strong>문장</strong>'));
    expect(html, contains('*기호*'));
    expect(html, isNot(contains('<em>기호</em>')));
    expect(html, contains('&lt;한글&gt;'));
  });

  test('deleting an opaque embed removes only that selected block', () {
    final codec = VisualMarkdownCodec('앞\n\n```\n원문\n```\n\n뒤');
    final edit = Delta()
      ..retain(2)
      ..delete(2);
    codec.track(edit);
    expect(codec.encode(codec.delta.compose(edit)), '앞\n\n뒤');
  });

  test('list and task edits preserve list semantics', () {
    final codec = VisualMarkdownCodec('- [ ] 준비\n- [x] 완료\n');
    final edit = Delta()
      ..retain(2)
      ..insert(' 중');
    codec.track(edit);
    final result = codec.encode(codec.delta.compose(edit));
    expect(result, '- [ ] 준비 중\n- [x] 완료\n');
  });

  test('paragraph Enter and range deletion produce valid Markdown', () {
    final codec = VisualMarkdownCodec('가나다');
    final edit = Delta()
      ..retain(1)
      ..insert('\n');
    codec.track(edit);
    final result = codec.encode(codec.delta.compose(edit));
    expect(result, '가\n\n나다');
    expect(md.markdownToHtml(result), '<p>가</p>\n<p>나다</p>\n');
  });
}
