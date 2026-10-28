import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as p;

/// Reject network roots before performing filesystem IO.
class LocalPathPolicy {
  LocalPathPolicy({bool Function(String root)? isRemote})
    : _isRemote = isRemote ?? _remoteDrive;
  final bool Function(String root) _isRemote;
  static final windows = p.Context(style: p.Style.windows);

  static bool _remoteDrive(String root) {
    if (!Platform.isWindows) return false;
    final getDriveType = DynamicLibrary.open('kernel32.dll')
        .lookupFunction<
          Uint32 Function(Pointer<Utf16>),
          int Function(Pointer<Utf16>)
        >('GetDriveTypeW');
    final pointer = root.toNativeUtf16();
    try {
      return getDriveType(pointer) == 4; // DRIVE_REMOTE
    } finally {
      calloc.free(pointer);
    }
  }

  String validate(String path) {
    if (path.startsWith(r'\\') || path.startsWith('//')) {
      throw const FormatException('네트워크 공유 경로는 지원하지 않습니다.');
    }
    if (!windows.isAbsolute(path) ||
        !RegExp(r'^[a-zA-Z]:[\\/]').hasMatch(path)) {
      throw const FormatException('로컬 드라이브의 전체 경로를 선택해 주세요.');
    }
    final normalized = windows.normalize(path);
    if (_isRemote(windows.rootPrefix(normalized))) {
      throw const FormatException('네트워크 드라이브는 지원하지 않습니다.');
    }
    return normalized;
  }

  String markdownPath(String path) {
    final result = validate(path);
    if (![
      '.md',
      '.markdown',
    ].contains(windows.extension(result).toLowerCase())) {
      throw const FormatException('.md 또는 .markdown 파일을 선택해 주세요.');
    }
    return result;
  }

  String savePath(String path) {
    final result = validate(path);
    return markdownPath(
      windows.extension(result).isEmpty ? '$result.md' : result,
    );
  }
}

class ImageLocation {
  const ImageLocation({this.path, this.message});
  final String? path;
  final String? message;
}

class ContentPolicy {
  ContentPolicy(this.paths);
  final LocalPathPolicy paths;

  String _decodePath(String value) => value.replaceAllMapped(
    RegExp(r'(?:%[0-9a-fA-F]{2})+'),
    (match) => Uri.decodeComponent(match.group(0)!),
  );

  Uri? externalLink(String href) {
    final uri = Uri.tryParse(href);
    if (uri == null ||
        !['http', 'https'].contains(uri.scheme.toLowerCase()) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      return null;
    }
    return uri;
  }

  ImageLocation image(String source, String? documentPath) {
    try {
      final uri = Uri.tryParse(source);
      if (source.startsWith('//') || source.startsWith(r'\\')) {
        return const ImageLocation(message: '네트워크 이미지는 표시하지 않습니다.');
      }
      String imagePath;
      if (RegExp(r'^[a-zA-Z]:[\\/]').hasMatch(source)) {
        imagePath = _decodePath(source);
      } else if (uri != null && uri.scheme == 'file') {
        if (uri.host.isNotEmpty) {
          return const ImageLocation(message: '네트워크 이미지는 표시하지 않습니다.');
        }
        imagePath = uri.toFilePath(windows: true);
      } else if (uri != null && uri.hasScheme) {
        return const ImageLocation(message: '원격 이미지는 표시하지 않습니다.');
      } else {
        if (documentPath == null) {
          return const ImageLocation(
            message: '문서를 저장하면 상대 경로 이미지를 표시할 수 있습니다.',
          );
        }
        imagePath = LocalPathPolicy.windows.join(
          LocalPathPolicy.windows.dirname(documentPath),
          _decodePath(source),
        );
      }
      imagePath = paths.validate(imagePath);
      if (![
        '.png',
        '.jpg',
        '.jpeg',
        '.gif',
        '.webp',
      ].contains(LocalPathPolicy.windows.extension(imagePath).toLowerCase())) {
        return const ImageLocation(message: '지원하지 않는 이미지 형식입니다.');
      }
      return ImageLocation(path: imagePath);
    } catch (_) {
      return const ImageLocation(message: '이미지 경로를 확인해 주세요.');
    }
  }
}
