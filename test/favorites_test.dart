import 'package:dartle/dartle.dart';
import 'package:test/test.dart';

void main() {
  CheckoutRoute r(String text) => CheckoutRoute.parse(text);

  group('Favorites', () {
    late InMemoryStorageService storage;
    late Favorites favorites;

    setUp(() async {
      storage = InMemoryStorageService();
      favorites = Favorites(storage);
      await favorites.load();
    });

    test('a route is marked, and pressed again it is not any more', () async {
      expect(favorites.isFavorite(64, r('T16 D8')), isFalse);
      expect(await favorites.toggle(64, r('T16 D8')), isTrue);
      expect(favorites.isFavorite(64, r('T16 D8')), isTrue);
      expect(favorites.hasAny(64), isTrue);
      expect(await favorites.toggle(64, r('T16 D8')), isFalse);
      expect(favorites.isFavorite(64, r('T16 D8')), isFalse);
      expect(favorites.hasAny(64), isFalse);
    });

    test('the order of the setup darts does not matter', () async {
      await favorites.toggle(64, r('S8 S16 D20'));
      expect(favorites.isFavorite(64, r('S16 S8 D20')), isTrue);
    });

    test('per number, and split by the number of darts', () async {
      await favorites.toggle(64, r('T16 D8'));
      await favorites.toggle(64, r('S8 S16 D20'));
      await favorites.toggle(64, r('T8 D20'));
      expect(favorites.isFavorite(63, r('T16 D8')), isFalse);
      expect(favorites.dartCountsFor(64), [2, 3]);
      expect(favorites.routesFor(64, darts: 2).map((x) => x.notation), ['T16 D8', 'T8 D20']);
      expect(favorites.routesFor(64, darts: 3), hasLength(1));
      expect(favorites.routesFor(64), hasLength(3));
    });

    test('saved on this device: a new start reads them back', () async {
      await favorites.toggle(40, r('D20'));
      await favorites.toggle(170, r('T20 T20 Bull'));
      final again = Favorites(storage);
      await again.load();
      expect(again.isFavorite(40, r('D20')), isTrue);
      expect(again.isFavorite(170, r('T20 T20 Bull')), isTrue);
    });

    test('a broken save is ignored', () async {
      await storage.write(Favorites.storageKey, 'not json');
      final again = Favorites(storage);
      await again.load();
      expect(again.hasAny(40), isFalse);
      await storage.write(Favorites.storageKey, '{"40": ["D20", "X99"], "x": ["D1"]}');
      await again.load();
      expect(again.routesFor(40).map((x) => x.notation), ['D20']);
    });
  });

  test('the game loads them and keeps them across starts', () async {
    final storage = InMemoryStorageService();
    final game = createGameController(storage);
    await game.init();
    expect(await game.toggleFavorite(43, r('T11 D5')), isTrue);
    final again = createGameController(storage);
    await again.init();
    expect(again.favorites.isFavorite(43, r('T11 D5')), isTrue);
  });
}
