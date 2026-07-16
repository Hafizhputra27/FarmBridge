# Sprint 9: Recurring Order UI — Overview

## Isi sprint
| Ticket | Judul | PIC |
|---|---|---|
| FG-38 | pg_cron trigger H-1 next_order_date | Hafizh |
| FG-39 | My Recurring Orders + Detail UI | Fachri |
| FG-40 | CTA "Jadikan Recurring Order" (UI) | Hafizh |
| FG-60 | Guard: cegah archive listing dgn recurring order aktif (gap-fill, edge case §11) | Nevan (backend) + Fachri (UI) |

## FG-60 — edge case §11 yang sebelumnya tak punya owner
FG-60 menutup edge case §11 ke-8: farmer mencoba archive/hapus listing yang masih terikat `recurring_orders` aktif → sistem mencegah, arahkan pause/cancel dulu. Dibagi dua: **Nevan** (query check `recurring_orders.status='active'` sebelum allow archive/delete) dan **Fachri** (pesan error jelas di UI). Setelah jadi, tambahkan ke checklist verifikasi FG-48 (Sprint 10).

## Titik koordinasi teknis: FG-38 dan inventory locking
PRD bilang siklus H-1 di-skip kalau "stok tidak cukup" — tidak eksplisit menyebut apakah pembuatan `transaction` baru tiap siklus harus lewat mekanisme atomic locking yang sama seperti FG-35 (Sprint 5, Nevan). **Rekomendasi: reuse function locking dari FG-35** supaya tidak ada jalur race-condition kedua yang terpisah. Koordinasikan ke Nevan sebelum FG-38 ditulis (walau dia tidak punya ticket sprint ini, dia pemilik function-nya).

## Dependency & urutan
```
Hafizh: FG-38 (H-1 cron) — butuh FG-37 (Sprint 8) sudah ada
Hafizh: FG-40 (CTA UI) — butuh FG-37 + Transaction Detail screen (FG-59, Sprint 7)
Fachri: FG-39 (My Recurring Orders UI) — butuh FG-37 (Sprint 8)
Nevan + Fachri: FG-60 (archive guard) — butuh FG-37 (recurring aktif sudah ada); backend Nevan → pesan UI Fachri
```

## File di sprint ini
- `sprint9_hafizh_dev.md`
- `sprint9_fachri_dev.md`
- `sprint9_nevan_dev.md`
