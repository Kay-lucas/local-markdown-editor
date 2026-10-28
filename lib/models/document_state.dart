import 'dart:convert';
import 'dart:typed_data';

class DocumentFormat {
  const DocumentFormat({this.bom = false, this.newline = '\n'});
  final bool bom;
  final String newline;
  String get newlineLabel => newline == '\r\n' ? 'CRLF' : 'LF';

  Uint8List encode(String text) => Uint8List.fromList([
    if (bom) ...[0xef, 0xbb, 0xbf],
    ...utf8.encode(text.replaceAll('\n', newline)),
  ]);
}

class LoadedDocument {
  const LoadedDocument(
    this.text,
    this.format,
    this.bytes, {
    this.mixed = false,
  });
  final String text;
  final DocumentFormat format;
  final Uint8List bytes;
  final bool mixed;

  factory LoadedDocument.decode(Uint8List bytes) {
    final bom =
        bytes.length >= 3 &&
        bytes[0] == 0xef &&
        bytes[1] == 0xbb &&
        bytes[2] == 0xbf;
    final raw = utf8.decode(
      bom ? bytes.sublist(3) : bytes,
      allowMalformed: false,
    );
    final breaks = RegExp(r'\r\n|\n').allMatches(raw);
    final newline = breaks.isEmpty ? '\n' : breaks.first.group(0)!;
    return LoadedDocument(
      raw.replaceAll('\r\n', '\n'),
      DocumentFormat(bom: bom, newline: newline),
      Uint8List.fromList(bytes),
      mixed: breaks.any((match) => match.group(0) != newline),
    );
  }
}
