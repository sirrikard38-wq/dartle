import 'dart:io';

import 'package:test/test.dart';

/// The note under the leaderboard, and its places. Pinned from the source and the
/// stylesheet (the screen is drawn in the browser).
void main() {
  final screen = File('lib/ui/leaderboard_screen.dart').readAsStringSync();
  final css = File('web/styles.css').readAsStringSync();

  group('the note under the leaderboard', () {
    test('the online note is exactly: Your name and scores are visible to all players.', () {
      expect(screen, contains("online ? tr('Your name and scores are visible to all players.')"));
    });

    test('nothing else is said about the board: no old wording, nothing about sample players', () {
      expect(screen, isNot(contains('Online Dartle leaderboard')));
      expect(screen, isNot(contains('everyone who plays Dartle')));
      expect(screen, isNot(contains('sample')));
    });
  });

  group('the places', () {
    test('there is no trace of sample players on the screen or in the stylesheet', () {
      expect(screen, isNot(contains('isSample')));
      expect(css, isNot(contains('.sample')));
      expect(css, isNot(contains('sample-tag')));
    });

    test('the places nobody has taken are drawn empty, up to the 180 of the board', () {
      expect(screen, contains('place < LeaderboardService.boardSize'));
      expect(screen, contains("cls: 'empty'"));
      // They are not read out: 170 blank list items would be noise.
      expect(screen, contains("attrs: {'aria-hidden': 'true'}"));
    });

    test('an empty place is as tall as a taken one (a non-breaking space in both cells)', () {
      expect(screen, contains('final blank = String.fromCharCode(0xA0);'));
      final empty = screen.substring(screen.indexOf("cls: 'empty'"));
      expect(RegExp(r'text: blank\)').allMatches(empty), hasLength(2));
    });

    test('the real players come first, then the empty places', () {
      expect(screen.indexOf("cls: isMe(e) ? 'me' : null"),
          lessThan(screen.indexOf("cls: 'empty'")));
    });
  });
}
