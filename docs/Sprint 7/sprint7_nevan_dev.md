# Sprint 7: Buy Now UI & Fulfillment — Task Plan untuk Nevan

## Peran di sprint ini
**Satu ticket: FG-32 (POST /transactions/:id/fulfill).**

## Task Checklist

### FG-32 — POST /transactions/:id/fulfill
- [x] `POST /transactions/:id/fulfill`: `{ delivered_quantity, actual_delivery_date }` → `{ transaction_id, status, trust_metrics_updated:true }`
- [x] 403 jika requester bukan farmer pemilik transaksi
- [x] Trigger otomatis bandingkan `actual_delivery_date` vs `promised_delivery_date` dan `delivered_quantity` vs `agreed_quantity` → panggil `update trust_metrics` (FG-18, Sprint 4)
- [x] `anomaly_flag=true` kalau `delivered_quantity > agreed_quantity` (§11), status tetap `fulfilled`
- [x] TIDAK termasuk konfirmasi tambahan dari buyer (dihapus v5, satu langkah final)

## File/folder yang kamu sentuh
```
supabase/functions/transactions-fulfill/**
```

## Sync point dengan teammate
- **Begitu FG-32 selesai**: kabari Fachri — FG-34 (Fulfillment Form UI, Sprint 8) bisa mulai wiring.

## Definition of Done
- [x] Farmer fulfill transaksi miliknya → status `fulfilled`, `trust_metrics_updated:true`, dan `trust_metrics` benar-benar ter-update
- [x] `delivered_quantity > agreed_quantity` → tetap `fulfilled` dengan `anomaly_flag=true`, bukan ditolak

## Referensi PRD
§4.1, §5.1, §9, §10.5, §11.
