# Sprint 8: Fulfillment UI, Recurring — Overview

## Isi sprint
| Ticket | Judul | PIC |
|---|---|---|
| FG-34 | Fulfillment Form UI + modal konfirmasi | Fachri |
| FG-37 | POST/PATCH /recurring-orders | Hafizh |
| FG-42 | Wiring FCM push: negotiation update + recurring order H-1 reminder | Hafizh |

Nevan tidak punya ticket sprint ini.

## Catatan FG-42
Ticket ini memanggil FCM helper (FG-6, Sprint 1) dari titik-titik yang sebagian ada di kode Nevan (FG-22 negotiation actions, FG-24 expire job — Sprint 5-6) dan sebagian di kode Hafizh sendiri (FG-38, H-1 job — baru Sprint 9). Bagian negotiation/expire bisa dikerjakan sprint ini; bagian H-1 reminder baru bisa selesai penuh setelah FG-38 (Sprint 9) ada — boleh ditinggal sebagai TODO dan diselesaikan begitu FG-38 jadi.

## Dependency & urutan
```
Hafizh: FG-37 (recurring-orders CRUD) — endpoint dasar, tidak ada dependency masuk
Hafizh: FG-42 — bagian negotiation/expire bisa mulai sekarang, bagian H-1 nunggu Sprint 9
Fachri: FG-34 — butuh FG-32 (Nevan, Sprint 7) + Transaction Detail screen (FG-30, Sprint 7, milik sendiri)
```

## File di sprint ini
- `sprint8_hafizh_dev.md`
- `sprint8_fachri_dev.md`
