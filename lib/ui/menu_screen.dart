import 'package:web/web.dart' as web;

import 'dom.dart';
import 'install.dart';
import 'view_context.dart';

/// Main menu: Start, Leaderboard, Statistics.
web.HTMLElement buildMenuScreen(ViewContext ctx) {
  final game = ctx.game;
  final install = installHelp;

  return el('main', cls: 'screen menu', children: [
    el('div', cls: 'play-area', children: [
      el('p', cls: 'greeting', text: 'Hi, ${game.playerName}'),
      el('div', cls: 'menu-list', children: [
        button('Start',
            cls: 'menu-btn primary',
            focusKey: 'start',
            onPressed: (_) => ctx.showPage(MenuPage.modes)),
        button('Leaderboard',
            cls: 'menu-btn',
            focusKey: 'leaderboard',
            onPressed: (_) => ctx.showPage(MenuPage.leaderboard)),
        button('Statistics',
            cls: 'menu-btn',
            focusKey: 'stats',
            onPressed: (_) => ctx.showPage(MenuPage.stats)),
      ]),
      // Put the app on the phone's home screen (not shown once it is there).
      switch (install) {
        InstallHelp.prompt => button('Install app',
            cls: 'text-btn install',
            focusKey: 'install',
            onPressed: (_) => promptInstall()),
        InstallHelp.ios => el('p',
            cls: 'hint install-hint',
            text: 'Install on iPhone or iPad: tap Share, then Add to Home Screen.'),
        InstallHelp.none => el('span'),
      },
    ]),
  ]);
}
