# Sprint 6 — Dokumentasi Nevan (FG-24 expire + FG-29 Buy Now)

**Tanggal:** 16 Juli 2026  
**Status:** ✅ Selesai  
**Branch:** `nevan_dev`

---

## Ringkasan

Dua fitur: auto-expire negotiation (6 jam) via pg_cron, dan Buy Now endpoint untuk pembelian langsung tanpa negosiasi.

---

## Deliverables

| Item | Detail |
|---|---|
| pg_cron `expire-negotiations` | Logic asli: UPDATE OPEN/COUNTERED → EXPIRED setiap 5 menit |
| Edge Function `buy-now` | v2 ACTIVE — POST /listings/:id/buy-now |
| `supabase/functions/buy-now/index.ts` | Buy Now function + inline inventory locking |

---

## FG-24 — Auto-Expire Negotiation

### Yang Diubah
- Job `expire-negotiations` (Sprint 2 skeleton) diganti dari log "skipped" ke query expire asli
- Schedule: setiap 5 menit
- Log: `cron_execution_log` — sekarang catat jumlah negosiasi expired

### Test Results

| AC | Skenario | Hasil |
|---|---|---|
| OPEN >6 jam → EXPIRED | Manual trigger dengan mock expires_at | ✅ Status berubah EXPIRED |
| ACCEPTED tidak terpengaruh | Accepted negotiations tetap accepted | ✅ |
| Listing bisa dinegosiasi lagi | Listing tetap active setelah expire | ✅ |

---

## FG-29 — Buy Now

### Endpoint
```
POST /listings/:id/buy-now
{ quantity, buyer_id, note? }
→ { negotiation_id, transaction_id, status:'pending', total_amount }
```

### Flow
1. Validasi listing (404/400)
2. Buat negotiation dengan status='accepted' langsung (skip OPEN)
3. counter_count = 0, expires_at = null
4. TANPA negotiation_messages
5. Lock inventory → buat transaction PENDING

### Test Results

| AC | Skenario | Hasil |
|---|---|---|
| Buy Now valid | qty=30 | ✅ 200 + ACCEPTED + PENDING |
| Quantity > stock | qty=999 | ✅ 400 "Stok tidak cukup" |
| Listing not found | invalid ID | ✅ 404 |
| Tanpa messages | Cek negotiation_messages | ✅ 0 |
| Bisa dibedakan | ACCEPTED + NOT EXISTS messages | ✅ |

---

## Evidence

| Item | Detail |
|---|---|
| expire job | `cron.job` schedule 3, aktif |
| buy-now function | v2 ACTIVE |
| cron_execution_log | Sudah bukan "skipped" |
