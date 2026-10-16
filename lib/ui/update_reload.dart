import 'package:web/web.dart' as web;

/// Remembered (for this visit only) when the app reloads itself to show a newer
/// version, so the welcome screen after the reload goes straight to the name box
/// instead of playing its intro a second time.
const String skipIntroKey = 'dartle.skip-intro';

/// Reloads the page to show the newer version of the app.
void reloadForUpdate() {
  try {
    web.window.sessionStorage.setItem(skipIntroKey, '1');
  } on Object {
    // Without it the intro just plays again.
  }
  web.window.location.reload();
}

/// True once after [reloadForUpdate]: the welcome screen skips its intro.
bool takeSkipIntro() {
  try {
    final storage = web.window.sessionStorage;
    final skip = storage.getItem(skipIntroKey) == '1';
    if (skip) storage.removeItem(skipIntroKey);
    return skip;
  } on Object {
    return false;
  }
}
