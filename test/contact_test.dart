import 'package:dartle/dartle.dart';
import 'package:test/test.dart';

void main() {
  group('Contact (footer row)', () {
    test('Instagram link is the one the maker gave', () {
      final uri = Uri.parse(Contact.instagramUrl);
      expect(uri.scheme, 'https');
      expect(uri.host, 'instagram.com');
      expect(uri.path, '/pikadonormal');
      expect(uri.queryParameters['obrf'], 'MTd2a3hya3VidHg4NA==');
      expect(uri.queryParameters['utm_source'], 'qr');
    });

    test('email link is a mailto: for the maker', () {
      expect(Contact.email, 'pikadonormal@gmail.com');
      expect(Contact.emailUrl, 'mailto:pikadonormal@gmail.com');
    });

    test('Android app link points at the android-latest release', () {
      final uri = Uri.parse(Contact.androidAppUrl);
      expect(uri.scheme, 'https');
      expect(uri.path, endsWith('/releases/download/android-latest/dartle.apk'));
    });
  });
}
