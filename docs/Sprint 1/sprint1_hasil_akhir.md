> Ringkasan hasil akhir Sprint 1 — dibuat 2026-07-16 setelah `hafizh_dev` merge `nevan_dev` + `fachri_dev` dan berhasil masuk `main` dengan CI/CD hijau. Merangkum tiga dokumen per-orang (`dokumentasi_sprint1_nevan_dev.md`, `dokumentasi_sprint1_fachri.md`, `sprint1_hafizh_dev_report.md`) jadi satu gambaran utuh.

# Sprint 1: Foundation Kickoff — Hasil Akhir

## Status: ✅ Selesai & merge ke `main`

| Ticket | PIC | Status |
|---|---|---|
| FG-2 — Migration SQL 11 tabel + index | Nevan | ✅ |
| FG-5 — Setup CI/CD Pipeline | Hafizh | ✅ |
| FG-6 — Setup FCM Push Notification | Hafizh | ✅ |
| FG-57 — Flutter project init + GoRouter skeleton | Fachri | ✅ |
| FG-9 — Role picker screen (desain) | Alexander | ✅ (lihat `sprint0_alexander_design.md`) |

---

## FG-2 — Migration SQL (Nevan)

Fondasi skema database project di Supabase (`rwxnjxmzkcfoddnzjosi`, `ap-southeast-1`):

- **11 tabel**: `users`, `farmer_profiles`, `buyer_profiles`, `listings`, `price_reference_data`, `negotiations`, `negotiation_messages`, `transactions`, `recurring_orders`, `trust_metrics`, `buyer_metrics`
- **4 index**: `listings(status)`, `negotiations(status)`, `transactions(status)`, `transactions(farmer_id)`
- Poin kritis yang diuji langsung: `users.email` nullable, `buyer_metrics.buyer_id` FK ke `buyer_profiles` (bukan `users`), `users.role` CHECK constraint, `users.device_token` nullable, semua FK `ON DELETE CASCADE`
- File: `supabase/migrations/20260716083135_initial_schema.sql`

## FG-5 — CI/CD Pipeline (Hafizh)

- `.github/workflows/deploy.yml`: trigger push ke `main` → `supabase db push` → deploy semua `supabase/functions/*` secara generik (tidak hardcode nama function)
- GitHub repo secrets: `SUPABASE_ACCESS_TOKEN`, `SUPABASE_PROJECT_REF`, `SUPABASE_DB_PASSWORD`
- **Verifikasi live (bukan cuma dry-run):** run CI pertama dari push ke `main` (`Merge pull request #5`) — **sukses penuh**, `Remote database is up to date` + `send-push` ter-deploy otomatis. Cek: `gh run view 29494239186`

## FG-6 — FCM Push Notification (Hafizh)

- Firebase project `farmbridge-d7fe8`, Android app terdaftar via `flutterfire configure`
- `supabase/functions/_shared/fcm.ts` — helper generik `sendPush({deviceToken, title, body, deepLink})`, dipakai `send-push` dan (rencana) Edge Function lain mulai Sprint 6/8
- `lib/core/services/fcm_service.dart` — request permission, ambil & simpan device token, refresh listener
- **Verifikasi end-to-end di HP fisik (Infinix X6885, Android 15):** kirim push via `send-push` → notifikasi muncul di device ✅; token invalid → HTTP 200 `{"ok":false,...}`, tidak crash ✅
- **Temuan penting:** emulator Android tanpa akun Google tidak reliable buat test FCM (`getToken()` tetap sukses, tapi delivery gagal diam-diam) — pelajaran untuk sprint berikutnya, test FCM sebaiknya di device fisik atau emulator yang sudah sign-in Google

## FG-57 — Flutter Project Scaffold (Fachri)

- Struktur folder `lib/core/`, `lib/features/{buyer,farmer}/home/`, `lib/shared/widgets/`
- `lib/core/router/app_router.dart` — GoRouter skeleton dengan role-based redirect (role determination penuh baru di FG-11, Sprint 3)
- 6 dependency inti ditambahkan: `supabase_flutter`, `go_router`, `flutter_riverpod`, `cached_network_image`, `image_picker`, `shared_preferences`
- `flutter analyze` 0 issues, `flutter test` semua lolos

---

## Titik integrasi yang perlu effort ekstra

Sprint ini secara teknis "selesai" oleh masing-masing orang, tapi proses **merge ke `hafizh_dev`** menemukan beberapa gap yang tidak kelihatan sampai dicoba digabung:

1. **`supabase/config.toml` konflik** — `enable_anonymous_sign_ins`: Hafizh punya `false` (default `supabase init`), Nevan punya `true`. Resolusi: `true` menang, sesuai PRD §13.1 (arsitektur auth pakai `signInAnonymously()` tanpa email/password).
2. **Migration history remote vs git tidak sinkron** — Nevan sempat push migration ke database dengan nama file/timestamp berbeda dari yang dia commit ke git, dan **satu migration penuh (realtime + storage + pg_cron) sempat tidak ter-commit sama sekali** meski sudah aktif jalan di production. Direkonstruksi ulang lewat introspeksi SQL langsung ke database live, bukan lewat `supabase db pull` (macet di Docker) — jadi `supabase/migrations/20260716092216_realtime_storage_cron.sql`.
3. **`lib/main.dart`, `pubspec.yaml`/`pubspec.lock` konflik saat merge Fachri** — kedua belah pihak nambah dependency berbeda (FCM vs GoRouter/Riverpod) dan sama-sama menulis ulang `main()`. Digabung: `Firebase.initializeApp()` → `Supabase.initialize()` → `FcmService().initialize()` (urutan ini wajib, karena FCM butuh Supabase sudah siap) → `runApp(ProviderScope(child: FarmBridgeApp()))`. Kredensial Supabase asli diisi menggantikan placeholder Fachri.

Pelajaran: task checklist per-orang bisa semua tercentang ✅ tapi baru kelihatan benar-benar cocok satu sama lain di titik merge — proses integrasi `hafizh_dev` bukan formalitas, di sprint ini dia yang menangkap 3 masalah nyata di atas.

## Definition of Done — verifikasi final

| Item | Status |
|---|---|
| Push ke `main` → Edge Function ter-deploy otomatis | ✅ verified via CI run `29494239186` |
| `supabase db push` via CI berhasil apply migration tanpa manual intervention | ✅ `Remote database is up to date` |
| Device token terdaftar → FCM kirim notifikasi ke device Android | ✅ verified di HP fisik |
| `hafizh_dev` merge `nevan_dev` + `fachri_dev`, dry-run hijau sebelum masuk `main` | ✅ |

## Yang menyusul di Sprint 2+

- Seed data `price_reference_data` (FG-7) — dipindah ke Sprint 3, belum dikerjakan
- Rotate credential: DB password & Supabase access token yang sempat diketik di sesi kerja hari ini — **belum dikonfirmasi sudah di-rotate**
