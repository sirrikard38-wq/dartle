import 'dart:io';

import 'package:test/test.dart';

/// The note under the leaderboard. Pinned from the source (the screen is drawn in
/// the browser).
void main() {
  final screen = File('lib/ui/leaderboard_screen.dart').readAsStringSync();

  test('the online note is exactly: Online Dartle leaderboard. Your name and scores are visible to all players.', () {
    expect(screen,
        contains("? 'Online Dartle leaderboard. Your name and scores are visible to all players.'"));
  });

  test('the old long wording is gone, and the online note has no sample sentence', () {
    expect(screen, isNot(contains('everyone who plays Dartle')));
    expect(screen, isNot(contains('Online leaderboard:')));
    final online = screen.substring(screen.indexOf('note.textContent = online'));
    final onlineBranch = online.substring(0, online.indexOf(': '));
    expect(onlineBranch, isNot(contains('sampleNote')));
  });
}
