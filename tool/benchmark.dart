import 'dart:convert';
import 'dart:io';

import 'package:local_markdown_editor/models/document_state.dart';
import 'package:local_markdown_editor/services/content_policy.dart';
import 'package:local_markdown_editor/services/document_file_service.dart';
import 'package:markdown/markdown.dart' as md;

/// AOT benchmark for IO and parsing only; it does not measure Flutter frames.
Future<void> main(List<String> arguments) async {
  final directory = arguments.isEmpty
      ? await Directory.systemTemp.createTemp('local_markdown_benchmark_')
      : await Directory(arguments.first).create(recursive: true);
  final files = LocalDocumentFileService(LocalPathPolicy());
  const block =
      '## 한글 문서\n\n일반 본문과 **굵은 글씨**, 이모지 😀를 기록합니다.\n\n'
      '- [ ] 할 일\n- [x] 완료\n\n| 항목 | 내용 |\n| --- | --- |\n| 한글 | 정상 |\n\n';
  final extensions = md.ExtensionSet(
    md.ExtensionSet.gitHubFlavored.blockSyntaxes,
    md.ExtensionSet.gitHubFlavored.inlineSyntaxes
        .where((s) => s is! md.InlineHtmlSyntax)
        .toList(),
  );
  final results = <Map<String, Object>>[];
  for (final targetBytes in [100 * 1024, 1024 * 1024]) {
    final text = block * (targetBytes / utf8.encode(block).length).ceil();
    final bytes = const DocumentFormat().encode(text);
    final path = '${directory.path}\\${targetBytes ~/ 1024}kb.md';
    await files.write(path, bytes);
    for (var warm = 0; warm < 2; warm++) {
      md.Document(extensionSet: extensions, encodeHtml: false).parse(text);
    }
    final parses = <int>[];
    final io = <int>[];
    for (var run = 0; run < 5; run++) {
      final watch = Stopwatch()..start();
      md.Document(extensionSet: extensions, encodeHtml: false).parse(text);
      parses.add(watch.elapsedMicroseconds);
      watch.reset();
      final loaded = await files.read(path);
      if (loaded.text != text) throw StateError('Round-trip text mismatch');
      await files.write(path, loaded.format.encode(loaded.text));
      io.add(watch.elapsedMicroseconds);
    }
    parses.sort();
    io.sort();
    results.add({
      'bytes': bytes.length,
      'parseMedianMs': parses[2] / 1000,
      'readEncodeWriteMedianMs': io[2] / 1000,
      'roundTrip': true,
    });
  }
  final report = const JsonEncoder.withIndent('  ').convert({
    'kind': 'Dart AOT IO and GFM parser; not end-to-end UI timing',
    'dart': Platform.version,
    'os': Platform.operatingSystemVersion,
    'results': results,
  });
  await File('${directory.path}\\benchmark_results.json').writeAsString(report);
  stdout.writeln(report);
}
