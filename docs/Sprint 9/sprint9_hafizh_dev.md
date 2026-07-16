# Sprint 9: Recurring Order UI — Task Plan untuk Hafizh

## Peran di sprint ini
**FG-38 (pg_cron trigger H-1) dan FG-40 (CTA "Jadikan Recurring Order").**

## Task Checklist

### FG-38 — pg_cron trigger H-1 next_order_date
- [ ] Job cek `recurring_orders.status=active` dengan `next_order_date` = H-1
- [ ] **Koordinasi dulu dengan Nevan** soal reuse locking FG-35 (lihat README) sebelum menulis logic
- [ ] Kalau farmer konfirmasi & `listing.quantity` cukup: buat `transaction` baru `pending`, `locked_price` sama, tertaut `recurring_order_id` yang sama
- [ ] Kalau tidak: **skip siklus ini**, `recurring_orders` TETAP `active` untuk siklus berikutnya (§11)
- [ ] Trigger event untuk FG-42 (wiring FCM reminder, sudah kamu mulai Sprint 8 — sekarang bisa dituntaskan)

### FG-40 — CTA "Jadikan Recurring Order" (UI)
- [ ] CTA muncul di Transaction Detail screen (FG-30, Sprint 7) setelah status `fulfilled`
- [ ] Tap CTA → form input `frequency` → panggil `POST /recurring-orders` (FG-37, Sprint 8)
- [ ] Setelah submit, arahkan ke Recurring Order Detail (dibangun Fachri, FG-39 — koordinasi kalau belum selesai)

## File/folder yang kamu sentuh
```
supabase/functions/recurring-order-trigger/**
lib/features/transaction/**  (CTA di screen Fachri, Sprint 7)
```

## Sync point dengan teammate
- **Koordinasi dengan Nevan** soal locking sebelum FG-38 ditulis.
- **Koordinasi dengan Fachri** soal Transaction Detail screen (struktur) sebelum nambah CTA.

## Definition of Done
- [ ] Job H-1: farmer konfirmasi + stok cukup → transaction baru pending terbentuk
- [ ] Job H-1: tidak konfirmasi/stok kurang → TIDAK ada transaction baru, tetap `active`
- [ ] CTA muncul setelah `fulfilled`, submit berhasil membuat recurring order

## Referensi PRD
§4.1, §6, §9, §10.4, §11.
