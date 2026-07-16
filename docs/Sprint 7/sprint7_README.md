# Sprint 7: Buy Now UI & Fulfillment — Overview

## Isi sprint
| Ticket | Judul | PIC |
|---|---|---|
| FG-27 | Tap nama → lihat profil counterpart dari dalam chat | Hafizh |
| FG-30 | Buy Now UI di detail listing | Fachri |
| FG-59 | Transaction Detail / Order Aktif screen (gap-fill, subtask FG-30) | Fachri |
| FG-32 | POST /transactions/:id/fulfill | Nevan |
| FG-33 | POST /transactions/:id/reject | Hafizh |

## Transaction Detail screen sudah diformalkan jadi FG-59
Tadinya tidak ada ticket untuk "halaman order/transaction detail" — padahal FG-30 (AC: "buyer diarahkan ke halaman order aktif") dan FG-33 (butuh UI tempat buyer menekan Reject) sama-sama mengasumsikan screen ini ada. Sekarang sudah **diformalkan jadi FG-59** (subtask FG-30) di JIRA. Desainnya sudah ada di Figma (frame "order aktif [199:661]", "Transaction_Fulfilled"/"Transaction_detail" dari catatan revisi PRD v5). Dikerjakan Fachri sprint ini, dipakai lagi di Sprint 8 (FG-34) & Sprint 9 (FG-40).

## Catatan: FG-33 ↔ FG-35 (Sprint 5) — beda 2 sprint, bukan lagi Hari-1 coordination
FG-33 butuh function `releaseInventoryOnReject()` dari FG-35 — tapi FG-35 sudah selesai 2 sprint lalu (Sprint 5). Tinggal pastikan Hafizh tahu function itu sudah ada & cara pakainya, bukan buru-buru koordinasi Hari-1 seperti kalau keduanya di sprint yang sama.

## Dependency & urutan
```
Nevan: FG-32 (fulfill) — independen, bisa test pakai transaction dari negosiasi manual (Sprint 5-6)
Fachri: FG-30 (Buy Now UI) + FG-59 (Transaction Detail screen) — butuh FG-29 (Sprint 6)
Hafizh: FG-33 (reject) — pakai function Nevan dari FG-35 (Sprint 5)
Hafizh: FG-27 (tap nama dari chat) — butuh FG-25 (Sprint 6) sudah ada headernya
```

## File di sprint ini
- `sprint7_nevan_dev.md`
- `sprint7_hafizh_dev.md`
- `sprint7_fachri_dev.md`
