import 'dart:async';
import 'dart:io';

/// Invoke Flutter's bundled tool directly, avoiding shell-launcher differences.
/// Receives the standard Flutter CMake environment; does not modify the SDK.
Future<void> main(List<String> arguments) async {
  final env = Platform.environment;
  final root = env['FLUTTER_ROOT'];
  final project = env['PROJECT_DIR'];
  if (root == null || project == null || arguments.length != 2) {
    stderr.writeln(
      'Flutter SDK, project path and build configuration are required.',
    );
    exit(1);
  }
  final platform = arguments[0];
  final mode = arguments[1].toLowerCase();
  final process = await Process.start('$root/bin/cache/dart-sdk/bin/dart.exe', [
    '--packages=$root/packages/flutter_tools/.dart_tool/package_config.json',
    '$root/bin/cache/flutter_tools.snapshot',
    'assemble',
    '--no-version-check',
    '--output=build',
    '-dTargetPlatform=$platform',
    '-dBuildMode=$mode',
    '-dTargetFile=${env['FLUTTER_TARGET'] ?? 'lib/main.dart'}',
    '-dTrackWidgetCreation=${env['TRACK_WIDGET_CREATION'] ?? 'false'}',
    '-dTreeShakeIcons=${env['TREE_SHAKE_ICONS'] ?? 'false'}',
    '-dDartObfuscation=${env['DART_OBFUSCATION'] ?? 'false'}',
    if (env['DART_DEFINES'] != null) '--DartDefines=${env['DART_DEFINES']}',
    '${mode}_bundle_${platform}_assets',
  ], workingDirectory: project);
  await Future.wait([
    stdout.addStream(process.stdout),
    stderr.addStream(process.stderr),
  ]);
  exit(await process.exitCode);
}
