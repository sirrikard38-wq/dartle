import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

/// Registers the service worker, which saves the app on the phone so it opens
/// and plays with no connection. Quietly does nothing where it is not allowed
/// (an address that is not https or localhost, or an old browser).
///
/// [updateReady] is called when a newer version of the app has taken over from
/// the one this page is showing (never on the very first install, when there is
/// nothing older to replace). The page then still shows the old version until it
/// is reloaded, so the caller reloads it at a good moment.
Future<void> registerServiceWorker({void Function()? updateReady}) async {
  if (isNativeShell) return; // the Android app already holds every file
  try {
    final container = web.window.navigator.serviceWorker;
    final hadOlderVersion = container.controller != null;
    if (hadOlderVersion && updateReady != null) {
      container.addEventListener(
        'controllerchange',
        ((web.Event event) => updateReady()).toJS,
      );
    }
    await container.register('sw.js'.toJS).toDart;
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

/// True inside the Android app (a Capacitor shell around this page), where
/// there is nothing to install and no browser around the page.
bool get isNativeShell {
  try {
    return (web.window as JSObject).has('Capacitor');
  } on Object {
    return false;
  }
}

/// True when the app is running from the home screen or as a store/.apk app,
/// not in a browser tab.
bool get isInstalledApp {
  try {
    if (isNativeShell) return true;
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
