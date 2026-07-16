# Plan Sprint 7 — Nevan (FG-32 POST /transactions/:id/fulfill)

**Referensi:** PRD §4.1, §5.1, §9, §10.5, §11 | JIRA FG-32 | `sprint7_nevan_dev.md`

---

## Prasyarat
- [x] FG-18 update-trust-metrics (v1 ACTIVE)
- [x] FG-22/29 transactions PENDING exist di database
- [x] JWT anonymous auth ready

## Fase 1 — Tulis Edge Function

**File:** `supabase/functions/transactions-fulfill/index.ts`

**Endpoint:** `POST /transactions/:id/fulfill`

**Request:** `{ delivered_quantity, actual_delivery_date }`

**Logic:**
```
1. Extract transaction_id from URL path
2. Verifikasi JWT → user_id
3. Query transaction WHERE id = :id
   - 404 jika tidak ada
   - 403 jika farmer_id != user_id
   - 409 jika status != 'pending'
4. Set anomaly_flag = delivered_quantity > agreed_quantity
5. UPDATE transaction:
   - delivered_quantity, actual_delivery_date
   - status = 'fulfilled'
   - anomaly_flag
6. Panggil POST /functions/v1/update-trust-metrics { farmer_id } (service_role)
7. Return { transaction_id, status:'fulfilled', trust_metrics_updated:true }
```

**Checklist:**
- [x] Tulis `index.ts` — validasi + update + panggil trust-metrics
- [x] Deploy via MCP `supabase_deploy_edge_function` (verify_jwt=true)

## Fase 2 — Test 3 AC JIRA

- [x] **AC 1:** Farmer fulfill transaksi sendiri → 200 + fulfilled + trust_metrics_updated
- [x] **AC 2:** Buyer coba fulfill → 403
- [x] **AC 3:** delivered > agreed → anomaly_flag=true, tetap fulfilled

## Fase 3 — Update Checklist + Dokumentasi
- [x] Update `sprint7_nevan_dev.md` checklist → `[x]`
- [x] Buat `dokumentasi_sprint7_nevan_dev.md`
