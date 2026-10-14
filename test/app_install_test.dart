import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:test/test.dart';

/// The files that make Dartle installable on Android and iOS, checked without a
/// browser: the manifest, its icons, the page's links and the service worker.
void main() {
  final manifest =
      jsonDecode(File('web/manifest.webmanifest').readAsStringSync()) as Map<String, Object?>;
  final html = File('web/index.html').readAsStringSync();

  /// Width and height from a PNG file's header.
  (int, int) pngSize(File file) {
    final bytes = file.readAsBytesSync();
    expect(bytes.sublist(0, 8), [137, 80, 78, 71, 13, 10, 26, 10], reason: '${file.path} is a PNG');
    final data = ByteData.sublistView(Uint8List.fromList(bytes));
    return (data.getUint32(16), data.getUint32(20));
  }

  group('web app manifest', () {
    test('is installable: name, start page, standalone window, colours', () {
      expect(manifest['name'], isNotEmpty);
      expect(manifest['short_name'], 'Dartle');
      expect(manifest['display'], 'standalone');
      expect(manifest['start_url'], isNotEmpty);
      expect(manifest['scope'], isNotEmpty);
      expect(manifest['background_color'], '#000000');
      expect(manifest['theme_color'], '#000000');
      expect(manifest['orientation'], 'portrait');
    });

    test('start page and scope are relative, so it works under /dartle/ on GitHub Pages', () {
      for (final key in ['start_url', 'scope', 'id']) {
        final value = manifest[key] as String;
        expect(value.startsWith('/'), isFalse, reason: key);
        expect(value.startsWith('http'), isFalse, reason: key);
      }
    });

    test('has the 192 and 512 icons Android needs, and a maskable one', () {
      final icons = (manifest['icons'] as List).cast<Map<String, Object?>>();
      final sizes = icons.map((i) => i['sizes']).toSet();
      expect(sizes, containsAll(['192x192', '512x512']));
      expect(icons.where((i) => i['purpose'] == 'maskable'), isNotEmpty);
      expect(icons.where((i) => i['purpose'] == 'any').length, greaterThanOrEqualTo(2));
    });

    test('every icon exists and is exactly the size it says', () {
      for (final icon in (manifest['icons'] as List).cast<Map<String, Object?>>()) {
        final file = File('web/${icon['src']}');
        expect(file.existsSync(), isTrue, reason: '${icon['src']}');
        final side = int.parse((icon['sizes'] as String).split('x').first);
        expect(pngSize(file), (side, side), reason: '${icon['src']}');
        expect(icon['type'], 'image/png');
      }
    });

    test('the iPhone icon is 180x180 and the favicon 32x32', () {
      expect(pngSize(File('web/icons/apple-touch-icon.png')), (180, 180));
      expect(pngSize(File('web/icons/favicon-32.png')), (32, 32));
    });
  });

  group('index.html', () {
    test('links the manifest, the icons and the iOS app settings', () {
      expect(html, contains('rel="manifest" href="manifest.webmanifest"'));
      expect(html, contains('rel="apple-touch-icon" href="icons/apple-touch-icon.png"'));
      expect(html, contains('name="apple-mobile-web-app-capable" content="yes"'));
      expect(html, contains('name="mobile-web-app-capable" content="yes"'));
      expect(html, contains('name="theme-color" content="#000000"'));
    });

    test('uses the whole phone screen (notch and home bar are handled in the CSS)', () {
      expect(html, contains('viewport-fit=cover'));
      final css = File('web/styles.css').readAsStringSync();
      expect(css, contains('safe-area-inset-top'));
      expect(css, contains('safe-area-inset-bottom'));
    });

    test('keeps the build-stamped script and stylesheet links the build rewrites', () {
      expect(html, contains('href="styles.css"'));
      expect(html, contains('src="main.dart.js"'));
    });
  });

  group('Android app (.apk) project', () {
    final config =
        jsonDecode(File('android-app/capacitor.config.json').readAsStringSync()) as Map<String, Object?>;
    final package =
        jsonDecode(File('android-app/package.json').readAsStringSync()) as Map<String, Object?>;
    final workflow = File('.github/workflows/android.yml').readAsStringSync();

    test('wraps the built site, with a black background', () {
      expect(config['appId'], matches(RegExp(r'^[a-z]+(\.[a-z]+)+$')));
      expect(config['appName'], 'Dartle');
      expect(config['webDir'], '../build', reason: 'the output of tool/build.dart');
      expect(config['backgroundColor'], '#000000');
    });

    test('pins the Capacitor versions so a build is repeatable', () {
      final deps = {
        ...(package['dependencies'] as Map<String, Object?>),
        ...(package['devDependencies'] as Map<String, Object?>),
      };
      for (final name in ['@capacitor/core', '@capacitor/android', '@capacitor/cli', '@capacitor/assets']) {
        expect(deps[name], matches(RegExp(r'^\d+\.\d+\.\d+$')), reason: '$name is pinned exactly');
      }
      expect(deps['@capacitor/core'], deps['@capacitor/android']);
      expect(deps['@capacitor/core'], deps['@capacitor/cli']);
    });

    test('has the artwork @capacitor/assets needs, at the right sizes', () {
      for (final entry in {
        'icon-only.png': 1024,
        'icon-foreground.png': 1024,
        'icon-background.png': 1024,
        'splash.png': 2732,
        'splash-dark.png': 2732,
      }.entries) {
        expect(pngSize(File('android-app/assets/${entry.key}')), (entry.value, entry.value),
            reason: entry.key);
      }
    });

    test('the workflow builds the site, makes the project, builds the APK and publishes it', () {
      for (final step in [
        'dart run tool/build.dart',
        'npx cap add android',
        'npx capacitor-assets generate --android',
        'dart run tool/patch_android.dart',
        'npx cap sync android',
        './gradlew assembleDebug',
        'gh release create android-latest dartle.apk',
      ]) {
        expect(workflow, contains(step), reason: step);
      }
      expect(workflow, contains('contents: write'));
      expect(workflow, contains('debug.keystore'), reason: 'the signing key is kept between builds');
    });

    test('the generated Android project is not kept in git', () {
      final ignore = File('.gitignore').readAsStringSync();
      expect(ignore, contains('android-app/android/'));
      expect(ignore, contains('android-app/node_modules/'));
    });
  });

  group('service worker', () {
    final sw = File('web/sw.js').readAsStringSync();

    test('is stamped per build and saves the app shell', () {
      expect(sw, contains("const BUILD = '__BUILD__'"));
      for (final file in ['index.html', 'manifest.webmanifest', 'icons/icon-192.png']) {
        expect(sw, contains("'$file'"), reason: file);
      }
      expect(sw, contains(r'styles.css?v=${BUILD}'));
      expect(sw, contains(r'main.dart.js?v=${BUILD}'));
    });

    test('deletes the caches of older builds and serves the page network-first', () {
      expect(sw, contains("key.startsWith('dartle-')"));
      expect(sw, contains("request.mode === 'navigate'"));
    });

    test('online.json is never stuck on a saved copy: network first, revalidated', () {
      expect(sw, contains("endsWith('/online.json')"));
      expect(sw, contains("cache: 'no-cache'"));
      // It is not part of the precached shell (that would freeze it per build).
      expect(sw, isNot(contains("'online.json',")));
      final page = File('lib/ui/online_setup.dart').readAsStringSync();
      expect(page, contains("RequestInit(cache: 'no-cache')"));
    });

    test('everything it precaches really exists', () {
      for (final line in RegExp(r"^\s+'([^'$]+)',$", multiLine: true)
          .allMatches(sw)
          .map((m) => m.group(1)!)) {
        if (line == './') continue;
        expect(File('web/$line').existsSync(), isTrue, reason: line);
      }
    });
  });
}
