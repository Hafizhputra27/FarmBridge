# Plan Sprint 5 — Nevan (FG-22 + FG-58 + FG-35)

**Referensi:** PRD §5, §5.1, §9, §11 | JIRA FG-22, FG-35 | `sprint5_nevan_dev.md` | `plan_sprint3_nevan.md` (draft)

---

## Prasyarat
- [x] FG-2 migration (tabel `negotiations`, `negotiation_messages`, `transactions`, `listings`)
- [x] FG-3 RLS (participant-only policies)
- [x] FG-7 seed `price_reference_data` (18 baris)
- [x] Draft pseudocode FG-22 (`plan_sprint3_nevan.md`)
- [x] `getRecommendedPrice()` source dari Supabase server

## Fase 0 — Setup Shared Module
- [x] Buat `supabase/functions/_shared/price-recommendation.ts` (dari Hafizh, hasil merge)
- [x] Buat `supabase/functions/_shared/inventory-locking.ts` (FG-35 — fungsi locking reusable)

---

## Fase 1 — FG-22: POST /negotiations

**File:** `supabase/functions/negotiations/index.ts`

**Request:** `{ listing_id, buyer_id, initial_price, quantity }`

**Logic:**
```
1. Validasi: initial_price > 0, quantity > 0
2. Cek listing: SELECT * FROM listings WHERE id = listing_id
   - 404 jika tidak ada
   - 400 jika status != 'active'
   - 400 jika quantity > quantity_available
3. Ampli recommended_price via getRecommendedPrice(category, region)
4. expires_at = NOW() + 6 jam
5. INSERT negotiations: listing_id, buyer_id, farmer_id (dari listing), initial_price, current_offer_price, recommended_price, expires_at, status='open'
6. Return { negotiation_id, recommended_price, status:'open', expires_at }
```

**Note:** quantity_available TIDAK berkurang di sini. Hanya saat ACCEPTED.

---

## Fase 2 — FG-22: POST /negotiations/:id/messages (State Machine)

**File:** `supabase/functions/negotiations/messages.ts`

**Request:** `{ sender_id, message_text?, offer_price?, action_type }`
**action_type:** `counter` | `accept` | `decline` | `message`

**Logic:**
```
1. Cek negotiation: SELECT * WHERE id = :id
   - 404 jika tidak ada
   - 409 jika status IN ('accepted','declined','expired')

2. Validasi "pihak penerima" untuk counter/accept/decline:
   function getLastSender(neg):
     lastMsg = SELECT sender_id FROM negotiation_messages
               WHERE negotiation_id = neg.id ORDER BY created_at DESC LIMIT 1
     return lastMsg?.sender_id ?? neg.buyer_id
  
   Jika action_type IN ('counter','accept','decline'):
     Jika sender_id == getLastSender(neg) → 403 "Hanya pihak penerima yang bisa"

3. Insert negotiation_messages: negotiation_id, sender_id, action_type, message_text, offer_price

4. Update state:
   IF action_type == 'counter':
     UPDATE negotiations SET status='COUNTERED', current_offer_price=offer_price, counter_count=counter_count+1
   
   IF action_type == 'accept':
     -- Panggil FG-35 untuk atomic locking
     lockInventoryOnAccept(negotiation_id) → buat transaction PENDING
     UPDATE negotiations SET status='ACCEPTED'
   
   IF action_type == 'decline':
     UPDATE negotiations SET status='DECLINED'

5. Return { message_id, negotiation_status }
```

### State Transitions

| Current | Action | Next | Efek |
|---|---|---|---|
| OPEN | counter | COUNTERED | current_offer_price, counter_count++ |
| OPEN | accept | ACCEPTED | → lockInventoryOnAccept → transaction PENDING |
| OPEN | decline | DECLINED | Permanen tertutup |
| COUNTERED | counter | COUNTERED | current_offer_price, counter_count++ |
| COUNTERED | accept | ACCEPTED | → lockInventoryOnAccept → transaction PENDING |
| COUNTERED | decline | DECLINED | Permanen tertutup |
| (any) | message | (tetap) | Hanya chat, tidak ubah status |

---

## Fase 3 — FG-58: GET /negotiations (Chat Inbox)

**File:** `supabase/functions/negotiations/list.ts`

**Request:** `GET /negotiations?status=open,countered`

**Logic:**
```
1. Parse query param status (opsional)
2. Gunakan auth.uid() via token → user_id
3. Query: SELECT * FROM negotiations
          WHERE (buyer_id = user_id OR farmer_id = user_id)
          [AND status IN (filter)]
          ORDER BY updated_at DESC
4. Return array
```

---

## Fase 4 — FG-22: GET /negotiations/:id (Detail)

**File:** `supabase/functions/negotiations/detail.ts`

**Logic:**
```
1. Cek negotiation + join listing + farmer_profile + buyer_profile
2. 403 jika auth.uid() bukan buyer_id/farmer_id
3. Ambil negotiation_messages ORDER BY created_at ASC
4. Return { negotiation detail + messages[] }
```

---

## Fase 5 — FG-35: Inventory Locking (Shared Module)

**File:** `supabase/functions/_shared/inventory-locking.ts`

**Fungsi 1 — lockInventoryOnAccept:**
```
function lockInventoryOnAccept(supabase, negotiation_id):
  -- Atomic: kurangi qty + cek stok + buat transaction dalam 1 transaksi
  
  Panggil RPC / SQL transaction:
  1. neg = SELECT listing_id, farmer_id, buyer_id, current_offer_price, quantity_requested 
           FROM negotiations WHERE id = negotiation_id
  2. UPDATE listings SET quantity_available = quantity_available - neg.quantity_requested
     WHERE id = neg.listing_id AND quantity_available >= neg.quantity_requested
     RETURNING id
  3. If no row → 409 "Stok tidak mencukupi (first-accepted-wins)"
  4. tx = INSERT transactions (negotiation_id, farmer_id, buyer_id, 
          agreed_quantity=neg.quantity_requested, total_amount=neg.quantity_requested*neg.current_offer_price,
          promised_delivery_date=NULL, status='pending')
  5. Return { transaction_id, listing_id }
```

**Fungsi 2 — releaseInventoryOnReject:**
```
function releaseInventoryOnReject(supabase, transaction_id):
  tx = SELECT agreed_quantity, negotiation_id FROM transactions WHERE id = transaction_id
  neg = SELECT listing_id FROM negotiations WHERE id = tx.negotiation_id
  UPDATE listings SET quantity_available = quantity_available + tx.agreed_quantity
  WHERE id = neg.listing_id
```

---

## Fase 6 — Deploy Semua Edge Functions

- [x] `negotiations` — 1 fungsi dengan 4 endpoint (create, messages, detail, list)
- [x] Deployed as v4 ACTIVE, verify_jwt: true

---

## Fase 7 — Test 6 Skenario AC

### Data Test
- [x] Insert dummy farmer + buyer + listing (quantity_available=200)
- [x] Insert 2 nego paralel untuk listing sama

### Skenario

| # | AC JIRA | Tes |
|---|---|---|
| 1 | Quantity > stock → 400 | POST nego dengan qty=300 > stock=200 |
| 2 | Counter → COUNTERED + counter_count+1 | Buyer kirim counter via POST messages |
| 3 | Farmer accept (penerima) → PENDING + qty berkurang | Farmer accept setelah buyer counter |
| 4 | Buyer accept sendiri → 403 | Buyer (pengirim counter) coba accept |
| 5 | Race condition 2 nego paralel → 409 first-accepted-wins | Nego-1 di-accept, nego-2 dicoba accept → gagal |
| 6 | Transaction REJECTED → qty rollback | releaseInventoryOnReject → qty kembali |

---

## Fase 8 — Update Checklist + Dokumentasi

- [x] Update `sprint5_nevan_dev.md` checklist → `[x]`
- [x] Buat `dokumentasi_sprint5_nevan_dev.md`
