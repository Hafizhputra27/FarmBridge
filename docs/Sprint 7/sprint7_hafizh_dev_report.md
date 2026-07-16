> Laporan penyelesaian — dibuat 2026-07-17, mendokumentasikan status akhir FG-27, FG-33 (Hafizh) dan FG-30, FG-59 (Fachri, backup Hafizh karena Fachri tidak available sprint ini). Pelengkap `sprint7_hafizh_dev.md`/`sprint7_fachri_dev.md` (checklist ticket asli, sudah diupdate) dan `sprint7_hafizh_dev_plan.md` (rencana eksekusi lengkap dengan kode).

# Sprint 7 — Hafizh (+ backup Fachri) — Laporan Penyelesaian

## Ringkasan

4 dari 5 ticket sprint ini (semua kecuali FG-32 milik Nevan) selesai dikerjakan dari `hafizh_dev`. Fachri tidak available sprint ini — FG-30 dan FG-59 (ticket aslinya) ikut dikerjakan Hafizh sebagai backup. Di tengah jalan ketemu **bug produksi nyata** di `buy-now` (Edge Function Nevan) yang bikin fitur Buy Now mati total — didiagnosis dan diperbaiki karena blocking, bukan opsional.

## Yang dikerjakan

**FG-27** (tap nama → profil counterpart dari chat) — sudah efektif selesai dari fix bug sesi sebelumnya (`negotiation_chat_screen.dart`: `Navigator.pushNamed()` → `context.push()`, plus resolve `buyer_profiles.id` yang benar untuk arah farmer→buyer). Tidak ada kode baru, cuma verifikasi.

**FG-33** — `supabase/functions/transactions-reject/index.ts`: `POST /transactions/:id/reject`. Cek buyer terkait (403 kalau bukan), cek status `pending` (400 kalau bukan), panggil `releaseInventoryOnReject()` (Nevan, FG-35, sudah ada) buat rollback stok, update status `rejected`, panggil ulang `update-trust-metrics` (Nevan, FG-18, sudah ada) via HTTP fetch internal buat recompute `rejection_rate` farmer. `reason` diterima tapi tidak disimpan (tidak ada kolom di `transactions`, echo balik saja di response).

**FG-59** — `lib/features/transaction/data/transaction_repository.dart` + `lib/features/transaction/screens/transaction_detail_screen.dart`, route `/transaksi/:id`. Role-adaptive: buyer lihat tombol Reject (aktif kalau `pending`), farmer lihat tombol "Tandai Terkirim" (stub `SnackBar`, Fulfillment Form-nya baru Sprint 8 — sesuai catatan ticket sendiri, bukan kekurangan).

**FG-30** — Ketemu gap: **Listing Detail screen sama sekali belum ada** di codebase manapun (tap listing di feed sebelumnya langsung ke farmer-profile, bukan ke detail listing). Dibangun `lib/features/listing/screens/listing_detail_screen.dart` (baru), `getListingDetail()` di `ListingRepository`, `BuyNowRepository` baru (thin wrapper ke Edge Function `buy-now`). Tap card di `buyer_home_feed_screen.dart` diubah ke Listing Detail (nama farmer tetap terpisah ke farmer-profile, tidak berubah). Modal kuantitas via `showModalBottomSheet`, validasi client-side (`qty > stok`) + backend.

## Bug ditemukan & diperbaiki (di luar scope awal) — `buy-now` (Nevan) rusak total

`POST /buy-now/:listingId` konsisten balas `404 "Listing tidak ditemukan"` untuk listing yang terbukti ada dan aktif (diverifikasi query PostgREST langsung sukses dengan token yang sama). **Root cause:** parsing `listingId` dari URL pakai regex prefix-strip (`pathname.replace(/^\/functions\/v1\/buy-now\/?/, "")`) — rapuh terhadap bagaimana `req.url` disajikan runtime Supabase saat deploy, beda dari pola simpel (`pathname.split("/").pop()`) yang dipakai `trust-metrics`/`buyer-metrics` dan terbukti stabil.

**Cara diagnosis:** dikonfirmasi lebih dulu di function sendiri (`transactions-reject`, pola sama, gagal identik) — fix ke pola simpel, langsung sukses. Fix yang sama diterapkan ke `buy-now/index.ts`, deploy ulang. **Alur penuh `buy-now → transactions-reject` diverifikasi end-to-end via curl nyata**: stok listing 500 → 495 (setelah buy-now) → 500 (setelah reject), `rejection_rate` farmer ter-update benar.

**Perlu dikabari ke Nevan** — bug nyata di file dia, root cause sudah jelas, worth dia tahu supaya tidak terulang di function lain dengan pola URL sama.

## Verifikasi

| Test | Hasil |
|---|---|
| `flutter analyze lib/` | ✅ 0 issue |
| `flutter test` | ✅ 27/27 passed |
| `buy-now` end-to-end (curl, akun `buyer.test@farmbridge.dev`) | ✅ 200, transaction dibuat, stok terpotong benar |
| `transactions-reject` end-to-end | ✅ 200, stok balik, `rejection_rate` ter-update (diverifikasi query DB langsung) |
| `transactions-reject` guard 400 (reject transaksi yang sudah `rejected`) | ✅ ditolak dengan pesan jelas |
| `transactions-reject` guard 403 (bukan buyer terkait) | ⏳ tidak dites eksplisit — butuh transaksi milik user lain, di-block classifier (mutasi data orang lain tanpa izin eksplisit). Logic straightforward (`tx.buyer_id !== userData.user.id`), risiko rendah |
| UI manual (tap card, buka bottom sheet Buy Now, tap Reject di Transaction Detail) | ⏳ belum — keterbatasan sandbox (tidak ada akses screen), sama seperti sprint-sprint sebelumnya |
| Kesesuaian visual dengan frame Figma (FG-59) | ⏳ belum — tidak ada akses desain saat backup Fachri, perlu direview Fachri sendiri nanti |

## Commit

```
feat: FG-59 transaction detail + FG-30 buy now UI + listing detail screen (b2c937b)
feat: [FG-33] POST /transactions/:id/reject (bac2020)
fix: [FG-29] buy-now — parsing listing_id dari URL salah (7ef4697)
docs: plan Sprint 7 — FG-27/30/33/59 selesai + bug buy-now (cec06d6)
docs: checklist sprint7_fachri_dev — FG-30 & FG-59 selesai (68165e5)
```

Branch: `hafizh_dev` — working tree bersih, tapi **diverged dari `origin/hafizh_dev`** (5 commit lokal ahead, 2 commit remote behind — 2 commit remote itu noise merge PR biasa, pola yang sama seperti kejadian-kejadian sebelumnya, aman di-pull).

## Status Definition of Done

**FG-27** (`sprint7_hafizh_dev.md`): ✅ — sudah efektif selesai.
**FG-33**: ✅ semua item, termasuk rollback stok dan update `rejection_rate`, teruji end-to-end.
**FG-30 & FG-59** (`sprint7_fachri_dev.md`): ✅ semua item fungsional, ⏳ kesesuaian visual Figma belum direview.

## Yang masih menggantung

1. **Sync `hafizh_dev`** — pull 2 commit remote dulu sebelum push (rutin, bukan masalah baru).
2. **Kabari Nevan** soal bug `buy-now` yang diperbaiki — dia perlu tahu root cause-nya.
3. **Fachri review visual** `ListingDetailScreen`/`TransactionDetailScreen` begitu available lagi — struktur & fungsi sudah benar, tampilan belum ikut Figma.
4. **Migration `listings.title`/`listings.unit`** — drift lama dari Sprint 6, masih belum direkonstruksi jadi file (dicatat lagi di sini supaya tidak hilang dari radar).
5. **Verifikasi UI manual end-to-end** — device fisik, sama seperti item terbuka sprint-sprint sebelumnya.

## Yang menyusul

Sinkronisasi `nevan_dev` → `hafizh_dev` (rencana Anda selanjutnya), lalu lanjut Sprint 8 (FG-32 Nevan sudah independen dari sprint ini, Fulfillment Form yang di-reference tombol "Tandai Terkirim" FG-59 kemungkinan salah satu isinya).
