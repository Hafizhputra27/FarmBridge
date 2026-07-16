# Login Email/Password (Ganti Anonymous Auth) — Design Spec

> Dibuat 2026-07-17. Latar belakang: selama testing manual Sprint 1-6 (setelah sinkronisasi 3 branch), sulit tahu persis siapa user yang sedang login karena `signInAnonymously()` tidak punya identitas yang jelas — tiap sign-out/restart bisa jadi user anonymous baru. Fitur ini mengganti alur anonymous dengan login email/password ke akun dummy yang sudah ada, supaya jelas siapa yang sedang dipakai testing.

## Problem & Goal

**Problem:** `signInAnonymously()` (Supabase Anonymous Auth) tidak punya identitas yang bisa diverifikasi dari luar — tidak ada email, tidak ada cara "login sebagai user tertentu yang sama berulang kali". Ini menyulitkan QA manual (tidak tahu pasti akun mana yang lagi dipakai) dan reproduksi bug (tidak bisa "jadi user yang sama" dua kali tanpa reset device).

**Goal:** Ganti total alur anonymous dengan email/password login. User login ke akun dummy yang **sudah ada** (bukan signup baru) — datanya (nama, role, profile) sudah lengkap dari sebelumnya. Role picker tetap ada sebagai langkah UI, tapi role yang menentukan routing setelah login adalah `users.role` dari database (sumber kebenaran), bukan tombol yang di-tap — supaya tidak ada ambiguitas kalau user salah tap tombol role.

## Scope

**In scope:**
- Layar login baru (email + password)
- `AuthNotifier` method baru untuk sign-in dengan email/password
- Hapus alur anonymous (`signInAnonymously()`, `saveProfile()`, `NameInputScreen`, route `/name-input`) — dead code setelah fitur ini, bukan fallback
- 2 akun dummy existing (1 farmer, 1 buyer) di-upgrade supaya bisa login email/password
- Unit test untuk logic "role dari DB menentukan redirect, bukan role yang di-tap"

**Out of scope (eksplisit, jangan dikerjakan):**
- Form signup/registrasi akun baru — login-only ke akun dummy yang sudah ada
- Password reset / lupa password — tidak perlu untuk akun dummy internal
- Email verification flow — akun dummy langsung di-set `email_confirm: true` manual
- Validasi "role yang di-tap harus cocok dengan role akun" — kalau salah tap, tetap login sukses, redirect ke role asli dari DB (bukan ditolak)
- Mengubah 8 akun dummy anonymous lain yang sudah ada — tetap anonymous, tidak disentuh

## Arsitektur

Role picker screen (`RolePickerScreen`) tetap jadi entry point pertama, tapi tombolnya sekarang navigasi ke `LoginScreen` (bukan langsung `signInAnonymously()` + navigasi ke `NameInputScreen`). Role yang di-tap diteruskan sebagai `extra` (String) ke `LoginScreen`, dipakai murni untuk teks hint UI (misal "Login sebagai Petani") — **tidak** dipakai untuk validasi apapun.

Setelah `signInWithPassword()` sukses, `AuthNotifier` query `public.users.role` untuk user yang baru login (sumber kebenaran satu-satunya untuk role), simpan ke `SharedPreferences` (pola sama seperti sekarang: `user_role` key) dan update `AuthState`. Redirect ke `/farmer` atau `/buyer` sesudahnya tetap lewat `resolveRedirect()` yang sudah ada — logic intinya (role menentukan tujuan, cross-role guard) tidak berubah, cuma daftar `isOnboardingRoute` perlu ditambah `/login` (lihat bagian Route baru) supaya layar login sendiri tidak ikut ke-guard.

Session persistence antar app-restart **tidak berubah** — `supabase_flutter` sudah otomatis persist session (termasuk email/password session) ke local storage, dan `AuthNotifier.initialize()` yang sudah ada (baca `SharedPreferences` + `Supabase.instance.client.auth.currentUser`) tetap valid dipakai apa adanya.

## Komponen

### 1. `LoginScreen` (baru) — `lib/features/auth/screens/login_screen.dart`

Widget baru, `ConsumerStatefulWidget`, terima parameter `role` (String, cuma buat hint teks). Isi:
- `TextField` email
- `TextField` password (obscured)
- Tombol "Login"
- Text error kalau login gagal (di bawah tombol, bukan dialog/snackbar — konsisten sama pola error di `RolePickerScreen` yang sudah ada, baca `authProvider.select((s) => s.error)`)
- Loading state (disable tombol + spinner) selama proses login, pola sama `isLoading` yang sudah ada di `AuthState`

### 2. `AuthNotifier.signInWithPassword()` (baru) — `lib/features/auth/providers/auth_provider.dart`

```dart
Future<void> signInWithPassword({
  required String email,
  required String password,
}) async {
  state = state.copyWith(isLoading: true, clearError: true);
  try {
    final response = await Supabase.instance.client.auth.signInWithPassword(
      email: email,
      password: password,
    );
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
    state = state.copyWith(isLoading: false, error: 'Email atau password salah');
    debugPrint('signInWithPassword error: $e');
  } catch (e) {
    state = state.copyWith(isLoading: false, error: e.toString());
    debugPrint('signInWithPassword error: $e');
  }
}
```

Catatan: `FcmService().syncDeviceToken()` dipertahankan dari `saveProfile()` lama — device token tetap perlu disinkronkan setelah dapat session baru, tidak berubah dari perilaku sebelumnya.

### 3. Dihapus (dead code)

- `AuthNotifier.signInAnonymously()`
- `AuthNotifier.saveProfile()`
- `lib/features/auth/screens/name_input_screen.dart` (file dihapus)
- Route `/name-input` di `app_router.dart` (`GoRoute` + import `NameInputScreen`)
- `RolePickerScreen`: `onPressed` tombol role diganti dari `notifier.signInAnonymously()` + `context.push('/name-input', extra: role)` jadi `context.push('/login', extra: role)`

### 4. Route baru — `app_router.dart`

```dart
GoRoute(
  path: '/login',
  builder: (context, state) {
    final role = state.extra as String;
    return LoginScreen(role: role);
  },
),
```

Ditambahkan sejajar route `/role-picker` yang sudah ada (bukan di dalam `ShellRoute`). `resolveRedirect()` — `isOnboardingRoute` check perlu ditambah `matchedLocation == '/login'` supaya guard redirect tidak nge-bounce layar login (sama seperti `/name-input` sebelumnya).

## Data — 2 akun dummy di-upgrade

**Tidak ada migration/kode** — dikerjakan manual lewat Supabase Dashboard (Authentication → Users), karena cuma 2 baris data satu kali, bukan sesuatu yang perlu direproduksi berulang.

| Role | Nama (sudah ada) | user_id | Email baru | Password baru |
|---|---|---|---|---|
| Farmer | Pak Tani Maju | `38e89c06-2257-49f8-a392-ed2ee8734031` | `farmer.test@farmbridge.dev` | *(ditentukan Hafizh saat set manual)* |
| Buyer | Restoran Warung Kita | `ed23f6a6-21cb-4576-89ac-d8bfdae08a78` | `buyer.test@farmbridge.dev` | *(ditentukan Hafizh saat set manual)* |

Langkah manual (Dashboard → Authentication → Users → cari user_id di atas → Edit): set **Email**, set **Password**, aktifkan **Auto Confirm User** (supaya `email_confirm: true`, tidak perlu alur verifikasi email). 8 akun dummy anonymous lain **tidak disentuh**.

Password sengaja **tidak ditulis** di spec ini (file ini masuk git) — tentukan & catat sendiri di luar repo (mis. password manager tim), bukan di dokumen yang ter-commit.

## Error Handling

- Email/password salah → `AuthException` dari Supabase → pesan generik "Email atau password salah" (tidak bocorkan apakah email terdaftar atau tidak — praktik standar, walau ini cuma testing internal)
- Network/error lain → tampilkan `e.toString()` (pola sama seperti `saveProfile()` lama)
- User berhasil login tapi baris `public.users` untuk id itu tidak ada (`.single()` gagal) → exception ketangkap catch-all, tampil sebagai error — skenario ini seharusnya tidak terjadi untuk 2 akun dummy yang sudah divalidasi, tidak perlu penanganan khusus

## Testing

Unit test baru fokus ke bagian yang bisa diuji tanpa network (`AuthNotifier.signInWithPassword()` sendiri manggil Supabase langsung, sama seperti `saveProfile()` lama — tidak diberi seam DI baru, konsisten dengan kode yang sudah ada, bukan dites langsung).

Yang **bisa** dites otomatis: `resolveRedirect()` sudah punya coverage (`test/app_router_redirect_test.dart`) untuk "role dari state menentukan redirect" — cukup tambah 1 skenario baru: `resolveRedirect` dipanggil dengan `matchedLocation == '/login'` harus dianggap `isOnboardingRoute` (tidak di-redirect paksa ke role-picker).

Verifikasi manual (checklist, bukan otomatis) di plan eksekusi: login sukses dengan kredensial benar → routing sesuai role asli; login dengan kredensial salah → pesan error muncul; app di-restart setelah login → tetap login (session persist); tap "Petani" tapi login pakai akun buyer → tetap masuk sebagai buyer (bukan ditolak, sesuai keputusan out-of-scope).

## Dampak ke kode lain

`ref.read(authProvider).userId` dan `.role` dipakai di banyak tempat (`negotiation_chat_screen.dart`, dll) — **tidak berubah**, karena bentuk `AuthState` tetap sama, cuma cara pengisiannya yang beda (email/password, bukan anonymous). Tidak ada perubahan di luar `lib/features/auth/**` dan `app_router.dart`.
