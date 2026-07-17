# Sprint 10 Bugfix + Full Crosscheck Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Perbaiki 2 bug produksi yang ditemukan di Sprint 10 QA (race condition Buy Now, case mismatch `EXPIRED`/`expired`), rekonsiliasi data test yang rusak akibat pengujian bug tersebut, lalu crosscheck menyeluruh — **logic** (re-run semua skenario Sprint 10 + regression suite) dan **visual** (live UI di emulator) — sebelum lanjut ke Sprint 11.

**Architecture:** Fix Buy Now dengan mengganti implementasi lock stok lokal yang cacat dengan fungsi shared yang sudah terbukti benar (`_shared/inventory-locking.ts`) — pola reuse, bukan tambal manual. Fix cron `expire-negotiations` lewat migration (`cron.alter_job` + backfill data lama yang sudah kadung uppercase). Setelah fix, ulangi PERSIS skenario yang tadinya FAIL untuk buktikan sudah benar, lalu jalankan ulang semua skenario yang tadinya PASS untuk pastikan tidak ada regresi, ditutup dengan walkthrough visual di emulator untuk flow-flow inti (login, negosiasi+chat, Buy Now, fulfill/reject, recurring order, archive listing).

**Tech Stack:** Deno (Edge Functions), SQL migration (pg_cron), `supabase functions deploy` CLI, curl/SQL untuk re-test, ADB/uiautomator untuk visual crosscheck (pola sama seperti Sprint 7-9).

## Global Constraints

- **Jangan pernah menjalankan `git add`/`commit`/`push`/`merge`/dll** — `docs/CLAUDE.md` melarang keras, tanpa pengecualian.
- Deploy Edge Function pakai `supabase functions deploy <name> --project-ref rwxnjxmzkcfoddnzjosi` (CLI, resolve relative import otomatis) — bukan MCP `deploy_edge_function` (butuh flat file array manual, rawan salah untuk fungsi dengan banyak shared import).
- Migration DB pakai MCP `apply_migration` (preferensi user yang sudah konsisten sejak Sprint 8-9).
- Semua fix minimal — tidak ada refactor di luar yang dibutuhkan untuk memperbaiki 2 bug ini.

---

### Task 1: Fix race condition Buy Now — reuse shared inventory lock

**Files:**
- Modify: `supabase/functions/buy-now/index.ts`

**Interfaces:**
- Consumes: `lockInventoryOnAcceptWithQuantity(supabase, negotiationId, quantity) -> Promise<{success: boolean, transaction_id?: string, error?: string}>` dari `supabase/functions/_shared/inventory-locking.ts` (fungsi ini SUDAH punya optimistic concurrency guard `.eq("quantity_available", currentQty)`, sudah diverifikasi benar lewat race-condition test nyata di Sprint 10 Task 5 baris 5).

- [ ] **Step 1: Hapus fungsi `lockInventory` lokal yang cacat, ganti dengan import shared**

Baris 1-19 saat ini:
```ts
import { createClient } from "npm:@supabase/supabase-js@2";

async function lockInventory(supabase, negotiationId, quantity, farmerId, buyerId, price, listingId) {
  const { data: list } = await supabase.from("listings").select("quantity_available").eq("id", listingId).single();
  if (!list) return { success: false, error: "Listing tidak ditemukan" };
  const currentQty = Number(list.quantity_available);
  if (currentQty < quantity) return { success: false, error: "Stok tidak mencukupi (first-accepted-wins)" };
  const { error: deductErr } = await supabase.from("listings").update({ quantity_available: currentQty - quantity }).eq("id", listingId);
  if (deductErr) return { success: false, error: "Gagal mengurangi stok" };
  const totalAmount = quantity * Number(price);
  const promised = new Date(); promised.setDate(promised.getDate() + 7);
  const { data: tx, error: txErr } = await supabase.from("transactions").insert({
    negotiation_id: negotiationId, farmer_id: farmerId, buyer_id: buyerId,
    status: "pending", agreed_quantity: quantity, total_amount: totalAmount,
    promised_delivery_date: promised.toISOString().slice(0, 10)
  }).select("id").single();
  if (txErr) { await supabase.from("listings").update({ quantity_available: currentQty }).eq("id", listingId); return { success: false, error: "Gagal buat transaksi" }; }
  return { success: true, transaction_id: tx.id };
}
```

Ganti jadi:
```ts
import { createClient } from "npm:@supabase/supabase-js@2";
import { lockInventoryOnAcceptWithQuantity } from "../_shared/inventory-locking.ts";
```

(Fungsi lokal dihapus total — logiknya sudah persis sama dengan `lockInventoryOnAcceptWithQuantity`, hanya kurang guard-nya. Negotiation row yang dibuat Buy Now di Step 2 sudah punya `listing_id`, `farmer_id`, `buyer_id`, `current_offer_price` — persis field yang dibutuhkan fungsi shared lewat `negotiationId`.)

- [ ] **Step 2: Ganti call site**

Cari blok ini (sekitar baris 101-112 setelah Step 1 diterapkan, nomor baris akan bergeser):
```ts
    // 3. Lock inventory + buat transaction (FG-35)
    const lockResult = await lockInventory(
      supabase, negotiation.id, quantity,
      listing.farmer_id, buyer_id,
      listing.harga_per_unit, listingId,
    );

    if (!lockResult.success) {
      // Rollback negotiation
      await supabase.from("negotiations").delete().eq("id", negotiation.id);
      return new Response(JSON.stringify({ error: lockResult.error }), { status: 409, headers: { "Content-Type": "application/json" } });
    }
```

Ganti baris pemanggilan jadi:
```ts
    // 3. Lock inventory + buat transaction (FG-35) — reuse shared, guarded (fix FG-46 race condition)
    const lockResult = await lockInventoryOnAcceptWithQuantity(supabase, negotiation.id, quantity);

    if (!lockResult.success) {
      // Rollback negotiation
      await supabase.from("negotiations").delete().eq("id", negotiation.id);
      return new Response(JSON.stringify({ error: lockResult.error }), { status: 409, headers: { "Content-Type": "application/json" } });
    }
```

- [ ] **Step 3: Verifikasi tidak ada sisa referensi ke fungsi lama**

Run: `grep -n "lockInventory(" supabase/functions/buy-now/index.ts`
Expected: hanya 1 match, yaitu pemanggilan `lockInventoryOnAcceptWithQuantity` di Step 2 (tidak ada lagi definisi fungsi lokal `lockInventory`).

- [ ] **Step 4: Deploy**

Run: `supabase functions deploy buy-now --project-ref rwxnjxmzkcfoddnzjosi`
Expected: deploy sukses tanpa error TypeScript (import path `../_shared/inventory-locking.ts` valid, sudah dipakai fungsi lain seperti `negotiations`).

---

### Task 2: Fix case mismatch `EXPIRED` → `expired`

**Files:**
- Create: `supabase/migrations/20260717130000_fix_expire_negotiations_case.sql`

- [ ] **Step 1: Tulis migration**

```sql
-- Fix: cron job 'expire-negotiations' set status='EXPIRED' (uppercase),
-- sementara seluruh kode aplikasi (Flutter + Edge Functions lain) cek
-- 'expired' (lowercase). Akibatnya guard di negotiations/index.ts:87
-- ("Negosiasi sudah selesai") gagal total untuk negosiasi yang sudah
-- expired via cron — user masih bisa kirim pesan/aksi baru.
-- Ditemukan & dibuktikan di Sprint 10 QA (docs/qa/edge-case-checklist.md baris 3).

-- 1. Perbaiki job supaya ke depan selalu set lowercase.
SELECT cron.alter_job(
  (SELECT jobid FROM cron.job WHERE jobname = 'expire-negotiations'),
  command => $cron$
  DO 
  DECLARE
    expired_count INT;
  BEGIN
    UPDATE negotiations 
    SET status = 'expired'
    WHERE status IN ('open', 'countered') 
    AND expires_at IS NOT NULL 
    AND expires_at < NOW()
    AND status NOT IN ('accepted', 'declined');

    GET DIAGNOSTICS expired_count = ROW_COUNT;

    INSERT INTO cron_execution_log (job_name, status, message)
    VALUES ('expire-negotiations', 'success', 
      CASE WHEN expired_count > 0 
        THEN expired_count || ' negosiasi expired'
        ELSE 'Tidak ada negosiasi expired'
      END);
  END;
  $cron$
);

-- 2. Backfill baris yang sudah kadung 'EXPIRED' (uppercase) dari histori
--    cron sebelum fix ini — termasuk data real (bukan cuma data test),
--    dikonfirmasi via SQL sebelum migration ini ada 3 baris kena.
UPDATE negotiations SET status = 'expired' WHERE status = 'EXPIRED';
```

- [ ] **Step 2: Apply migration lewat MCP `apply_migration`**

(Dieksekusi langsung, bukan CLI — konsisten dengan preferensi user Sprint 8-9.)

- [ ] **Step 3: Verifikasi**

```sql
select jobname, command from cron.job where jobname = 'expire-negotiations';
select count(*) from negotiations where status = 'EXPIRED';
```
Expected: `command` sekarang mengandung `SET status = 'expired'` (lowercase), dan `count = 0`.

---

### Task 3: Rekonsiliasi data test listing `10bae509-7e72-49d6-8716-b84e600db379`

**Konteks:** Listing ini dipakai berulang kali selama Sprint 10 QA (Task 1, 3, 4) termasuk 2 manual override `quantity_available` untuk memaksa skenario race-condition dan skip-cycle. State akhir sebelum fix (`quantity_available=0`) tidak merefleksikan histori transaksi riil. Derivasi nilai benar (didokumentasikan untuk audit):

```
43 (awal)
- 3  (Task1 Step1: accept qty3, fulfilled — c95e71b1)         → 40
- 2  (Task1 Step4: accept qty2)                                → 38
+ 2  (Task1 Step5: reject qty2 — rollback)                     → 40
- 1  (Task3 Step2: buy-now normal qty1, pending — 8c382aa0)     → 39
- 4  (Task3 Step4: SATU dari 2 request race yang seharusnya
      menang kalau guard benar — e37efa63, pending)             → 35
```
Baris `41e98b7d` (qty4) adalah duplikat yang seharusnya ditolak race guard — di-reject manual sebagai representasi perilaku yang benar.

- [ ] **Step 1: Set transaksi duplikat race jadi rejected**

```sql
update transactions set status = 'rejected' where id = '41e98b7d-988e-4760-b4f9-2ab16ae3d50b';
```

- [ ] **Step 2: Set `quantity_available` ke nilai benar**

```sql
update listings set quantity_available = 35 where id = '10bae509-7e72-49d6-8716-b84e600db379';
```

- [ ] **Step 3: Verifikasi state akhir konsisten**

```sql
select status, count(*), sum(agreed_quantity) from transactions where negotiation_id in (select id from negotiations where listing_id = '10bae509-7e72-49d6-8716-b84e600db379') or recurring_order_id in (select id from recurring_orders where listing_id = '10bae509-7e72-49d6-8716-b84e600db379') group by status;
select quantity_available from listings where id = '10bae509-7e72-49d6-8716-b84e600db379';
```
Expected: `quantity_available = 35`, transaksi `41e98b7d...` masuk grup `rejected`.

---

### Task 4: Re-verifikasi kedua fix (ulangi persis skenario yang tadinya FAIL)

**Files:** tidak ada file baru — verifikasi API-level.

- [ ] **Step 1: Ulangi race condition Buy Now (harus FAIL sekarang, artinya salah satu request ditolak)**

```bash
# Set stok kecil & pasti untuk listing test baru (hindari re-pakai 10bae509 yang baru direkonsiliasi)
```
```sql
update listings set quantity_available = 5 where id = '1786952b-1802-43e6-b6b0-236780899905';
```
```bash
BUYER_JWT="<ambil ulang via password grant seperti Sprint 10 Task 3 Step 1>"

curl -s -X POST "https://rwxnjxmzkcfoddnzjosi.supabase.co/functions/v1/buy-now/1786952b-1802-43e6-b6b0-236780899905" \
  -H "apikey: sb_publishable_-tmXQTkiRSNHtvjBVILpvA_oGVnliRX" \
  -H "Authorization: Bearer $BUYER_JWT" -H "Content-Type: application/json" \
  -d '{"quantity":4,"buyer_id":"ed23f6a6-21cb-4576-89ac-d8bfdae08a78"}' > /tmp/race_fix_a.json &

curl -s -X POST "https://rwxnjxmzkcfoddnzjosi.supabase.co/functions/v1/buy-now/1786952b-1802-43e6-b6b0-236780899905" \
  -H "apikey: sb_publishable_-tmXQTkiRSNHtvjBVILpvA_oGVnliRX" \
  -H "Authorization: Bearer $BUYER_JWT" -H "Content-Type: application/json" \
  -d '{"quantity":4,"buyer_id":"ed23f6a6-21cb-4576-89ac-d8bfdae08a78"}' > /tmp/race_fix_b.json &

wait
cat /tmp/race_fix_a.json; echo; cat /tmp/race_fix_b.json
```
Expected: **satu** response sukses (`transaction_id`), **satu** response error `"Stok tidak mencukupi — transaksi lain mungkin sudah mengambil (first-accepted-wins)"` dengan status 409. Verifikasi `quantity_available` akhir = `1` (5-4, bukan hasil lost-update).

- [ ] **Step 2: Ulangi expired-guard-bypass (harus ditolak sekarang)**

```sql
insert into negotiations (listing_id, buyer_id, farmer_id, initial_price, current_offer_price, counter_count, status, expires_at, quantity)
values ('1786952b-1802-43e6-b6b0-236780899905', 'ed23f6a6-21cb-4576-89ac-d8bfdae08a78', '38e89c06-2257-49f8-a392-ed2ee8734031', 25000, 25000, 0, 'open', now() - interval '1 hour', 1)
returning id;
```
Catat `id` sebagai `$NEG_ID_VERIFY`, lalu jalankan ulang DO block cron yang SUDAH diperbaiki (Task 2 Step 1) secara manual untuk memastikan berperilaku benar:
```sql
DO $$
DECLARE
  expired_count INT;
BEGIN
  UPDATE negotiations SET status = 'expired'
  WHERE status IN ('open', 'countered') AND expires_at IS NOT NULL AND expires_at < NOW() AND status NOT IN ('accepted', 'declined');
  GET DIAGNOSTICS expired_count = ROW_COUNT;
  INSERT INTO cron_execution_log (job_name, status, message)
  VALUES ('expire-negotiations', 'success', expired_count || ' negosiasi expired');
END $$;
```
```sql
select status from negotiations where id = '$NEG_ID_VERIFY';
```
Expected: `status = 'expired'` (lowercase).

```bash
curl -s -X POST "https://rwxnjxmzkcfoddnzjosi.supabase.co/functions/v1/negotiations/$NEG_ID_VERIFY/messages" \
  -H "apikey: sb_publishable_-tmXQTkiRSNHtvjBVILpvA_oGVnliRX" \
  -H "Authorization: Bearer sb_publishable_-tmXQTkiRSNHtvjBVILpvA_oGVnliRX" -H "Content-Type: application/json" \
  -d '{"sender_id":"ed23f6a6-21cb-4576-89ac-d8bfdae08a78","action_type":"message","message_text":"test setelah fix"}'
```
Expected: **409**, `{"error":"Negosiasi sudah selesai — status: expired"}` — BUKAN 200 seperti sebelum fix.

---

### Task 5: Full logic regression — re-run semua skenario Sprint 10 yang tadinya PASS

**Files:**
- Modify: `docs/qa/e2e-buy-now.md`, `docs/qa/edge-case-checklist.md` (update status FAIL→PASS + tambahkan bagian "Verifikasi Pasca-Fix")

- [ ] **Step 1: `flutter analyze` + `flutter test`**

Run: `flutter analyze && flutter test`
Expected: `No issues found!`, `26/26 passed` — sama seperti sebelum fix (perubahan hanya di Edge Function/migration, tidak menyentuh kode Flutter).

- [ ] **Step 2: Smoke-check ulang FG-44 (negotiation pipeline) masih jalan normal**

```bash
curl -s -X POST "https://rwxnjxmzkcfoddnzjosi.supabase.co/functions/v1/negotiations" \
  -H "apikey: sb_publishable_-tmXQTkiRSNHtvjBVILpvA_oGVnliRX" \
  -H "Authorization: Bearer sb_publishable_-tmXQTkiRSNHtvjBVILpvA_oGVnliRX" -H "Content-Type: application/json" \
  -d '{"listing_id":"1786952b-1802-43e6-b6b0-236780899905","buyer_id":"ed23f6a6-21cb-4576-89ac-d8bfdae08a78","initial_price":20000,"quantity":1}'
```
Expected: 200, `negotiation_id` baru, `status=open` — flow negosiasi dasar tidak terpengaruh perubahan buy-now/cron.

- [ ] **Step 3: Smoke-check Buy Now jalur normal (non-race) masih PASS**

```sql
select quantity_available from listings where id = '1786952b-1802-43e6-b6b0-236780899905';
```
```bash
curl -s -X POST "https://rwxnjxmzkcfoddnzjosi.supabase.co/functions/v1/buy-now/1786952b-1802-43e6-b6b0-236780899905" \
  -H "apikey: sb_publishable_-tmXQTkiRSNHtvjBVILpvA_oGVnliRX" \
  -H "Authorization: Bearer $BUYER_JWT" -H "Content-Type: application/json" \
  -d '{"quantity":1,"buyer_id":"ed23f6a6-21cb-4576-89ac-d8bfdae08a78"}'
```
Expected: 200, `transaction_id` non-null, stok berkurang tepat 1 — jalur normal (bukan race) tetap berfungsi identik setelah fix.

- [ ] **Step 4: Smoke-check recurring order masih jalan (tidak tersentuh fix, tapi pastikan tidak ada regresi tidak langsung)**

```bash
curl -s -X POST "https://rwxnjxmzkcfoddnzjosi.supabase.co/functions/v1/check-recurring-orders" \
  -H "apikey: sb_publishable_-tmXQTkiRSNHtvjBVILpvA_oGVnliRX" \
  -H "Authorization: Bearer sb_publishable_-tmXQTkiRSNHtvjBVILpvA_oGVnliRX"
```
Expected: 200, response shape sama seperti biasa (`due_orders`, `notified`, `due_today`, `created`, `skipped`) — tidak error.

- [ ] **Step 5: Update dokumen QA**

Di `docs/qa/e2e-buy-now.md`: tambahkan bagian "## Verifikasi Pasca-Fix" mengutip hasil Task 4 Step 1 di atas, ubah kesimpulan Skenario 2 dari FAIL → **PASS (setelah fix)**.
Di `docs/qa/edge-case-checklist.md`: update baris 3 dari FAIL → **PASS (setelah fix)**, kutip hasil Task 4 Step 2.

---

### Task 6: Visual crosscheck di emulator — flow inti

**Files:** tidak ada file kode — verifikasi UI langsung, screenshot sebagai bukti.

**Scoping eksplisit:** crosscheck visual difokuskan ke flow inti yang paling berisiko kalau ada regresi tersembunyi (money-path + fitur Sprint 8-9), BUKAN klik-satu-per-satu semua layar di 10 sprint — proporsional dengan perubahan kode yang benar-benar terjadi (Edge Function + cron, bukan UI).

- [ ] **Step 1: Pastikan emulator jalan & app ter-install**

```bash
/Users/haimac/Library/Android/sdk/platform-tools/adb devices
```
Expected: `emulator-5554	device`. Kalau app belum jalan, `flutter run -d emulator-5554` dari root project (tunggu build selesai).

- [ ] **Step 2: Login sebagai buyer, screenshot home**

Login pakai `buyer.test@farmbridge.dev`. Screenshot:
```bash
/Users/haimac/Library/Android/sdk/platform-tools/adb -s emulator-5554 exec-out screencap -p > "/private/tmp/claude-501/-Users-haimac-AndroidStudioProjects-FarmBridge/f7f3c8ed-335a-4db2-989e-3cb296e89b54/scratchpad/vc_01_buyer_home.png"
```
Baca screenshot dengan tool Read untuk verifikasi visual layar tampil benar (bukan blank/error).

- [ ] **Step 3: Buka listing → mulai negosiasi → kirim counter → screenshot chat**

Navigasi ke listing test (`Listing Test FG-48 Fallback` atau listing lain yang aktif), buka chat negosiasi, kirim counter offer, screenshot:
```bash
/Users/haimac/Library/Android/sdk/platform-tools/adb -s emulator-5554 exec-out screencap -p > ".../scratchpad/vc_02_negotiation_chat.png"
```
Verifikasi via Read: banner status, tombol Terima/Tolak/Tawar muncul benar, tidak ada teks mentah "EXPIRED"/error.

- [ ] **Step 4: Buy Now dari listing lain → screenshot konfirmasi**

Lakukan Buy Now di listing berbeda (bukan yang stoknya baru direkonsiliasi), screenshot hasil/toast konfirmasi:
```bash
/Users/haimac/Library/Android/sdk/platform-tools/adb -s emulator-5554 exec-out screencap -p > ".../scratchpad/vc_03_buy_now.png"
```

- [ ] **Step 5: Logout, login sebagai farmer, buka transaksi pending → Tandai Terkirim → screenshot**

Login `farmer.test@farmbridge.dev`, buka transaction detail dari salah satu transaksi pending hasil test di atas, tap "Tandai Terkirim", screenshot hasil:
```bash
/Users/haimac/Library/Android/sdk/platform-tools/adb -s emulator-5554 exec-out screencap -p > ".../scratchpad/vc_04_fulfill.png"
```

- [ ] **Step 6: Buka Recurring Order Saya (icon autorenew di profile) → screenshot list & detail**

```bash
/Users/haimac/Library/Android/sdk/platform-tools/adb -s emulator-5554 exec-out screencap -p > ".../scratchpad/vc_05_recurring_list.png"
```
Tap salah satu item, screenshot detail:
```bash
/Users/haimac/Library/Android/sdk/platform-tools/adb -s emulator-5554 exec-out screencap -p > ".../scratchpad/vc_06_recurring_detail.png"
```

- [ ] **Step 7: Coba archive listing yang punya recurring order aktif → screenshot pesan error yang benar muncul di UI (bukan cuma di SQL)**

Buka "Listing Saya", tap archive pada listing yang terikat recurring order aktif, screenshot dialog/snackbar error:
```bash
/Users/haimac/Library/Android/sdk/platform-tools/adb -s emulator-5554 exec-out screencap -p > ".../scratchpad/vc_07_archive_blocked.png"
```
Expected: snackbar/dialog menampilkan pesan error dari trigger Postgres (`PostgrestException` ditangkap di `my_listings_screen.dart`), listing TIDAK ter-archive.

- [ ] **Step 8: Ringkas semua temuan visual**

Untuk setiap screenshot Step 2-7: baca via tool Read, catat pass/fail (tampilan sesuai ekspektasi, tidak ada crash/blank/teks error mentah).

---

### Task 7: Laporan konsolidasi

**Files:**
- Modify: `docs/Sprint 10/sprint10_hasil_akhir.md`

- [ ] **Step 1: Update laporan**

Tambahkan bagian "## Update Pasca-Fix (2026-07-17, lanjutan)" berisi:
- Ringkasan fix Task 1 & 2 (diff singkat + hasil deploy/migration)
- Hasil Task 4 (re-verifikasi 2 bug — sekarang PASS)
- Hasil Task 5 (regression logic — tidak ada yang rusak)
- Hasil Task 6 (crosscheck visual — pass/fail per screenshot)
- Status akhir: berapa dari 9 unit FG-48 + FG-46 sekarang PASS (target: 9/9 dan 2/2)
- Rekomendasi go/no-go untuk lanjut Sprint 11

---

## Self-Review

**Spec coverage:**
- Fix Buy Now race condition → Task 1.
- Fix EXPIRED case mismatch → Task 2.
- Data korup akibat pengujian bug → Task 3 (bagian dari "aman sebelum lanjut" yang diminta user, bukan scope asli tapi perlu supaya listing test tidak nyisa data cacat).
- Re-verifikasi bug benar-benar fixed → Task 4.
- "Check logic" → Task 5.
- "Check visual" → Task 6.
- Laporan akhir & rekomendasi lanjut/tidak → Task 7.

**Placeholder scan:** Task 4/6 punya beberapa nilai yang baru diketahui saat eksekusi (`$BUYER_JWT`, `$NEG_ID_VERIFY`, screenshot look) — ini bukan placeholder tersembunyi, melainkan nilai runtime yang memang baru ada saat command sebelumnya dijalankan (pola sama seperti seluruh sesi Sprint 10 sebelumnya, sudah terbukti bisa dieksekusi penuh).

**Konsistensi:** Task 1 memverifikasi fungsi shared yang dipakai (`lockInventoryOnAcceptWithQuantity`) sama persis dengan yang sudah diverifikasi benar di Sprint 10 Task 5 baris 5 (race condition negosiasi) — bukan asumsi baru. Task 3 derivasi angka `35` didokumentasikan penuh untuk audit, bukan angka ditebak.

**Dependency antar-task:** Task 1→4 (harus deploy dulu sebelum re-test race). Task 2→4 (migration harus di-apply dulu sebelum re-test expired-bypass). Task 3 independen, bisa kapan saja tapi logis setelah Task 1 (supaya tidak ada race baru yang mengotori ulang sebelum sempat direkonsiliasi). Task 5 & 6 butuh Task 1-4 selesai. Task 7 terakhir.
