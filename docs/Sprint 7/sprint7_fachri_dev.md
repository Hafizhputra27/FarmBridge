# Sprint 7: Buy Now UI & Fulfillment — Task Plan untuk Fachri

## Peran di sprint ini
**FG-30 (Buy Now UI) + FG-59 (Transaction Detail / Order Aktif screen — gap-fill, subtask FG-30).**

> **Catatan 2026-07-17:** Fachri sedang tidak available sprint ini, dikerjakan Hafizh sebagai backup. Detail eksekusi lengkap ada di `sprint7_hafizh_dev_plan.md` (plan gabungan FG-27+FG-30+FG-33+FG-59). Layout/visual **belum** mengikuti frame Figma asli (tidak ada akses desain saat backup) — struktur data & alur sudah benar dan teruji end-to-end (backend), tapi Fachri perlu review kesesuaian visual begitu available lagi.

## Kenapa Transaction Detail screen jadi ticket terpisah (FG-59)
AC FG-30 bilang "buyer diarahkan ke halaman order aktif" setelah Buy Now sukses — tapi halaman itu tadinya tidak punya ticket sendiri. Sekarang sudah diformalkan jadi **FG-59** (subtask FG-30) di JIRA. Desain sudah ada di Figma (frame "order aktif [199:661]", "Transaction_Fulfilled"/"Transaction_detail"). Screen ini dipakai lagi Sprint 8 (FG-34, entry point fulfillment form) dan Sprint 9 (FG-40, CTA recurring order).

## Task Checklist

### FG-30 — Buy Now UI
- [x] Tombol Buy Now di halaman detail listing (semua listing) — `ListingDetailScreen` baru dibangun sekalian (belum ada sama sekali sebelumnya, gap ditemukan saat analisis sprint)
- [x] Modal/screen input kuantitas sebelum konfirmasi final — `showModalBottomSheet`
- [x] Kuantitas melebihi stok → error sebelum request dikirim + tervalidasi backend — dicek client-side (`qty > available`) dan backend (`buy-now` sudah validasi, dites langsung via curl)
- [x] Setelah Buy Now sukses, arahkan ke Transaction Detail (FG-59) menampilkan transaksi baru — `context.go('/transaksi/$transactionId')`
- [x] TIDAK termasuk pembayaran (out of scope §14) — tidak ada elemen pembayaran ditambahkan

### FG-59 — Transaction Detail / Order Aktif screen (gap-fill, subtask FG-30)
- [x] **Transaction Detail screen** (role-adaptive):
  - Buyer view: detail transaksi + tombol Reject (aktif hanya saat `pending`, panggil endpoint FG-33 Hafizh) — ✅
  - Farmer view: detail transaksi + tombol "Tandai Terkirim" (akan buka Fulfillment Form, dibangun Sprint 8) — tombol ada, stub `SnackBar` (Fulfillment Form memang belum ada sampai Sprint 8, sesuai catatan ticket sendiri)
  - Ikuti frame Figma "order aktif [199:661]"/"Transaction_Fulfilled"/"Transaction_detail" — ⏳ **belum**, layout dasar saja (tidak ada akses Figma saat backup)
- [x] Screen ini reusable — dipakai FG-34 (Sprint 8) & FG-40 (Sprint 9) — desain `TransactionDetailScreen({transactionId})` generik by-id, siap dipanggil ulang

## File/folder yang kamu sentuh
```
lib/features/transaction/**
```

## Sync point dengan teammate
- **Tunggu Nevan** FG-29 (Sprint 6) untuk endpoint Buy Now.
- **Tunggu Hafizh** FG-33 sebelum wiring tombol Reject di Transaction Detail.
- **Informasikan ke Hafizh** struktur widget tombol Reject (props yang dia butuh) supaya dia tinggal wire handler.

## Definition of Done
- [x] Buyer bisa Buy Now dari listing manapun, diarahkan ke Transaction Detail menampilkan transaksi baru — teruji end-to-end via curl (backend), UI tap manual belum dites device
- [x] Kuantitas melebihi stok → error sebelum request dikirim + tervalidasi backend
- [x] Buyer bisa reject transaksi pending dari Transaction Detail — teruji end-to-end (stok balik, `rejection_rate` update)

## Referensi PRD
§3.1, §4.1, §14, §15.
