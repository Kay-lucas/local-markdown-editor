import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import '../models/document_state.dart';
import 'content_policy.dart';

abstract class DocumentFileService {
  Future<LoadedDocument> read(String path);
  Future<Uint8List?> diskBytes(String path);
  Future<void> write(String path, Uint8List bytes);
}

class DocumentWriteException implements Exception {
  const DocumentWriteException(this.tempPath);
  final String tempPath;
  @override
  String toString() =>
      '저장하지 못했습니다. 편집 내용은 유지됩니다. '
      '권한·파일 잠금·저장 공간을 확인하거나 다른 이름으로 저장해 주세요. '
      '남아 있는 임시 파일: $tempPath';
}

class LocalDocumentFileService implements DocumentFileService {
  LocalDocumentFileService(this.paths);
  final LocalPathPolicy paths;

  @override
  Future<LoadedDocument> read(String path) async =>
      LoadedDocument.decode(await File(paths.markdownPath(path)).readAsBytes());

  @override
  Future<Uint8List?> diskBytes(String path) async {
    final file = File(paths.validate(path));
    return await file.exists() ? file.readAsBytes() : null;
  }

  @override
  Future<void> write(String path, Uint8List bytes) async {
    final target = paths.markdownPath(path);
    final token =
        '${DateTime.now().microsecondsSinceEpoch}-'
        '${Random.secure().nextInt(0x7fffffff)}';
    final temp = File('$target.$token.tmp');
    try {
      await temp.writeAsBytes(bytes, flush: true);
      // Dart's Windows rename replaces the target without truncating it first.
      // Failure leaves the original intact and the temp file available for recovery.
      await temp.rename(target);
    } catch (_) {
      throw DocumentWriteException(temp.path);
    }
  }
}
