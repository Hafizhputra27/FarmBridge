> Ringkasan hasil akhir Sprint 3 — dibuat 2026-07-16, setelah `fachri_dev` (FG-11) merge ke `hafizh_dev` dan integrasi disinkronkan dengan FG-6/FG-7. Merangkum `sprint3_hafizh_dev_report.md`, `dokumentasi_sprint3_fachri.md`, dan temuan integrasi yang muncul saat proses sinkronisasi.

# Sprint 3: Seed Data & Role Picker Flow — Hasil Akhir

## Status: ✅ Selesai — terverifikasi end-to-end di device/emulator

| Ticket | PIC | Status |
|---|---|---|
| FG-7 — Seed `price_reference_data` awal | Hafizh | ✅ |
| FG-11 — Build role picker flow (Flutter) | Fachri | ✅ (3 bug integrasi ditemukan & diperbaiki setelah merge) |

Nevan tidak ada ticket sprint ini (breathing room setelah FG-2/FG-3/FG-4, sesuai rencana Sprint 3 README).

---

## FG-7 — Seed `price_reference_data` (Hafizh)

`supabase/seed.sql` — 6 kategori produk pertanian (Beras, Cabai Merah, Bawang Merah, Tomat, Jagung, Kentang) × 3 region (Jawa Barat/Tengah/Timur), 18 baris. Strategi idempotency: `DELETE` + `INSERT` massal (bukan `ON CONFLICT`, karena tabel tidak punya unique constraint di `category`+`region`).

**Verifikasi:** rerun 2x tetap 18 baris (tidak dobel), semua `min_price < avg_price < max_price`, akses `anon` via REST API sukses HTTP 200. Detail lengkap: `sprint3_hafizh_dev_report.md`.

## FG-11 — Role Picker Flow (Fachri)

File baru: `lib/features/auth/providers/auth_provider.dart` (AuthState/AuthNotifier — `signInAnonymously()`, `saveProfile()`, `signOut()`), `lib/features/auth/screens/role_picker_screen.dart`, `lib/features/auth/screens/name_input_screen.dart`. `lib/core/router/app_router.dart` di-wire ke screen asli (dari dummy provider FG-57).

Flow: `/role-picker` → tap role → `signInAnonymously()` → `/name-input` → isi nama → `saveProfile()` (insert `users` + `farmer_profiles`/`buyer_profiles`) → `SharedPreferences` → `/farmer` atau `/buyer`.

`flutter analyze`/`flutter test` bersih saat FG-11 di-commit — **tapi belum pernah dites end-to-end tap-per-tap sebelum merge** (checklist checklist Fachri sendiri mengklaim beberapa perilaku yang ternyata belum benar-benar jalan saat diuji nyata, lihat bagian bawah).

---

## Temuan integrasi (baru ketahuan setelah merge, bukan sebelum)

Task checklist FG-6, FG-11 sama-sama sudah ✅ di dokumen masing-masing sebelum merge. Begitu diuji end-to-end nyata di emulator (tap sungguhan, bukan cuma `flutter analyze`), ditemukan **3 masalah** yang cuma kelihatan di titik pertemuan dua fitur:

### 1. Device token tidak pernah tersimpan (FG-6 × FG-11)
`FcmService` mengambil token FCM saat app start — sebelum ada user login, jadi `_saveDeviceToken()` selalu skip (`currentUser` masih null). Setelah `signInAnonymously()` + `saveProfile()` membuat user baru, tidak ada kode yang memanggil ulang penyimpanan token. **Hasil: kolom `users.device_token` selalu `null` untuk user manapun yang lewat role picker** — push notification (seluruh tujuan FG-6) putus total di jalur yang sebenarnya dipakai user.

**Fix:** `FcmService` dapat method baru `syncDeviceToken()` (re-fetch + simpan token tanpa re-request permission), dipanggil dari `AuthNotifier.saveProfile()` setelah insert user berhasil.

### 2. Session tidak restore saat app restart (murni FG-11)
`AuthNotifier.initialize()` (baca `SharedPreferences`) ditulis tapi **tidak pernah dipanggil dari mana pun** — klaim di `dokumentasi_sprint3_fachri.md` ("App restart langsung skip role picker") ternyata tidak benar saat dites: user yang sudah pilih role akan selalu dilempar balik ke role picker setiap buka app lagi.

**Fix:** `main.dart` memanggil `authProvider.notifier.initialize()` lewat `ProviderContainer` **sebelum** `runApp()`, supaya state ter-restore sebelum route pertama dievaluasi. `initialize()` juga disempurnakan untuk restore `userId` dari `Supabase.instance.client.auth.currentUser`, bukan cuma `role` dari `SharedPreferences`.

### 3. Onboarding loop di `GoRouter.redirect` (murni FG-11, paling parah)
Redirect logic awal: `if (role == null) return '/role-picker';` — berlaku untuk **semua** route termasuk `/name-input` sendiri. Karena `role` baru ke-set setelah `NameInputScreen` submit (bukan setelah `signInAnonymously()`), begitu `RolePickerScreen` coba `context.push('/name-input')`, redirect langsung mental balik ke `/role-picker` karena role masih null di titik itu. **Onboarding tidak pernah bisa lolos dari role picker sama sekali** — bug paling signifikan di sprint ini, tidak kelihatan lewat `flutter analyze`/`flutter test` sama sekali, cuma ketahuan lewat tap manual di device sungguhan.

**Fix:** redirect logic ditulis ulang 3 kondisi: (a) role null → izinkan tetap di `/role-picker`/`/name-input`, paksa ke `/role-picker` untuk route lain; (b) role sudah ada tapi masih di route onboarding → dorong ke `/farmer` atau `/buyer` (ini juga yang memperbaiki restore session setelah fix #2); (c) proteksi silang buyer/farmer seperti semula.

**Pelajaran:** checklist per-fitur (FG-6, FG-11) bisa sama-sama ✅ dan lolos `flutter analyze`, tapi baru kelihatan benar-benar jalan setelah dites end-to-end nyata di device — bukan formalitas. Sama seperti Sprint 1 (migration file hilang) dan Sprint 2 (migration timestamp tidak sinkron), Sprint 3 ini masalahnya di titik integrasi, bukan di kode masing-masing orang secara terpisah.

---

## Verifikasi end-to-end (emulator Pixel 7, 2026-07-16)

| Test | Hasil |
|---|---|
| Fresh install → tap "Saya Petani" → isi nama → submit | ✅ sampai ke Farmer Home |
| Query `users` setelah submit | ✅ `device_token` terisi token FCM asli (baris lama sebelum fix: semua `null`) |
| `farmer_profiles` setelah submit | ✅ baris baru sesuai nama yang diketik |
| Force-stop + restart app | ✅ langsung ke Farmer Home, tidak balik ke role picker |
| `dart analyze` / `flutter test` setelah semua fix | ✅ bersih |

## Migration tambahan Sprint 3

`supabase/migrations/20260716121157_users_insert_policy.sql` (dari Nevan, FG-3 follow-up) — policy `users_insert_self` (`INSERT ... WITH CHECK (auth.uid() = id)`) yang sebelumnya tidak ada, dibutuhkan supaya `saveProfile()` FG-11 bisa insert baris `users` baru. Sama seperti Sprint 1-2, file ini sempat punya timestamp berbeda dari yang applied di remote — sudah di-rename supaya sinkron (lihat commit `d1e5c25`).

## Commit terkait

```
1603d0e feat: FG-11 role picker flow (Fachri)
d1e5c25 [FG-3] rename migration users_insert_policy — sinkron timestamp dengan state remote
79a4ba0 [FG-6][FG-11] sinkronisasi device_token + fix session restore + fix routing loop onboarding
```

## Status merge

Semua di atas ada di `hafizh_dev` (`79a4ba0`), **belum di-merge ke `main`** — menunggu MERGE #1 sesuai strategi hybrid-per-fase (`HYBRID_MERGE_KICKOFF.md`): Fase 1 (Sprint 1-3) di-merge sekali di titik ini.

## Yang menyusul

- FG-9 (desain Alexander) — dependency FG-11, sudah dikonfirmasi selesai sebelum Sprint 3 mulai
- Dashboard farmer/buyer sungguhan masih placeholder — bukan scope FG-11, menyusul di sprint lanjutan
- 2 file strategi (`HYBRID_MERGE_KICKOFF.md`, perubahan `FarmBridge_Branching_Playbook.md`) masih perlu di-commit resmi
