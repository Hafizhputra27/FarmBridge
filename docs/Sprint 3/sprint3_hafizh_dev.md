> Direvisi 2026-07-14 — sinkron ulang dengan label JIRA (skema granular 13-sprint), menggantikan versi kompresi 6-sprint sebelumnya.

# Sprint 3: Seed Data & Role Picker Flow — Task Plan untuk Hafizh

## Peran di sprint ini
**Satu ticket: FG-7 (Seed price_reference_data awal).** Independen total dari FG-11 (Fachri) sprint ini — beda domain, tidak ada sync point teknis di antara keduanya. Tabel `price_reference_data` sudah ada sejak FG-2 (Sprint 1) dan RLS-nya sudah aktif sejak FG-3 (Sprint 2), jadi tidak ada blocker tersisa — tinggal eksekusi.

## Task Checklist

### FG-7 — Seed price_reference_data awal
- [ ] Dataset dummy untuk minimal 5-8 kategori produk pertanian × 2-3 region, dengan `avg_price`/`min_price`/`max_price` yang masuk akal
- [ ] Insert via seed script (`supabase/seed.sql`), bukan manual satu-satu — supaya bisa di-rerun
- [ ] Test: kategori/region yang ada di seed → `POST /price-recommendation` (Sprint 4, FG-23) akan mengembalikan `recommended_price` bukan null; kategori di luar seed → fallback sesuai §11 (belum ada endpoint-nya sprint ini, cukup pastikan data-nya siap dikonsumsi nanti)

## File/folder yang kamu sentuh
```
supabase/seed.sql
```

## Sync point dengan teammate
- **Kabari Hafizh-di-masa-depan (dirimu sendiri di Sprint 4)**: begitu FG-7 selesai, data ini langsung dipakai FG-23 (`POST /price-recommendation`, sprint depan, juga ticketmu).
- Tidak ada dependency masuk dari Nevan/Fachri sprint ini.

## Definition of Done
- [ ] `price_reference_data` terisi lewat `supabase/seed.sql`, bisa di-rerun tanpa duplikasi — **cara cek**: jalankan seed script 2x, pastikan tidak ada row ganda (pakai `on conflict do nothing`/`upsert` kalau perlu)
- [ ] Data mencakup minimal 5-8 kategori × 2-3 region dengan angka harga yang masuk akal (bukan angka acak)

## Referensi PRD
§2.3, §9 (price_reference_data, konteks untuk FG-23 di Sprint 4).
