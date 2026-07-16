# Project Plan: FG-11 — Role Picker Flow

> Dibuat 16 Juli 2026 · Fachri · Sprint 3

---

## Ringkasan

| | |
|---|---|
| **Ticket** | FG-11 — Build Role Picker Flow |
| **PIC** | Fachri |
| **Sprint** | 3 — Seed Data & Role Picker Flow |
| **Dependency** | FG-9 (desain), FG-3 (Auth), FG-57 (scaffold) |
| **Branch** | `fachri_dev` |
| **Estimasi** | 50-60 menit |

---

## Status Prasyarat

| Prasyarat | Status | Catatan |
|---|---|---|
| FG-9 desain Role Picker | ✅ Final | Alexander sudah share desain |
| FG-3 Anonymous Auth | ✅ Live | `enable_anonymous_sign_ins = true` |
| FG-57 scaffold | ✅ Siap | GoRouter skeleton + deps lengkap |
| Supabase credential | ✅ Asli | `rwxnjxmzkcfoddnzjosi.supabase.co` |
| Anonymous Sign-ins Dashboard | ✅ Enabled | Sudah di-enable di Supabase Dashboard |
| INSERT policy `users` table | ✅ Ada | Terverifikasi live via SQL Editor |

---

## Checklist FG-11 (dari `sprint3_fachri_dev.md`)

- [x] 2 screen sesuai desain FG-9: pilih role (farmer/buyer), isi nama
- [x] Validasi nama kosong ditolak dengan pesan jelas
- [x] Panggil `auth.signInAnonymously()` (FG-3, sudah live sejak Sprint 2) saat role dipilih
- [x] Simpan hasil ke tabel `users`/`farmer_profiles`/`buyer_profiles` sesuai role
- [x] Simpan role & nama lokal via `shared_preferences` — app di-kill lalu dibuka lagi langsung ke halaman sesuai role tanpa role picker muncul ulang
- [x] Aktifkan penuh redirect logic `GoRouter` dari skeleton FG-57 (Sprint 1): `/buyer/*` dan `/farmer/*` saling menolak akses role yang salah, provider role diisi dari hasil auth sungguhan (bukan dummy lagi)

### Mapping Checklist → Task

| Item Checklist FG-11 | Task di Plan |
|---|---|
| 2 screen role picker + isi nama | T2 (RolePickerScreen) + T3 (NameInputScreen) |
| Validasi nama kosong | T3 (validator di TextFormField) |
| `auth.signInAnonymously()` | T2 (RolePickerScreen onTap) |
| Simpan ke `users`/`farmer_profiles`/`buyer_profiles` | T1 (AuthNotifier.saveProfile) |
| Simpan role & nama ke `shared_preferences` | T1 (AuthNotifier.signInAndSaveProfile Step 4) |
| Redirect logic GoRouter penuh | T4 (app_router.dart — hapus dummy, wire provider) |

---

## Task Breakdown

```
FG-11 Role Picker Flow
│
├── T0: Verifikasi Prasyarat (CLEAR ✅)
│   ├── ✅ Konfirmasi ke Alexander: FG-9 desain sudah final
│   ├── ✅ Verifikasi Anonymous Sign-ins enable di Dashboard
│   └── ✅ Verifikasi INSERT policy di users table
│
├── T1: Buat AuthProvider (10 mnt)
│   ├── auth_state.dart — StateNotifier + state class
│   ├── auth_provider.dart — signIn, saveProfile, SharedPreferences
│   └── Update currentUserRoleProvider di app_router
│
├── T2: Build RolePickerScreen (15 mnt)
│   ├── 2 tombol: "Saya Petani" / "Saya Pembeli"
│   ├── Style: ikuti glassmorphic dari FG-9
│   └── Navigasi ke NameInputScreen dengan selectedRole
│
├── T3: Build NameInputScreen (15 mnt)
│   ├── 1 text field, label switch (farm_name / business_name)
│   ├── Validasi: nama kosong → error message
│   ├── On submit: signInAnonymously() → insert DB → SharedPreferences
│   └── Navigasi ke /buyer atau /farmer
│
├── T4: Wire Up GoRouter (5 mnt)
│   ├── Ganti /role-picker PlaceholderScreen → RolePickerScreen
│   ├── currentUserRoleProvider baca SharedPreferences
│   └── Redirect logic aktif penuh
│
└── T5: Verifikasi (10 mnt)
    ├── flutter analyze
    ├── flutter test
    ├── flutter run: test 2 role path
    ├── Cek tabel users/farmer_profiles/buyer_profiles di Supabase
    └── Test app di-kill → buka lagi (skip role picker)
```

---

## Deliverables

| File | Aksi | Output |
|---|---|---|
| `lib/features/auth/providers/auth_provider.dart` | File baru | AuthNotifier + AuthState + provider |
| `lib/features/auth/screens/role_picker_screen.dart` | File baru | 2 role button screen |
| `lib/features/auth/screens/name_input_screen.dart` | File baru | Name input + validasi |
| `lib/core/router/app_router.dart` | Edit | Wire real screens, aktifkan provider |
| `test/widget_test.dart` | Edit | Update test untuk flow baru |

---

## Spesifikasi Teknis

### T1 — AuthProvider

**State:**

```dart
class AuthState {
  final bool isLoading;
  final bool isAuthenticated;
  final String? role;
  final String? userId;
  final String? error;
}
```

**Notifier methods:**
- `initialize()` — baca `SharedPreferences`, jika role ada → set authenticated
- `signInAnonymously()` — dipanggil di RolePickerScreen saat role dipilih:
  1. `auth.signInAnonymously()` → dapat `userId`
  2. Simpan `userId` ke state
- `saveProfile({role, name})` — dipanggil di NameInputScreen saat submit:
  1. Insert ke `users` table: `{ id: state.userId, role: role }`
  2. Insert ke `farmer_profiles` / `buyer_profiles`
  3. Simpan role + nama ke `SharedPreferences`
  4. Update state → authenticated + update role
- `signOut()` — untuk testing, hapus SharedPreferences + signOut Supabase

**Providers:**
```dart
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) { ... });

final currentUserRoleProvider = Provider<String?>((ref) {
  return ref.watch(authProvider).role;
});
```

### T2 — RolePickerScreen

- 2 card/button vertikal: "Saya Petani" (ikon traktor/pertanian), "Saya Pembeli" (ikon toko/keranjang)
- Glassmorphic: `BackdropFilter` + `BoxDecoration(borderRadius, color: Colors.white.withValues(alpha: 0.15))`
- `onTap` → loading overlay → `authNotifier.signInAnonymously()` → jika sukses `context.push('/name-input', extra: role)`
- Layout: `SafeArea` + `Column` center + title "FarmBridge" + subtitle "Pilih peran Anda"

### T3 — NameInputScreen

- Menerima `role` parameter dari route extra
- 1 `TextFormField` dengan label dinamis:
  - farmer → "Nama Petani / Nama Kebun"
  - buyer → "Nama Bisnis / Institusi"
- Validator: `required`, minimal 2 karakter
- Tombol "Mulai" → loading spinner → panggil `authNotifier.saveProfile(role, name)`
- Error: snackbar merah jika insert gagal
- Success: `context.go(role == 'farmer' ? '/farmer' : '/buyer')`

### T4 — GoRouter Update

Perubahan di `app_router.dart`:

1. Hapus `currentUserRoleProvider` dummy (`return null`)
2. Import `auth_provider.dart`
3. Ganti `/role-picker` builder ke `RolePickerScreen`
4. Tambah route `/name-input` dengan builder `NameInputScreen`, menerima `extra` sebagai `String role`
5. Redirect logic tetap sama — tapi sekarang berfungsi penuh

### T5 — Alur Auth Lengkap

```
App Start
  │
  ├── check SharedPreferences
  │     │
  │     ├── role ada ──► GoRouter redirect ke /buyer atau /farmer
  │     │
│     └── role null ──► tampil /role-picker
│                          │
│                          ├── tap "Saya Petani"
│                          │   ├── signInAnonymously()
│                          │   └── push /name-input?role=farmer
│                          │
│                          └── tap "Saya Pembeli"
│                              ├── signInAnonymously()
│                              └── push /name-input?role=buyer
│                                     │
│                                     └── isi nama, submit
│                                           │
│                                           ├── insert users + profiles
│                                           ├── save SharedPreferences
│                                           └── context.go('/buyer' | '/farmer')
  │
  └── App restart ──► SharedPreferences ada ──► langsung /buyer atau /farmer
```

---

## Acceptance Criteria (Definition of Done)

```
[x] flutter run — role picker 2 screen bisa dijalankan
[x] Validasi nama kosong: error message muncul
[ ] auth.signInAnonymously() terpanggil → user muncul di Auth Users Supabase
[ ] Data tersimpan di tabel users + farmer_profiles / buyer_profiles
[ ] Role & nama di SharedPreferences → app restart skip role picker
[ ] Route /buyer/* dan /farmer/* saling tolak akses role salah
[x] flutter analyze 0 issues
[x] flutter test PASS
[ ] Commit ke fachri_dev
```

---

## Risiko & Mitigasi

| Risiko | Prob. | Dampak | Mitigasi |
|---|---|---|---|
| FG-9 desain belum selesai | Sedang | Tidak bisa build UI | Konfirmasi Alexander sebelum Sprint 3 mulai |
| Anonymous Sign-ins belum enable | Rendah | `signInAnonymously()` gagal | Cek Dashboard, enable manual |
| INSERT policy `users` tidak ada | Sedang | Insert gagal (RLS error 42501) | Minta Nevan tambahkan policy: `auth.uid() = id` |
| SharedPreferences tidak sinkron | Rendah | App restart tetap tampil role picker | Test siklus kill-restart |
| FCM token belum tersimpan | Rendah | Notifikasi tidak jalan | `FcmService._saveDeviceToken` sudah handle case `userId == null` |

---

## Referensi

- `docs/Sprint 1/sprint0_alexander_design.md` (FG-9 desain spec)
- `docs/Sprint 2/sprint2_hasil_akhir.md` (FG-3 Auth live)
- `docs/Sprint 3/sprint3_README.md`
- `docs/Sprint 3/sprint3_fachri_dev.md`
- PRD §3.1, §4.1, §13.1
