import 'package:test/test.dart';

import '../tool/patch_android.dart';

/// The patch script runs on the Android project that Capacitor generates, which
/// is only made in the GitHub build. These checks use small copies of the files
/// Capacitor's template contains.
void main() {
  const gradle = '''
android {
    defaultConfig {
        applicationId "com.pknormal.dartle"
        minSdkVersion rootProject.ext.minSdkVersion
        versionCode 1
        versionName "1.0"
    }
}
''';

  const manifest = '''
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <application android:label="@string/app_name">
        <activity
            android:configChanges="orientation|screenSize"
            android:name=".MainActivity"
            android:label="@string/title_activity_main"
            android:exported="true">
        </activity>
    </application>
</manifest>
''';

  const styles = '''
<?xml version="1.0" encoding="utf-8" ?>
<resources>
    <style name="AppTheme" parent="Theme.AppCompat.DayNight.DarkActionBar">
    </style>

    <style name="AppTheme.NoActionBar" parent="Theme.AppCompat.DayNight.NoActionBar">
        <item name="windowActionBar">false</item>
        <item name="windowNoTitle">true</item>
        <item name="android:background">@null</item>
    </style>

    <style name="AppTheme.NoActionBarLaunch" parent="AppTheme.NoActionBar">
        <item name="android:background">@drawable/splash</item>
    </style>
</resources>
''';

  group('version', () {
    test('versionCode is the build number and versionName is 1.0.<build>', () {
      final out = patchVersion(gradle, '42');
      expect(out, contains('versionCode 42'));
      expect(out, contains('versionName "1.0.42"'));
      expect(out, isNot(contains('versionCode 1\n')));
      expect(out, contains('applicationId "com.pknormal.dartle"'));
    });

    test('a later build is a higher versionCode, so it can update the earlier one', () {
      int code(String build) =>
          int.parse(RegExp(r'versionCode (\d+)').firstMatch(patchVersion(gradle, build))![1]!);
      expect(code('13'), greaterThan(code('9')));
    });
  });

  group('portrait', () {
    test('is added to the main activity', () {
      final out = patchPortrait(manifest);
      expect(out, contains('android:screenOrientation="portrait"'));
      expect(out, contains('android:name=".MainActivity"'));
    });

    test('is not added twice', () {
      expect(patchPortrait(patchPortrait(manifest)), patchPortrait(manifest));
    });
  });

  group('black bars', () {
    test('go into the app theme only, not the others', () {
      final out = patchBlackBars(styles);
      expect(out, contains('android:statusBarColor">#000000'));
      expect(out, contains('android:navigationBarColor">#000000'));
      expect(out, contains('android:windowBackground">@android:color/black'));
      expect('android:statusBarColor'.allMatches(out), hasLength(1));
      // Inside AppTheme.NoActionBar, before the next style starts.
      final theme = out.indexOf('<style name="AppTheme.NoActionBar"');
      final bars = out.indexOf('android:statusBarColor');
      final launch = out.indexOf('<style name="AppTheme.NoActionBarLaunch"');
      expect(bars, greaterThan(theme));
      expect(bars, lessThan(launch));
      expect(out, contains('<item name="android:background">@null</item>'));
    });

    test('is not added twice', () {
      expect(patchBlackBars(patchBlackBars(styles)), patchBlackBars(styles));
    });

    test('a file without the theme is left alone', () {
      const other = '<resources><style name="Other"></style></resources>';
      expect(patchBlackBars(other), other);
    });
  });
}
