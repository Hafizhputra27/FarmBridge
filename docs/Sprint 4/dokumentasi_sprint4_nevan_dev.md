# Sprint 4 — Dokumentasi Nevan (FG-18 Edge Function trust_metrics)

**Tanggal:** 16 Juli 2026  
**Status:** ✅ Selesai  
**Branch:** `nevan_dev`  
**Function:** `update-trust-metrics` (v1, ACTIVE)

---

## Ringkasan

Edge Function Deno yang menghitung Trust Score 3 dimensi untuk farmer berdasarkan data transaksi riil. Dipanggil via HTTP POST, menggunakan Supabase client dengan `service_role` untuk bypass RLS. Formula sesuai PRD §2.3, rolling window 90 hari.

---

## Deliverables

| File | Detail |
|---|---|
| `supabase/functions/update-trust-metrics/index.ts` | Edge Function — hitung 3 metrik + UPSERT trust_metrics |
| Deployed: `https://rwxnjxmzkcfoddnzjosi.supabase.co/functions/v1/update-trust-metrics` | Status: ACTIVE |

---

## 3 Metrik (PRD §2.3)

| Metrik | Formula | Rolling |
|---|---|---|
| `on_time_delivery_rate` | fulfilled & `actual ≤ promised` / total fulfilled × 100% | 90 hari |
| `rejection_rate` | rejected / total pending × 100% | 90 hari |
| `fulfillment_consistency` | fulfilled & `delivered = agreed` / total fulfilled × 100% | 90 hari |

---

## Hasil Test

| Tes | Skenario | Result | Status |
|---|---|---|---|
| 1 | 3 fulfilled (2 on-time, 1 late) + 1 rejected | 66.67% / 25% / 100% | ✅ |
| 2 | +1 partial delivery (delivered=80, agreed=100) | 75% / 20% / 75% | ✅ |
| 3 | +1 transaksi Januari (>90 hari lalu) | 75% / 20% / 75% (tidak berubah) | ✅ |
| 4 | Farmer tanpa transaksi | 0% / 0% / 0% | ✅ |

---

## Evidence

| Item | Hasil |
|---|---|
| Function deployed | v1, ACTIVE, verify_jwt=false |
| Data tersimpan di `trust_metrics` | Verified via SQL query |
| 4 AC dari JIRA | Semua terpenuhi |
| File di `supabase/functions/` | `update-trust-metrics/index.ts` |

---

## Catatan

- **Belum ada trigger asli** — perubahan status `fulfilled`/`rejected` baru di Sprint 6-7. Function sudah siap dipanggil kapan saja.
- **Dipanggil via:** `POST /functions/v1/update-trust-metrics` dengan body `{ farmer_id }`
- **Untuk Sprint 5:** Hafizh (FG-20 `GET /trust-metrics/:id`) bisa langsung query tabel `trust_metrics` — sudah terisi
- **Untuk Sprint 7:** Function ini akan dipanggil sebagai trigger setelah `transactions` status berubah fulfilled/rejected
