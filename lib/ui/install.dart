import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

/// Registers the service worker, which saves the app on the phone so it opens
/// and plays with no connection. Quietly does nothing where it is not allowed
/// (an address that is not https or localhost, or an old browser).
Future<void> registerServiceWorker() async {
  try {
    await web.window.navigator.serviceWorker.register('sw.js'.toJS).toDart;
  } on Object {
    // The app works without it; it just cannot be used offline.
  }
}

/// What the menu should offer to help install the app.
enum InstallHelp {
  /// Nothing: it is already installed, or this browser cannot install it.
  none,

  /// Android / desktop Chrome: a real "Install app" button.
  prompt,

  /// iPhone / iPad: there is no button; the player must use Share.
  ios,
}

JSObject? _installEvent;

/// Remembers the browser's "install" offer (Chrome fires `beforeinstallprompt`)
/// and calls [changed] when the offer appears or the app gets installed.
void watchForInstall(void Function() changed) {
  web.window.addEventListener(
    'beforeinstallprompt',
    ((web.Event event) {
      event.preventDefault(); // keep the offer for our own button
      _installEvent = event;
      changed();
    }).toJS,
  );
  web.window.addEventListener(
    'appinstalled',
    ((web.Event event) {
      _installEvent = null;
      changed();
    }).toJS,
  );
}

/// True when the app is running from the home screen, not in a browser tab.
bool get isInstalledApp {
  try {
    if (web.window.matchMedia('(display-mode: standalone)').matches) return true;
    final standalone = (web.window.navigator as JSObject).getProperty('standalone'.toJS);
    return standalone.dartify() == true; // iOS Safari's own flag
  } on Object {
    return false;
  }
}

bool get _isIos {
  final nav = web.window.navigator;
  final ua = nav.userAgent;
  if (RegExp(r'iPhone|iPad|iPod').hasMatch(ua)) return true;
  // iPadOS pretends to be a Mac; a Mac with a touch screen is an iPad.
  return ua.contains('Macintosh') && nav.maxTouchPoints > 1;
}

/// Which install help to show right now.
InstallHelp get installHelp {
  if (isInstalledApp) return InstallHelp.none;
  if (_installEvent != null) return InstallHelp.prompt;
  if (_isIos) return InstallHelp.ios;
  return InstallHelp.none;
}

/// Shows the browser's own install dialog.
void promptInstall() {
  final event = _installEvent;
  if (event == null) return;
  event.callMethod('prompt'.toJS);
}
