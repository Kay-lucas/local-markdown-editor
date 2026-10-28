import 'package:flutter_test/flutter_test.dart';
import 'package:local_markdown_editor/services/content_policy.dart';

void main() {
  final paths = LocalPathPolicy(
    isRemote: (root) => root.toUpperCase() == 'Z:\\',
  );
  final policy = ContentPolicy(paths);
  test('relative image resolves against the saved Markdown document', () {
    expect(
      policy.image('../사진/한글%20이미지.png', r'C:\문서\초안\memo.md').path,
      r'C:\문서\사진\한글 이미지.png',
    );
  });
  test('unsaved relative images never resolve against working directory', () {
    final result = policy.image('photo.png', null);
    expect(result.path, isNull);
    expect(result.message, contains('문서를 저장'));
  });
  test('local absolute paths and hostless file URIs work', () {
    expect(policy.image(r'C:\문서\사진.png', null).path, r'C:\문서\사진.png');
    expect(
      policy.image('file:///C:/photos/a%20b.jpg', null).path,
      r'C:\photos\a b.jpg',
    );
  });
  test(
    'remote, UNC, mapped network and unsupported images are rejected before IO',
    () {
      for (final source in [
        'https://example.com/a.png',
        'data:image/png;base64,AA',
        '//server/share/a.png',
        r'\\server\share\a.png',
        'file://server/share/a.png',
        r'Z:\a.png',
        r'C:\a.svg',
      ]) {
        expect(
          policy.image(source, r'C:\doc\memo.md').path,
          isNull,
          reason: source,
        );
      }
    },
  );
  test('only explicit HTTP(S) text links can open', () {
    expect(policy.externalLink('https://example.com/a'), isNotNull);
    expect(policy.externalLink('http://example.com'), isNotNull);
    for (final link in [
      'javascript:alert(1)',
      'file:///C:/x.exe',
      'data:text/html,a',
      'mailto:a@example.com',
      '#heading',
      'https:',
      'https://user:pass@example.com',
    ]) {
      expect(policy.externalLink(link), isNull, reason: link);
    }
  });
  test(
    'Markdown extensions are case insensitive and extensionless save gets .md',
    () {
      expect(paths.markdownPath(r'C:\a.MARKDOWN'), r'C:\a.MARKDOWN');
      expect(paths.savePath(r'C:\a'), r'C:\a.md');
      expect(() => paths.savePath(r'C:\a.txt'), throwsFormatException);
      expect(() => paths.markdownPath(r'Z:\a.md'), throwsFormatException);
      expect(() => paths.markdownPath(r'\\host\a.md'), throwsFormatException);
    },
  );
}
