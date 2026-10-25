import 'package:web/web.dart' as web;

import '../dartle.dart';
import 'dom.dart';
import 'install.dart';
import 'modal.dart';

/// The row of links at the very end of every screen: install, Instagram, email.
web.HTMLElement buildFooter() {
  return el('footer', cls: 'app-footer', children: [
    // Nothing to install once the app is on the home screen (or is the .apk).
    if (!isInstalledApp)
      button(tr('Install'), cls: 'footer-link', onPressed: (_) => _install()),
    _link('Instagram', Contact.instagramUrl,
        label: tr('Instagram, opens in a new tab'), newTab: true),
    _link(tr('Email'), Contact.emailUrl, label: tr('Email {address}', {'address': Contact.email})),
  ]);
}

web.HTMLElement _link(String text, String href, {required String label, bool newTab = false}) {
  return el('a', cls: 'footer-link', text: text, attrs: {
    'href': href,
    'aria-label': label,
    if (newTab) ...{'target': '_blank', 'rel': 'noopener noreferrer'},
  });
}

/// The browser's own install dialog when it offers one; otherwise a popup that
/// says how to install on this kind of phone.
void _install() {
  switch (installHelp) {
    case InstallHelp.prompt:
      promptInstall();
    case InstallHelp.ios:
      showModal(title: tr('Install Dartle'), body: [
        modalLine(tr('Tap the Share button in Safari, then Add to Home Screen.')),
      ]);
    case InstallHelp.none:
      showModal(title: tr('Install Dartle'), body: [
        modalLine(tr('Android: open the browser menu, then tap Install app '
            '(or Add to Home screen).')),
        modalLine(tr('iPhone and iPad: tap the Share button in Safari, then '
            'Add to Home Screen.')),
        el('p', cls: 'modal-line', children: [
          el('a', text: tr('Download the Android app (.apk)'), attrs: {
            'href': Contact.androidAppUrl,
            'target': '_blank',
            'rel': 'noopener noreferrer',
          }),
        ]),
      ]);
  }
}
