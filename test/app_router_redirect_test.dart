import 'package:flutter_test/flutter_test.dart';
import 'package:farmbridge/core/router/app_router.dart';

void main() {
  group('resolveRedirect — role null (belum onboarding)', () {
    test('boleh tetap di role-picker/login', () {
      expect(resolveRedirect(null, '/role-picker'), isNull);
      expect(resolveRedirect(null, '/login'), isNull);
    });

    test('route lain dipaksa balik ke role-picker', () {
      expect(resolveRedirect(null, '/buyer'), '/role-picker');
      expect(resolveRedirect(null, '/farmer-profile/abc'), '/role-picker');
    });
  });

  group('resolveRedirect — role ada, masih di onboarding route', () {
    test('didorong ke home sesuai role', () {
      expect(resolveRedirect('farmer', '/role-picker'), '/farmer');
      expect(resolveRedirect('buyer', '/login'), '/buyer');
    });
  });

  group('resolveRedirect — cross-role guard untuk /buyer & /farmer', () {
    test('buyer diblokir dari /farmer, farmer diblokir dari /buyer', () {
      expect(resolveRedirect('buyer', '/farmer'), '/buyer');
      expect(resolveRedirect('farmer', '/buyer'), '/farmer');
    });

    test('nested route Fachri ikut ke-guard (exact-or-slash, bukan raw prefix)', () {
      expect(resolveRedirect('farmer', '/buyer/search'), '/farmer');
      expect(resolveRedirect('buyer', '/farmer/listings'), '/buyer');
      expect(resolveRedirect('buyer', '/farmer/listings/create'), '/buyer');
      // role yang benar tidak boleh ke-redirect
      expect(resolveRedirect('buyer', '/buyer/search'), isNull);
      expect(resolveRedirect('farmer', '/farmer/listings'), isNull);
    });
  });

  group('resolveRedirect — regresi bug prefix mentah (FG-16)', () {
    test('/farmer-profile/:id TIDAK dianggap route farmer-only', () {
      // sebelum fix: startsWith('/farmer') mentah bikin buyer ke-bounce
      // balik ke /buyer saat coba lihat profil farmer.
      expect(resolveRedirect('buyer', '/farmer-profile/abc123'), isNull);
      expect(resolveRedirect('farmer', '/farmer-profile/abc123'), isNull);
    });

    test('/buyer-profile/:id TIDAK dianggap route buyer-only', () {
      expect(resolveRedirect('farmer', '/buyer-profile/xyz789'), isNull);
      expect(resolveRedirect('buyer', '/buyer-profile/xyz789'), isNull);
    });
  });

  group('resolveRedirect — route Fachri tanpa role-gate (negosiasi/percakapan)', () {
    test('bisa diakses kedua role, tidak ke-redirect', () {
      expect(resolveRedirect('buyer', '/negosiasi/neg-1'), isNull);
      expect(resolveRedirect('farmer', '/negosiasi/neg-1'), isNull);
      expect(resolveRedirect('buyer', '/percakapan'), isNull);
      expect(resolveRedirect('farmer', '/percakapan'), isNull);
    });
  });
}
