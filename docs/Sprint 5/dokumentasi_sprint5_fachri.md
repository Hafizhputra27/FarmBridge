# Sprint 5 — Dokumentasi Fachri (FG-15)

**Tanggal:** 17 Juli 2026  
**Status:** ✅ Selesai & committed  
**Branch:** `fachri_dev`  
**Commit:** `8145cb3`

---

## Ringkasan

FG-15 Buyer Home Feed + Search & Filter — buyer bisa melihat semua listing dari semua farmer dengan filter kategori, region, dan rentang harga. Feed dengan infinite scroll dan pull-to-refresh.

---

## Deliverables

| File | Aksi | Detail |
|---|---|---|
| `lib/features/listing/screens/buyer_home_feed_screen.dart` | File baru | Grid feed 2 kolom, infinite scroll, pull-to-refresh |
| `lib/features/listing/screens/search_filter_screen.dart` | File baru | Filter kategori, region, rentang harga |
| `lib/core/router/app_router.dart` | Edit | `/buyer` + `/buyer/search` + `/farmer-profile/:id` stub |
| `supabase/migrations/20260717000000_listings_farmer_profiles_fk.sql` | File baru | FK `listings.farmer_id` → `farmer_profiles(user_id)` |

---

## Checklist FG-15

- [x] Home Feed: listing (foto, harga per unit, lokasi petani) dengan infinite scroll
- [x] Search page terpisah dengan filter: kategori, region, rentang harga
- [x] State hasil kosong yang jelas ("Tidak ada hasil")
- [x] State feed kosong per kategori
- [x] Tap listing/nama farmer → navigasi ke Farmer Public Profile stub

---

## Verifikasi

| Item | Hasil |
|---|---|
| `flutter analyze` | No issues found |
| `flutter test` | All tests passed |

---

## Catatan

- Feed menggunakan `ListingRepository.filterListings()` dari FG-13
- Data listing berasal dari FG-14 (Create Listing)
- Pagination: `limit(20)`, scroll controller untuk load more
- **FK Fix:** `listings.farmer_id` → `farmer_profiles(user_id)` — menyelesaikan error PostgREST `PGRST200` saat query join `.select('*, farmer_profiles(nama, lokasi)')`. Migration tercatat di `supabase/migrations/20260717000000_listings_farmer_profiles_fk.sql`
- Farmer profile screen asli di FG-16 (Hafizh, Sprint 6)
- Route stub: `/farmer-profile/:farmerId` → PlaceholderScreen

---

## Referensi

- `docs/Sprint 5/sprint5_fachri_dev.md`
- `docs/Sprint 5/projek_plan_fachri_sprint5.md`
- `docs/Sprint 4/dokumentasi_sprint4_fachri.md`
