# Plan Sprint 4 — Nevan (FG-18 Edge Function trust_metrics)

**Referensi:** PRD §2.3, §9, §12 | JIRA FG-18 | `sprint4_nevan_dev.md`

---

## Prasyarat
- [x] Ambil Supabase URL (`rwxnjxmzkcfoddnzjosi.supabase.co`)
- [x] Ambil `service_role` key (pakai publishable key `sb_publishable_...` untuk anon, service_role untuk bypass RLS)

## Fase 1 — Tulis Edge Function

**File:** `supabase/functions/update-trust-metrics/index.ts`

Logic:
```
POST /update-trust-metrics
Body: { farmer_id: string }

1. Terima POST dengan { farmer_id }
2. Query ke transactions (service_role, bypass RLS):
   - WHERE farmer_id = $farmer_id
   - WHERE status IN ('fulfilled', 'rejected')  
   - WHERE created_at >= NOW() - 90 days
3. Hitung 3 metrik:
   - total_fulfilled = count(status='fulfilled')
   - on_time = count(fulfilled & actual_delivery_date <= promised_delivery_date)
   - on_time_delivery_rate = (on_time / total_fulfilled) * 100
   
   - total_rejected = count(status='rejected')
   - total_pending_ever = count(all transactions)
   - rejection_rate = (total_rejected / total_pending_ever) * 100
   
   - konsisten = count(fulfilled & delivered_quantity = agreed_quantity)
   - fulfillment_consistency = (konsisten / total_fulfilled) * 100
4. UPSERT ke trust_metrics (window_days=90)
5. Return JSON { on_time_delivery_rate, rejection_rate, fulfillment_consistency }
```

## Fase 2 — Deploy
- [x] Deploy via MCP `supabase_deploy_edge_function`
- [x] `verify_jwt = false` (internal function, tidak perlu JWT verification)

## Fase 3 — Insert Dummy Data
- [x] Buat 1 dummy farmer (user + farmer_profile)
- [x] Buat 1 dummy buyer (user + buyer_profile)
- [x] Insert 4 transactions untuk test:
  1. T1: fulfilled, tepat waktu, kuantitas pas
  2. T2: fulfilled, tepat waktu, kuantitas pas
  3. T3: fulfilled, TELAT (actual > promised)
  4. T4: rejected

## Fase 4 — Test 4 Skenario
- [x] **Tes 1:** Panggil function setelah T1+T2+T3+T4 → (66.67%, 25%, 100%) ✅
- [x] **Tes 2:** Tambah partial delivery → consistency turun ke 75% ✅
- [x] **Tes 3:** Data > 90 hari lalu → tidak pengaruh, hasil tetap ✅
- [x] **Tes 4:** Farmer tanpa transaksi → all zero ✅

## Fase 5 — Update Checklist
- [x] Update `sprint4_nevan_dev.md` checklist → `[x]`

## Fase 6 — Dokumentasi
- [x] Buat `dokumentasi_sprint4_nevan_dev.md`
