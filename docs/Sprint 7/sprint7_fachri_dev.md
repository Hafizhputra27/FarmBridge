# Sprint 7: Buy Now UI & Fulfillment — Task Plan untuk Fachri

## Peran di sprint ini
**FG-30 (Buy Now UI) + FG-59 (Transaction Detail / Order Aktif screen — gap-fill, subtask FG-30).**

## Kenapa Transaction Detail screen jadi ticket terpisah (FG-59)
AC FG-30 bilang "buyer diarahkan ke halaman order aktif" setelah Buy Now sukses — tapi halaman itu tadinya tidak punya ticket sendiri. Sekarang sudah diformalkan jadi **FG-59** (subtask FG-30) di JIRA. Desain sudah ada di Figma (frame "order aktif [199:661]", "Transaction_Fulfilled"/"Transaction_detail"). Screen ini dipakai lagi Sprint 8 (FG-34, entry point fulfillment form) dan Sprint 9 (FG-40, CTA recurring order).

## Task Checklist

### FG-30 — Buy Now UI
- [ ] Tombol Buy Now di halaman detail listing (semua listing)
- [ ] Modal/screen input kuantitas sebelum konfirmasi final
- [ ] Kuantitas melebihi stok → error sebelum request dikirim + tervalidasi backend
- [ ] Setelah Buy Now sukses, arahkan ke Transaction Detail (FG-59) menampilkan transaksi baru
- [ ] TIDAK termasuk pembayaran (out of scope §14)

### FG-59 — Transaction Detail / Order Aktif screen (gap-fill, subtask FG-30)
- [ ] **Transaction Detail screen** (role-adaptive):
  - Buyer view: detail transaksi + tombol Reject (aktif hanya saat `pending`, panggil endpoint FG-33 Hafizh)
  - Farmer view: detail transaksi + tombol "Tandai Terkirim" (akan buka Fulfillment Form, dibangun Sprint 8)
  - Ikuti frame Figma "order aktif [199:661]"/"Transaction_Fulfilled"/"Transaction_detail"
- [ ] Screen ini reusable — dipakai FG-34 (Sprint 8) & FG-40 (Sprint 9)

## File/folder yang kamu sentuh
```
lib/features/transaction/**
```

## Sync point dengan teammate
- **Tunggu Nevan** FG-29 (Sprint 6) untuk endpoint Buy Now.
- **Tunggu Hafizh** FG-33 sebelum wiring tombol Reject di Transaction Detail.
- **Informasikan ke Hafizh** struktur widget tombol Reject (props yang dia butuh) supaya dia tinggal wire handler.

## Definition of Done
- [ ] Buyer bisa Buy Now dari listing manapun, diarahkan ke Transaction Detail menampilkan transaksi baru
- [ ] Kuantitas melebihi stok → error sebelum request dikirim + tervalidasi backend
- [ ] Buyer bisa reject transaksi pending dari Transaction Detail

## Referensi PRD
§3.1, §4.1, §14, §15.
