> Direvisi 2026-07-14 — sinkron ulang dengan label JIRA (skema granular 13-sprint), menggantikan versi kompresi 6-sprint sebelumnya.

# Sprint 3: Seed Data & Role Picker Flow — Task Plan untuk Hafizh

## Peran di sprint ini
**Satu ticket: FG-7 (Seed price_reference_data awal).** Independen total dari FG-11 (Fachri) sprint ini — beda domain, tidak ada sync point teknis di antara keduanya. Tabel `price_reference_data` sudah ada sejak FG-2 (Sprint 1) dan RLS-nya sudah aktif sejak FG-3 (Sprint 2), jadi tidak ada blocker tersisa — tinggal eksekusi.

## Task Checklist

### FG-7 — Seed price_reference_data awal
- [x] Dataset dummy untuk minimal 5-8 kategori produk pertanian × 2-3 region, dengan `avg_price`/`min_price`/`max_price` yang masuk akal — 6 kategori (Beras, Cabai Merah, Bawang Merah, Tomat, Jagung, Kentang) × 3 region (Jawa Barat/Tengah/Timur), 18 baris, semua `min_price < avg_price < max_price`
- [x] Insert via seed script (`supabase/seed.sql`), bukan manual satu-satu — supaya bisa di-rerun — `DELETE`+`INSERT`, diuji rerun 2x tetap 18 baris (tidak dobel)
- [x] Test: data siap dikonsumsi nanti (endpoint `POST /price-recommendation` sendiri belum ada sprint ini, sesuai catatan) — diverifikasi lewat RLS public read + `curl` sebagai `anon` key, HTTP 200, data lengkap terbaca

## File/folder yang kamu sentuh
```
supabase/seed.sql
```

## Sync point dengan teammate
- **Kabari Hafizh-di-masa-depan (dirimu sendiri di Sprint 4)**: begitu FG-7 selesai, data ini langsung dipakai FG-23 (`POST /price-recommendation`, sprint depan, juga ticketmu).
- Tidak ada dependency masuk dari Nevan/Fachri sprint ini.

## Definition of Done
- [x] `price_reference_data` terisi lewat `supabase/seed.sql`, bisa di-rerun tanpa duplikasi — **cara cek**: jalankan seed script 2x, pastikan tidak ada row ganda (pakai `on conflict do nothing`/`upsert` kalau perlu) — **diverifikasi 2026-07-16**, tetap 18 baris setelah rerun
- [x] Data mencakup minimal 5-8 kategori × 2-3 region dengan angka harga yang masuk akal (bukan angka acak) — 6 kategori × 3 region

## Referensi PRD
§2.3, §9 (price_reference_data, konteks untuk FG-23 di Sprint 4).
