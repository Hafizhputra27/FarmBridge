# Plan Sprint 3 — Nevan (Draft Pseudocode State Machine FG-22)

**Referensi:** PRD §5, §5.1, §9, §11 | `sprint3_nevan_dev.md` | `sprint5_nevan_dev.md`

---

## DoD Sprint 3

- [x] Tidak ada isu schema/RLS menghambat FG-7/FG-11
- [x] Draft pseudocode state machine FG-22 — siap jadi starting point Sprint 5

---

## 1. POST /negotiations

**Endpoint:** `POST /negotiations`

**Request:**
```json
{
  "listing_id": "uuid",
  "buyer_id": "uuid",
  "initial_price": 35000,
  "quantity": 100
}
```

**Pseudocode:**
```
function createNegotiation(req):
  // 1. Validasi input
  if initial_price <= 0 → 400 "Harga harus > 0"
  if quantity <= 0 → 400 "Quantity harus > 0"

  // 2. Cek listing tersedia
  listing = SELECT * FROM listings WHERE id = listing_id
  if not listing → 404 "Listing tidak ditemukan"
  if listing.status != 'active' → 400 "Listing tidak aktif"
  if quantity > listing.quantity_available → 400 "Stok tidak cukup"

  // 3. Ambil recommended_price dari Hafizh (shared function)
  recommended_price = getRecommendedPrice(listing.category, listing.region, quantity)

  // 4. Hitung expiry (6 jam)
  expires_at = NOW() + 6 hours

  // 5. Insert negotiation
  negotiation = INSERT INTO negotiations (
    listing_id, buyer_id, farmer_id,
    initial_price, current_offer_price,
    recommended_price, expires_at,
    status  // default 'open'
  ) VALUES ($1, $2, listing.farmer_id, $3, $3, $4, $5, 'open')
  RETURNING *

  // Note: quantity_available TIDAK berkurang saat OPEN
  // Hanya berkurang saat ACCEPTED (lihat §5 Inventory Locking)

  // 6. Return
  return {
    negotiation_id: negotiation.id,
    recommended_price,
    status: 'open',
    expires_at
  }
```

---

## 2. Prinsip "Pihak Penerima"

**Aturan inti (§5.1):**
Pihak yang **TIDAK** mengirim `initial_price`/`current_offer_price` terakhir = pihak penerima yang berhak Accept/Decline/Counter.

**Pseudocode:**
```
function getLastSender(negotiation_id):
  last_message = SELECT sender_id FROM negotiation_messages
                 WHERE negotiation_id = $1
                 ORDER BY created_at DESC LIMIT 1

  if last_message exists:
    return last_message.sender_id
  else:
    // Belum ada message → pengirim = buyer (pengirim initial_price pertama)
    neg = SELECT buyer_id FROM negotiations WHERE id = $1
    return neg.buyer_id

function isRecipient(negotiation_id, user_id):
  last_sender = getLastSender(negotiation_id)
  return user_id != last_sender
```

---

## 3. POST /negotiations/:id/messages

**Request:**
```json
{
  "sender_id": "uuid",
  "message_text": "Bisa kurang?",
  "offer_price": 30000,
  "action_type": "counter"
}
```

**action_type:** `counter` | `accept` | `decline` | `message`

**Pseudocode:**
```
function sendMessage(negotiation_id, req):
  // 1. Cek negotiation
  neg = SELECT * FROM negotiations WHERE id = negotiation_id
  if not neg → 404
  if neg.status IN ('accepted', 'declined', 'expired') → 409 "Negosiasi sudah selesai"

  // 2. Validasi "pihak penerima" untuk counter/accept/decline
  if action_type IN ('counter', 'accept', 'decline'):
    if NOT isRecipient(negotiation_id, sender_id):
      → 403 "Hanya pihak penerima yang bisa melakukan aksi ini"

  // 3. Insert message
  msg = INSERT INTO negotiation_messages (
    negotiation_id, sender_id, action_type,
    message_text, offer_price
  ) VALUES ($1, $2, $3, $4, $5) RETURNING *

  // 4. Update negotiation sesuai action_type
  new_status = neg.status

  if action_type == 'counter':
    new_status = 'COUNTERED'
    UPDATE negotiations SET
      current_offer_price = offer_price,
      counter_count = counter_count + 1,
      status = new_status
    WHERE id = negotiation_id

  elsif action_type == 'accept':
    new_status = 'ACCEPTED'
    UPDATE negotiations SET status = new_status WHERE id = negotiation_id
    // Panggil inventory locking
    lockInventoryOnAccept(negotiation_id)  // lihat §5

  elsif action_type == 'decline':
    new_status = 'DECLINED'
    UPDATE negotiations SET status = new_status WHERE id = negotiation_id

  // 5. Return
  return {
    message_id: msg.id,
    negotiation_status: new_status
  }
```

---

## 4. State Transitions (PRD §5.1)

```
                    ┌─────────────┐
                    │    OPEN     │
                    └──────┬──────┘
           ┌───────────────┼───────────────┐
           ▼               ▼               ▼
    ┌──────────┐   ┌──────────────┐  ┌─────────┐
    │ ACCEPTED │   │  COUNTERED   │  │DECLINED │
    └────┬─────┘   └──────┬───────┘  └─────────┘
         │          ┌─────┼─────┐         ⛔ permanen
         ▼          ▼     ▼     ▼
  ┌──────────┐ ACCEPT DECLINE COUNTER
  │ PENDING  │          │
  │(tran-    │     ⛔ permanen
  │ saction) │
  └────┬─────┘
       │
  ┌────┼────┐
  ▼         ▼
FULFILLED REJECTED
  │         │
  │    ┌────┴──────┐
  │    │ rollback   │
  │    │ inventory  │
  │    └───────────┘
  │
  └──► update trust_metrics

Semua state bisa → EXPIRED (6 jam tanpa respons, via cron FG-24)
```

---

## 5. Inventory Locking (FG-35)

**Fungsi reusable:**

```
function lockInventoryOnAccept(negotiation_id):
  BEGIN TRANSACTION
    neg = SELECT listing_id, quantity_requested FROM negotiations WHERE id = $1

    // Atomic: kurangi quantity DAN cek stok cukup
    result = UPDATE listings
             SET quantity_available = quantity_available - quantity_requested
             WHERE id = neg.listing_id
             AND quantity_available >= quantity_requested
             RETURNING quantity_available

    if no row updated:
      ROLLBACK
      → 409 "Stok tidak cukup (mungkin sudah diambil transaksi lain)"

    // Buat transaction PENDING
    INSERT INTO transactions (
      negotiation_id, farmer_id, buyer_id,
      agreed_quantity, total_amount,
      promised_delivery_date, status
    ) VALUES (
      $1, neg.farmer_id, neg.buyer_id,
      quantity_requested, current_offer_price * quantity_requested,
      NULL, 'pending'  // promised_delivery_date diisi saat nego accept
    )

  COMMIT

function releaseInventoryOnReject(transaction_id):
  tx = SELECT negotiation_id, agreed_quantity FROM transactions WHERE id = $1
  neg = SELECT listing_id FROM negotiations WHERE id = tx.negotiation_id

  UPDATE listings
  SET quantity_available = quantity_available + tx.agreed_quantity
  WHERE id = neg.listing_id
```

**Race condition — first-accepted-wins (§11):**
```
Given: listing A punya quantity_available = 100
  Buyer 1 & Buyer 2 kirim negosiasi bersamaan untuk quantity 80

Scenario 1: Buyer 1 accepted duluan
  → lockInventoryOnAccept berhasil, quantity_available = 20
  → Buyer 2 coba accept → UPDATE listings WHERE quantity_available >= 80 FAILS
  → Return 409 "Stok tidak cukup"

Scenario 2: Transaction REJECTED
  → releaseInventoryOnReject dijalankan
  → quantity_available kembali ke 100
```

---

## 6. GET /negotiations (FG-58 — Chat Inbox)

**Request:** `GET /negotiations?status=open,countered`

**Pseudocode:**
```
function listNegotiations(user_id, status_filter):
  query = SELECT * FROM negotiations
          WHERE (buyer_id = user_id OR farmer_id = user_id)

  if status_filter:
    query += AND status IN (status_filter)

  query += ORDER BY updated_at DESC

  // RLS dari Sprint 2 otomatis memfilter — no need manual guard
  return query_result
```

---

## 7. File Mapping untuk Sprint 5

| File | Fungsi |
|---|---|
| `supabase/functions/negotiations/index.ts` | POST /negotiations (FG-22) |
| `supabase/functions/negotiations/messages.ts` | POST /negotiations/:id/messages (FG-22) |
| `supabase/functions/negotiations/detail.ts` | GET /negotiations/:id (FG-22) |
| `supabase/functions/negotiations/list.ts` | GET /negotiations (FG-58) |
| `supabase/functions/_shared/inventory-locking.ts` | lockInventoryOnAccept + releaseInventoryOnReject (FG-35) |
| `supabase/functions/_shared/price-recommendation.ts` | Import getRecommendedPrice() dari Hafizh |

---

## Catatan untuk Sprint 5

- Buy Now (FG-29, Sprint 6) — desain function harus support loncat langsung ACCEPTED tanpa OPEN
- Expired (FG-24, Sprint 6) — pg_cron job akan auto-set status EXPIRED + release inventory
- Trust metrics update — dipanggil setelah FULFILLED/REJECTED (FG-18 dari Sprint 4)
- Semua validasi "pihak penerima" WAJIB backend — jangan andalkan UI guard saja
