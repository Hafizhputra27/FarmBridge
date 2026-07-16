# Sprint 5 — Dokumentasi Nevan (FG-22 + FG-58 + FG-35)

**Tanggal:** 16 Juli 2026  
**Status:** ✅ Selesai  
**Branch:** `nevan_dev`  
**Function:** `negotiations` v4 ACTIVE

---

## Ringkasan

Implementasi penuh lifecycle negosiasi FarmBridge — dari pembuatan, state machine (counter/accept/decline), inventory locking atomik, hingga chat inbox list. Semua dalam 1 Edge Function dengan routing internal.

---

## Deliverables

| File | Fungsi |
|---|---|
| `supabase/functions/negotiations/index.ts` | 4 endpoint (POST create + POST messages + GET detail + GET list) |
| `supabase/functions/_shared/inventory-locking.ts` | lockInventoryOnAcceptWithQuantity + releaseInventoryOnReject |
| `supabase/migrations/add_quantity_column` | ALTER TABLE negotiations ADD COLUMN quantity |

---

## 4 Endpoint

| Method | Path | Deskripsi |
|---|---|---|
| POST | `/negotiations` | Buat negosiasi baru + validasi + recommended_price |
| POST | `/negotiations/:id/messages` | State machine (counter/accept/decline/message) |
| GET | `/negotiations/:id` | Detail negosiasi + messages[] |
| GET | `/negotiations?status=open,countered` | Chat inbox list (FG-58) |

---

## State Machine (PRD §5.1)

| Transition | Trigger | Efek |
|---|---|---|
| → OPEN | POST /negotiations | expires_at = NOW + 6h, recommended_price |
| OPEN → COUNTERED | counter | current_offer_price updated, counter_count++, last_sender tracked |
| OPEN/COUNTERED → ACCEPTED | accept | lockInventory → transaction PENDING, qty berkurang |
| OPEN/COUNTERED → DECLINED | decline | Permanen tertutup |
| (any) → message | message | Chat-only, no state change |

### "Pihak Penerima" Rule
- Yang bukan pengirim last message = pihak penerima
- Hanya pihak penerima yang bisa counter/accept/decline
- Validasi di backend, bukan UI-only

---

## Inventory Locking (FG-35)

- **lockInventoryOnAcceptWithQuantity**: atomic check `quantity_available >= quantity` → deduct → buat transaction
- **releaseInventoryOnReject**: rollback qty ke listing
- **First-accepted-wins**: 2 nego paralel → yang pertama accepted menang, kedua gagal 409

---

## Test Results (6 AC JIRA)

| AC | Skenario | Hasil |
|---|---|---|
| 1 | qty=300 > stock=200 | 400 "Stok tidak cukup" |
| 2 | Farmer counter | COUNTERED, counter_count=1, price 35k→38k |
| 3 | Buyer accept (penerima) | ACCEPTED + transaction PENDING + qty 200→150 |
| 4 | Farmer accept sendiri | 403 "Hanya pihak penerima" |
| 5 | 2 nego paralel, first-accepted-wins | Nego-2 gagal 409 "Stok tidak mencukupi" |
| 6 | Reject → rollback | qty 50→150 kembali |

---

## Evidence

| Item | Detail |
|---|---|
| Edge Function | `negotiations` v4, ACTIVE |
| Migration | ALTER TABLE negotiations ADD COLUMN quantity |
| AC results | 6/6 lulus |

---

## Catatan untuk Sprint 6

- **FG-24 (expire):** pg_cron skeleton di Sprint 2 sudah siap — tinggal implementasi logic expire di job `expire-negotiations`
- **FG-29 (Buy Now):** bisa reuse `lockInventoryOnAcceptWithQuantity()` dari FG-35
- **FG-25/26 (Chat UI):** Fachri bisa langsung wiring ke endpoint asli
- **releaseInventoryOnReject:** siap dipakai FG-33 (Sprint 7)
