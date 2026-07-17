# Sprint 10: Integration & E2E Testing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Selesaikan 5 ticket Sprint 10 (`sprint10_README.md`) — semuanya E2E testing/verifikasi, **bukan** pembangunan fitur baru: FG-44 (pipeline negosiasi→transaksi→trust_metrics), FG-45 (latensi realtime chat), FG-46 (Buy Now + race condition), FG-47 (recurring order full cycle), FG-48 (checklist 9 edge case §11).

**Architecture:** Semua fitur yang diuji sudah dibangun (Sprint 1-9) — sprint ini murni menjalankan skenario, mengumpulkan bukti (query SQL, response curl, log), dan menuliskannya ke `docs/qa/*.md` sesuai lokasi yang sudah ditentukan tim di checklist masing-masing. Beberapa skenario **sudah punya bukti** dari sesi QA Sprint 7-9 (dicatat eksplisit per task, tinggal dirujuk/dikonsolidasi) — beberapa **benar-benar baru** (race condition, latensi realtime, cancel-mid-cycle, auto-expire, edge case §11 baris 3/6/8).

**Tech Stack:** curl, SQL langsung (Supabase), 1 script Deno kecil untuk FG-45 (subscribe Realtime, ukur latensi) — tidak ada kode aplikasi baru.

## Global Constraints

- **Jangan pernah menjalankan `git add`/`commit`/`push`/`merge`/dll** — `docs/CLAUDE.md` melarang keras.
- Sprint ini **tidak menyentuh kode aplikasi** kecuali kalau testing menemukan bug nyata yang perlu diperbaiki (pola yang sudah terjadi berulang di Sprint 7-9) — kalau itu terjadi, ikuti pola yang sama: tandai temuan, minta konfirmasi sebelum fix, dokumentasikan di laporan.
- Semua dokumen QA Bahasa Indonesia, format tabel/checklist konsisten dengan `sprint10_hafizh_dev.md`/`sprint10_nevan_dev.md`/`sprint10_fachri_dev.md`.
- Test yang memodifikasi data production (accept, fulfill, reject, buy-now, cancel recurring order) pakai data test yang sudah ada dari Sprint 7-9 kalau relevan, atau bikin baru — **jangan** sentuh data user asli/non-test.

## Koreksi penting dari checklist lama (baca sebelum mulai FG-48)

`sprint10_README.md`/`sprint10_nevan_dev.md` menulis edge case **baris 8** (archive listing dengan recurring aktif) sebagai **"tidak bisa dites — fitur archive tidak pernah dibangun"** dan minta ditandai "Out of scope MVP". **Ini sudah tidak benar** — fitur archive (trigger Postgres + tombol UI) **dibangun lengkap di Sprint 9 (FG-60)** dan sudah diverifikasi end-to-end (lihat `sprint9_hasil_akhir.md`). Task 5 di bawah **menguji ulang** baris 8 secara formal untuk checklist FG-48 ini, **bukan** menandainya out-of-scope.

---

### Task 1: FG-44 — E2E negotiation → transaction → trust_metrics pipeline

**Files:**
- Create: `docs/qa/e2e-negotiation-pipeline.md`

**Skenario 1 — Accept path (negotiation → counter → accept → transaction pending → fulfill → trust_metrics ter-update):**

- [ ] **Step 1: Buat negosiasi baru, counter, accept**

```bash
# Buyer buat negosiasi baru
curl -s -X POST "https://rwxnjxmzkcfoddnzjosi.supabase.co/functions/v1/negotiations" \
  -H "apikey: sb_publishable_-tmXQTkiRSNHtvjBVILpvA_oGVnliRX" \
  -H "Authorization: Bearer sb_publishable_-tmXQTkiRSNHtvjBVILpvA_oGVnliRX" \
  -H "Content-Type: application/json" \
  -d '{"listing_id":"255b9d9a-a093-45a8-8599-da5f0f7d63d9","buyer_id":"ed23f6a6-21cb-4576-89ac-d8bfdae08a78","initial_price":32000,"quantity":3}'
# Catat negotiation_id dari response sebagai $NEG_ID

# Farmer counter
curl -s -X POST "https://rwxnjxmzkcfoddnzjosi.supabase.co/functions/v1/negotiations/$NEG_ID/messages" \
  -H "apikey: sb_publishable_-tmXQTkiRSNHtvjBVILpvA_oGVnliRX" \
  -H "Authorization: Bearer sb_publishable_-tmXQTkiRSNHtvjBVILpvA_oGVnliRX" \
  -H "Content-Type: application/json" \
  -d '{"sender_id":"dd97243c-c350-4282-8fe2-4e8e1084f951","action_type":"counter","offer_price":34000}'

# Buyer accept (jadi penerima karena farmer barusan counter)
curl -s -X POST "https://rwxnjxmzkcfoddnzjosi.supabase.co/functions/v1/negotiations/$NEG_ID/messages" \
  -H "apikey: sb_publishable_-tmXQTkiRSNHtvjBVILpvA_oGVnliRX" \
  -H "Authorization: Bearer sb_publishable_-tmXQTkiRSNHtvjBVILpvA_oGVnliRX" \
  -H "Content-Type: application/json" \
  -d '{"sender_id":"ed23f6a6-21cb-4576-89ac-d8bfdae08a78","action_type":"accept","offer_price":34000}'
# Catat transaction_id dari response sebagai $TX_ID
```
Expected: response accept berisi `transaction_id` non-null, `negotiation_status: "accepted"`.

- [ ] **Step 2: Verifikasi transaction pending**

```sql
select id, status, agreed_quantity, total_amount from transactions where id = '$TX_ID';
```
Expected: `status = 'pending'`, `total_amount = 3 × 34000 = 102000`.

- [ ] **Step 3: Fulfill, verifikasi trust_metrics ter-update**

```bash
# Perlu JWT asli farmer (transactions-fulfill wajib auth) — lihat Task 3 Step 1 untuk cara ambil token
curl -s -X POST "https://rwxnjxmzkcfoddnzjosi.supabase.co/functions/v1/transactions-fulfill/fulfill/$TX_ID" \
  -H "apikey: sb_publishable_-tmXQTkiRSNHtvjBVILpvA_oGVnliRX" \
  -H "Authorization: Bearer $FARMER_JWT" \
  -H "Content-Type: application/json" \
  -d '{"delivered_quantity":3,"actual_delivery_date":"'$(date +%F)'"}'
```
```sql
select on_time_delivery_rate, rejection_rate, fulfillment_consistency, total_transactions, updated_at
from trust_metrics where farmer_id = 'dd97243c-c350-4282-8fe2-4e8e1084f951';
```
Expected: `total_transactions` bertambah 1 dari nilai sebelum Step 3, `updated_at` mendekati waktu sekarang.

**Skenario 2 — Reject path (transaction pending → reject → rejection_rate ter-update, quantity_available rollback):**

- [ ] **Step 4: Buat negosiasi→accept baru (transaksi ke-2), catat `quantity_available` SEBELUM reject**

Ulangi Step 1 dengan kuantitas berbeda (mis. 2), catat `$TX_ID_2`. Sebelum reject:
```sql
select quantity_available from listings where id = '255b9d9a-a093-45a8-8599-da5f0f7d63d9';
```
Catat sebagai `$QTY_BEFORE`.

- [ ] **Step 5: Buyer reject**

```bash
curl -s -X POST "https://rwxnjxmzkcfoddnzjosi.supabase.co/functions/v1/transactions-reject/$TX_ID_2" \
  -H "apikey: sb_publishable_-tmXQTkiRSNHtvjBVILpvA_oGVnliRX" \
  -H "Authorization: Bearer $BUYER_JWT" \
  -H "Content-Type: application/json" \
  -d '{"reason":"Kualitas tidak sesuai (E2E test FG-44)"}'
```
```sql
select status from transactions where id = '$TX_ID_2';
select quantity_available from listings where id = '255b9d9a-a093-45a8-8599-da5f0f7d63d9';
select rejection_rate from trust_metrics where farmer_id = 'dd97243c-c350-4282-8fe2-4e8e1084f951';
```
Expected: `transactions.status = 'rejected'`, `quantity_available = $QTY_BEFORE + 2` (rollback), `rejection_rate` naik dari sebelumnya.

- [ ] **Step 6: Tulis `docs/qa/e2e-negotiation-pipeline.md`**

Format: judul, 2 skenario di atas dengan step + expected + actual + bukti (response/query result), kesimpulan PASS/FAIL per skenario, referensi silang ke bukti serupa dari `sprint7_hasil_akhir.md`/`sprint8_hasil_akhir.md` (transaksi `4f58b43f...` fulfilled, `8561d904...` pending) sebagai bukti tambahan yang sudah ada sebelum sprint ini.

---

### Task 2: FG-45 — E2E realtime chat latency <2 detik

**Files:**
- Create: `docs/qa/e2e-realtime-latency.md`
- Create: `/private/tmp/.../scratchpad/realtime_latency_test.ts` (script sementara, tidak perlu masuk repo)

**Pendekatan:** deteksi latensi Supabase Realtime tidak butuh 2 device fisik — subscribe ke channel `postgres_changes` pada tabel `negotiation_messages` lewat script Deno, kirim pesan lewat Edge Function, ukur delta waktu kirim vs waktu event realtime diterima. Ini mengukur komponen yang sama (server→client Supabase Realtime) yang dialami 2 device asli, tanpa perlu orkestrasi UI ganda.

- [ ] **Step 1: Siapkan negosiasi test berstatus `open`/`countered`**

```bash
curl -s -X POST "https://rwxnjxmzkcfoddnzjosi.supabase.co/functions/v1/negotiations" \
  -H "apikey: sb_publishable_-tmXQTkiRSNHtvjBVILpvA_oGVnliRX" \
  -H "Authorization: Bearer sb_publishable_-tmXQTkiRSNHtvjBVILpvA_oGVnliRX" \
  -H "Content-Type: application/json" \
  -d '{"listing_id":"255b9d9a-a093-45a8-8599-da5f0f7d63d9","buyer_id":"ed23f6a6-21cb-4576-89ac-d8bfdae08a78","initial_price":30000,"quantity":1}'
```
Catat `negotiation_id` sebagai `$NEG_ID`.

- [ ] **Step 2: Tulis script `realtime_latency_test.ts`**

```typescript
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = "https://rwxnjxmzkcfoddnzjosi.supabase.co";
const ANON_KEY = "sb_publishable_-tmXQTkiRSNHtvjBVILpvA_oGVnliRX";
const NEGOTIATION_ID = Deno.args[0];
const SENDER_ID = Deno.args[1]; // farmer_id, kirim pesan sebagai "pihak lain" tiap kali gantian

if (!NEGOTIATION_ID || !SENDER_ID) {
  console.error("Usage: deno run --allow-net realtime_latency_test.ts <negotiation_id> <sender_id>");
  Deno.exit(1);
}

const supabase = createClient(SUPABASE_URL, ANON_KEY);
const latencies: number[] = [];
let pending: { sentAt: number; resolve: (v: number) => void } | null = null;

const channel = supabase
  .channel(`latency-test-${NEGOTIATION_ID}`)
  .on(
    "postgres_changes",
    { event: "INSERT", schema: "public", table: "negotiation_messages", filter: `negotiation_id=eq.${NEGOTIATION_ID}` },
    () => {
      if (pending) {
        pending.resolve(Date.now() - pending.sentAt);
        pending = null;
      }
    },
  )
  .subscribe();

await new Promise((r) => setTimeout(r, 2000)); // tunggu subscription siap

for (let i = 0; i < 10; i++) {
  const sentAt = Date.now();
  const latencyPromise = new Promise<number>((resolve) => {
    pending = { sentAt, resolve };
  });

  await fetch(`${SUPABASE_URL}/functions/v1/negotiations/${NEGOTIATION_ID}/messages`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "apikey": ANON_KEY,
      "Authorization": `Bearer ${ANON_KEY}`,
    },
    body: JSON.stringify({ sender_id: SENDER_ID, action_type: "message", message_text: `latency test ${i + 1}` }),
  });

  const latency = await Promise.race([
    latencyPromise,
    new Promise<number>((r) => setTimeout(() => r(-1), 5000)),
  ]);
  latencies.push(latency);
  console.log(`Trial ${i + 1}: ${latency < 0 ? "TIMEOUT (>5000ms)" : latency + "ms"}`);
  await new Promise((r) => setTimeout(r, 1000));
}

const valid = latencies.filter((l) => l >= 0);
const avg = valid.length ? valid.reduce((a, b) => a + b, 0) / valid.length : -1;
console.log(`\n${valid.length}/10 trial berhasil. Rata-rata: ${avg.toFixed(0)}ms`);
console.log(avg >= 0 && avg < 2000 ? "PASS (<2000ms)" : "FAIL");

Deno.exit(0);
```

- [ ] **Step 3: Jalankan**

```bash
deno run --allow-net realtime_latency_test.ts $NEG_ID dd97243c-c350-4282-8fe2-4e8e1084f951
```
Expected: 10 trial tercatat, rata-rata < 2000ms untuk PASS. Kalau Deno tidak terpasang: `curl -fsSL https://deno.land/install.sh | sh` dulu (atau catat sebagai blocker kalau tidak boleh install tooling baru — laporkan ke user).

- [ ] **Step 4: Tulis `docs/qa/e2e-realtime-latency.md`**

Tabel 10 baris (trial, latensi ms), rata-rata, kesimpulan PASS/FAIL, catatan kalau ada trial yang timeout (bug ticket terpisah sesuai DoD `sprint10_fachri_dev.md` kalau rata-rata ≥ 2000ms).

---

### Task 3: FG-46 — E2E Buy Now + race condition

**Files:**
- Create: `docs/qa/e2e-buy-now.md`

**Skenario 1 — Alur normal:**

- [ ] **Step 1: Ambil JWT asli buyer & farmer (dibutuhkan endpoint auth-protected: `buy-now`, `transactions-fulfill`, `transactions-reject`)**

```bash
BUYER_JWT=$(curl -s -X POST "https://rwxnjxmzkcfoddnzjosi.supabase.co/auth/v1/token?grant_type=password" \
  -H "apikey: sb_publishable_-tmXQTkiRSNHtvjBVILpvA_oGVnliRX" \
  -H "Content-Type: application/json" \
  -d '{"email":"buyer.test@farmbridge.dev","password":"<PASSWORD_BUYER>"}' | grep -o '"access_token":"[^"]*"' | cut -d'"' -f4)

FARMER_JWT=$(curl -s -X POST "https://rwxnjxmzkcfoddnzjosi.supabase.co/auth/v1/token?grant_type=password" \
  -H "apikey: sb_publishable_-tmXQTkiRSNHtvjBVILpvA_oGVnliRX" \
  -H "Content-Type: application/json" \
  -d '{"email":"farmer.test@farmbridge.dev","password":"<PASSWORD_FARMER>"}' | grep -o '"access_token":"[^"]*"' | cut -d'"' -f4)
echo "buyer token length: ${#BUYER_JWT}, farmer token length: ${#FARMER_JWT}"
```
Expected: keduanya non-kosong (JWT panjang ratusan karakter). Simpan `$BUYER_JWT`/`$FARMER_JWT` untuk dipakai lagi di Task 1 Step 3/5.

- [ ] **Step 2: Cek stok awal, lakukan Buy Now normal**

```sql
select quantity_available from listings where id = '10bae509-7e72-49d6-8716-b84e600db379';
```
Catat sebagai `$QTY_BEFORE`.
```bash
curl -s -X POST "https://rwxnjxmzkcfoddnzjosi.supabase.co/functions/v1/buy-now/10bae509-7e72-49d6-8716-b84e600db379" \
  -H "apikey: sb_publishable_-tmXQTkiRSNHtvjBVILpvA_oGVnliRX" \
  -H "Authorization: Bearer $BUYER_JWT" \
  -H "Content-Type: application/json" \
  -d '{"quantity":1,"buyer_id":"ed23f6a6-21cb-4576-89ac-d8bfdae08a78"}'
```
Expected: `{"negotiation_id":..., "transaction_id":..., "status":"pending", "total_amount":...}`. Verifikasi `quantity_available` berkurang tepat 1, `transactions.status = 'pending'`.

**Skenario 2 — Race condition (first-accepted-wins):**

- [ ] **Step 3: Set stok listing test jadi angka kecil & pasti (biar race condition gampang dipicu)**

```sql
update listings set quantity_available = 5 where id = '10bae509-7e72-49d6-8716-b84e600db379';
```

- [ ] **Step 4: Kirim 2 request Buy Now nyaris bersamaan, masing-masing minta kuantitas yang totalnya melebihi stok**

```bash
curl -s -X POST "https://rwxnjxmzkcfoddnzjosi.supabase.co/functions/v1/buy-now/10bae509-7e72-49d6-8716-b84e600db379" \
  -H "apikey: sb_publishable_-tmXQTkiRSNHtvjBVILpvA_oGVnliRX" \
  -H "Authorization: Bearer $BUYER_JWT" \
  -H "Content-Type: application/json" \
  -d '{"quantity":4,"buyer_id":"ed23f6a6-21cb-4576-89ac-d8bfdae08a78"}' > /tmp/race_a.json &

curl -s -X POST "https://rwxnjxmzkcfoddnzjosi.supabase.co/functions/v1/buy-now/10bae509-7e72-49d6-8716-b84e600db379" \
  -H "apikey: sb_publishable_-tmXQTkiRSNHtvjBVILpvA_oGVnliRX" \
  -H "Authorization: Bearer $BUYER_JWT" \
  -H "Content-Type: application/json" \
  -d '{"quantity":4,"buyer_id":"ed23f6a6-21cb-4576-89ac-d8bfdae08a78"}' > /tmp/race_b.json &

wait
cat /tmp/race_a.json; echo; cat /tmp/race_b.json
```
Expected: **salah satu** sukses (`transaction_id` non-null, stok 5→1), **satu lagi gagal** dengan pesan stok tidak cukup / first-accepted-wins (409 atau error message dari `lockInventory` di `buy-now/index.ts`) — **bukan** keduanya sukses (yang berarti stok jadi -3, race condition nyata terjadi dan atomic guard gagal).

- [ ] **Step 5: Verifikasi hasil akhir konsisten**

```sql
select quantity_available from listings where id = '10bae509-7e72-49d6-8716-b84e600db379';
```
Expected: `1` (5 − 4, dari yang menang saja) — **bukan negatif**.

- [ ] **Step 6: Tulis `docs/qa/e2e-buy-now.md`**

Kedua skenario + bukti mentah (response JSON kedua request race, hasil query stok sebelum/sesudah), kesimpulan PASS/FAIL.

---

### Task 4: FG-47 — E2E recurring order full cycle

**Files:**
- Create: `docs/qa/e2e-recurring-order.md`

**Skenario 1 & 2 (create→trigger sukses, skip karena stok kurang) — SUDAH ada bukti dari Sprint 9 Task 3, tinggal dirujuk + 1 run segar untuk catatan sprint ini:**

- [ ] **Step 1: Jalankan ulang skenario sukses + skip (ringkas, bukti lengkap sudah ada di `sprint9_hasil_akhir.md`)**

```bash
# Sukses: pakai recurring order test Sprint 9 yang masih ada
# (cek dulu statusnya masih 'active' — kalau sudah 'cancelled' dari QA Sprint 9, buat baru)
```
```sql
select id, status, next_order_date, quantity from recurring_orders
where id in ('1eadb85a-a417-44c7-a912-826ddafc949d', 'a1c1800c-7a75-4db1-a741-05e523ef8575');
```
Kalau salah satu masih `active`: `update recurring_orders set next_order_date = current_date where id = '<ID>';` lalu trigger:
```bash
curl -s -X POST "https://rwxnjxmzkcfoddnzjosi.supabase.co/functions/v1/check-recurring-orders" \
  -H "apikey: sb_publishable_-tmXQTkiRSNHtvjBVILpvA_oGVnliRX" \
  -H "Authorization: Bearer sb_publishable_-tmXQTkiRSNHtvjBVILpvA_oGVnliRX"
```
Expected: `created` bertambah 1, transaksi baru `recurring_order_id` sesuai, `next_order_date` maju.

**Skenario 3 — Cancel di tengah siklus pending (BARU, belum pernah dites):**

- [ ] **Step 2: Buat recurring order baru khusus untuk skenario ini**

```bash
curl -s -X POST "https://rwxnjxmzkcfoddnzjosi.supabase.co/functions/v1/recurring-orders" \
  -H "apikey: sb_publishable_-tmXQTkiRSNHtvjBVILpvA_oGVnliRX" \
  -H "Authorization: Bearer sb_publishable_-tmXQTkiRSNHtvjBVILpvA_oGVnliRX" \
  -H "Content-Type: application/json" \
  -d '{"buyer_id":"ed23f6a6-21cb-4576-89ac-d8bfdae08a78","farmer_id":"38e89c06-2257-49f8-a392-ed2ee8734031","listing_id":"10bae509-7e72-49d6-8716-b84e600db379","quantity":1,"frequency":"weekly","locked_price":30000}'
```
Catat `recurring_order_id` sebagai `$RO_ID`.

- [ ] **Step 3: Set `next_order_date` ke hari ini, trigger, dapatkan transaction pending**

```sql
update recurring_orders set next_order_date = current_date where id = '$RO_ID';
```
```bash
curl -s -X POST "https://rwxnjxmzkcfoddnzjosi.supabase.co/functions/v1/check-recurring-orders" \
  -H "apikey: sb_publishable_-tmXQTkiRSNHtvjBVILpvA_oGVnliRX" \
  -H "Authorization: Bearer sb_publishable_-tmXQTkiRSNHtvjBVILpvA_oGVnliRX"
```
```sql
select id, status from transactions where recurring_order_id = '$RO_ID';
```
Catat `transaction_id` sebagai `$TX_ID_3` — expected `status = 'pending'`.

- [ ] **Step 4: Cancel recurring order SEMENTARA transaction masih pending**

```bash
curl -s -X PATCH "https://rwxnjxmzkcfoddnzjosi.supabase.co/functions/v1/recurring-orders/$RO_ID" \
  -H "apikey: sb_publishable_-tmXQTkiRSNHtvjBVILpvA_oGVnliRX" \
  -H "Authorization: Bearer sb_publishable_-tmXQTkiRSNHtvjBVILpvA_oGVnliRX" \
  -H "Content-Type: application/json" \
  -d '{"status":"cancelled"}'
```

- [ ] **Step 5: Verifikasi transaction pending TIDAK terpengaruh**

```sql
select status from transactions where id = '$TX_ID_3';
select status from recurring_orders where id = '$RO_ID';
```
Expected: `transactions.status` **tetap `pending`** (cancel recurring order tidak boleh membatalkan transaksi yang sudah terlanjur dibuat — sesuai §11 "Transaksi yang sudah PENDING tetap berjalan sampai selesai; hanya siklus berikutnya yang dihentikan"), `recurring_orders.status = 'cancelled'`.

- [ ] **Step 6: Verifikasi siklus berikutnya benar-benar berhenti**

```sql
update recurring_orders set next_order_date = current_date where id = '$RO_ID';
```
```bash
curl -s -X POST "https://rwxnjxmzkcfoddnzjosi.supabase.co/functions/v1/check-recurring-orders" \
  -H "apikey: sb_publishable_-tmXQTkiRSNHtvjBVILpvA_oGVnliRX" \
  -H "Authorization: Bearer sb_publishable_-tmXQTkiRSNHtvjBVILpvA_oGVnliRX"
```
Expected: `due_today` **tidak** menghitung `$RO_ID` (karena query filter `status='active'`, sudah `cancelled`) — tidak ada transaction baru untuk `$RO_ID` walau `next_order_date` di-set ke hari ini secara manual.

- [ ] **Step 7: Tulis `docs/qa/e2e-recurring-order.md`**

3 skenario (sukses, skip, cancel-mid-cycle) dengan bukti, PASS/FAIL, referensi ke `sprint9_hasil_akhir.md` untuk skenario 1&2.

---

### Task 5: FG-48 — Checklist 9 edge case §11 (cakupan diperbaiki dari 7)

**Files:**
- Create: `docs/qa/edge-case-checklist.md`

Setiap baris: skenario, cara uji, expected, hasil actual (bukti), status PASS/FAIL/N/A.

- [ ] **Baris 1 — Counter offer lebih tinggi dari harga sendiri**

```bash
# Buyer initial_price 30000, lalu buyer counter 50000 (lebih tinggi dari harga sendiri)
curl -s -X POST ".../negotiations/$NEG_ID/messages" -d '{"sender_id":"...","action_type":"counter","offer_price":50000}' ...
```
Expected: diterima (200), tidak ada validasi "counter harus lebih rendah dari harga sendiri" — PRD cuma minta harga > 0 (`Number(initial_price) <= 0` check di `negotiations/index.ts`, tidak ada batas atas).

- [ ] **Baris 2 — Stok berubah saat negotiation berjalan → warning di chat**

Sudah ada di kode (`negotiation_chat_screen.dart`: `stockChanged` banner oranye) — verifikasi dengan: buat negosiasi, lalu `update listings set quantity_available = quantity_available - 5 where id = ...` manual, reload chat screen di device/emulator, cek banner "Stok berubah: X → Y unit" muncul, negosiasi **tidak** auto-cancel.

- [ ] **Baris 3 — Farmer tidak respons 6 jam → EXPIRED, tidak pengaruhi trust_metrics**

```sql
-- Buat negosiasi test, manual mundurkan expires_at ke masa lalu
update negotiations set expires_at = now() - interval '1 hour' where id = '$NEG_ID_EXPIRE_TEST' and status = 'open';
-- Tunggu maks 5 menit (jadwal cron) atau cek langsung:
select status from negotiations where id = '$NEG_ID_EXPIRE_TEST';
```
**Perhatian:** cron `expire-negotiations` (dikonfirmasi lewat `select command from cron.job where jobname='expire-negotiations'`) set `status = 'EXPIRED'` — **huruf besar semua**, sedangkan seluruh kode aplikasi (Flutter, Edge Function lain) pakai `'expired'` huruf kecil (lihat `negotiation_chat_screen.dart:_statusLabel`, PRD §5.1). **Kemungkinan besar ini bug lama** (sudah dicatat di `sprint7_hasil_akhir.md` tapi belum pernah diperbaiki) — kalau expected `'expired'` tidak match hasil `'EXPIRED'`, catat FAIL dengan root cause ini, **jangan langsung perbaiki** — tanyakan ke user dulu (pola yang sama seperti bug-bug lain di Sprint 7-9), karena ini mengubah cron job production.

Verifikasi trust_metrics tidak berubah: catat `total_transactions` farmer sebelum & sesudah expire — harus sama (expire tidak melibatkan transactions/trust_metrics sama sekali secara desain).

- [ ] **Baris 4 — `delivered_quantity` > `agreed_quantity` → fulfilled + `anomaly_flag=true`**

Sudah punya bukti dari `dokumentasi_sprint7_nevan_dev.md` (AC 3, transaction `ecbb7788` → `anomaly_flag=true`) — cukup dirujuk, atau ulangi cepat: fulfill transaksi test dengan `delivered_quantity` sengaja lebih besar dari `agreed_quantity`, cek `anomaly_flag` di response & SQL.

- [ ] **Baris 5 — Race condition dua negotiation/Buy Now bersamaan → first-accepted-wins**

Sudah dites di Task 3 Skenario 2 (Buy Now) — cukup rujuk. Untuk race condition di jalur **negosiasi** (bukan Buy Now): 2 `action_type: accept` nyaris bersamaan pada negosiasi yang sama — cek `lockInventoryOnAcceptWithQuantity`'s optimistic concurrency guard (`eq("quantity_available", currentQty)`) berperilaku sama; opsional dites terpisah kalau ada waktu, atau catat sebagai "logic sama dengan Buy Now, sudah diverifikasi di Task 3, tidak diulang" (N/A dengan alasan).

- [ ] **Baris 6 — `price_reference_data` kosong → 200 dengan fallback**

```bash
curl -s -X POST ".../functions/v1/negotiations" -d '{"listing_id":"...","buyer_id":"...","initial_price":10000,"quantity":1}' ...
# Pakai listing dengan category/region yang PASTI tidak ada di price_reference_data, contoh:
```
```sql
-- Cek dulu kombinasi category/region yang tidak ada
select distinct category, region from price_reference_data;
-- Bikin/pakai listing dengan kombinasi di luar itu, atau insert listing test kategori "Kategori Uji FG48"
```
Expected: response 200, `recommended_price: null`, `message: "Data referensi belum tersedia untuk kategori ini"` (persis string ini, dicek di `_shared/price-recommendation.ts`) — bukan error/500.

- [ ] **Baris 7 — Cancel recurring order di tengah siklus pending**

Sudah dites di Task 4 Skenario 3 — cukup rujuk, tidak diulang.

- [ ] **Baris 8 — Farmer archive listing dengan recurring_orders aktif → DITOLAK (koreksi: fitur SUDAH ada sejak Sprint 9)**

```sql
-- Pastikan ada recurring order active untuk listing test
select id, status from recurring_orders where listing_id = '10bae509-7e72-49d6-8716-b84e600db379' and status = 'active';
```
```sql
update listings set status = 'archived' where id = '10bae509-7e72-49d6-8716-b84e600db379';
```
Expected: **error** dari trigger `guard_archive_listing_with_active_recurring` (`supabase/migrations/20260718010000_...`) — `"Listing masih terikat N recurring order aktif..."`. Ini **mengulang verifikasi yang sudah dilakukan di Sprint 9** (`sprint9_hasil_akhir.md`) — jalankan lagi di sini murni supaya baris 8 checklist FG-48 tercatat resmi PASS dengan tanggal Sprint 10, bukan sekadar rujukan (checklist lama secara eksplisit minta ini ditandai "Out of scope", jadi perlu bukti baru yang membantah itu).

- [ ] **Baris 9 — H-1 skip cycle → sudah dites FG-47 (Hafizh) sprint ini juga**

Rujuk Task 4 Skenario 2 (dan Sprint 9 Task 3 Step 5) — tidak perlu diulang, sesuai catatan asli di `sprint10_nevan_dev.md`.

- [ ] **Tulis `docs/qa/edge-case-checklist.md`**

Tabel 9 baris: No, Skenario, Cara Uji, Expected, Actual, Status (PASS/FAIL/N/A + alasan). Highlight baris 3 (kemungkinan FAIL karena bug `EXPIRED` uppercase) dan baris 8 (koreksi dari checklist lama) di bagian catatan.

---

### Task 6: Konsolidasi + regression check + laporan akhir

**Files:**
- Create: `docs/Sprint 10/sprint10_hasil_akhir.md`

- [ ] **Step 1: `flutter analyze` & `flutter test`**

Run: `flutter analyze && flutter test`
Expected: 0 issue, 26/26 pass — sprint ini tidak mengubah kode aplikasi, jadi hasil harus identik dengan akhir Sprint 9. Kalau ada perbedaan, itu sendiri temuan yang perlu diselidiki.

- [ ] **Step 2: Kumpulkan semua temuan bug/gap dari Task 1-5**

Terutama: bug `EXPIRED` uppercase (Task 5 baris 3) — kalau dikonfirmasi FAIL, ini kandidat fix nyata untuk didiskusikan dengan user (bukan otomatis diperbaiki sprint ini, sesuai instruksi Task 5).

- [ ] **Step 3: Tulis `sprint10_hasil_akhir.md`**

Ringkasan 5 ticket, tabel status tiap E2E test + edge case, link ke 5 file `docs/qa/*.md`, daftar bug/gap ditemukan (terutama `EXPIRED` uppercase), data test yang dipakai/dibuat, dan pembuka ke sprint berikutnya (kemungkinan demo/polish final berdasarkan posisi Sprint 10 dari 13 total sprint di roadmap).

---

## Self-Review

**Spec coverage:**
- FG-44 (accept & reject pipeline, trust_metrics) → Task 1.
- FG-45 (latensi realtime <2 detik, 10 percobaan) → Task 2.
- FG-46 (Buy Now normal + race condition) → Task 3.
- FG-47 (create→trigger, skip, cancel-mid-cycle) → Task 4.
- FG-48 (9 baris edge case, bukan 7) → Task 5, termasuk koreksi eksplisit baris 8.

**Placeholder scan:** tidak ada TBD tersembunyi. Baris 3 dan 5 Task 5 punya ketidakpastian hasil yang **disengaja dan dijelaskan** (bug `EXPIRED` yang sudah diketahui, dan race condition negosiasi yang boleh di-N/A-kan dengan alasan eksplisit) — bukan pekerjaan yang disembunyikan.

**Konsistensi dengan temuan sesi sebelumnya:** Task 5 baris 3 dan 8 secara eksplisit mengoreksi asumsi lama di `sprint10_README.md`/`sprint10_nevan_dev.md` — kedua koreksi didukung bukti konkret (query `cron.job` untuk baris 3, `sprint9_hasil_akhir.md` untuk baris 8), bukan tebakan.

**Dependency antar-task:** Task 1-5 sebagian besar independen (bisa jalan urutan apapun), tapi Task 5 baris 5, 7, 9 secara eksplisit merujuk hasil Task 3/4 — kerjakan Task 3 & 4 sebelum baris-baris itu di Task 5 supaya rujukannya valid. Task 6 di akhir, butuh Task 1-5 selesai.
