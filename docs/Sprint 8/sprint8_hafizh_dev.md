# Sprint 8: Fulfillment UI, Recurring — Task Plan untuk Hafizh

## Peran di sprint ini
**FG-37 (POST/PATCH /recurring-orders) dan FG-42 (Wiring FCM push).**

## Task Checklist

### FG-37 — POST/PATCH /recurring-orders
- [ ] `POST /recurring-orders`: `{ buyer_id, farmer_id, listing_id, quantity, frequency, locked_price }` → `{ recurring_order_id, next_order_date }`; 400 jika `listing_id` tidak `active`
- [ ] `PATCH /recurring-orders/:id`: `{ status: 'paused'|'cancelled'|'active' }` → `{ recurring_order_id, status }`; 409 jika transisi tidak valid (`cancelled`→`active` tidak diizinkan, §6)
- [ ] Hitung `next_order_date` otomatis dari `frequency` saat create

### FG-42 — Wiring FCM push (bagian yang bisa selesai sprint ini)
- [ ] Panggil FCM helper (FG-6) dari: perubahan status negotiation accept/decline/counter (kode Nevan, FG-22, Sprint 5), expire negotiation (kode Nevan, FG-24, Sprint 6)
- [ ] Payload berisi `negotiation_id` untuk deep-link
- [ ] **Bagian H-1 recurring reminder ditinggal sebagai TODO** — job-nya (FG-38) baru ada Sprint 9

## File/folder yang kamu sentuh
```
supabase/functions/recurring-orders/**
supabase/functions/negotiations/**  (tambah pemanggilan send-push, kode Nevan — koordinasi sebelum edit)
supabase/functions/expire-negotiations/**  (tambah pemanggilan send-push)
```

## Sync point dengan teammate
- **Koordinasi dengan Nevan** sebelum edit file negotiation/expire miliknya untuk nambah pemanggilan FCM.

## Definition of Done
- [ ] `listing_id` tidak `active` → 400 saat create recurring order
- [ ] `PATCH` status `cancelled`→`active` ditolak 409
- [ ] Negotiation accepted/declined/countered/expired → kedua pihak menerima push notification

## Referensi PRD
§4.1, §6, §7, §9, §11, §12.
