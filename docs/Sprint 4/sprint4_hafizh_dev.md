> Direvisi 2026-07-14 — sinkron ulang dengan label JIRA (skema granular 13-sprint), menggantikan versi kompresi 6-sprint sebelumnya.

# Sprint 4: Listing Management & Trust/Buyer Metrics Functions — Task Plan untuk Hafizh

## Peran di sprint ini
**2 ticket independen: FG-19 (Edge Function update buyer_metrics) dan FG-23 (POST /price-recommendation + fallback).** Beda domain total — tidak ada dependency di antara keduanya, bisa dikerjakan dengan urutan bebas. Satu-satunya hal yang membuat FG-23 lebih genting: hasil kerjamu di situ akan diimport Nevan sprint depan (FG-22), jadi selesaikan dengan kontrak function yang jelas dan stabil.

## Urutan kerja yang disarankan
1. **FG-23 duluan** (prioritas) — Nevan Sprint 5 (FG-22) bergantung pada function shared-nya, jadi lebih aman ada waktu tenggang untuk kamu memastikan signature-nya stabil sebelum sprint ini berakhir.
2. **FG-19** — independen, bisa mulai kapan saja, tidak ada yang menunggu ini secara mendesak (dipakai FG-20 di Sprint 5 milikmu sendiri).

## Task Checklist

### FG-23 — POST /price-recommendation + fallback
- [x] `POST /price-recommendation`: `{ category, region, quantity }` → `{ recommended_price, avg_price, min_price, max_price }` — diverifikasi via curl, `Beras`/`Jawa Barat` → data valid
- [x] Rule-based: lookup `avg_price` dari `price_reference_data` (FG-7, Sprint 3) yang cocok `category` & `region`, sesuaikan dengan tier harga by `quantity` kalau tersedia — lookup selesai; tier-by-quantity tidak diimplementasi karena `price_reference_data` belum punya kolom tier sama sekali ("kalau tersedia" = tidak tersedia, jadi vacuously selesai — lihat Decisions Log di plan doc)
- [x] Fallback: response 200 dengan `recommended_price: null` + pesan "Data referensi belum tersedia untuk kategori ini" kalau data kosong — **BUKAN error 404/500** (§11) — diverifikasi via curl, `Durian`/`Jawa Barat` → HTTP 200 + pesan fallback
- [x] **Ekstrak logic lookup-nya jadi function terpisah** (bukan langsung di handler endpoint) supaya Nevan bisa import di FG-22 (Sprint 5), bukan menyalin ulang logic yang sama — `_shared/price-recommendation.ts`
- [x] Pastikan signature function final & stabil sebelum sprint ini selesai — beri tahu Nevan begitu siap diimport — Nevan sudah dikonfirmasi

**Detail teknis — lokasi shared function**:
```
supabase/functions/_shared/price-recommendation.ts
  export async function getRecommendedPrice(category, region, quantity) {
    // lookup price_reference_data, return { recommended_price, avg_price, min_price, max_price }
  }
```
Endpoint `POST /price-recommendation` kamu sendiri tinggal jadi thin wrapper yang panggil function ini.

### FG-19 — Edge Function update buyer_metrics
- [x] `total_procurement` = SUM(`total_amount`) transaksi fulfilled milik buyer tsb, 90 hari — diverifikasi via test manual, Rp1.200.000 sesuai dummy transaction
- [x] `active_orders_count` = COUNT(pending) + COUNT(recurring_orders active) — **real-time, BUKAN rolling window** (beda dari 3 metrik lain) — formula terverifikasi lewat code review (query independen tiap invoke, tidak ada cache); skenario before/after eksplisit belum dijalankan, lihat DoD di bawah
- [x] `fulfillment_rate` = (fulfilled) / (total pernah pending untuk buyer tsb) × 100%, 90 hari — diverifikasi 100% sesuai 1/1 transaction fulfilled
- [x] `avg_monthly_volume` = rata-rata SUM(`delivered_quantity`) per bulan, 90 hari (3 bulan window) — diverifikasi 100 sesuai dummy
- [x] Trigger dipicu setelah transaction berubah `fulfilled` (sama pola seperti trust_metrics — belum ada trigger asli sampai Sprint 6-7, test manual dulu) — sesuai desain, test manual (insert dummy) sudah dilakukan
- [x] Buyer tanpa transaksi apapun → `fulfillment_rate`/`avg_monthly_volume` = 0/null, bukan error — dijamin kode (`transactions.length === 0 ? 0`, `monthlyTotals.size === 0 ? null`), dikonfirmasi tidak langsung lewat `GET /buyer-metrics` (Sprint 5) yang menunjukkan default 0/null untuk buyer tanpa baris metrics

## File/folder yang kamu sentuh
```
supabase/functions/price-recommendation/**  (thin wrapper endpoint, FG-23)
supabase/functions/_shared/price-recommendation.ts  (shared logic, dipakai Nevan di Sprint 5)
supabase/functions/update-buyer-metrics/**  (FG-19)
```

## Sync point dengan teammate
- **Beri tahu Nevan** begitu `getRecommendedPrice()` (FG-23) stabil — dia akan mengimportnya di Sprint 5 (FG-22), bukan Hari-1 coordination lagi karena beda sprint, tapi tetap perlu kepastian kontraknya sebelum sprint ini berakhir.
- Tidak ada dependency masuk untuk FG-19 sprint ini.

## Potensi conflict & cara handle
- File `_shared/price-recommendation.ts` cuma kamu yang mengubah — Nevan cukup import di FG-22 (Sprint 5). Kalau dia butuh perubahan, minta dikomunikasikan dulu, bukan langsung edit.

## Definition of Done
- [x] Kategori & region yang ada di `price_reference_data` → response berisi `recommended_price`/`avg_price`/`min_price`/`max_price` valid
- [x] Kategori di luar data yang ada → response 200 dengan `recommended_price: null` + pesan fallback, bukan error
- [x] Function `getRecommendedPrice()` siap diimport (signature final, tidak akan berubah tanpa komunikasi) sebelum sprint berakhir — Nevan sudah dikonfirmasi
- [x] Formula 4 metrik buyer_metrics terbukti benar lewat test manual (before) — **cara cek**: insert dummy transaction, verifikasi angka — dilakukan, cocok
- [ ] `active_orders_count` terbukti real-time (bukan snapshot lama) — **cara cek**: ubah status transaction/recurring_order dummy, cek angka langsung berubah tanpa trigger tambahan — *skenario before/after ini di-skip sesi verifikasi (formula sudah benar lewat code review, tapi belum dibuktikan empiris dengan test ini)*

## Referensi PRD
§2.3 (formula recommended_price & Trust/Buyer Metrics), §9, §10.2, §11, §12 (Data Integrity).
