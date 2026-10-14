import 'package:dartle/dartle.dart';
import 'package:dartle/ui/app.dart';
import 'package:dartle/ui/install.dart';
import 'package:dartle/ui/local_storage_service.dart';
import 'package:web/web.dart' as web;

Future<void> main() async {
  final game = createGameController(LocalStorageService());
  final root = web.document.querySelector('#app')!;
  final app = DartleApp(root, game);
  await game.init(); // loads saved history and the player name
  app.start(); // asks new players for a username, then starts a checkout
  registerServiceWorker(); // lets the installed app work offline
}
