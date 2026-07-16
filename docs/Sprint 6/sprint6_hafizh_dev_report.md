> Laporan penyelesaian — dibuat 2026-07-17, mendokumentasikan status akhir FG-16 (Buyer & Farmer Public Profile UI), bagian Hafizh Sprint 6. Pelengkap `sprint6_hafizh_dev.md` (checklist ticket asli) dan `sprint6_hafizh_dev_plan.md` (rencana eksekusi, termasuk catatan pivot metode testing).

# Sprint 6 — Hafizh (FG-16 Public Profile UI) — Laporan Penyelesaian

## Ringkasan

Ticket UI Flutter pertama Hafizh di project ini (sebelumnya 3 sprint berturut-turut Edge Function backend). `lib/features/profile/` sebelumnya belum ada sama sekali. Selesai secara fungsional & lolos test otomatis; **verifikasi visual manual (screenshot) belum dilakukan** — dijelaskan di bawah kenapa, dan jadi satu-satunya item yang masih terbuka.

## Yang dikerjakan

- **Fix prasyarat**: `lib/core/router/app_router.dart` — guard redirect `isBuyerRoute`/`isFarmerRoute` pakai `startsWith('/buyer')`/`startsWith('/farmer')` mentah, yang akan salah-cocok dengan route baru `/farmer-profile/:id` (prefix string, bukan segment) dan mem-bounce buyer yang mencoba membuka profil farmer. Diperbaiki jadi exact-or-slash match sebelum nambah route baru.
- **Route baru**: `/farmer-profile/:id` (sudah disepakati dengan Fachri sejak Sprint 4) dan `/buyer-profile/:id` (dibuat simetris, belum ada kesepakatan formal — tidak ada ticket lain yang butuh sprint ini).
- `lib/features/profile/providers/profile_metrics_provider.dart` — dua `FutureProvider.family` yang manggil `Supabase.instance.client.functions.invoke('trust-metrics/$id')`/`'buyer-metrics/$id'` langsung (tanpa repository layer, konsisten dengan pola `auth_provider.dart` yang sudah ada).
- `lib/features/profile/screens/farmer_profile_screen.dart` — 3 angka trust metrics terpisah + total transaksi, state kosong "Belum ada riwayat transaksi" kalau `total_transactions == 0`.
- `lib/features/profile/screens/buyer_profile_screen.dart` — 4 angka buyer metrics, label `fulfillment_rate` = **"Reliability (Completion Rate)"** (bukan "Payment Rate", sesuai larangan PRD), state kosong kalau `total_procurement == 0 && active_orders_count == 0`.

## Kenapa testing-nya pivot ke widget test (bukan screenshot Chrome seperti rencana awal)

Plan awal: `flutter run -d chrome`, navigasi manual ke URL profil, `screencapture` untuk verifikasi visual. Dua kendala muncul saat eksekusi:
1. **Sandbox eksekusi sesi ini tidak punya akses screen** — `screencapture` gagal (`could not create image from display`), otomasi klik via `System Events` juga ditolak (`not allowed to send keystrokes`).
2. Ditemukan juga: route baru butuh `role` sudah ke-set (guard redirect `role == null → /role-picker`), jadi navigasi URL langsung ke browser baru (belum login) tidak akan sampai ke screen tujuan tanpa melalui onboarding dulu — bukan sekadar buka URL.

**Diganti `test/profile_screens_test.dart`** — 5 widget test pakai Riverpod provider override, data yang dipakai **persis sama** dengan response asli yang sudah diverifikasi via curl di Sprint 5 (bukan angka karangan):
- Farmer, data ada → 4 label + angka muncul, empty-state tidak muncul
- Farmer, `total_transactions: 0` → "Belum ada riwayat transaksi" muncul
- Farmer, `null` (404) → "Profil tidak ditemukan" muncul
- Buyer, data ada → 4 label termasuk "Reliability (Completion Rate)", assert eksplisit **"Payment Rate" tidak muncul**
- Buyer, kosong → empty-state

Widget test ini secara desain lebih ketat dari screenshot manual untuk soal seperti larangan label "Payment Rate" (gampang kelewat kalau cuma dilihat sekilas), tapi **tidak menggantikan cek estetika visual** (warna, spacing, kerapian layout) — itu perlu mata manusia.

## Verifikasi

| Test | Hasil |
|---|---|
| `flutter analyze lib/` | 0 issue |
| `flutter test` (termasuk `widget_test.dart` lama) | 6/6 passed, tidak ada regresi |
| `test/profile_screens_test.dart` — 5 skenario (lihat di atas) | 5/5 passed |

**Belum dilakukan:** verifikasi visual manual (jalankan app beneran, lihat layout dengan mata) — perlu Hafizh sendiri yang jalankan `flutter run -d chrome` (atau device fisik), login/onboarding dulu, lalu buka `/farmer-profile/1666543a-bd53-4b22-80c7-3a5186afb2c5` dan `/buyer-profile/84a10df5-3b65-486a-af2c-d6f8f3abd07b` (dua ID nyata dari test Sprint 4/5, satu punya data satu kosong).

## Commit

*Belum di-commit* — file baru: `lib/core/router/app_router.dart` (modified), `lib/features/profile/**` (baru), `test/profile_screens_test.dart` (baru), draft commit message di bawah.

## Status Definition of Done (`sprint6_hafizh_dev.md`)

| Item | Status |
|---|---|
| Farmer baru → "Belum ada riwayat transaksi", bukan 0% | ✅ logic (widget test); ⏳ screenshot visual manual |
| Label buyer metrics bukan "Payment Rate" | ✅ logic (widget test assert negatif); ⏳ screenshot visual manual |
| State "ada data" tervalidasi, tampil benar di UI | ✅ logic + data asli (widget test); ⏳ tampilan visual manual |

**FG-16 selesai fungsional 100%, verifikasi visual manual jadi satu-satunya item terbuka** (di luar kendali sandbox eksekusi sesi ini).

## Yang masih ditunggu sebelum merge ke `main`

Masih FASE 2 (Sprint 4-9), belum merge ke `main` sampai akhir Sprint 9. Merge `nevan_dev`/`fachri_dev` ke `hafizh_dev` disepakati di Sprint 6 (bukan per-tiket) — accumulate dulu.

**Entry point dari FG-15 (Fachri) belum bisa disambungkan** — Fachri belum mulai FG-14/FG-15 di branch-nya (dicek `origin/fachri_dev`, commit terakhir masih seputar FG-11). Route `/farmer-profile/:id` sudah siap di sisi Hafizh, tinggal Fachri sambungkan begitu FG-15 jalan.

## Dipakai di sprint mendatang

Tidak ada consumer langsung — FG-16 ini sendiri konsumen akhir dari FG-20 (Sprint 5). Entry point-nya (FG-15, Fachri) menyusul.
