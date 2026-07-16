> Direvisi 2026-07-14 — sinkron ulang dengan label JIRA (skema granular 13-sprint), menggantikan versi kompresi 6-sprint sebelumnya.

# Sprint 1: Foundation Kickoff — Task Plan untuk Hafizh

## Peran di sprint ini
**FG-5 (Setup CI/CD Pipeline) dan FG-6 (Setup FCM Push Notification) + integration branch owner.** FG-7 (seed `price_reference_data`) yang dulu ada di sprint ini sekarang resmi pindah ke Sprint 3 — supaya seed data ditulis setelah backbone Auth/RLS (Sprint 2) benar-benar siap diuji, bukan buru-buru sebelum itu. Peran integration/merge-to-`main` tetap melekat ke kamu karena kamu satu-satunya project lead di project ini.

**Kenapa FG-5 dan FG-6 aman dikerjakan paralel dengan kerjaan Nevan**: CI/CD (workflow YAML, secrets) dan FCM (Firebase project, Edge Function generik pengirim push) tidak menyentuh file migration yang sedang aktif diubah Nevan — risiko konflik file rendah. Satu titik soft-dependency: FG-6 butuh keputusan final kolom `device_token` (dari FG-2, Nevan) sebelum kamu wiring penyimpanan token.

## Urutan kerja yang disarankan
1. **FG-5 (CI/CD) — mulai duluan, tidak butuh schema**: scaffold `.github/workflows/deploy.yml`, setup GitHub Secrets (Supabase access token, project ref). Testing end-to-end deploy migration baru bisa dilakukan setelah FG-2 Nevan siap.
2. **FG-6 (FCM) — bagian yang tidak butuh schema**: buat project Firebase, `google-services.json`, integrasi FCM SDK dasar. **Sebelum bikin kolom penyimpanan token, konfirmasi dulu ke Nevan** — kolom `device_token` sudah masuk migration FG-2 atau kamu perlu migration terpisah.
3. Begitu FG-2 (Nevan) selesai: finalisasi bagian device_token wiring di FG-6.
4. Sambil menunggu, siapkan draft rencana seed data untuk FG-7 (Sprint 3) — kategori/region kandidat, supaya begitu Sprint 3 mulai kamu bisa langsung eksekusi tanpa riset dari nol.

## Task Checklist

### FG-5 — Setup CI/CD Pipeline
- [x] GitHub Actions workflow: lint (kalau ada) → deploy migration via Supabase CLI → deploy Edge Functions — `.github/workflows/deploy.yml`
- [x] GitHub Secrets untuk Supabase access token & project ref (jangan hardcode) — `SUPABASE_ACCESS_TOKEN`, `SUPABASE_PROJECT_REF`, `SUPABASE_DB_PASSWORD` terpasang & terverifikasi (`gh secret list`)
- [x] Trigger pada push ke branch `main` — dikonfigurasi di workflow; run sungguhan baru terjadi setelah merge `hafizh_dev` → `main`
- [x] Kalau workflow gagal (token salah/expired), job harus gagal dengan pesan jelas — jangan silent fail — by design (`bash -eo pipefail` default GitHub Actions, tanpa script tambahan)

**Detail teknis**: workflow minimal `.github/workflows/deploy.yml`, trigger `on: push: branches: [main]`, step `supabase functions deploy` per folder di `supabase/functions/`, plus `supabase db push` untuk migration. Deploy Flutter APK **di luar scope** ini (build manual, sesuai batasan hackathon §13.1).

### FG-6 — Setup FCM Push Notification
- [x] Project Firebase Cloud Messaging, hubungkan ke app Flutter (Android minimal untuk demo; iOS opsional) — project `farmbridge-d7fe8`, `flutterfire configure` selesai, `main.dart` wired
- [x] Edge Function helper generik: `send-push(device_token, title, body, deep_link)` — satu fungsi, dipanggil dari job/fitur lain (jangan bikin fungsi terpisah per use-case, biar tidak duplikasi logic FCM API call) — dideploy & **diverifikasi end-to-end, notifikasi muncul di HP fisik (Infinix X6885)**
- [x] Simpan device token ke kolom `users.device_token` (hasil koordinasi dengan Nevan di FG-2) — kolom `device_token` (text) terkonfirmasi ada di DB, `FcmService._saveDeviceToken()` (`lib/core/services/fcm_service.dart:31`) menulis ke `users.device_token` — selesai lewat commit `[FG-6][FG-11] sinkronisasi device_token`
- [x] Error handling: token invalid/expired tidak boleh crash Edge Function — diverifikasi: token invalid → HTTP 200 `{"ok":false,"error":"FCM 400: ..."}`, bukan 500

## File/folder yang kamu sentuh
```
.github/workflows/*.yml
supabase/functions/send-push/**
Firebase config (google-services.json, GoogleService-Info.plist)
```

## Menarik branch di akhir sprint (integration branch owner)
```
git checkout hafizh_dev
git fetch origin
git merge origin/nevan_dev
supabase db push --dry-run   # wajib hijau (migration FG-2 saja sprint ini, belum RLS)
git push origin hafizh_dev
git checkout main
git merge hafizh_dev
git push origin main
```
Kalau `supabase db push --dry-run` gagal, **jangan lanjut ke `main`** — kembalikan ke Nevan untuk diperbaiki dulu. Sprint 1 yang cacat menular ke semua sprint berikutnya karena semua orang mulai dari `hafizh_dev`.

## Sync point dengan teammate
- **Sebelum mulai bagian penyimpanan token di FG-6**: konfirmasi ke Nevan soal kolom `device_token` — idealnya sebelum dia commit migration FG-2, bukan sesudahnya.
- **Begitu Nevan share migration FG-2**: finalisasi FG-6 (device_token wiring).
- **Begitu `nevan_dev` di-merge ke `hafizh_dev` dan lolos dry-run**: kabari Fachri — scaffold FG-57 miliknya bisa disambungkan ke project Supabase yang sudah final schema-nya (walau belum wajib, RLS baru Sprint 2).

## Potensi conflict & cara handle
- Kamu dan Nevan sama-sama berkepentingan dengan struktur `users` table (kolom `device_token`) — selesaikan lewat obrolan cepat sebelum migration ditulis, bukan lewat edit-mengedit file yang sama.

## Definition of Done
- [x] Push ke `main` → Edge Function ter-deploy otomatis ke staging — **diverifikasi**: workflow "Deploy Supabase" (`gh run list`) sukses 3x (`[ok]`, run terbaru #29511090590), trigger `on push: [main]` sesuai desain
- [x] `supabase db push` via CI/CD berhasil apply migration FG-2 tanpa manual intervention — step "Push database migrations" ada di job yang sama, job keseluruhan hijau
- [x] Device token terdaftar → FCM kirim notifikasi ke device Android — **cara cek**: panggil `send-push` manual dari Supabase function invoke, notifikasi muncul di device fisik/emulator — **diverifikasi 2026-07-16 di HP fisik Infinix X6885**
- [x] `hafizh_dev` berhasil merge `nevan_dev` dan masuk `main` — sudah terjadi (PR merge ke `main` terkonfirmasi via git history), CI/CD di atas jadi bukti tidak langsungnya migration/function state di `main` sehat

## Referensi PRD
§7 (Tech Stack), §12 (NFR — Observability untuk CI/CD & FCM).
