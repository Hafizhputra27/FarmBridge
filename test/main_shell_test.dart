import 'package:flutter_test/flutter_test.dart';
import 'package:farmbridge/core/widgets/main_shell.dart';

void main() {
  group('buyerTabIndexFor', () {
    test('Home', () => expect(buyerTabIndexFor('/buyer'), 0));
    test('Search', () => expect(buyerTabIndexFor('/buyer/search'), 1));
    test('Percakapan', () => expect(buyerTabIndexFor('/percakapan'), 2));
    test('Profil', () => expect(buyerTabIndexFor('/buyer-profile/abc'), 3));
    test('route lain default ke Home',
        () => expect(buyerTabIndexFor('/negosiasi/xyz'), 0));
  });

  group('farmerTabIndexFor', () {
    test('Listing Saya (Home)',
        () => expect(farmerTabIndexFor('/farmer/listings'), 0));
    test('nested route listings tetap Home', () =>
        expect(farmerTabIndexFor('/farmer/listings/abc/edit'), 0));
    test('Percakapan', () => expect(farmerTabIndexFor('/percakapan'), 1));
    test('Profil', () => expect(farmerTabIndexFor('/farmer-profile/abc'), 2));
  });
}
