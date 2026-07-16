# Sprint 7: Buy Now UI & Fulfillment — Task Plan untuk Hafizh

## Peran di sprint ini
**FG-27 (Tap nama → profil counterpart) dan FG-33 (POST /transactions/:id/reject).**

## Task Checklist

### FG-27 — Tap nama → lihat profil counterpart dari dalam chat
- [ ] Nama counterpart yang bisa di-tap di header/dalam chat screen (dari FG-25, Sprint 6)
- [ ] Navigasi ke Public Profile yang sudah dibangun FG-16 (Sprint 6) — reuse, jangan bikin ulang
- [ ] Farmer tap nama buyer → Buyer Public Profile dengan `buyer_metrics`
- [ ] Buyer tap nama farmer → Farmer Public Profile dengan Trust Score

### FG-33 — POST /transactions/:id/reject
- [ ] `POST /transactions/:id/reject`: `{ reason }` → `{ transaction_id, status:'rejected' }`
- [ ] 403 jika requester bukan buyer terkait; hanya bisa saat status `pending`
- [ ] Trigger rollback `quantity_available` — panggil `releaseInventoryOnReject()` dari Nevan (FG-35, **selesai sejak Sprint 5** — cek dokumentasi function-nya, jangan tulis ulang)
- [ ] Trigger update `rejection_rate` farmer via `trust_metrics` (FG-18, Sprint 4)
- [ ] Aksi independen buyer, bisa kapan saja selama pending — bukan langkah wajib setelah farmer fulfill

## File/folder yang kamu sentuh
```
lib/features/negotiation/**  (FG-27, tap nama)
supabase/functions/transactions-reject/**  (FG-33)
```

## Sync point dengan teammate
- **Kabari Fachri** begitu FG-33 selesai — tombol Reject di Transaction Detail screen (bagian FG-30 miliknya) butuh ini.

## Definition of Done
- [ ] Farmer/buyer bisa tap nama dari chat → profil counterpart terbuka dengan metrik yang benar
- [ ] Buyer terkait reject transaction pending → status `rejected`, `quantity_available` kembali
- [ ] Transaction sudah `fulfilled` → reject ditolak

## Referensi PRD
§3.1(v6), §4.1(v6), §5.1, §9, §14.
