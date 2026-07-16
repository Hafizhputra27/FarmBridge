# Login Email/Password (Ganti Anonymous Auth) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

> **Catatan eksekusi:** Sesuai `docs/CLAUDE.md`, Claude tidak menjalankan operasi git yang mengubah state repo (`add`/`commit`/`push`/`merge`/dst). Commit/push tetap dijalankan Hafizh sendiri di terminal. Task 6 (set kredensial 2 akun dummy di Supabase Dashboard) juga manual — di luar kemampuan eksekusi Claude (bukan operasi API/SQL biasa, dan password tidak boleh ditulis di file/command yang bisa ke-log).

**Goal:** Ganti `signInAnonymously()` dengan login email/password ke akun dummy yang sudah ada, supaya jelas siapa yang sedang dipakai testing.

**Architecture:** `RolePickerScreen` tetap jadi entry point, tombolnya navigasi ke `LoginScreen` baru (bukan langsung anonymous sign-in). Setelah `signInWithPassword()` sukses, role diambil dari `public.users.role` (sumber kebenaran), bukan dari tombol yang di-tap. `NameInputScreen`/`saveProfile()`/`signInAnonymously()` dihapus (dead code, login-only tanpa signup).

**Tech Stack:** `supabase_flutter` (`auth.signInWithPassword()`), Riverpod (`StateNotifierProvider` yang sudah ada, tidak ada provider baru), go_router.

## Global Constraints

- Spec lengkap: `docs/superpowers/specs/2026-07-17-email-login-testing-design.md` — baca dulu kalau ada bagian plan ini yang ambigu.
- Login-only, TIDAK ada form signup/registrasi baru (lihat spec bagian "Out of scope").
- Role yang di-tap di `RolePickerScreen` cuma hint teks — TIDAK divalidasi terhadap role akun asli. Salah tap tetap sukses login, redirect ke role asli dari DB.
- Password akun dummy TIDAK PERNAH ditulis di kode, plan, commit message, atau file apapun yang masuk git.
- `AuthState` (shape: `isLoading`, `isAuthenticated`, `role`, `userId`, `error`) TIDAK berubah — kode lain yang baca `ref.read(authProvider).userId`/`.role` (mis. `negotiation_chat_screen.dart`) tidak perlu disentuh.

---

### Task 1: `AuthNotifier.signInWithPassword()` — ganti `signInAnonymously()` + `saveProfile()`

**Files:**
- Modify: `lib/features/auth/providers/auth_provider.dart`

**Interfaces:**
- Produces: `AuthNotifier.signInWithPassword({required String email, required String password}) -> Future<void>` — dipakai Task 2 (`LoginScreen`). Efek samping: update `state` (`AuthState`) jadi `isAuthenticated: true, role: <dari DB>, userId: <dari auth>` kalau sukses, atau `error: 'Email atau password salah'` kalau gagal.

**Catatan:** tidak ada test unit untuk method ini (lihat spec bagian Testing) — manggil `Supabase.instance.client` langsung tanpa DI seam, konsisten dengan `saveProfile()`/`signInAnonymously()` yang diganti (sama-sama tidak pernah dites langsung). Verifikasi lewat Task 6 (manual, end-to-end).

- [x] **Step 1: Hapus `signInAnonymously()` dan `saveProfile()`, tambah `signInWithPassword()`**

Cari dan hapus method `signInAnonymously()` (baris ~53-64) dan `saveProfile()` (baris ~66-116) di `lib/features/auth/providers/auth_provider.dart`. Ganti dengan:

```dart
  Future<void> signInWithPassword({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final response = await Supabase.instance.client.auth
          .signInWithPassword(email: email, password: password);
      final userId = response.user!.id;

      final userRow = await Supabase.instance.client
          .from('users')
          .select('role')
          .eq('id', userId)
          .single();
      final role = userRow['role'] as String;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_role', role);

      // User baru login — device token yang didapat FcmService saat app
      // start (sebelum ada session) belum tersimpan, sync sekarang.
      // (perilaku sama seperti saveProfile() lama, dipertahankan)
      await FcmService().syncDeviceToken();

      state = AuthState(isAuthenticated: true, role: role, userId: userId);
    } on AuthException catch (e) {
      debugPrint('signInWithPassword error: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Email atau password salah',
      );
    } catch (e) {
      debugPrint('signInWithPassword error: $e');
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
```

File lengkap setelah perubahan (referensi — pastikan hasil akhir persis begini):

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/fcm_service.dart';

class AuthState {
  final bool isLoading;
  final bool isAuthenticated;
  final String? role;
  final String? userId;
  final String? error;

  const AuthState({
    this.isLoading = false,
    this.isAuthenticated = false,
    this.role,
    this.userId,
    this.error,
  });

  AuthState copyWith({
    bool? isLoading,
    bool? isAuthenticated,
    String? role,
    String? userId,
    String? error,
    bool clearError = false,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      role: role ?? this.role,
      userId: userId ?? this.userId,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState());

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final role = prefs.getString('user_role');
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (role != null && userId != null) {
      state = state.copyWith(isAuthenticated: true, role: role, userId: userId);
    }
  }

  Future<void> signInWithPassword({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final response = await Supabase.instance.client.auth
          .signInWithPassword(email: email, password: password);
      final userId = response.user!.id;

      final userRow = await Supabase.instance.client
          .from('users')
          .select('role')
          .eq('id', userId)
          .single();
      final role = userRow['role'] as String;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_role', role);

      await FcmService().syncDeviceToken();

      state = AuthState(isAuthenticated: true, role: role, userId: userId);
    } on AuthException catch (e) {
      debugPrint('signInWithPassword error: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Email atau password salah',
      );
    } catch (e) {
      debugPrint('signInWithPassword error: $e');
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> signOut() async {
    await Supabase.instance.client.auth.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_role');
    await prefs.remove('user_name');
    state = const AuthState();
  }
}

final authProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});

final currentUserRoleProvider = Provider<String?>((ref) {
  return ref.watch(authProvider).role;
});
```

- [x] **Step 2: `flutter analyze lib/`**

Run: `flutter analyze lib/`
Expected: masih ada error, karena `role_picker_screen.dart` masih manggil `signInAnonymously()` yang sudah dihapus — lanjut Task 3, jangan commit dulu.

---

### Task 2: `LoginScreen` (test-first — widget test)

**Files:**
- Create: `lib/features/auth/screens/login_screen.dart`
- Test: `test/login_screen_test.dart`

**Interfaces:**
- Consumes: `AuthNotifier.signInWithPassword()` (Task 1), `authProvider` (existing).
- Produces: `LoginScreen({required String role})` widget — dipakai Task 4 (route `/login`).

- [x] **Step 1: Tulis test (akan gagal — `LoginScreen` belum ada)**

```dart
// test/login_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:farmbridge/features/auth/providers/auth_provider.dart';
import 'package:farmbridge/features/auth/screens/login_screen.dart';

class _FakeAuthNotifier extends AuthNotifier {
  _FakeAuthNotifier(AuthState initial) {
    state = initial;
  }
}

void main() {
  testWidgets('LoginScreen menampilkan field email, password, dan hint role',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith((ref) => _FakeAuthNotifier(const AuthState())),
        ],
        child: const MaterialApp(home: LoginScreen(role: 'farmer')),
      ),
    );

    expect(find.text('Login sebagai Petani'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(find.widgetWithText(ElevatedButton, 'Login'), findsOneWidget);
  });

  testWidgets('LoginScreen menampilkan pesan error dari authProvider',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith((ref) => _FakeAuthNotifier(
                const AuthState(error: 'Email atau password salah'),
              )),
        ],
        child: const MaterialApp(home: LoginScreen(role: 'buyer')),
      ),
    );

    expect(find.text('Email atau password salah'), findsOneWidget);
  });

  testWidgets('LoginScreen nonaktifkan tombol & tampil loading saat isLoading true',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith((ref) => _FakeAuthNotifier(
                const AuthState(isLoading: true),
              )),
        ],
        child: const MaterialApp(home: LoginScreen(role: 'farmer')),
      ),
    );

    final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(button.onPressed, isNull);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
```

- [x] **Step 2: Jalankan test, pastikan gagal (file belum ada)** — terkonfirmasi FAIL: `Method not found: 'LoginScreen'`

Run: `flutter test test/login_screen_test.dart`
Expected: FAIL — `Error: Couldn't resolve the package 'farmbridge/features/auth/screens/login_screen.dart'` (file belum ada)

- [x] **Step 3: Tulis `LoginScreen`**

```dart
// lib/features/auth/screens/login_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  final String role;

  const LoginScreen({super.key, required this.role});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String get _titleText => widget.role == 'farmer'
      ? 'Login sebagai Petani'
      : 'Login sebagai Pembeli';

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final notifier = ref.read(authProvider.notifier);
    await notifier.signInWithPassword(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );

    final state = ref.read(authProvider);
    if (state.error != null) return;

    if (mounted && state.role != null) {
      context.go(state.role == 'farmer' ? '/farmer' : '/buyer');
    }
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white70),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.4)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.white),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authProvider.select((s) => s.isLoading));
    final error = ref.watch(authProvider.select((s) => s.error));

    return Scaffold(
      backgroundColor: Colors.green.shade800,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: isLoading ? null : () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 24),
                Text(
                  _titleText,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _emailController,
                  autofocus: true,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDecoration('Email'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Email tidak boleh kosong';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDecoration('Password'),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Password tidak boleh kosong';
                    }
                    return null;
                  },
                ),
                if (error != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    error,
                    style: const TextStyle(color: Colors.redAccent),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.green.shade800,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text(
                            'Login',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

- [x] **Step 4: Jalankan test, pastikan lolos**

Run: `flutter test test/login_screen_test.dart`
Expected: PASS (3/3) — terkonfirmasi 3/3 passed

---

### Task 3: Wire `RolePickerScreen` ke `/login`

**Files:**
- Modify: `lib/features/auth/screens/role_picker_screen.dart`

**Interfaces:**
- Consumes: route `/login` (Task 4 — route belum ada di titik ini, tapi kode ini cuma manggil `context.push`, tidak error kompilasi kalau route-nya belum terdaftar, cuma runtime nanti; urutan Task tidak masalah).

- [x] **Step 1: Ganti `_handleRoleSelect`**

```dart
  void _handleRoleSelect(BuildContext context, String role) {
    context.push('/login', extra: role);
  }
```

Ganti signature lama (`Future<void> _handleRoleSelect(BuildContext context, WidgetRef ref, String role) async { ... }`) — method baru tidak butuh `ref` lagi (tidak ada lagi panggilan ke `authProvider.notifier` di titik ini, `signInWithPassword` baru dipanggil nanti di `LoginScreen`). Update juga pemanggilnya:

```dart
                  _RoleCard(
                    icon: Icons.agriculture,
                    label: 'Saya Petani',
                    role: 'farmer',
                    isLoading: isLoading,
                    onTap: () => _handleRoleSelect(context, 'farmer'),
                  ),
                  const SizedBox(height: 16),
                  _RoleCard(
                    icon: Icons.storefront,
                    label: 'Saya Pembeli',
                    role: 'buyer',
                    isLoading: isLoading,
                    onTap: () => _handleRoleSelect(context, 'buyer'),
                  ),
```

- [x] **Step 2: Commit** *(gabung dengan Task 1, lihat Task 5 Step 3 — satu commit buat semua perubahan auth)*

---

### Task 4: Route `/login`, hapus route `/name-input` + hapus `name_input_screen.dart`

**Files:**
- Modify: `lib/core/router/app_router.dart`
- Delete: `lib/features/auth/screens/name_input_screen.dart`
- Modify: `test/app_router_redirect_test.dart`

**Interfaces:**
- Consumes: `LoginScreen` (Task 2), `resolveRedirect()` (existing, sudah pure function).
- Produces: `resolveRedirect()` — `isOnboardingRoute` sekarang juga true untuk `/login` (bukan lagi `/name-input`).

- [x] **Step 1: Update test dulu (TDD — ganti skenario `/name-input` jadi `/login`)**

Di `test/app_router_redirect_test.dart`, ganti:

```dart
  group('resolveRedirect — role null (belum onboarding)', () {
    test('boleh tetap di role-picker/login', () {
      expect(resolveRedirect(null, '/role-picker'), isNull);
      expect(resolveRedirect(null, '/login'), isNull);
    });
```

(sebelumnya `'boleh tetap di role-picker/name-input'` + `resolveRedirect(null, '/name-input')`)

Dan:

```dart
  group('resolveRedirect — role ada, masih di onboarding route', () {
    test('didorong ke home sesuai role', () {
      expect(resolveRedirect('farmer', '/role-picker'), '/farmer');
      expect(resolveRedirect('buyer', '/login'), '/buyer');
    });
  });
```

(sebelumnya `resolveRedirect('buyer', '/name-input')`)

- [x] **Step 2: Jalankan test, pastikan gagal**

Run: `flutter test test/app_router_redirect_test.dart`
Expected: FAIL — terkonfirmasi (kompilasi gagal karena `name_input_screen.dart` masih referensi `saveProfile()` yang sudah dihapus di Task 1, sinyal yang sama validnya dengan test assertion gagal) — 2 skenario di atas gagal (`/login` belum dianggap onboarding route oleh `resolveRedirect()` yang masih pakai `/name-input`)

- [x] **Step 3: Update `resolveRedirect()` di `app_router.dart`**

```dart
  final isOnboardingRoute =
      matchedLocation == '/role-picker' || matchedLocation == '/login';
```

(ganti dari `matchedLocation == '/name-input'`)

- [x] **Step 4: Ganti import + route di `app_router.dart`**

Ganti:
```dart
import '../../features/auth/screens/name_input_screen.dart';
```
jadi:
```dart
import '../../features/auth/screens/login_screen.dart';
```

Ganti:
```dart
      GoRoute(
        path: '/name-input',
        builder: (context, state) {
          final role = state.extra as String;
          return NameInputScreen(role: role);
        },
      ),
```
jadi:
```dart
      GoRoute(
        path: '/login',
        builder: (context, state) {
          final role = state.extra as String;
          return LoginScreen(role: role);
        },
      ),
```

- [x] **Step 5: Hapus file `name_input_screen.dart`**

```bash
rm lib/features/auth/screens/name_input_screen.dart
```

- [x] **Step 6: Jalankan test, pastikan lolos**

Run: `flutter test`
Expected: semua test PASS — terkonfirmasi 18/18 passed

- [x] **Step 7: `flutter analyze lib/`**

Run: `flutter analyze lib/`
Expected: 0 issue — terkonfirmasi, plus grep manual konfirmasi 0 sisa referensi `NameInputScreen`/`name-input`/`saveProfile`/`signInAnonymously` di `lib/`+`test/` (semua referensi `signInAnonymously`/`saveProfile`/`NameInputScreen`/`/name-input` sudah hilang dari seluruh `lib/`)

---

### Task 5: Verifikasi akhir + commit

- [x] **Step 1:** `flutter analyze lib/` → 0 issue
- [x] **Step 2:** `flutter test` → semua PASS
- [ ] **Step 3: Commit** *(belum — dijalankan Hafizh sendiri, lihat draft commit di respons)*

```bash
git add lib/features/auth/ lib/core/router/app_router.dart test/app_router_redirect_test.dart test/login_screen_test.dart
git commit -m "feat: ganti anonymous auth dengan login email/password"
```

---

### Task 6 (MANUAL — Hafizh, bukan Claude): Set kredensial 2 akun dummy + verifikasi end-to-end

**Kenapa manual:** set password lewat Supabase Dashboard (bukan operasi API/SQL yang bisa dijalankan Claude), dan password tidak boleh diketik di command/file yang bisa ke-log atau ter-commit.

- [ ] **Step 1:** Buka Supabase Dashboard → Authentication → Users
- [ ] **Step 2:** Cari user `38e89c06-2257-49f8-a392-ed2ee8734031` ("Pak Tani Maju") → Edit → set Email `farmer.test@farmbridge.dev` → set Password (pilih sendiri, simpan di luar repo) → aktifkan **Auto Confirm User**
- [ ] **Step 3:** Ulangi Step 2 untuk user `ed23f6a6-21cb-4576-89ac-d8bfdae08a78` ("Restoran Warung Kita") — email `buyer.test@farmbridge.dev`
- [ ] **Step 4:** `flutter run` (device/emulator/chrome) → tap "Saya Petani" → harus masuk ke `LoginScreen` (judul "Login sebagai Petani") → login pakai `farmer.test@farmbridge.dev` → harus masuk ke Farmer Home (bukan error)
- [ ] **Step 5:** Sign out (kalau ada tombolnya) atau restart app → tap "Saya Pembeli" → login pakai `buyer.test@farmbridge.dev` → harus masuk ke Buyer Home
- [ ] **Step 6:** Coba login dengan password salah → harus muncul "Email atau password salah", tetap di layar login
- [ ] **Step 7:** Restart app setelah login sukses → harus tetap login (tidak balik ke role picker) — verifikasi session persistence tidak rusak dari perubahan ini
- [ ] **Step 8 (edge case dari spec):** tap "Saya Petani" tapi login pakai kredensial buyer (`buyer.test@farmbridge.dev`) → harus tetap sukses login, redirect ke **Buyer** Home (role asli dari DB menang, bukan yang di-tap) — sesuai keputusan out-of-scope di spec

---

## Self-Review (ditulis, bukan dijalankan subagent)

**Spec coverage:** Login-only ✅ (Task 1-2, tidak ada form signup). 2 akun existing di-upgrade ✅ (Task 6). Role dari DB menentukan redirect, bukan yang di-tap ✅ (Task 1 query `users.role`, Task 6 Step 8 verifikasi). `AuthState` shape tidak berubah ✅ (Task 1 tetap pakai `AuthState`/`copyWith` yang sama). Password tidak ditulis di repo ✅ (Task 6 eksplisit bilang "pilih sendiri, simpan di luar repo"). `resolveRedirect()` unit test diupdate ✅ (Task 4).

**Placeholder scan:** tidak ada "TBD"/"implement later" — semua step punya kode lengkap atau instruksi manual eksplisit (Task 6).

**Type consistency:** `signInWithPassword({required String email, required String password})` dipakai identik di Task 1 (definisi) dan Task 2 (`LoginScreen._submit()` pemanggilan) — cocok. `AuthState.error`/`.isLoading`/`.role` dipakai konsisten di semua task.
