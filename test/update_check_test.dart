import 'dart:io';

import 'package:dartle/ui/update_check.dart';
import 'package:test/test.dart';

/// The app reloads itself for a newer version, but not when the page is already
/// the newest (after a deploy the page is fetched fresh; only the worker is
/// behind). A needless reload replays the welcome screen a few seconds after the
/// intro, which looks like the animation playing again.
void main() {
  group('the build of a script', () {
    test('is its ?v= stamp', () {
      expect(buildOfScriptSrc('main.dart.js?v=1792130584657'), '1792130584657');
      expect(buildOfScriptSrc('https://x.github.io/dartle/main.dart.js?v=17#a'), '17');
      expect(buildOfScriptSrc('main.dart.js?x=1&v=42'), '42');
    });

    test('is null when there is none', () {
      expect(buildOfScriptSrc('main.dart.js'), isNull);
      expect(buildOfScriptSrc(null), isNull);
    });
  });

  group('does the page have to reload?', () {
    test('no: the page is already the newest build (the new worker\'s cache is the page\'s own)', () {
      expect(updateNeeded(runningBuild: '200', cacheNames: ['dartle-200']), isFalse);
    });

    test('no, even while the older build\'s cache is still there: the worker cleans it up only after taking over', () {
      // The situation seen in the browser: both caches exist when the takeover is announced.
      expect(updateNeeded(runningBuild: '200', cacheNames: ['dartle-100', 'dartle-200']), isFalse);
      expect(updateNeeded(runningBuild: '1792131793660', cacheNames: ['dartle-1792131738377', 'dartle-1792131793660']), isFalse);
    });

    test('yes: a newer build has taken over from the page that was left open', () {
      expect(updateNeeded(runningBuild: '100', cacheNames: ['dartle-200']), isTrue);
      expect(updateNeeded(runningBuild: '100', cacheNames: ['dartle-100', 'dartle-200']), isTrue);
    });

    test('a bigger stamp is a newer build, however many digits it has', () {
      expect(updateNeeded(runningBuild: '999', cacheNames: ['dartle-1000']), isTrue);
      expect(updateNeeded(runningBuild: '1000', cacheNames: ['dartle-999']), isFalse);
    });

    test('other caches on the same site are not the worker\'s', () {
      expect(updateNeeded(runningBuild: '200', cacheNames: ['other-999', 'dartle-200']), isFalse);
      expect(updateNeeded(runningBuild: '100', cacheNames: ['other-1', 'dartle-200']), isTrue);
    });

    test('in any doubt it reloads, as it always did', () {
      // The page does not know its build, or it is not a stamp.
      expect(updateNeeded(runningBuild: null, cacheNames: ['dartle-200']), isTrue);
      expect(updateNeeded(runningBuild: 'abc', cacheNames: ['dartle-200']), isTrue);
      // No cache of the app can be seen.
      expect(updateNeeded(runningBuild: '200', cacheNames: []), isTrue);
      expect(updateNeeded(runningBuild: '200', cacheNames: ['other-1']), isTrue);
      expect(updateNeeded(runningBuild: '200', cacheNames: ['dartle-x']), isTrue);
    });
  });

  group('wired in', () {
    final install = File('lib/ui/install.dart').readAsStringSync();
    final sw = File('web/sw.js').readAsStringSync();
    final css = File('web/styles.css').readAsStringSync();

    test('the worker names its cache the way the check expects', () {
      expect(sw, contains('const CACHE = `dartle-\${BUILD}`;'));
      expect(cachePrefix, 'dartle-');
    });

    test('a worker makes its own cache when it installs, before it can take over', () {
      final install = sw.substring(sw.indexOf("addEventListener('install'"), sw.indexOf("addEventListener('activate'"));
      expect(install.indexOf('caches.open(CACHE)'), lessThan(install.indexOf('self.skipWaiting()')));
    });

    test('the page\'s build and the cache\'s build are stamped the same way', () {
      final build = File('tool/build.dart').readAsStringSync();
      expect(build, contains('main.dart.js?v=\$stamp'));
      expect(build, contains(".replaceAll('__BUILD__', '\$stamp')"));
    });

    test('taking over only reloads the page when it is really older', () {
      expect(install, contains("'controllerchange'"));
      expect(install, contains('_notifyIfNewer(updateReady);'));
      expect(install, contains('web.window.caches.keys()'));
      expect(install, contains('updateNeeded('));
      expect(install, contains('buildOfScriptSrc('));
      // The page is only told when a reload is needed.
      expect(install, contains('if (needed) updateReady();'));
      // No leftover debugging.
      expect(install, isNot(contains('TEMP')));
      expect(install, isNot(contains('console.log')));
    });

    test('the reload itself does not replay anything on the welcome screen', () {
      expect(css, contains('.screen.welcome.skip.enter { animation: none; }'));
    });
  });
}
