# Sprint 5 — Dokumentasi Fachri (FG-15)

**Tanggal:** 16 Juli 2026  
**Status:** ✅ Selesai  
**Branch:** `fachri_dev`

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
- `farmer_profiles` join sudah include di query PostgREST
- Farmer profile screen asli di FG-16 (Hafizh, Sprint 6)
- Route stub: `/farmer-profile/:farmerId` → PlaceholderScreen

---

## Referensi

- `docs/Sprint 5/sprint5_fachri_dev.md`
- `docs/Sprint 5/projek_plan_fachri_sprint5.md`
- `docs/Sprint 4/dokumentasi_sprint4_fachri.md`
