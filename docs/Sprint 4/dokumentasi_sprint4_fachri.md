# Sprint 4 — Dokumentasi Fachri (FG-13 + FG-14)

**Tanggal:** 16 Juli 2026  
**Status:** ✅ Selesai  
**Branch:** `fachri_dev`

---

## Ringkasan

FG-13 (Listing filter endpoint) + FG-14 (Create/Edit Listing UI). Farmer bisa membuat listing baru dengan foto, mengedit listing, dan listing bisa difilter berdasarkan kategori/region/harga via PostgREST.

---

## Deliverables

| File | Aksi | Detail |
|---|---|---|
| `lib/features/listing/data/listing_repository.dart` | File baru | filterListings, getMyListings, create, update |
| `lib/features/listing/screens/listing_form.dart` | File baru | Shared form (create+edit), 6 field, validasi visual |
| `lib/features/listing/screens/create_listing_screen.dart` | File baru | Create/Edit wrapper |
| `lib/features/listing/screens/my_listings_screen.dart` | File baru | List + edit button |
| `lib/core/router/app_router.dart` | Edit | Route `/farmer/listings/*` nested |
| `lib/main.dart` | Edit | FCM try-catch untuk emulator |

---

## Checklist FG-13 + FG-14

- [x] Form create/edit: 6 field (foto, title, category, price+unit, qty stepper)
- [x] Validasi visual: border merah + error text, tombol disabled
- [x] 2 tombol foto: Take Photo + Choose from Gallery
- [x] Stepper kuantitas (minus/plus, min 1)
- [x] List listing farmer sendiri
- [x] Status langsung `active`
- [x] Edit mode: pre-filled, tombol "Save Changes"
- [x] ListingRepository: filterListings, getMyListings, create, update
- [x] Route /farmer/listings/* nested

- [ ] Filter GET /listings?category=...&harga=gte... — E2E test
- [ ] Test kombinasi filter — E2E test
- [ ] RLS: Farmer B tidak bisa edit listing Farmer A — E2E test

---

## Verifikasi

| Item | Hasil |
|---|---|
| `flutter analyze` | No issues found |
| `flutter test` | All tests passed |
| `flutter run` (Android) | App boots, Supabase init OK, role picker appears |
| E2E filter + RLS | Pending (waiting manual test) |

---

## Desain Final (Alexander)

Single page form, 6 field:
- Product Photo (Take Photo / Choose from Gallery)
- Listing Title (text input)
- Category (dropdown picker)
- Region (dropdown picker)
- Price per Unit (numeric + unit dropdown: kg/head/flat/box/ikat)
- Quantity Available (stepper minus/plus)

Validasi: border merah + error text per field, tombol disabled sampai valid.
Edit mode: form sama, pre-filled, tombol "Save Changes".

---

## Catatan

- 2 kolom baru `title` + `unit` ditambahkan ke tabel `listings` via SQL Editor
- FCM di-wrap try-catch di `main.dart` (emulator tanpa Google Play Services crash)
- `dart:io` File dipakai untuk upload foto ke Supabase Storage
- Listing feed buyer (FG-15, Sprint 5) akan query dari data FG-14
- List `listing-photos.xlsx` disarankan untuk mapping field yang akan muncul di feed buyer

---

## Referensi

- `docs/Sprint 4/sprint4_fachri_dev.md`
- `docs/Sprint 4/projek_plan_fachri_sprint4.md`
- PRD §3.1, §4.1, §9, §15
