import 'dart:async';

import 'package:web/web.dart' as web;

import '../dartle.dart';
import 'dom.dart';
import 'footer.dart';
import 'game_screen.dart';
import 'impossible_screen.dart';
import 'install.dart';
import 'leaderboard_screen.dart';
import 'menu_screen.dart';
import 'modal.dart';
import 'modes_screen.dart';
import 'number_entry_screen.dart';
import 'result_screen.dart';
import 'sound.dart';
import 'stats_screen.dart';
import 'view_context.dart';
import 'welcome_screen.dart';

/// Mounts the app and re-renders on every [GameController] change.
class DartleApp {
  DartleApp(this._root, this._game) {
    _ctx = ViewContext(
      game: _game,
      rerender: render,
      showPage: _showPage,
      keepFocus: (key) => _focusKey = key,
      toast: _showToast,
    );
    _game.addListener(() {
      final phase = _game.phase;
      if (phase != _lastPhase) {
        // A new checkout starts with the smart default mode: Triple when the
        // best route has a triple in it.
        if (phase == GamePhase.playing) {
          _ctx.pickedMultiplier = ViewContext.startingMultiplier(_game.challenge);
        }
        if (phase == GamePhase.entering) _ctx.numberBuffer = '';
        // Celebrate the moment an optimal checkout is revealed (not in a replay).
        final result = _game.lastResult;
        if (phase == GamePhase.result &&
            _game.mode.hasSound &&
            result?.isOptimal == true &&
            result?.isReplay == false) {
          _sound.playOptimal();
        }
        if (phase != GamePhase.result) _sound.stop();
        _lastPhase = phase;
      }
      render();
    });
    // The menu offers to install the app once the browser says it can.
    watchForInstall(render);
    _toast = el('div', cls: 'toast', attrs: {'role': 'status', 'aria-live': 'polite'});
    web.document.body!.appendChild(_toast);
    web.EventStreamProviders.keyDownEvent.forTarget(web.document).listen(_onKey);
    // Only the clock text is updated per tick, never the whole tree. The value
    // comes from the monotonic AttemptTimer, so re-renders can't skew it.
    Timer.periodic(const Duration(milliseconds: 50), (_) => _tickClock());
  }

  final web.Element _root;
  final GameController _game;
  late final ViewContext _ctx;
  late final web.HTMLElement _toast;
  final SoundService _sound = SoundService();
  GamePhase _lastPhase = GamePhase.menu;
  MenuPage _page = MenuPage.welcome;
  bool _started = false;
  String? _focusKey;
  Timer? _toastTimer;

  // Typed-number buffer: "2" then "0" within the window means 20.
  String _digits = '';
  Timer? _digitTimer;

  /// Entry point once saved data is loaded. The welcome screen is shown every
  /// time the app opens; its name box continues to the menu.
  void start() {
    _started = true;
    _page = MenuPage.welcome;
    render();
  }

  /// Opens a menu page. Leaving a checkout stops its timer and the unfinished
  /// attempt is not recorded.
  void _showPage(MenuPage page) {
    _page = page;
    if (_game.phase == GamePhase.menu) {
      render();
    } else {
      _game.quitToMenu(); // notifies, which re-renders
    }
  }

  String? _lastScreen;

  void render() {
    if (!_started) return; // nothing to draw until saved data has loaded
    final screen = switch (_game.phase) {
      GamePhase.playing => buildGameScreen(_ctx),
      GamePhase.result => buildResultScreen(_ctx),
      GamePhase.entering => buildNumberEntryScreen(_ctx),
      GamePhase.impossible => buildImpossibleScreen(_ctx),
      GamePhase.menu => switch (_page) {
          MenuPage.welcome => buildWelcomeScreen(_ctx),
          MenuPage.home => buildMenuScreen(_ctx),
          MenuPage.modes => buildModesScreen(_ctx),
          MenuPage.stats => buildStatsScreen(_ctx),
          MenuPage.leaderboard => buildLeaderboardScreen(_ctx),
        },
    };
    // Fade a screen in only when it changes, not on every dart tapped. A popup
    // belongs to the screen it was opened on.
    final screenKey = '${_game.phase.name}-${_page.name}';
    if (screenKey != _lastScreen) {
      screen.classList.add('enter');
      closeModal();
    }
    _lastScreen = screenKey;

    _root.textContent = '';
    // The welcome screen is full-screen: no header, no footer.
    final fullScreen = _game.phase == GamePhase.menu && _page == MenuPage.welcome;
    if (!fullScreen) _root.appendChild(_buildHeader());
    _root.appendChild(screen);
    if (!fullScreen) _root.appendChild(buildFooter());

    final key = _focusKey;
    _focusKey = null;
    if (key != null) {
      final target = _root.querySelector('[data-focus="$key"]');
      if (target != null && !target.hasAttribute('disabled')) {
        (target as web.HTMLElement).focus();
      }
    }
  }

  web.HTMLElement _buildHeader() {
    final inMenu = _game.phase == GamePhase.menu;
    // Back: stats/leaderboard -> menu; checkout/result -> menu; menu: none.
    final left = inMenu && _page == MenuPage.home
        ? el('span', cls: 'header-spacer')
        : button('←',
            cls: 'icon-btn',
            ariaLabel: 'Back to the menu',
            onPressed: (_) => _showPage(MenuPage.home));

    final soundButton = button(_sound.isMuted ? '🔇' : '🔊',
        cls: 'icon-btn',
        ariaLabel: _sound.isMuted ? 'Turn sound on' : 'Turn sound off',
        onPressed: (_) {
          _sound.toggleMuted();
          render();
        });

    // No sound (and no sound button) in the practice modes.
    final showSound = inMenu || _game.mode.hasSound;
    final right = el('div', cls: 'header-actions', children: [
      if (showSound) soundButton,
      // Only Checkout calculator has a score: the current score, with a small
      // grey label under it.
      if (!inMenu && _game.mode.hasScore)
        el('div', cls: 'score-box', children: [
          el('span', cls: 'score-pill', text: formatScore(_game.sessionPoints)),
          el('span', cls: 'score-label', text: 'Current score'),
        ]),
    ]);

    return el('header', cls: 'app-header', children: [
      left,
      el('div', cls: 'title', text: 'DARTLE'),
      right,
    ]);
  }

  void _showToast(String message) {
    _toast.textContent = message;
    _toast.classList.add('show');
    _toastTimer?.cancel();
    _toastTimer = Timer(const Duration(milliseconds: 1800), () {
      _toast.classList.remove('show');
    });
  }

  void _tickClock() {
    if (_game.phase != GamePhase.playing) return;
    final clock = web.document.getElementById('timer');
    if (clock == null) return;
    final remaining = _game.remaining;
    clock.textContent = formatCountdown(remaining);
    // Past zero the clock turns red; the minus sign carries it without colour.
    clock.classList.toggle('over', remaining.isNegative);
  }

  void _onKey(web.KeyboardEvent event) {
    if (event.ctrlKey || event.metaKey || event.altKey) return;
    if (event.key == 'Escape' && isModalOpen) {
      closeModal();
      return;
    }
    if (isModalOpen) return; // a popup is open: the keys belong to it
    final active = web.document.activeElement;
    final tag = active?.tagName.toLowerCase();
    if (tag == 'input' || tag == 'textarea' || tag == 'select') return;
    // Dartboard wedges are SVG elements acting as buttons.
    final onButton = tag == 'button' || active?.getAttribute('role') == 'button';

    switch (_game.phase) {
      case GamePhase.playing:
        _onPlayingKey(event, onButton);
      case GamePhase.result:
        if (event.key == 'Enter' && !onButton) {
          event.preventDefault();
          _game.nextCheckout();
        }
      case GamePhase.entering:
        _onEntryKey(event, onButton);
      case GamePhase.impossible:
        if (event.key == 'Enter' && !onButton) {
          final next = _root.querySelector('[data-focus="next"]');
          if (next != null && !next.hasAttribute('disabled')) {
            event.preventDefault();
            _game.nextCheckout();
          }
        }
      case GamePhase.menu:
        break;
    }
  }

  /// Checkout input: type the number on the keyboard too.
  void _onEntryKey(web.KeyboardEvent event, bool onButton) {
    final key = event.key;
    if (key == 'Backspace') {
      event.preventDefault();
      deleteNumberDigit(_ctx);
    } else if (key == 'Enter' && !onButton) {
      event.preventDefault();
      submitNumber(_ctx);
    } else if (key.length == 1 && '0123456789'.contains(key)) {
      typeNumberDigit(_ctx, key);
    }
  }

  void _onPlayingKey(web.KeyboardEvent event, bool onButton) {
    final key = event.key;
    switch (key) {
      case 'Backspace':
        event.preventDefault();
        _game.undo();
      case 'Escape':
        _game.clear();
      case 's' || 'S':
        _pick(Multiplier.single);
      case 'd' || 'D':
        _pick(Multiplier.double);
      case 't' || 'T':
        _pick(Multiplier.treble);
      case 'b' || 'B':
        enterDart(_ctx, DartThrow.bull);
      default:
        if (key.length == 1 && '0123456789'.contains(key)) _typeDigit(key);
    }
  }

  void _pick(Multiplier m) {
    // The practice modes have no ring buttons, so S / D / T do nothing there.
    if (_game.mode.isPractice) return;
    if (_ctx.isFinalBox && m != Multiplier.double) {
      _showToast('The last dart must be a double');
      return;
    }
    _ctx.pickedMultiplier = m;
    render();
  }

  /// "2" waits briefly in case "0" follows; digits that can only be one
  /// number ("3".."9", or "2" then "0") are committed straight away.
  void _typeDigit(String digit) {
    _digitTimer?.cancel();
    final candidate = _digits + digit;
    final value = int.parse(candidate);
    if (value < 1 || value > DartThrow.maxBoardNumber) {
      _digits = '';
      if (digit != '0') _typeDigit(digit);
      return;
    }
    if (value * 10 > DartThrow.maxBoardNumber) {
      _commitNumber(value);
    } else {
      _digits = candidate;
      _digitTimer = Timer(const Duration(milliseconds: 600), () => _commitNumber(value));
    }
  }

  void _commitNumber(int value) {
    _digits = '';
    _digitTimer?.cancel();
    if (_game.phase != GamePhase.playing) return;
    enterDart(_ctx, DartThrow(_ctx.activeMultiplier(), value));
  }
}
