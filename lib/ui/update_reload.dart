import 'package:web/web.dart' as web;

/// Remembered (for this visit only) when the app reloads itself to show a newer
/// version, so the welcome screen after the reload goes straight to the name box
/// instead of playing its intro a second time.
const String skipIntroKey = 'dartle.skip-intro';

/// The menu page on screen when the app reloaded itself (this visit only):
/// the reload comes back to it.
const String resumePageKey = 'dartle.resume-page';

/// Reloads the page to show the newer version of the app, back on [page] (the
/// menu page on screen; the game modes, say) rather than the welcome screen.
void reloadForUpdate({String? page}) {
  try {
    web.window.sessionStorage.setItem(skipIntroKey, '1');
    if (page != null) web.window.sessionStorage.setItem(resumePageKey, page);
  } on Object {
    // Without it the intro just plays again.
  }
  web.window.location.reload();
}

/// Once after [reloadForUpdate]: the page to come back to, or null.
String? takeResumePage() {
  try {
    final storage = web.window.sessionStorage;
    final page = storage.getItem(resumePageKey);
    storage.removeItem(resumePageKey);
    return page;
  } on Object {
    return null;
  }
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
