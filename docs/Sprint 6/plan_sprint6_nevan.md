# Plan Sprint 6 — Nevan (FG-24 auto-expire + FG-29 Buy Now)

**Referensi:** PRD §3.1, §5.1, §8, §9, §11 | JIRA FG-24, FG-29 | `sprint6_nevan_dev.md`

---

## Prasyarat
- [x] FG-4 pg_cron skeleton (2 job setiap 5 menit + setiap jam 8 pagi)
- [x] FG-22 state machine (negotiations v4 ACTIVE)
- [x] FG-35 inventory locking (`lockInventoryOnAcceptWithQuantity`, `releaseInventoryOnReject`)

---

## Fase 1 — FG-24: Update pg_cron expire-negotiations

### Yang dilakukan
- Ganti logic skeleton job `expire-negotiations` dengan query asli
- Update via SQL: `SELECT cron.alter_job(...)` atau `drop_schedule` + `schedule` ulang

### Query job:
```sql
UPDATE negotiations SET status = 'EXPIRED'
WHERE status IN ('open', 'countered') 
AND expires_at < NOW()
AND status NOT IN ('accepted', 'declined', 'expired');

INSERT INTO cron_execution_log (job_name, status, message)
VALUES ('expire-negotiations', 'success', 
  CONCAT(COUNT(*) filter from UPDATE, ' negosiasi expired'));
```

### Checklist
- [x] Update job `expire-negotiations` dengan query expire asli
- [x] Job tetap berjalan tiap 5 menit
- [x] Log ke `cron_execution_log` dengan status aktual (bukan "skipped" lagi)

---

## Fase 2 — FG-29: Edge Function buy-now

### File: `supabase/functions/buy-now/index.ts`

### Endpoint: `POST /listings/:id/buy-now`

**Request:** `{ quantity, note? }`

**Logic:**
```
1. Extract listing_id from URL path
2. Validasi: quantity > 0
3. Query listing: SELECT * WHERE id = listing_id
   - 404 jika tidak ada
   - 400 jika status != 'active'
   - 400 jika quantity > quantity_available
4. Buat negotiation dengan status ACCEPTED langsung:
   - initial_price = current_offer_price = listing.harga_per_unit
   - counter_count = 0
   - TANPA negotiation_messages
   - expires_at = NULL (Buy Now tidak pernah expire)
   - quantity = request.quantity
5. Panggil lockInventoryOnAcceptWithQuantity() (FG-35)
   - Kurangi quantity_available
   - Buat transaction PENDING
   - Jika gagal → 409
6. Return { negotiation_id, transaction_id, status:'pending', total_amount }
```

### Checklist
- [x] Buat `supabase/functions/buy-now/index.ts`
- [x] Deploy sebagai Edge Function `buy-now` (verify_jwt=true)
- [x] Test: quantity > stock → 400
- [x] Test: listing not active → 400
- [x] Test: listing not found → 404
- [x] Test: Buy Now sukses → 200 + negotiation ACCEPTED + transaction PENDING
- [x] Verifikasi: tidak ada negotiation_messages terbuat
- [x] Verifikasi: bisa dibedakan dari negosiasi manual via query

---

## Fase 3 — Verifikasi

### FG-24
- [x] Test: set expires_at = NOW()-1jam pada nego OPEN → status jadi EXPIRED setelah cron
- [x] Test: nego ACCEPTED tidak terpengaruh
- [x] Cek log `cron_execution_log` — sudah bukan "skipped" lagi

### FG-29
- [x] Buy Now valid → ACCEPTED + PENDING + inventory berkurang
- [x] Quantity > stock → 400 "Stok tidak cukup"
- [x] Listing not active → 400 "Listing tidak aktif"
- [x] Listing not found → 404
- [x] Atomic: semua sukses atau semua gagal

## Fase 4 — Update Checklist + Dokumentasi
- [x] Update `sprint6_nevan_dev.md` checklist → `[x]`
- [x] Buat `dokumentasi_sprint6_nevan_dev.md`
