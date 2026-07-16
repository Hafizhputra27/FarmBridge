> Direvisi 2026-07-14 — sinkron ulang dengan label JIRA (skema granular 13-sprint), menggantikan versi kompresi 6-sprint sebelumnya.

# Sprint 6: Profile UI, Chat & Buy Now — Task Plan untuk Nevan

## Peran di sprint ini
**2 ticket: FG-24 (pg_cron auto-expire negotiation 6 jam) dan FG-29 (POST /listings/:id/buy-now endpoint).** Dua-duanya membangun di atas kerjaanmu sendiri dari Sprint 5 (FG-22 state machine, FG-35 inventory locking) — tidak ada blocker dari orang lain.

## Urutan kerja yang disarankan
1. **FG-24** — butuh FG-22 (Sprint 5) solid, yang sudah selesai. Bisa mulai langsung.
2. **FG-29** — reuse `lockInventoryOnAccept()` dari FG-35 (Sprint 5, kamu sendiri) — jangan tulis ulang logic locking.

## Task Checklist

### FG-24 — pg_cron auto-expire negotiation 6 jam
- [ ] Job cek `negotiations` `OPEN`/`COUNTERED` dengan `expires_at` terlewati
- [ ] Set status `EXPIRED`, `listings.quantity_available` tidak perlu di-rollback (belum pernah dikurangi untuk status ini)
- [ ] Kirim notifikasi ke kedua pihak — integrasi FCM belum perlu kamu wire sekarang, cukup siapkan hook/event yang bisa dipanggil nanti
- [ ] Log eksekusi job terpisah (§12 Observability)

### FG-29 — POST /listings/:id/buy-now endpoint
- [ ] `POST /listings/:id/buy-now`: `{ quantity, note? }` → `{ negotiation_id, transaction_id, status:'pending', total_amount }`
- [ ] Buat record `negotiations` (status `ACCEPTED`, `initial_price=current_offer_price=price_per_unit`, `counter_count=0`, **tanpa** `negotiation_messages` dari buyer) DAN `transaction PENDING` dalam **satu transaksi database atomik**
- [ ] Reuse `lockInventoryOnAccept()` dari FG-35 (Sprint 5) — jangan tulis ulang logic locking
- [ ] 400 jika `quantity > quantity_available` atau `listing.status != active`; 404 jika listing tidak ditemukan
- [ ] TIDAK termasuk: kolom/tabel ERD baru (dilarang eksplisit §8)
- [ ] Pastikan bisa dibedakan dari negosiasi manual lewat query: `ACCEPTED` tanpa `negotiation_messages` sebelumnya

## File/folder yang kamu sentuh
```
supabase/functions/expire-negotiations/**  (FG-24)
supabase/functions/buy-now/**  (FG-29)
```

## Sync point dengan teammate
- **Begitu FG-29 selesai**: kabari Fachri — FG-30 (Buy Now UI, Sprint 7) bisa mulai wiring data asli.

## Definition of Done
- [ ] Negotiation `OPEN`/`COUNTERED` > 6 jam otomatis jadi `EXPIRED` — **cara cek**: manual trigger job, atau set `expires_at` mundur untuk test
- [ ] Buy Now dari listing valid → `negotiation` ACCEPTED (skip OPEN) + `transaction` PENDING terbentuk atomik — **cara cek**: query `negotiations` pastikan tidak ada `negotiation_messages` terkait
- [ ] `quantity > stok` atau listing tidak `active` → 400, tidak ada record terbentuk sama sekali (test atomicity)

## Referensi PRD
§3.1, §5.1, §8, §9, §10.5, §11, §12.
