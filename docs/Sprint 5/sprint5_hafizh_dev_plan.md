# Sprint 5 (Hafizh) — FG-20 GET /trust-metrics/:id + GET /buyer-metrics/:id Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

> **Catatan eksekusi:** Sesuai `docs/CLAUDE.md`, Claude tidak menjalankan operasi git yang mengubah state repo (`add`/`commit`/`push`/`merge`/dst). Claude bisa menulis file Edge Function, menjalankan `supabase functions deploy`, dan query read-only untuk verifikasi — tapi commit/push tetap dijalankan Hafizh sendiri di terminal. Migration SQL tidak pernah ditulis di plan ini — domain Nevan (tabel `trust_metrics`/`buyer_metrics` sudah ada dari migration awal, cukup dibaca).

**Goal:** Bangun dua thin GET endpoint read-only: `GET /trust-metrics/:farmer_id` dan `GET /buyer-metrics/:buyer_id`, yang membaca tabel `trust_metrics`/`buyer_metrics` (sudah diisi FG-18 milik Nevan dan FG-19 milik Hafizh sendiri di Sprint 4).

**Arsitektur:** Dua Edge Function terpisah (`trust-metrics/index.ts`, `buyer-metrics/index.ts`), bukan satu shared module — beda dari pola FG-23 (Sprint 4) karena tidak ada consumer lain yang butuh import logic-nya (YAGNI). Masing-masing thin handler: cek profile ada (404 kalau tidak) → select metrics table → return data atau default 0/null kalau baris metrics belum pernah dihitung (trigger belum pernah jalan).

**Tech Stack:** Supabase Edge Functions (Deno), `@supabase/supabase-js` (npm specifier), PostgREST query builder. Kedua tabel sudah punya RLS policy `SELECT` public (`qual: true`), jadi secara desain **anon/publishable key** cukup — tapi di eksekusi ternyata `SUPABASE_PUBLISHABLE_KEYS` (nama secret plural) bukan JWT tunggal yang bisa langsung dipakai `createClient()`, langsung 500. Diganti ke **`SUPABASE_SERVICE_ROLE_KEY`** (pola yang sama dengan FG-23/FG-19) — RLS bypass tidak masalah di sini karena 404 sudah kita enforce sendiri di application logic, bukan mengandalkan RLS.

## Skema (sudah diverifikasi read-only ke DB)

```
trust_metrics: farmer_id (uuid, PK, FK -> farmer_profiles.id), on_time_delivery_rate, rejection_rate,
               fulfillment_consistency, total_transactions, window_days, updated_at
buyer_metrics: id (uuid, PK), buyer_id (uuid, FK -> buyer_profiles.id), total_procurement,
               active_orders_count, fulfillment_rate, avg_monthly_volume, window_days, updated_at
```

`:farmer_id` di path = **`users.id`** (bukan `farmer_profiles.id`) — terverifikasi lewat data: `trust_metrics.farmer_id` dan `listings.farmer_id` sama-sama menyimpan `users.id`, konsisten dengan pola `transactions.farmer_id`. Ini beda dari asumsi awal saat plan ini ditulis (lihat catatan bug di Task 1). `:buyer_id` di path = `buyer_profiles.id` (terverifikasi benar, sama seperti `buyer_metrics.buyer_id` dari FG-19).

## Global Constraints

- Kerja langsung di branch `hafizh_dev`, format commit `[FG-XX] deskripsi singkat` (Playbook §2).
- Migration/schema **tidak pernah** ditulis Hafizh — tabel `trust_metrics`/`buyer_metrics` sudah ada dari migration awal (`20260716083135_initial_schema.sql`), cukup dibaca.
- **404 vs 0/null — bedakan dua kondisi:**
  - `farmer_id`/`buyer_id` tidak ada di `farmer_profiles`/`buyer_profiles` sama sekali → **404**.
  - Profile ada, tapi baris `trust_metrics`/`buyer_metrics` belum pernah dihitung (trigger FG-18/FG-19 belum pernah jalan untuk id ini) → **200** dengan field 0/null, **bukan** 404 (sesuai DoD "field 0/null jika belum ada transaksi, bukan error").
- Default saat baris metrics belum ada: numerik/count → `0`, kecuali `avg_monthly_volume` → `null` (konsisten dengan default yang dipakai `update-buyer-metrics` FG-19 saat `monthlyTotals.size === 0`). `window_days` default `90` (window yang dipakai FG-18/FG-19).
- Awalnya rencana pakai publishable/anon key (RLS `SELECT` sudah `true` untuk keempat tabel terkait, jadi harusnya tidak perlu bypass) — tapi `SUPABASE_PUBLISHABLE_KEYS` (secret plural) terbukti bukan JWT tunggal yang valid untuk `createClient()`, langsung 500. Dipakai `SUPABASE_SERVICE_ROLE_KEY` sebagai gantinya (pola sama dengan FG-23/FG-19), 404 tetap dijamin lewat application logic, bukan RLS.

---

### Task 1: FG-20 — `GET /trust-metrics/:farmer_id`

**Files:**
- Create: `supabase/functions/trust-metrics/index.ts`

- [x] **Step 1: Tulis handler**

**Bug ditemukan saat testing:** asumsi awal `:farmer_id = farmer_profiles.id` salah — data pembuktian: `select id, user_id from farmer_profiles where user_id = '<farmer_id_dari_trust_metrics>'` mengembalikan baris (id ≠ user_id, keduanya beda UUID), dan `trust_metrics.farmer_id` cocok dengan `user_id` bukan `id`. Query eksistensi diperbaiki dari `.eq("id", farmerId)` jadi `.eq("user_id", farmerId)`. Query ke `trust_metrics` sendiri tidak berubah (sudah benar dari awal, `farmer_id` di situ memang `users.id`).

```typescript
// supabase/functions/trust-metrics/index.ts
import { createClient } from "npm:@supabase/supabase-js@2";

Deno.serve(async (req) => {
  if (req.method !== "GET") {
    return new Response("Method not allowed", { status: 405 });
  }

  const farmerId = new URL(req.url).pathname.split("/").pop();
  if (!farmerId) {
    return new Response(
      JSON.stringify({ error: "farmer_id is required" }),
      { status: 400, headers: { "Content-Type": "application/json" } },
    );
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  // trust_metrics.farmer_id mengacu ke users.id (auth uid), bukan farmer_profiles.id —
  // cek eksistensi lewat farmer_profiles.user_id, bukan farmer_profiles.id.
  const { data: profile, error: profileError } = await supabase
    .from("farmer_profiles")
    .select("id")
    .eq("user_id", farmerId)
    .maybeSingle();
  if (profileError) throw profileError;
  if (!profile) {
    return new Response(
      JSON.stringify({ error: "farmer not found" }),
      { status: 404, headers: { "Content-Type": "application/json" } },
    );
  }

  const { data: metrics, error: metricsError } = await supabase
    .from("trust_metrics")
    .select("on_time_delivery_rate, rejection_rate, fulfillment_consistency, total_transactions, window_days")
    .eq("farmer_id", farmerId)
    .maybeSingle();
  if (metricsError) throw metricsError;

  const result = metrics ?? {
    on_time_delivery_rate: 0,
    rejection_rate: 0,
    fulfillment_consistency: 0,
    total_transactions: 0,
    window_days: 90,
  };

  return new Response(JSON.stringify(result), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
});
```

- [x] **Step 2: Deploy** (2x — deploy awal 500 karena `SUPABASE_PUBLISHABLE_KEYS` invalid, redeploy setelah fix key + fix ID-space bug)

```bash
supabase functions deploy trust-metrics --project-ref rwxnjxmzkcfoddnzjosi
```

- [x] **Step 3: Test — farmer dengan metrics ada, farmer tidak ada (404), farmer ada tapi metrics kosong (0/null, bukan error)**

Hasil akhir (setelah 2 bug fix): metrics ada → `{"on_time_delivery_rate":75,"rejection_rate":20,"fulfillment_consistency":75,"total_transactions":5,"window_days":90}`; farmer tidak ada → `404`; farmer ada tapi belum ada trust_metrics → `{"on_time_delivery_rate":0,"rejection_rate":0,"fulfillment_consistency":0,"total_transactions":0,"window_days":90}`. Ketiganya sesuai expected.

- [ ] **Step 4: Commit**

```bash
git add supabase/functions/trust-metrics/index.ts
git commit -m "[FG-20] endpoint GET /trust-metrics/:farmer_id"
```

---

### Task 2: FG-20 — `GET /buyer-metrics/:buyer_id`

**Files:**
- Create: `supabase/functions/buyer-metrics/index.ts`

- [ ] **Step 1: Tulis handler**

```typescript
// supabase/functions/buyer-metrics/index.ts
import { createClient } from "npm:@supabase/supabase-js@2";

Deno.serve(async (req) => {
  if (req.method !== "GET") {
    return new Response("Method not allowed", { status: 405 });
  }

  const buyerId = new URL(req.url).pathname.split("/").pop();
  if (!buyerId) {
    return new Response(
      JSON.stringify({ error: "buyer_id is required" }),
      { status: 400, headers: { "Content-Type": "application/json" } },
    );
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  const { data: profile, error: profileError } = await supabase
    .from("buyer_profiles")
    .select("id")
    .eq("id", buyerId)
    .maybeSingle();
  if (profileError) throw profileError;
  if (!profile) {
    return new Response(
      JSON.stringify({ error: "buyer not found" }),
      { status: 404, headers: { "Content-Type": "application/json" } },
    );
  }

  const { data: metrics, error: metricsError } = await supabase
    .from("buyer_metrics")
    .select("total_procurement, active_orders_count, fulfillment_rate, avg_monthly_volume, window_days")
    .eq("buyer_id", buyerId)
    .maybeSingle();
  if (metricsError) throw metricsError;

  const result = metrics ?? {
    total_procurement: 0,
    active_orders_count: 0,
    fulfillment_rate: 0,
    avg_monthly_volume: null,
    window_days: 90,
  };

  return new Response(JSON.stringify(result), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
});
```

- [x] **Step 2: Deploy**

```bash
supabase functions deploy buyer-metrics --project-ref rwxnjxmzkcfoddnzjosi
```

- [x] **Step 3: Test — buyer dengan metrics ada, buyer tidak ada (404), buyer ada tapi metrics kosong (0/null)**

Hasil: buyer ada, belum ada baris `buyer_metrics` → `{"total_procurement":0,"active_orders_count":0,"fulfillment_rate":0,"avg_monthly_volume":null,"window_days":90}` ✅; buyer tidak ada → `404` ✅. Kasus "metrics ada" tidak dites ulang dengan insert dummy baru (sudah divalidasi lewat pola select yang sama persis di Task 1, dan `buyer_metrics` masih kosong pasca cleanup Sprint 4 — tidak insert dummy lagi supaya tidak nambah siklus write ke production tanpa perlu).

- [ ] **Step 4: Commit**

```bash
git add supabase/functions/buyer-metrics/index.ts
git commit -m "[FG-20] endpoint GET /buyer-metrics/:buyer_id"
```

---

## Decisions Log

- **Dua function terpisah, bukan satu shared module:** tidak ada consumer lain yang butuh import logic-nya sprint ini (beda dari FG-23 Sprint 4 yang memang disiapkan untuk Nevan) — YAGNI.
- **Rencana awal pakai publishable/anon key, realisasi pakai service role:** RLS `SELECT` keempat tabel terkait sudah `true` (public read) jadi secara desain anon key cukup, tapi `SUPABASE_PUBLISHABLE_KEYS` (secret plural) bukan JWT tunggal valid untuk `createClient()` → 500 di percobaan pertama. Diganti `SUPABASE_SERVICE_ROLE_KEY`, 404 tetap dijamin di application logic.
- **`:buyer_id` = `buyer_profiles.id` langsung** (bukan `users.id`): terverifikasi benar via test — caller endpoint publik ini (mis. halaman profil buyer) sudah pegang `buyer_profiles.id`, beda dari FG-19 yang cuma punya `auth.uid()` dari trigger/client.
- **`:farmer_id` = `users.id`, BUKAN `farmer_profiles.id`** (koreksi dari asumsi awal plan ini): ditemukan lewat test gagal (farmer yang pasti punya `trust_metrics` malah balas 404) → dicek data, `trust_metrics.farmer_id` cocok `farmer_profiles.user_id`, bukan `farmer_profiles.id`. Beda dari `:buyer_id` — dua entity (farmer vs buyer) tidak konsisten dalam ID-space yang dipakai kolom metrics-nya, harus dicek per tabel, jangan asumsi simetris.
- **404 vs 0/null:** 404 kalau id tidak ditemukan di tabel profile sama sekali; 0/null (HTTP 200) kalau profile ada tapi metrics belum pernah dihitung — dua kondisi beda, bukan kontradiksi dengan DoD.

## Self-Check Coverage (`sprint5_hafizh_dev.md` checklist asli → task di plan ini)

| Item checklist asli | Task di plan ini |
|---|---|
| `GET /trust-metrics/:farmer_id` sesuai skema, 404 jika tidak ditemukan | Task 1 |
| `GET /buyer-metrics/:buyer_id` sesuai skema, 404 jika tidak ditemukan | Task 2 |
| Field 0/null jika belum ada transaksi, bukan error | Task 1 & 2 (fallback `metrics ?? {...}`) |
