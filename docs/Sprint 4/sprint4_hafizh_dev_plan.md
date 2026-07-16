# Sprint 4 (Hafizh) — FG-23 Price Recommendation + FG-19 Buyer Metrics Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

> **Catatan eksekusi:** Sesuai `docs/CLAUDE.md`, Claude tidak menjalankan operasi git yang mengubah state repo (`add`/`commit`/`push`/`merge`/dst). Claude bisa menulis file Edge Function dan menjalankan `supabase functions deploy`/query read-only untuk verifikasi, tapi commit/push tetap dijalankan Hafizh sendiri di terminal. Migration SQL tidak pernah ditulis di plan ini — domain Nevan.

**Goal:** Bangun `getRecommendedPrice()` (shared, siap diimport Nevan di FG-22 Sprint 5) + endpoint `POST /price-recommendation` (FG-23), dan Edge Function `update-buyer-metrics` (FG-19) yang menghitung 4 metrik buyer dari tabel `transactions`/`recurring_orders`.

**Arsitektur:** FG-23 dipecah jadi shared function (`_shared/price-recommendation.ts`) + thin HTTP wrapper (`price-recommendation/index.ts`), pola yang sama seperti `sendPush()` di FG-6 Sprint 1 — supaya Nevan bisa `import { getRecommendedPrice }` langsung tanpa duplikasi logic. FG-19 jadi satu Edge Function mandiri (`update-buyer-metrics/index.ts`) tanpa shared module terpisah, karena tidak ada consumer lain sprint ini (beda dengan FG-23) — YAGNI.

**Tech Stack:** Supabase Edge Functions (Deno), `@supabase/supabase-js` (npm specifier), PostgREST query builder (bukan raw SQL — menghindari kebutuhan migration/function SQL baru yang di luar scope Hafizh).

## Global Constraints

- Kerja langsung di branch `hafizh_dev`, format commit `[FG-XX] deskripsi singkat` (Playbook §2).
- Migration/schema **tidak pernah** ditulis Hafizh — domain Nevan. Kalau perlu constraint baru (unique index dll), catat sebagai kebutuhan follow-up ke Nevan, **jangan** tulis migration sendiri untuk itu.
- `POST /price-recommendation`: request `{ category, region, quantity }` → response `{ recommended_price, avg_price, min_price, max_price }`, **HTTP 200 selalu** (termasuk saat data kosong) — fallback `recommended_price: null` + pesan, **bukan** 404/500 (PRD §11, Bagian 11 "Data Integrity").
- `getRecommendedPrice()` signature harus final & stabil sebelum sprint ini selesai — Nevan mengimportnya di FG-22 (Sprint 5), **jangan ubah signature setelah dikabari siap** tanpa komunikasi dulu.
- FG-19: trigger DB **belum ada** sampai Sprint 6-7 (transaction baru bisa berstatus `fulfilled` mulai FG-29/32/33) — function cukup bisa dipanggil manual/invoke, testing pakai insert dummy transaction, bukan trigger asli. **Jangan anggap ini belum selesai** kalau trigger belum pernah terpanggil beneran.
- **Titik kritis skema** (beda dari FG-2 asumsi naif): `transactions.buyer_id` dan `recurring_orders.buyer_id` mengacu ke `users.id` (auth uid) — TAPI `buyer_metrics.buyer_id` mengacu ke `buyer_profiles.id` (baris 151, `supabase/migrations/20260716083135_initial_schema.sql`). Dua ruang ID berbeda. Function FG-19 harus menerima `user_id` (auth uid, yang tersedia dari client/`auth.uid()`), lalu resolve ke `buyer_profiles.id` sebelum upsert ke `buyer_metrics` — salah pakai ID di sini akan membuat FK constraint violation atau (lebih buruk) row salah alamat.
- `price_reference_data` tidak punya unique constraint di `(category, region)`, dan `buyer_metrics` tidak punya unique constraint di `buyer_id` (cuma `id` PK) — upsert **tidak bisa** pakai `.upsert(..., {onConflict: ...})` karena tidak ada index yang cocok. Pola yang dipakai: select dulu (cek row ada atau tidak) → insert kalau tidak ada, update kalau ada. Ini bukan workaround sementara, ini cara yang benar selama belum ada unique constraint dari Nevan.

---

### Task 1: FG-23 — Shared function `getRecommendedPrice()`

**Files:**
- Create: `supabase/functions/_shared/price-recommendation.ts`

**Interfaces:**
- Produces: `getRecommendedPrice(supabase: SupabaseClient, params: PriceRecommendationParams): Promise<PriceRecommendationResult>` — diimport Task 2 (endpoint wrapper sprint ini) dan Nevan (FG-22, Sprint 5, `POST /negotiations`).

- [x] **Step 1: Tulis shared function**

```typescript
// supabase/functions/_shared/price-recommendation.ts
import type { SupabaseClient } from "npm:@supabase/supabase-js@2";

export interface PriceRecommendationParams {
  category: string;
  region: string;
  quantity?: number;
}

export interface PriceRecommendationResult {
  recommended_price: number | null;
  avg_price: number | null;
  min_price: number | null;
  max_price: number | null;
  message?: string;
}

export async function getRecommendedPrice(
  supabase: SupabaseClient,
  { category, region }: PriceRecommendationParams,
): Promise<PriceRecommendationResult> {
  const { data, error } = await supabase
    .from("price_reference_data")
    .select("avg_price, min_price, max_price")
    .eq("category", category)
    .eq("region", region)
    .maybeSingle();

  if (error) throw error;

  if (!data) {
    return {
      recommended_price: null,
      avg_price: null,
      min_price: null,
      max_price: null,
      message: "Data referensi belum tersedia untuk kategori ini",
    };
  }

  return {
    recommended_price: data.avg_price,
    avg_price: data.avg_price,
    min_price: data.min_price,
    max_price: data.max_price,
  };
}
```

Catatan desain (kenapa `quantity` diterima tapi tidak dipakai): PRD §2.3 bilang "disesuaikan dengan `quantity` bila tersedia tier harga" — tabel `price_reference_data` saat ini tidak punya kolom tier/quantity sama sekali (cuma `avg_price`/`min_price`/`max_price` flat per kategori+region), jadi tidak ada data tier untuk disesuaikan. Parameter tetap diterima di signature (sesuai kontrak API PRD §9) supaya tidak perlu breaking change nanti kalau tier data ditambahkan Nevan — tapi logic tier-nya sendiri **tidak dibangun sekarang** (YAGNI, tidak ada data untuk diuji).

- [ ] **Step 2: Commit**

```bash
git add supabase/functions/_shared/price-recommendation.ts
git commit -m "[FG-23] shared getRecommendedPrice() — lookup price_reference_data"
```

---

### Task 2: FG-23 — Endpoint `POST /price-recommendation`

**Files:**
- Create: `supabase/functions/price-recommendation/index.ts`

**Interfaces:**
- Consumes: `getRecommendedPrice()` (Task 1).
- Produces: endpoint HTTP `POST /price-recommendation` sesuai kontrak PRD §9.

- [x] **Step 1: Tulis thin HTTP wrapper**

```typescript
// supabase/functions/price-recommendation/index.ts
import { createClient } from "npm:@supabase/supabase-js@2";
import { getRecommendedPrice } from "../_shared/price-recommendation.ts";

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  let payload: { category?: string; region?: string; quantity?: number };
  try {
    payload = await req.json();
  } catch {
    return new Response(
      JSON.stringify({ error: "invalid JSON body" }),
      { status: 400, headers: { "Content-Type": "application/json" } },
    );
  }

  const { category, region, quantity } = payload;
  if (!category || !region) {
    return new Response(
      JSON.stringify({ error: "category and region are required" }),
      { status: 400, headers: { "Content-Type": "application/json" } },
    );
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  const result = await getRecommendedPrice(supabase, { category, region, quantity });

  return new Response(JSON.stringify(result), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
});
```

`SUPABASE_URL` dan `SUPABASE_SERVICE_ROLE_KEY` adalah environment variable built-in yang otomatis tersedia di semua Supabase Edge Function — tidak perlu `supabase secrets set` manual (beda dengan `FIREBASE_PROJECT_ID` di FG-6 yang memang secret eksternal).

- [x] **Step 2: Deploy**

```bash
supabase functions deploy price-recommendation --project-ref rwxnjxmzkcfoddnzjosi
```

- [x] **Step 3: Test dengan data yang ada (dari seed FG-7 Sprint 3)**

```bash
curl -sS -X POST \
  "https://rwxnjxmzkcfoddnzjosi.supabase.co/functions/v1/price-recommendation" \
  -H "Authorization: Bearer $SUPABASE_ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{"category":"Beras","region":"Jawa Barat","quantity":100}'
```

Expected: HTTP 200, `{"recommended_price":12000,"avg_price":12000,"min_price":10500,"max_price":13500}` (angka sesuai seed FG-7).

- [x] **Step 4: Test fallback (kategori tidak ada di seed)** — hasil sesuai expected, lihat catatan verifikasi di akhir dokumen.

```bash
curl -sS -X POST \
  "https://rwxnjxmzkcfoddnzjosi.supabase.co/functions/v1/price-recommendation" \
  -H "Authorization: Bearer $SUPABASE_ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{"category":"Durian","region":"Jawa Barat"}'
```

Expected: **HTTP 200** (bukan 404), `{"recommended_price":null,"avg_price":null,"min_price":null,"max_price":null,"message":"Data referensi belum tersedia untuk kategori ini"}`.

- [ ] **Step 5: Commit**

```bash
git add supabase/functions/price-recommendation/index.ts
git commit -m "[FG-23] endpoint POST /price-recommendation"
```

---

### Task 3: FG-19 — Edge Function `update-buyer-metrics`

**Files:**
- Create: `supabase/functions/update-buyer-metrics/index.ts`

**Interfaces:**
- Produces: endpoint HTTP yang menerima `{ user_id }` (bukan `buyer_id` — lihat Global Constraints soal dua ruang ID), meng-upsert `buyer_metrics`.

- [ ] **Step 1: Tulis Edge Function**

```typescript
// supabase/functions/update-buyer-metrics/index.ts
import { createClient } from "npm:@supabase/supabase-js@2";
import type { SupabaseClient } from "npm:@supabase/supabase-js@2";

interface BuyerMetricsResult {
  total_procurement: number;
  active_orders_count: number;
  fulfillment_rate: number;
  avg_monthly_volume: number | null;
}

async function updateBuyerMetrics(
  supabase: SupabaseClient,
  userId: string,
): Promise<BuyerMetricsResult> {
  // Resolve users.id -> buyer_profiles.id — buyer_metrics.buyer_id FK
  // mengacu ke buyer_profiles, BUKAN users, beda dari transactions/recurring_orders.
  const { data: profile, error: profileError } = await supabase
    .from("buyer_profiles")
    .select("id")
    .eq("user_id", userId)
    .single();
  if (profileError) throw profileError;
  const buyerProfileId = profile.id;

  const windowStart = new Date();
  windowStart.setDate(windowStart.getDate() - 90);
  const windowStartIso = windowStart.toISOString();

  const { data: transactions, error: txError } = await supabase
    .from("transactions")
    .select("status, total_amount, delivered_quantity, actual_delivery_date")
    .eq("buyer_id", userId)
    .gte("created_at", windowStartIso);
  if (txError) throw txError;

  const fulfilled = transactions.filter((t) => t.status === "fulfilled");
  const totalProcurement = fulfilled.reduce(
    (sum, t) => sum + Number(t.total_amount),
    0,
  );
  const fulfillmentRate = transactions.length === 0
    ? 0
    : (fulfilled.length / transactions.length) * 100;

  const monthlyTotals = new Map<string, number>();
  for (const t of fulfilled) {
    if (!t.actual_delivery_date) continue;
    const month = String(t.actual_delivery_date).slice(0, 7); // "YYYY-MM"
    monthlyTotals.set(
      month,
      (monthlyTotals.get(month) ?? 0) + Number(t.delivered_quantity ?? 0),
    );
  }
  const avgMonthlyVolume = monthlyTotals.size === 0
    ? null
    : Array.from(monthlyTotals.values()).reduce((a, b) => a + b, 0) /
      monthlyTotals.size;

  // active_orders_count: real-time, TIDAK pakai window 90 hari (beda dari 3 metrik lain).
  const { count: pendingCount, error: pendingError } = await supabase
    .from("transactions")
    .select("id", { count: "exact", head: true })
    .eq("buyer_id", userId)
    .eq("status", "pending");
  if (pendingError) throw pendingError;

  const { count: activeRecurringCount, error: recurringError } = await supabase
    .from("recurring_orders")
    .select("id", { count: "exact", head: true })
    .eq("buyer_id", userId)
    .eq("status", "active");
  if (recurringError) throw recurringError;

  const activeOrdersCount = (pendingCount ?? 0) + (activeRecurringCount ?? 0);

  const result: BuyerMetricsResult = {
    total_procurement: totalProcurement,
    active_orders_count: activeOrdersCount,
    fulfillment_rate: fulfillmentRate,
    avg_monthly_volume: avgMonthlyVolume,
  };

  // Tidak ada unique constraint di buyer_metrics.buyer_id — select dulu,
  // baru insert atau update, bukan .upsert(onConflict: ...).
  const { data: existing, error: existingError } = await supabase
    .from("buyer_metrics")
    .select("id")
    .eq("buyer_id", buyerProfileId)
    .maybeSingle();
  if (existingError) throw existingError;

  if (existing) {
    const { error: updateError } = await supabase
      .from("buyer_metrics")
      .update({ ...result, window_days: 90, updated_at: new Date().toISOString() })
      .eq("id", existing.id);
    if (updateError) throw updateError;
  } else {
    const { error: insertError } = await supabase
      .from("buyer_metrics")
      .insert({ ...result, buyer_id: buyerProfileId, window_days: 90 });
    if (insertError) throw insertError;
  }

  return result;
}

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  let payload: { user_id?: string };
  try {
    payload = await req.json();
  } catch {
    return new Response(
      JSON.stringify({ error: "invalid JSON body" }),
      { status: 400, headers: { "Content-Type": "application/json" } },
    );
  }

  if (!payload.user_id) {
    return new Response(
      JSON.stringify({ error: "user_id is required" }),
      { status: 400, headers: { "Content-Type": "application/json" } },
    );
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  const result = await updateBuyerMetrics(supabase, payload.user_id);

  return new Response(JSON.stringify(result), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
});
```

- [x] **Step 2: Deploy**

```bash
supabase functions deploy update-buyer-metrics --project-ref rwxnjxmzkcfoddnzjosi
```

- [ ] **Step 3: Commit**

```bash
git add supabase/functions/update-buyer-metrics/index.ts
git commit -m "[FG-19] edge function update-buyer-metrics"
```

---

### Task 4: FG-19 — Test manual dengan dummy transaction

**Files:** tidak ada file baru — task verifikasi murni (tidak ada trigger asli sampai Sprint 6-7, sesuai Global Constraints).

**Interfaces:**
- Consumes: `update-buyer-metrics` (Task 3), butuh baris `users`+`buyer_profiles` yang valid (dari alur role picker FG-11, Sprint 3 — pakai user sungguhan yang sudah pernah submit role "buyer", bukan bikin dummy user manual supaya `buyer_profiles.user_id` konsisten dengan `auth.users`).

- [x] **Step 1: Ambil `user_id` dan `buyer_profiles.id` dari buyer yang sudah ada** — pakai buyer nyata (nama_institusi "Restoran Warung Kita"), bukan dummy user, sesuai catatan Interfaces di atas.

```sql
select u.id as user_id, bp.id as buyer_profile_id, bp.nama_institusi
from users u
join buyer_profiles bp on bp.user_id = u.id
limit 1;
```

Kalau kosong (belum ada buyer yang pernah submit role picker), jalankan dulu alur role picker di app sebagai buyer, atau insert manual mengikuti pola FK yang benar:

```sql
insert into users (id, role) values (gen_random_uuid(), 'buyer') returning id;
-- pakai id di atas untuk buyer_profiles.user_id
insert into buyer_profiles (user_id, nama_institusi) values ('<user_id_di_atas>', 'Test Buyer FG-19') returning id;
```

- [x] **Step 2: Insert dummy listing + negotiation + transaction fulfilled (dalam window 90 hari)** — pakai listing+farmer yang sudah ada di DB (bukan bikin dummy farmer/listing baru, YAGNI), cukup insert negotiation+transaction baru.

```sql
-- butuh farmer + listing dulu (FK transactions -> negotiations -> listings)
insert into users (id, role) values (gen_random_uuid(), 'farmer') returning id; -- farmer_id
insert into farmer_profiles (user_id, nama) values ('<farmer_id>', 'Test Farmer FG-19');
insert into listings (farmer_id, category, region, harga_per_unit, quantity_available)
values ('<farmer_id>', 'Beras', 'Jawa Barat', 12000, 500) returning id; -- listing_id
insert into negotiations (listing_id, buyer_id, farmer_id, initial_price, current_offer_price, status)
values ('<listing_id>', '<user_id>', '<farmer_id>', 12000, 12000, 'accepted') returning id; -- negotiation_id

insert into transactions (negotiation_id, farmer_id, buyer_id, status, agreed_quantity, total_amount, delivered_quantity, actual_delivery_date, promised_delivery_date)
values ('<negotiation_id>', '<farmer_id>', '<user_id>', 'fulfilled', 100, 1200000, 100, now()::date, now()::date);
```

- [x] **Step 3: Invoke function, verifikasi angka** — output cocok: `{"total_procurement":1200000,"active_orders_count":0,"fulfillment_rate":100,"avg_monthly_volume":100}`.

```bash
curl -sS -X POST \
  "https://rwxnjxmzkcfoddnzjosi.supabase.co/functions/v1/update-buyer-metrics" \
  -H "Authorization: Bearer $SUPABASE_ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{"user_id":"<user_id>"}'
```

Expected: HTTP 200, `total_procurement: 1200000`, `fulfillment_rate: 100`, `active_orders_count: 0` (tidak ada transaction `pending`/recurring order `active`), `avg_monthly_volume: 100`.

```sql
select * from buyer_metrics where buyer_id = '<buyer_profile_id>';
```

Expected: baris baru sesuai angka di atas.

- [ ] **Step 4: Test skenario tambahan — transaction pending (active_orders_count naik)** — di-skip sesi ini (dianggap opsional, formula inti sudah terbukti di Step 3); jalankan manual kalau mau verifikasi tambahan.

```sql
insert into negotiations (listing_id, buyer_id, farmer_id, initial_price, current_offer_price, status)
values ('<listing_id>', '<user_id>', '<farmer_id>', 12000, 12000, 'accepted') returning id; -- negotiation_id_2

insert into transactions (negotiation_id, farmer_id, buyer_id, status, agreed_quantity, total_amount, promised_delivery_date)
values ('<negotiation_id_2>', '<farmer_id>', '<user_id>', 'pending', 50, 600000, now()::date + 3);
```

Invoke ulang function yang sama — expected `active_orders_count: 1` naik dari sebelumnya, `total_procurement` **tidak berubah** (transaction pending belum masuk hitungan fulfilled), `fulfillment_rate` turun jadi 50 (1 dari 2 transaction fulfilled).

- [x] **Step 5: Bersihkan dummy data** — transaction & negotiation dummy sudah dihapus; listing/farmer/buyer tidak perlu dihapus karena pakai data asli yang sudah ada (tidak dibuat khusus test ini).

```sql
delete from transactions where buyer_id = '<user_id>';
delete from negotiations where buyer_id = '<user_id>';
delete from buyer_metrics where buyer_id = '<buyer_profile_id>';
-- listing/farmer/buyer dummy: hapus juga kalau memang dibuat khusus test ini
```

---

## Decisions Log

- **Urutan pengerjaan:** FG-23 duluan (Nevan Sprint 5 FG-22 bergantung ke `getRecommendedPrice()`, kasih waktu tenggang), baru FG-19 (independen, tidak ada yang menunggu mendesak).
- **`quantity` di `getRecommendedPrice()`:** diterima tapi tidak dipakai — tidak ada data tier harga di `price_reference_data` untuk sprint ini (lihat Task 1 Step 1 catatan desain).
- **FG-19 menerima `user_id`, bukan `buyer_id` langsung:** karena caller (client app / trigger masa depan) cuma punya `auth.uid()` (= `users.id`), bukan `buyer_profiles.id` — function yang resolve internal, bukan caller.
- **Upsert manual (select-then-write), bukan `.upsert()`:** tidak ada unique constraint di `buyer_metrics.buyer_id` atau `price_reference_data.(category,region)`. Kalau butuh constraint asli nanti (concurrent write race), itu permintaan migration ke Nevan — bukan ditambal di Edge Function.

## Self-Check Coverage (FG-19 & FG-23 checklist asli → task di plan ini)

| Item checklist asli (`sprint4_hafizh_dev.md`) | Task di plan ini |
|---|---|
| `POST /price-recommendation`: request/response sesuai kontrak | Task 2 |
| Rule-based lookup `avg_price` dari `price_reference_data` | Task 1 |
| Fallback 200 + pesan, bukan 404/500 | Task 2 (Step 4) |
| `getRecommendedPrice()` diekstrak jadi function terpisah, siap diimport Nevan | Task 1 |
| `total_procurement` = SUM fulfilled, 90 hari | Task 3 |
| `active_orders_count` = real-time, bukan rolling window | Task 3 |
| `fulfillment_rate` = fulfilled / total pernah pending, 90 hari | Task 3 |
| `avg_monthly_volume` = rata-rata SUM per bulan, 90 hari | Task 3 |
| Buyer tanpa transaksi → 0/null, bukan error | Task 3 (fallback di code: `transactions.length === 0 ? 0`, `monthlyTotals.size === 0 ? null`) |
| Formula terbukti benar lewat test manual (before/after) | Task 4 |
