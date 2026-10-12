// Builds the static site into build/: dart run tool/build.dart
import 'dart:io';

Future<void> main() async {
  final out = Directory('build')..createSync(recursive: true);
  for (final name in ['index.html', 'styles.css']) {
    File('web/$name').copySync('${out.path}/$name');
  }
  // Optional user-supplied sounds (e.g. web/audio/optimal.mp3).
  final audio = Directory('web/audio');
  if (audio.existsSync()) {
    final target = Directory('${out.path}/audio')..createSync(recursive: true);
    for (final file in audio.listSync().whereType<File>()) {
      file.copySync('${target.path}/${file.uri.pathSegments.last}');
    }
  }
  final result = await Process.run(
    Platform.resolvedExecutable,
    ['compile', 'js', '-O2', 'web/main.dart', '-o', '${out.path}/main.dart.js'],
  );
  stdout.write(result.stdout);
  stderr.write(result.stderr);
  if (result.exitCode != 0) exit(result.exitCode);
  stdout.writeln('Built into ${out.path}/');
}
