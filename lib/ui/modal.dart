import 'package:web/web.dart' as web;

import 'dom.dart';

web.HTMLElement? _open;

/// True while a popup is on screen.
bool get isModalOpen => _open != null;

/// Closes the popup, if one is open.
void closeModal() {
  _open?.remove();
  _open = null;
}

/// A popup with a [title] and a [body]. It closes with the Close button, a
/// press on the dark area around it, or Escape. It lives on the page itself, so
/// the screen behind it can redraw without losing it.
void showModal({required String title, required List<web.Node> body}) {
  closeModal();
  final close = button('Close', cls: 'modal-close', onPressed: (_) => closeModal());
  final backdrop = el('div', cls: 'modal-backdrop', attrs: {
    'role': 'dialog',
    'aria-modal': 'true',
    'aria-label': title,
  }, children: [
    el('div', cls: 'modal', children: [
      el('h3', cls: 'modal-title', text: title),
      el('div', cls: 'modal-body', children: body),
      close,
    ]),
  ]);
  backdrop.onClick.listen((event) {
    if (event.target == backdrop) closeModal();
  });
  web.document.body!.appendChild(backdrop);
  _open = backdrop;
  // Focus Close for keyboard users, but without letting that scroll a long
  // popup down to it: a popup always opens at its top.
  close.focus(web.FocusOptions(preventScroll: true));
  backdrop.querySelector('.modal')?.scrollTop = 0;
}

/// A plain paragraph for a popup.
web.HTMLElement modalLine(String text) => el('p', cls: 'modal-line', text: text);
