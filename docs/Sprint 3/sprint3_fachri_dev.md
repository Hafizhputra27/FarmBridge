> Direvisi 2026-07-14 — sinkron ulang dengan label JIRA (skema granular 13-sprint), menggantikan versi kompresi 6-sprint sebelumnya.

# Sprint 3: Seed Data & Role Picker Flow — Task Plan untuk Fachri

## Peran di sprint ini
**Satu ticket: FG-11 (Build role picker flow — Flutter), kali ini tanpa blocker.** Beda dari skema lama, kedua dependency-nya sudah selesai di sprint-sprint sebelumnya: FG-9 (desain, Alexander) selesai Sprint 1, FG-3 (Auth live, Nevan) selesai Sprint 2. Scaffold dasarnya (FG-57) juga sudah ada dari Sprint 1. Jadi sprint ini murni build penuh, tidak ada lagi drama menunggu.

## Task Checklist

### FG-11 — Build role picker flow (Flutter)
- [ ] 2 screen sesuai desain FG-9: pilih role (farmer/buyer), isi nama
- [ ] Validasi nama kosong ditolak dengan pesan jelas
- [ ] Panggil `auth.signInAnonymously()` (FG-3, sudah live sejak Sprint 2) saat role dipilih
- [ ] Simpan hasil ke tabel `users`/`farmer_profiles`/`buyer_profiles` sesuai role
- [ ] Simpan role & nama lokal via `shared_preferences` — app di-kill lalu dibuka lagi langsung ke halaman sesuai role tanpa role picker muncul ulang
- [ ] Aktifkan penuh redirect logic `GoRouter` dari skeleton FG-57 (Sprint 1): `/buyer/*` dan `/farmer/*` saling menolak akses role yang salah, provider role diisi dari hasil auth sungguhan (bukan dummy lagi)

## File/folder yang kamu sentuh
```
lib/features/auth/**  (role picker screens)
lib/core/router/app_router.dart  (aktifkan redirect logic penuh)
```

## Sync point dengan teammate
- Tidak ada blocker masuk — FG-9 dan FG-3 sudah selesai. Kalau ada perubahan desain terbaru dari Alexander, konfirmasi sebelum mulai build.
- **Begitu FG-11 selesai**: kabari Hafizh & Nevan — semua orang butuh `auth.uid()` valid dari flow ini untuk Sprint 4+ (listing, negosiasi, dst).

## Definition of Done
- [ ] `flutter run` jalan, role picker (2 screen) bisa dijalankan, validasi nama kosong bekerja
- [ ] `signInAnonymously()` terpanggil saat role dipilih, `auth.uid()` tercatat di Supabase — **cara cek**: cek tabel `users`/`farmer_profiles`/`buyer_profiles` di Supabase Studio setelah submit
- [ ] Role & nama tersimpan lokal, app di-kill lalu dibuka lagi langsung ke halaman sesuai role tanpa role picker muncul ulang
- [ ] Route `/buyer/*` dan `/farmer/*` saling menolak akses role yang salah — **cara cek**: buat 2 akun dummy role beda, coba akses route role lain secara manual (ketik URL/deep link), harus di-redirect balik

## Referensi PRD
§3.1, §4.1, §13.1 (role picker & auth).
