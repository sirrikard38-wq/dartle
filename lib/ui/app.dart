import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../dartle.dart';
import 'dart_shot.dart';
import 'dom.dart';
import 'favorites_ui.dart';
import 'felga_screen.dart';
import 'footer.dart';
import 'game_screen.dart';
import 'install.dart';
import 'leaderboard_screen.dart';
import 'menu_screen.dart';
import 'modal.dart';
import 'modes_screen.dart';
import 'result_screen.dart';
import 'sound.dart';
import 'swipes.dart';
import 'to_top.dart';
import 'tutorial_screen.dart';
import 'update_reload.dart';
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
    _toTop = ToTopDart();
    web.EventStreamProviders.keyDownEvent.forTarget(web.document).listen(_onKey);
    _listenForBack();
    // Only the clock text is updated per tick, never the whole tree. The value
    // comes from the monotonic AttemptTimer, so re-renders can't skew it.
    Timer.periodic(const Duration(milliseconds: 50), (_) => _tickClock());
  }

  final web.Element _root;
  final GameController _game;
  late final ViewContext _ctx;
  /// The message at the top of the screen showing (a new one takes its
  /// place); the ones on a board or near the foot each have their own.
  web.HTMLElement? _topToast;
  late final ToTopDart _toTop;
  final SoundService _sound = SoundService();
  GamePhase _lastPhase = GamePhase.menu;
  MenuPage _page = MenuPage.welcome;
  bool _started = false;
  String? _focusKey;

  // Typed-number buffer: "2" then "0" within the window means 20.
  String _digits = '';
  Timer? _digitTimer;

  /// Entry point once saved data is loaded. The welcome screen is shown every
  /// time the app opens; its name box continues to the menu.
  void start() {
    _started = true;
    _page = MenuPage.welcome;
    // Reloaded for a newer version: back where it was (the game modes, say),
    // not on the welcome screen and then the menu.
    final resume = MenuPage.values.asNameMap()[takeResumePage()];
    if (resume != null && resume != MenuPage.welcome && !_game.needsPlayerName) {
      takeSkipIntro();
      _page = resume;
    }
    // The steps of history kept for the way back survive a reload.
    final state = web.window.history.state.dartify();
    if (state is Map && state['d'] is num) _historyDepth = (state['d'] as num).toInt();
    render();
  }

  /// The menu page on screen, for a reload to come back to.
  String get pageName => _page.name;

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
    // Screen readers read the page in the language that is on.
    web.document.documentElement?.setAttribute('lang', I18n.current.code.toLowerCase());
    // Checkout choice is one screen while a number is played and with its
    // answer (in its part Choose).
    final screenKey =
        _game.phase != GamePhase.menu && _game.mode.isPractice ? 'choice' : '${_game.phase.name}-${_page.name}';
    // The welcome screen is full-screen: no header, no footer.
    final fullScreen = _game.phase == GamePhase.menu && _page == MenuPage.welcome;
    // The welcome screen plays its intro once. Drawing it again while it is on
    // screen (the browser offering to install the app a few seconds after it
    // opened, say) would build it from scratch and play the intro a second time:
    // DARTLE, Welcome, DARTLE again. So it is never redrawn while it shows.
    if (fullScreen && screenKey == _lastScreen && _root.querySelector('.screen.welcome') != null) {
      return;
    }
    final screen = switch (_game.phase) {
      GamePhase.playing => buildGameScreen(_ctx),
      GamePhase.result => buildResultScreen(_ctx),
      GamePhase.menu => switch (_page) {
          MenuPage.welcome => buildWelcomeScreen(_ctx),
          MenuPage.home => buildMenuScreen(_ctx),
          MenuPage.modes => buildModesScreen(_ctx),
          MenuPage.favorites => buildFavoritesScreen(_ctx),
          MenuPage.leaderboard => buildLeaderboardScreen(_ctx),
          MenuPage.tutorial => buildTutorialScreen(_ctx),
          MenuPage.felga => buildFelgaScreen(_ctx),
        },
    };
    // Fade a screen in only when it changes, not on every dart tapped. A popup
    // belongs to the screen it was opened on.
    final screenChanged = screenKey != _lastScreen;
    if (screenChanged) {
      screen.classList.add('enter');
      closeModal();
    }
    _lastScreen = screenKey;

    _root.textContent = '';
    if (!fullScreen) _root.appendChild(_buildHeader());
    _root.appendChild(screen);
    // Checkout calculator and Checkout choice have the links in their parts,
    // at the foot of each (under the answer in Practice and Choose).
    final footerInPage = (_game.phase == GamePhase.menu && _page == MenuPage.tutorial) ||
        (_game.phase != GamePhase.menu && _game.mode.isPractice);
    if (!fullScreen && !footerInPage) _root.appendChild(buildFooter());
    _syncHistory();

    final key = _focusKey;
    _focusKey = null;
    if (key != null) {
      final target = _root.querySelector('[data-focus="$key"]');
      if (target != null && !target.hasAttribute('disabled')) {
        (target as web.HTMLElement).focus();
      }
    }
    // A new screen (Next checkout, Replay checkout, a menu page ...) always
    // starts at the top, not wherever the last, longer screen was scrolled to.
    // After the focus above, which can scroll a button into view.
    if (screenChanged) web.window.scrollTo(0.toJS, 0);
    // At the end of the Leaderboard and Favorites a little dart
    // shoots you back to the top.
    _toTop.element.setAttribute('aria-label', tr('Back to the top'));
    _toTop.enabled = !fullScreen &&
        _game.phase == GamePhase.menu &&
        (_page == MenuPage.leaderboard || _page == MenuPage.favorites);
  }

  web.HTMLElement _buildHeader() {
    final inMenu = _game.phase == GamePhase.menu;
    // Back: stats/leaderboard -> menu; checkout/result -> menu; menu: none.
    final left = inMenu && _page == MenuPage.home
        ? el('span', cls: 'header-spacer')
        : _buildBackDart();

    final soundButton = button(_sound.isMuted ? '🔇' : '🔊',
        cls: 'icon-btn',
        ariaLabel: _sound.isMuted ? tr('Turn sound on') : tr('Turn sound off'),
        onPressed: (_) {
          _sound.toggleMuted();
          render();
        });

    // The language box: the two letters of the language that is on; pressing it
    // goes to the next language (there are two for now, EN and HR).
    final language = I18n.current;
    final languageButton = button('',
        cls: 'lang-btn',
        focusKey: 'language',
        ariaLabel: tr('Language: {name}. Press to change it.', {'name': language.name}),
        onPressed: (_) {
          _focusKey = 'language';
          _game.setLanguage(language.next);
        })
      ..appendChild(el('span', cls: 'lang-code', text: language.code));

    // No sound (and no sound button) in the practice modes. The sound icon and the
    // language box sit right next to the word DARTLE, on its right; the score
    // (calculator only) is at the far right.
    final showSound = inMenu || _game.mode.hasSound;
    final showScore = !inMenu && _game.mode.hasScore;
    final right = el('div',
        cls: 'header-right${showSound ? '' : ' no-sound'}${showScore ? ' has-score' : ''}',
        children: [
      el('div', cls: 'header-tools', children: [
        if (showSound) soundButton,
        languageButton,
      ]),
      // Only Checkout calculator has a score: the current score, with a small
      // grey label under it.
      if (showScore)
        el('div', cls: 'score-box', children: [
          el('span', cls: 'score-pill', text: formatScore(_game.sessionPoints)),
          el('span', cls: 'score-label', text: tr('Current score')),
        ]),
    ]);

    // Just the title: the game being played is not written under it.
    return el('header', cls: 'app-header', children: [
      left,
      el('div', cls: 'title', text: 'DARTLE'),
      right,
    ]);
  }

  /// The Back button: the welcome screen's dart turned round to point left, with
  /// no background. Pressed, it does not shoot: it slides half a centimetre left
  /// and fades out smoothly (no circle, no wiggle), then goes one step back: from
  /// a game to the game modes, from anywhere else to the menu
  /// ([ViewContext.backTarget]).
  web.HTMLElement _buildBackDart() {
    late final web.HTMLElement stage;
    var leaving = false;
    Future<void> back() async {
      if (leaving) return; // the dart is already on its way out
      leaving = true;
      await playDartFade(stage);
      _showPage(ViewContext.backTarget(_game.phase, _page));
    }

    stage = buildDartStage(
      label: tr('Back'),
      stageClass: 'back-stage',
      buttonClass: 'back-dart',
      circle: false,
      onPressed: back,
    );
    _back = back;
    return stage;
  }

  /// What the Back dart on screen does, with its animation; null on the menu,
  /// which has no way back.
  Future<void> Function()? _back;

  /// The steps of the browser's history the app keeps for the ways back: one
  /// for each level under the menu ([_depth]).
  int _historyDepth = 0;

  /// Steps back the app took itself (its Back dart, a button to the menu):
  /// their popstate is not the phone's way back.
  int _ownPops = 0;

  /// How deep the screen is: the menu 0; the game modes, Favorites and
  /// Leaderboard 1; a game or the tutorial (under the game modes) 2.
  int get _depth {
    if (_game.phase != GamePhase.menu) return 2;
    return switch (_page) {
      MenuPage.welcome || MenuPage.home => 0,
      MenuPage.tutorial => 2,
      _ => 1,
    };
  }

  /// The phone's own ways back go one step back: the back button or the swipe
  /// from the edge (a step of the browser's history is kept for each level),
  /// and on an iPhone the app on the home screen, which has no swipe of its
  /// own, a swipe from the left edge. The phone's back has already shown its
  /// own slide (with the picture of the screen it goes back to), so the app
  /// goes there at once, with no Back dart animation after it.
  void _listenForBack() {
    web.EventStreamProviders.popStateEvent.forTarget(web.window).listen((_) {
      if (_ownPops > 0) {
        _ownPops--;
        return;
      }
      if (_historyDepth == 0) return; // a step from before: nothing to leave
      _historyDepth--;
      _showPage(ViewContext.backTarget(_game.phase, _page));
    });
    if (!isInstalledApp || !isIos) return;
    double? startX;
    var startY = 0.0;
    web.EventStreamProviders.touchStartEvent.forTarget(web.document).listen((event) {
      final touch = event.changedTouches.item(0)!;
      startX = event.touches.length == 1 && touch.clientX < backGestureEdge ? touch.clientX.toDouble() : null;
      startY = touch.clientY.toDouble();
    });
    web.EventStreamProviders.touchEndEvent.forTarget(web.document).listen((event) {
      final from = startX;
      startX = null;
      if (from == null) return;
      final touch = event.changedTouches.item(0)!;
      final across = touch.clientX - from;
      if (across > 70 && (touch.clientY - startY).abs() < across) _back?.call();
    });
  }

  /// Keeps one step of the browser's history for each level under the menu.
  /// A step is added as a screen goes a level deeper, before the new screen is
  /// drawn: the browser keeps a picture of the screen being left with it, and
  /// shows that picture as the phone's back slides to it - the screen the way
  /// back goes to (from a game: the game modes, not the menu). Going back up
  /// another way (the Back dart, a button) takes the steps off again.
  void _syncHistory() {
    final depth = _depth;
    if (depth == 0) _back = null;
    while (_historyDepth < depth) {
      _historyDepth++;
      web.window.history.pushState({'d': _historyDepth}.jsify(), '');
    }
    if (_historyDepth > depth) {
      final steps = _historyDepth - depth;
      _historyDepth = depth;
      _ownPops++;
      web.window.history.go(-steps);
    }
  }

  /// A message: each is its own, so several boards made favorites one after
  /// the other each keep theirs for its whole time (one does not cut the one
  /// before short). Only a message at the top takes the place of the one
  /// there.
  void _showToast(String message, {bool low = false, ({double x, double y, double width})? at}) {
    final toast = el('div',
        cls: 'toast${low ? ' low' : ''}${at != null ? ' at-point' : ''}',
        text: message,
        attrs: {'role': 'status', 'aria-live': 'polite'});
    // On a point (the middle of a board): placed there, else where its class
    // puts it. On a board it is no wider than the board, its letters smaller
    // to fit (a small board in Learn or Miss).
    if (at != null) {
      toast.style
        ..left = '${at.x}px'
        ..top = '${at.y}px'
        ..maxWidth = '${at.width}px'
        ..fontSize = 'min(0.9rem, ${(at.width / 12).toStringAsFixed(1)}px)'
        ..padding = '0.6em 0.8em';
    }
    if (!low && at == null) {
      _topToast?.remove();
      _topToast = toast;
    }
    web.document.body!.appendChild(toast);
    // Next frame, so that it fades in.
    Timer(const Duration(milliseconds: 16), () => toast.classList.add('show'));
    // Added to / removed from favorites: half as long as other messages; then
    // it fades out (450 ms) and goes.
    Timer(Duration(milliseconds: low ? 900 : 1800), () {
      toast.classList.remove('show');
      Timer(const Duration(milliseconds: 500), () {
        toast.remove();
        if (_topToast == toast) _topToast = null;
      });
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
          if (_game.isSessionOver) {
            _game.replaySession();
          } else {
            _game.nextCheckout();
          }
        }
      case GamePhase.menu:
        break;
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
      _showToast(tr('The last dart must be a double'));
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
