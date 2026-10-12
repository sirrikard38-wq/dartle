// Builds the static site into build/: dart run tool/build.dart
import 'dart:io';

Future<void> main() async {
  final out = Directory('build')..createSync(recursive: true);
  File('web/styles.css').copySync('${out.path}/styles.css');
  // GitHub Pages lets browsers keep files for 10 minutes. A build stamp on the
  // script and stylesheet addresses makes every deploy load fresh copies.
  final stamp = DateTime.now().millisecondsSinceEpoch;
  File('${out.path}/index.html').writeAsStringSync(File('web/index.html')
      .readAsStringSync()
      .replaceAll('href="styles.css"', 'href="styles.css?v=$stamp"')
      .replaceAll('src="main.dart.js"', 'src="main.dart.js?v=$stamp"'));
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
