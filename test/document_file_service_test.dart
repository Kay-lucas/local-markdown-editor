import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_markdown_editor/models/document_state.dart';
import 'package:local_markdown_editor/services/content_policy.dart';
import 'package:local_markdown_editor/services/document_file_service.dart';

void main() {
  late Directory directory;
  late LocalDocumentFileService files;
  late String path;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('local_markdown_test_');
    path = '${directory.path}\\회의록 (초안).md';
    files = LocalDocumentFileService(LocalPathPolicy());
  });
  tearDown(() async => directory.delete(recursive: true));

  for (final bom in [false, true]) {
    for (final newline in ['\n', '\r\n']) {
      for (final text in [
        '',
        '한글 English 😀 é  ',
        '마지막 줄\n',
        '첫 줄\n둘째 줄  \n',
      ]) {
        test(
          'UTF-8 round-trip BOM=$bom newline=${newline.length} chars=${text.length}',
          () async {
            final bytes = DocumentFormat(
              bom: bom,
              newline: newline,
            ).encode(text);
            await files.write(path, bytes);
            final loaded = await files.read(path);
            expect(loaded.text, text);
            expect(loaded.format.bom, bom);
            if (text.contains('\n')) expect(loaded.format.newline, newline);
            expect(await File(path).readAsBytes(), bytes);
            expect((await directory.list().toList()).length, 1);
          },
        );
      }
    }
  }
  test('mixed line endings use the first observed newline', () {
    final loaded = LoadedDocument.decode(
      Uint8List.fromList(utf8.encode('가\r\n나\n다')),
    );
    expect(loaded.mixed, isTrue);
    expect(loaded.format.newline, '\r\n');
    expect(utf8.decode(loaded.format.encode(loaded.text)), '가\r\n나\r\n다');
  });
  test('invalid UTF-8 throws rather than inserting replacement characters', () {
    expect(
      () => LoadedDocument.decode(Uint8List.fromList([0xff, 0xfe, 0x41])),
      throwsFormatException,
    );
  });
  test('replacement writes the full new bytes over an existing file', () async {
    await File(path).writeAsString('기존 원본');
    await files.write(path, Uint8List.fromList(utf8.encode('새 내용')));
    expect(await File(path).readAsString(), '새 내용');
  });
  test(
    'failed replacement retains original directory and recovery temp',
    () async {
      await Directory(path).create();
      final original = File('$path\\original.txt');
      await original.writeAsString('보존');
      await expectLater(
        files.write(path, Uint8List.fromList([65])),
        throwsA(isA<DocumentWriteException>()),
      );
      expect(await original.readAsString(), '보존');
      expect(
        (await directory.list().toList()).whereType<File>().single.path,
        endsWith('.tmp'),
      );
    },
  );
  test(
    'exclusive Windows file handle prevents replacement without damaging original',
    () async {
      if (!Platform.isWindows) return;
      await File(path).writeAsString('원본 유지');
      final library = DynamicLibrary.open('kernel32.dll');
      final createFile = library
          .lookupFunction<
            IntPtr Function(
              Pointer<Utf16>,
              Uint32,
              Uint32,
              Pointer<Void>,
              Uint32,
              Uint32,
              IntPtr,
            ),
            int Function(Pointer<Utf16>, int, int, Pointer<Void>, int, int, int)
          >('CreateFileW');
      final closeHandle = library
          .lookupFunction<Int32 Function(IntPtr), int Function(int)>(
            'CloseHandle',
          );
      final pointer = path.toNativeUtf16();
      final handle = createFile(pointer, 0x80000000, 0, nullptr, 3, 0x80, 0);
      calloc.free(pointer);
      expect(handle, isNot(-1));
      try {
        await expectLater(
          files.write(path, Uint8List.fromList([65])),
          throwsA(isA<DocumentWriteException>()),
        );
      } finally {
        closeHandle(handle);
      }
      expect(await File(path).readAsString(), '원본 유지');
    },
  );
  test(
    'missing parent reports a write failure without creating a false saved file',
    () async {
      final missing = '${directory.path}\\missing\\file.md';
      await expectLater(
        files.write(missing, Uint8List.fromList([65])),
        throwsA(isA<DocumentWriteException>()),
      );
      expect(await File(missing).exists(), isFalse);
    },
  );
}
