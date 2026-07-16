> Laporan penyelesaian — dibuat 2026-07-17, mendokumentasikan status akhir FG-20 (`GET /trust-metrics/:farmer_id` + `GET /buyer-metrics/:buyer_id`), bagian Hafizh Sprint 5. Pelengkap `sprint5_hafizh_dev.md` (checklist ticket asli, sudah full `[x]`) dan `sprint5_hafizh_dev_plan.md` (rencana eksekusi task-by-task, termasuk catatan bug yang ditemukan saat testing).

# Sprint 5 — Hafizh (FG-20 Trust/Buyer Metrics Endpoints) — Laporan Penyelesaian

## Ringkasan

Satu ticket, ringan, tanpa dependency masuk (FG-18 Nevan & FG-19 Hafizh sudah selesai dari Sprint 4). Selesai 100%, termasuk satu bug ID-space yang ditemukan dan diperbaiki di tengah proses testing.

## Yang dikerjakan

- `supabase/functions/trust-metrics/index.ts` — `GET /trust-metrics/:farmer_id`: cek `farmer_profiles` ada (404 kalau tidak) → select `trust_metrics` → return data atau default 0 kalau baris metrics belum pernah dihitung.
- `supabase/functions/buyer-metrics/index.ts` — `GET /buyer-metrics/:buyer_id`: pola sama untuk `buyer_profiles`/`buyer_metrics`.
- Dua Edge Function terpisah, bukan shared module — beda dari FG-23 (Sprint 4) karena tidak ada consumer lain yang butuh import logic-nya sprint ini (YAGNI).

## Bug ditemukan & diperbaiki saat testing

**Asumsi awal salah (di plan): `:farmer_id` = `farmer_profiles.id`.** Test pertama ke farmer yang pasti punya `trust_metrics` malah balas 404. Dicek data: `farmer_profiles.id` ≠ `farmer_profiles.user_id`, dan `trust_metrics.farmer_id` ternyata cocok ke `user_id`, bukan `id` — sama seperti trap ID-space yang sudah dicatat di FG-19 (Sprint 4), tapi kali ini jatuh ke jebakan yang sama meski sudah ada peringatannya di plan. Fix: query eksistensi diubah dari `.eq("id", farmerId)` jadi `.eq("user_id", farmerId)`. Setelah fix, ketiga skenario (data ada, 404, 0/null) lolos.

**Bug kedua (lebih kecil):** rencana awal pakai `SUPABASE_PUBLISHABLE_KEYS` (RLS `SELECT` sudah public untuk keempat tabel terkait) — ternyata secret itu bukan JWT tunggal yang valid untuk `createClient()`, langsung 500 di semua request. Diganti `SUPABASE_SERVICE_ROLE_KEY` (pola sama dengan FG-23/FG-19 di Sprint 4), 404 tetap dijamin lewat application logic, bukan RLS.

`:buyer_id` = `buyer_profiles.id` terbukti benar dari awal, tidak ada bug di sisi ini.

## Verifikasi (2026-07-17)

| Test | Hasil |
|---|---|
| `GET /trust-metrics/:farmer_id` — farmer dengan `trust_metrics` ada | `{"on_time_delivery_rate":75,"rejection_rate":20,"fulfillment_consistency":75,"total_transactions":5,"window_days":90}` ✅ |
| `GET /trust-metrics/:farmer_id` — farmer tidak ada | HTTP 404 ✅ |
| `GET /trust-metrics/:farmer_id` — farmer ada, `trust_metrics` belum pernah dihitung | `{"on_time_delivery_rate":0,"rejection_rate":0,"fulfillment_consistency":0,"total_transactions":0,"window_days":90}` ✅ |
| `GET /buyer-metrics/:buyer_id` — buyer ada, `buyer_metrics` kosong | `{"total_procurement":0,"active_orders_count":0,"fulfillment_rate":0,"avg_monthly_volume":null,"window_days":90}` ✅ |
| `GET /buyer-metrics/:buyer_id` — buyer tidak ada | HTTP 404 ✅ |

Skenario "buyer dengan `buyer_metrics` ada" tidak dites ulang dengan insert dummy baru — pola select-nya identik dengan `trust-metrics` yang sudah tervalidasi ada-datanya, dan `buyer_metrics` masih kosong pasca cleanup Sprint 4, jadi tidak nambah siklus write ke production tanpa perlu.

Kedua function di-deploy ke project Supabase `FarmBridge` (`rwxnjxmzkcfoddnzjosi`) — masing-masing 2x (deploy awal gagal karena bug key, redeploy setelah fix).

## Commit

```
docs: checklist sprint5_hafizh_dev_plan — FG-20 verified
6714850

[FG-20] endpoint GET /buyer-metrics/:buyer_id
80b2015

[FG-20] endpoint GET /trust-metrics/:farmer_id
9b16ca6
```

Branch: `hafizh_dev`, sudah sinkron dengan `origin/hafizh_dev`.

## Status Definition of Done (`sprint5_hafizh_dev.md`)

| Item | Status |
|---|---|
| `GET /trust-metrics/:id` & `GET /buyer-metrics/:id` sesuai skema, 404 untuk id tidak ditemukan | ✅ |
| Farmer/buyer tanpa transaksi apapun → field 0/null, bukan error | ✅ |

**FG-20 selesai 100%.**

## Yang masih ditunggu sebelum merge ke `main`

Masih FASE 2 (Sprint 4-9) sesuai `HYBRID_MERGE_KICKOFF.md` — **tidak** merge ke `main` sampai akhir Sprint 9. Rencana merge `nevan_dev`/`fachri_dev` ke `hafizh_dev` disepakati di **Sprint 6** (bukan per-tiket-selesai seperti Playbook default) — jadi FG-20 accumulate dulu di `hafizh_dev`, ditarik bareng nanti.

**Drift yang perlu diperhatikan sebelum merge Sprint 6:** `supabase db push --dry-run` di local `hafizh_dev` menunjukkan remote DB sudah punya migration `20260716164950` yang tidak ada di `supabase/migrations/` lokal — kemungkinan sudah di-apply langsung dari `nevan_dev` tapi branch-nya belum ditarik. Bukan blocker sekarang, tapi cek ulang saat pre-merge checklist Sprint 6 (Playbook §4).

## Dipakai di sprint mendatang

- **FG-16** (Profile UI, Sprint 6, Hafizh sendiri) — akan mengonsumsi kedua endpoint ini untuk menampilkan trust/buyer metrics di halaman profil publik.
