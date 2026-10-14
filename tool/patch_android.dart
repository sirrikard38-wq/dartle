// Small changes to the Android project that `npx cap add android` generates
// (android-app/android):
//
//   dart run tool/patch_android.dart <build number>
//
//  * the version: versionCode = the build number (so each download can update
//    the one before it), versionName = 1.0.<build number>;
//  * portrait only, like the web app;
//  * black status bar, navigation bar and window, so there is no white flash.
//
// Nothing here is allowed to break the build: a file or pattern that is not
// found is reported and skipped.
import 'dart:io';

/// versionCode and versionName in app/build.gradle.
String patchVersion(String gradle, String build) => gradle
    .replaceFirst(RegExp(r'versionCode\s+\d+'), 'versionCode $build')
    .replaceFirst(RegExp(r'versionName\s+"[^"]*"'), 'versionName "1.0.$build"');

/// Portrait only, on the main activity.
String patchPortrait(String manifest) {
  if (manifest.contains('android:screenOrientation')) return manifest;
  return manifest.replaceFirst(
    'android:name=".MainActivity"',
    'android:name=".MainActivity"\n            android:screenOrientation="portrait"',
  );
}

const _bars = '        <item name="android:statusBarColor">#000000</item>\n'
    '        <item name="android:navigationBarColor">#000000</item>\n'
    '        <item name="android:windowBackground">@android:color/black</item>';

/// Black bars and window, added to the app theme just before it closes.
String patchBlackBars(String styles) {
  if (styles.contains('android:statusBarColor')) return styles;
  return styles.replaceFirstMapped(
    RegExp(r'(<style name="AppTheme\.NoActionBar"[^>]*>.*?)(\s*</style>)', dotAll: true),
    (m) => '${m[1]!.trimRight()}\n$_bars${m[2]}',
  );
}

void _patch(String path, String what, String Function(String) change) {
  final file = File(path);
  if (!file.existsSync()) {
    stdout.writeln('skipped $what: $path not found');
    return;
  }
  final before = file.readAsStringSync();
  final after = change(before);
  if (after == before) {
    stdout.writeln('skipped $what: nothing to change in $path');
    return;
  }
  file.writeAsStringSync(after);
  stdout.writeln('patched $what');
}

void main(List<String> args) {
  final build = args.isNotEmpty ? args.first : '1';
  const app = 'android-app/android/app';
  _patch('$app/build.gradle', 'version', (t) => patchVersion(t, build));
  _patch('$app/src/main/AndroidManifest.xml', 'portrait orientation', patchPortrait);
  _patch('$app/src/main/res/values/styles.xml', 'black bars', patchBlackBars);
}
