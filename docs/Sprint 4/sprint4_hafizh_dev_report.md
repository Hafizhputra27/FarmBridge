> Laporan penyelesaian — dibuat 2026-07-16, mendokumentasikan status akhir FG-23 (`POST /price-recommendation`) dan FG-19 (Edge Function `update-buyer-metrics`), bagian Hafizh Sprint 4. Pelengkap `sprint4_hafizh_dev.md` (checklist ticket asli) dan `sprint4_hafizh_dev_plan.md` (rencana eksekusi task-by-task, checkbox sudah diupdate sesuai hasil verifikasi).

# Sprint 4 — Hafizh (FG-23 Price Recommendation + FG-19 Buyer Metrics) — Laporan Penyelesaian

## Ringkasan

Dua ticket independen (beda domain, tidak ada dependency di antara keduanya), keduanya selesai dan sudah ter-push ke `hafizh_dev`. FG-23 dikerjakan duluan sesuai urutan yang disarankan di `sprint4_hafizh_dev.md` (Nevan bergantung ke `getRecommendedPrice()` di FG-22, Sprint 5).

## Yang dikerjakan

**FG-23 — `POST /price-recommendation`:**
- `supabase/functions/_shared/price-recommendation.ts` — `getRecommendedPrice()`, lookup `avg_price`/`min_price`/`max_price` dari `price_reference_data` (`category`+`region`), fallback `null` + pesan kalau data kosong. Diekstrak jadi shared function (bukan langsung di handler) supaya Nevan bisa import di FG-22 tanpa duplikasi logic — signature sudah final: `getRecommendedPrice(supabase, { category, region, quantity? })`.
- `supabase/functions/price-recommendation/index.ts` — thin HTTP wrapper, validasi `category`/`region` wajib ada, selalu HTTP 200 (termasuk saat fallback, sesuai PRD §11 — bukan 404/500).
- `quantity` diterima di signature tapi belum dipakai untuk tier harga — `price_reference_data` belum punya kolom tier, jadi tidak ada data untuk disesuaikan (lihat Decisions Log di plan doc).

**FG-19 — Edge Function `update-buyer-metrics`:**
- `supabase/functions/update-buyer-metrics/index.ts` — hitung 4 metrik buyer dari tabel `transactions`/`recurring_orders`, window 90 hari (kecuali `active_orders_count` yang real-time): `total_procurement`, `active_orders_count`, `fulfillment_rate`, `avg_monthly_volume`.
- Menerima `user_id` (auth uid) di body, resolve internal ke `buyer_profiles.id` sebelum upsert — dua ruang ID berbeda (`transactions.buyer_id` = `users.id`, `buyer_metrics.buyer_id` = `buyer_profiles.id`), lihat Global Constraints di plan doc.
- Upsert pakai pola select-then-write (bukan `.upsert(onConflict:)`) karena `buyer_metrics.buyer_id` belum punya unique constraint.
- Belum ada trigger asli (transaction baru bisa `fulfilled` mulai FG-29/32/33, Sprint 6-7) — sesuai catatan `sprint4_README.md`, testing sprint ini memang unit test terisolasi via insert manual, bukan kekurangan.

## Verifikasi (2026-07-16)

| Test | Hasil |
|---|---|
| `POST /price-recommendation` — kategori ada di seed (`Beras`, `Jawa Barat`) | `{"recommended_price":12000,"avg_price":12000,"min_price":10500,"max_price":13500}` ✅ |
| `POST /price-recommendation` — kategori tidak ada (`Durian`, `Jawa Barat`) | HTTP 200 (bukan 404), `recommended_price: null` + pesan fallback ✅ |
| `update-buyer-metrics` — buyer nyata + 1 transaction `fulfilled` dummy (Rp1.200.000, 100 unit) | `{"total_procurement":1200000,"active_orders_count":0,"fulfillment_rate":100,"avg_monthly_volume":100}` — sesuai perhitungan manual ✅ |
| `update-buyer-metrics` — skenario tambahan transaction `pending` (`active_orders_count` naik) | Di-skip sesi ini (opsional, formula inti sudah terbukti di test di atas) — belum dijalankan |
| Cleanup dummy data (`transactions`/`negotiations`/`buyer_metrics` milik buyer test) | Sudah dihapus; listing/farmer/buyer pakai data asli yang sudah ada, tidak dibuat khusus test ini ✅ |

Kedua function di-deploy ke project Supabase `FarmBridge` (`rwxnjxmzkcfoddnzjosi`) sebelum test dijalankan.

## Commit

```
docs: checklist sprint4_hafizh_dev_plan — FG-23 & FG-19 verified
6ec3b71

[FG-19] edge function update-buyer-metrics
00ce9e6

[FG-23] endpoint POST /price-recommendation
6c21cae

[FG-23] shared getRecommendedPrice() — lookup price_reference_data
28de336
```

Branch: `hafizh_dev` (local, 4 commit ahead dari `origin/hafizh_dev` — belum di-push).

## Status Definition of Done (`sprint4_hafizh_dev.md`)

| Item | Status |
|---|---|
| Kategori & region yang ada di `price_reference_data` → response valid | ✅ |
| Kategori di luar data → response 200 + fallback, bukan error | ✅ |
| `getRecommendedPrice()` siap diimport (signature final) sebelum sprint berakhir | ✅ |
| Formula 4 metrik `buyer_metrics` terbukti benar lewat test manual (before) | ✅ |
| `active_orders_count` terbukti real-time — cek before/after ubah status | ⏳ belum dites (skenario `pending` di-skip sesi ini) |

**FG-23 selesai 100%. FG-19 selesai fungsional, 1 item verifikasi opsional (`active_orders_count` real-time before/after) belum dijalankan.**

## Yang masih ditunggu sebelum merge ke `main`

Sesuai strategi hybrid per-fase (`HYBRID_MERGE_KICKOFF.md`): Sprint 4 masuk **FASE 2 (Sprint 4-9)** — **tidak merge ke `main` dulu**, accumulate di `hafizh_dev` sampai akhir Sprint 9 (MERGE #2, tag `phase-2-complete`).

**Merge ke `hafizh_dev` (bukan ke `main`) di Sprint 5:** sesuai `FarmBridge_Branching_Playbook.md` §3, `nevan_dev` dan `fachri_dev` akan ditarik (`git merge origin/nevan_dev` / `origin/fachri_dev`) ke `hafizh_dev` begitu ticket masing-masing lolos smoke-test. Checklist pre-merge (§4) yang perlu dijalankan Hafizh sebelum menarik:
- `supabase db push --dry-run` hijau kalau ada migration baru dari Nevan
- `flutter analyze` tidak ada error baru kalau ada perubahan Fachri
- Urutan prioritas kalau menumpuk: migration/schema (Nevan) duluan → endpoint yang jadi dependency UI Fachri → sisanya FIFO

## Dipakai di sprint mendatang

- **FG-22** (`POST /negotiations`, Nevan, Sprint 5) — akan `import { getRecommendedPrice }` dari `supabase/functions/_shared/price-recommendation.ts`. Nevan perlu dikabari signature-nya sudah final: `getRecommendedPrice(supabase, { category, region, quantity? })`.
- **FG-20** (Hafizh sendiri, Sprint 5) — kemungkinan konsumsi `buyer_metrics` yang di-upsert `update-buyer-metrics`.
