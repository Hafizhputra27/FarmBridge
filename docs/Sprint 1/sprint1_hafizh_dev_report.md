> Laporan penyelesaian — dibuat 2026-07-16, mendokumentasikan status akhir FG-5 & FG-6 sebelum merge ke `main`. Pelengkap `sprint1_hafizh_dev.md` (checklist ticket asli) dan `sprint1_hafizh_dev_plan.md` (rencana eksekusi task-by-task).

# Sprint 1 — Hafizh (FG-5 CI/CD + FG-6 FCM) — Laporan Penyelesaian

## Ringkasan

Kedua ticket (FG-5, FG-6) selesai dari sisi kode dan infrastruktur, dan **FG-6 sudah diverifikasi end-to-end di HP fisik** (notifikasi push benar-benar muncul). Satu item tersisa — kolom `users.device_token` — menunggu migration FG-2 dari Nevan sesuai urutan kerja yang direncanakan sejak awal sprint (bukan pekerjaan yang belum selesai, itu urutan yang disengaja).

## FG-5 — CI/CD Pipeline

**Dibuat:** `.github/workflows/deploy.yml` — trigger push ke `main`, jalankan `supabase db push` lalu deploy semua `supabase/functions/*` secara generik (skip `_shared/`), tanpa hardcode nama function.

**Infra live:**
- Project Supabase (`rwxnjxmzkcfoddnzjosi`) di-link
- GitHub repo secrets terpasang & terverifikasi (`gh secret list`): `SUPABASE_ACCESS_TOKEN`, `SUPABASE_PROJECT_REF`, `SUPABASE_DB_PASSWORD`

**Belum bisa diverifikasi:** run CI sungguhan (baru terdaftar setelah workflow ada di branch `main`) dan `supabase db push` via CI (belum ada migration untuk di-push — nunggu FG-2 Nevan).

## FG-6 — FCM Push Notification

**Dibuat:**
- `supabase/functions/_shared/fcm.ts` — `sendPush({deviceToken, title, body, deepLink})`, satu helper generik dipakai `send-push` dan Edge Function lain di sprint berikutnya (FG-24, FG-42)
- `supabase/functions/send-push/index.ts` — thin HTTP wrapper untuk test manual
- `lib/core/services/fcm_service.dart` — request permission, ambil token, simpan ke `users.device_token`, refresh listener
- Firebase project `farmbridge-d7fe8` dibuat, Android app terdaftar (`flutterfire configure`)
- `lib/main.dart` — `Firebase.initializeApp()` + `FcmService().initialize()` di entry point

**Verifikasi end-to-end (2026-07-16):**

| Test | Device | Hasil |
|---|---|---|
| Token generation (`getToken()`) | Emulator Pixel 7 (Google Play image) | ✅ token valid didapat |
| `send-push` dengan token valid | Emulator Pixel 7 | HTTP 200, `{"ok":true}` — **notifikasi tidak muncul** |
| `send-push` dengan token valid | HP fisik Infinix X6885 (Android 15) | HTTP 200, `{"ok":true}` — **notifikasi muncul di device** ✅ |
| `send-push` dengan token invalid | — | HTTP 200, `{"ok":false,"error":"FCM 400: ..."}` — tidak crash ✅ |

**Temuan penting — emulator tanpa akun Google tidak reliable untuk test FCM:** Percobaan pertama di emulator gagal menampilkan notifikasi walau FCM API mengembalikan `{"ok":true}` dan client SDK terbukti menerima pesan (log `FirebaseMessaging`/`FLTFireMsgReceiver` aktif). Root cause: `adb shell dumpsys account` menunjukkan **tidak ada Google account** ter-sign-in di emulator — Play Services tidak bisa registrasi penuh ke channel push Google walau `getToken()` tetap mengembalikan token yang terlihat valid. Setelah pindah ke HP fisik (yang sudah sign-in Google account), notifikasi langsung muncul dengan payload identik. **Pelajaran untuk sprint berikutnya:** kalau butuh test FCM di emulator, pastikan emulator pakai image "Google Play" dan sudah sign-in akun Google dulu — kalau tidak, uji langsung di device fisik.

**Belum selesai:** kolom `users.device_token` sudah ada di migration Nevan (`origin/nevan_dev`, belum di-merge ke `hafizh_dev`) — begitu di-merge dan `supabase db push --dry-run` hijau, `_saveDeviceToken()` di `FcmService` langsung bisa jalan tanpa perubahan kode lagi.

## Proposal `device_token` untuk Nevan (Task 1 — menunggu konfirmasi)

Belum dikonfirmasi ke Nevan per 2026-07-16. Yang perlu disepakati sebelum dia commit migration FG-2:

1. **Lokasi:** kolom langsung di tabel `users` — bukan tabel terpisah (`device_tokens`)
2. **Nama kolom:** persis `device_token` — sudah di-hardcode di `lib/core/services/fcm_service.dart`:
   ```dart
   await Supabase.instance.client
       .from('users')
       .update({'device_token': token}).eq('id', userId);
   ```
   Kalau Nevan pakai nama lain (mis. `fcm_token`), file ini harus disesuaikan dulu sebelum device_token wiring bisa jalan (lihat Task 9 Step 3 di `sprint1_hafizh_dev_plan.md`).
3. **Tipe:** `text`, nullable — bukan `NOT NULL`, karena user baru register belum tentu langsung punya token.

Alasan satu kolom nullable (bukan tabel terpisah): satu user = satu device token aktif cukup untuk kebutuhan MVP (push reminder recurring order + update negosiasi) — tabel many-to-many tidak dibutuhkan untuk scope hackathon ini (YAGNI).

Draft pesan yang dipakai untuk konfirmasi ke Nevan:

> "Untuk FG-6 (push notification), tolong tambahin kolom `device_token text null` langsung di tabel `users` waktu nulis migration FG-2 — nullable karena user baru belum tentu punya token. Satu kolom aja cukup, gak perlu tabel terpisah, karena satu user cuma butuh satu device token aktif buat MVP ini. Oke?"

**Status 2026-07-16: terverifikasi lewat kode.** Migration Nevan di `origin/nevan_dev` (`supabase/migrations/20260716080000_initial_schema.sql`) berisi persis `device_token text NULL` di tabel `users` — cocok 1:1 dengan proposal di atas dan dengan `fcm_service.dart`. Tidak perlu penyesuaian nama kolom (Task 9 Step 3 aman).

## File yang dibuat/diubah (belum di-commit)

```
.gitignore                                    (modified — exclude firebase service account, supabase/.env)
.github/workflows/deploy.yml                  (new)
android/app/build.gradle.kts                  (modified — google-services plugin)
android/app/google-services.json              (new)
android/settings.gradle.kts                   (modified — google-services plugin)
firebase.json                                 (new)
lib/core/services/fcm_service.dart            (new)
lib/firebase_options.dart                     (new)
lib/main.dart                                 (modified — Firebase + FcmService init)
pubspec.yaml / pubspec.lock                   (modified — firebase_core, firebase_messaging, supabase_flutter)
supabase/config.toml, supabase/.gitignore     (new — supabase init scaffold)
supabase/functions/_shared/fcm.ts             (new)
supabase/functions/send-push/index.ts         (new)
```

Draft urutan commit ada di riwayat percakapan sesi ini — belum dijalankan (sesuai `docs/CLAUDE.md`, Claude tidak menjalankan `git add`/`commit`/`push`).

## Yang masih pending sebelum merge ke `main`

1. ~~Task 1 (blocking): konfirmasi device_token dengan Nevan~~ — **selesai, terverifikasi lewat migration `origin/nevan_dev`**
2. ~~Commit semua perubahan~~ — **selesai** (7 commit di `hafizh_dev`, lihat `git log`)
3. **Merge `nevan_dev` → `hafizh_dev`**, lalu `supabase db push --dry-run` (wajib hijau)
4. **Merge `fachri_dev` → `hafizh_dev`** (setelah Nevan aman, risiko konflik rendah karena FG-57 tidak menyentuh migration)
5. ~~Task 9 Step 3: cek nama kolom~~ — **sudah dicek dari migration, cocok, tidak perlu perubahan kode**
6. Push `hafizh_dev` → merge ke `main` → verifikasi Actions run hijau (DoD FG-5 & FG-6 sisanya)

## Catatan keamanan

DB password dan Supabase access token sempat diketik langsung di percakapan chat sesi ini untuk keperluan setup (`supabase link`, `gh secret set`). **Rotate kedua kredensial ini dari Supabase Dashboard setelah sprint ini** supaya tidak ada credential asli yang tersimpan permanen di histori chat manapun.
