import 'package:dartle/dartle.dart';
import 'package:dartle/ui/app.dart';
import 'package:dartle/ui/install.dart';
import 'package:dartle/ui/local_storage_service.dart';
import 'package:dartle/ui/online_setup.dart';
import 'package:dartle/ui/scrollbars.dart';
import 'package:dartle/ui/update_reload.dart';
import 'package:web/web.dart' as web;

Future<void> main() async {
  final storage = LocalStorageService();
  // The shared online leaderboard, if web/online.json is filled in.
  final leaderboard = await buildLeaderboard(storage);
  final game = createGameController(storage, leaderboard: leaderboard);
  final root = web.document.querySelector('#app')!;
  autoHideScrollbars(); // scrollbars show only while scrolling, then fade out
  final app = DartleApp(root, game);
  await game.init(); // loads saved history and the player name
  app.start(); // asks new players for a username, then starts a checkout

  // A newer version of the app arrives by itself; show it as soon as nothing is
  // being played (any menu page), never in the middle of a checkout.
  var updateWaiting = false;
  void reloadIfIdle() {
    if (updateWaiting && game.phase == GamePhase.menu) reloadForUpdate();
  }

  game.addListener(reloadIfIdle);
  registerServiceWorker(updateReady: () {
    updateWaiting = true;
    reloadIfIdle();
  }); // lets the installed app work offline
}
