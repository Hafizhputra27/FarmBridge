> Direvisi 2026-07-14 — sinkron ulang dengan label JIRA (skema granular 13-sprint), menggantikan versi kompresi 6-sprint sebelumnya.

# Sprint 4: Listing Management & Trust/Buyer Metrics Functions — Task Plan untuk Fachri

## Peran di sprint ini
**2 ticket berurutan: FG-13 (endpoint filter listing) dan FG-14 (Create/Edit Listing UI).** FG-15 (Home Feed + Search) yang dulu satu paket dengan dua ticket ini sekarang resmi pindah ke Sprint 5 — supaya kamu punya data listing asli (dari FG-14) sebelum mulai membangun feed-nya.

**Kenapa FG-13 dulu, baru FG-14**: FG-13 murni kerjaan query/RLS (PostgREST filter kombinasi kategori+region+harga), tidak butuh apapun dari ticket lain — paling aman dikerjakan duluan buat pemanasan.

## Sebelum mulai — cek dulu
- [ ] **Pastikan open question 3 varian "Create Listing" di Figma sudah terjawab** (diminta ditanyakan sejak Sprint 1-2). Kalau belum, ini prioritas #1 sebelum baris kode pertama FG-14.
- [ ] Tarik `hafizh_dev` terbaru (hasil Sprint 1-3: schema, RLS, bucket `listing-photos`, seed price_reference_data, role picker jalan)

## Task Checklist

### FG-13 — Endpoint & query listing filter (PostgREST)
- [ ] Pastikan `GET /listings` (auto dari PostgREST) mendukung filter kombinasi: `category=eq.X`, `region=eq.Y`, `price_per_unit=gte.A&price_per_unit=lte.B`
- [ ] Test kombinasi filter (kategori+region+range harga bersamaan)
- [ ] Pastikan RLS `listings` mengizinkan semua role baca (publik), tapi hanya farmer pemilik yang bisa insert/update/delete listing miliknya — **ini sudah dipasang Nevan di FG-3 (Sprint 2), tugasmu di sini cuma verifikasi**, bukan pasang ulang
- [ ] TIDAK termasuk: full text search nama listing (tidak diminta PRD)

### FG-14 — Farmer: Create/Edit Listing UI + upload foto
- [ ] Form create/edit listing: foto (upload ke bucket `listing-photos`), kategori, harga per unit, kuantitas tersedia
- [ ] Validasi input: harga > 0, kuantitas > 0, foto wajib minimal 1
- [ ] List listing milik farmer sendiri (untuk edit) di Farmer Dashboard
- [ ] Listing yang di-submit langsung status `active`, tanpa approval (§14 — moderasi konten out of scope)

## File/folder yang kamu sentuh
```
lib/features/listing/**  (create/edit form)
lib/features/listing/data/listing_repository.dart  (query builder untuk filter PostgREST)
```

## Sync point dengan teammate
- **Koordinasi dengan Hafizh** soal nama route untuk buka profil farmer dari listing (mis. `/farmer-profile/:id`) — dipakai nanti di FG-15 (Sprint 5, milikmu) dan FG-16 (Sprint 6, Hafizh).

## Definition of Done
- [ ] `GET /listings?category=eq.sayuran&price_per_unit=gte.10000&price_per_unit=lte.50000` mengembalikan hasil sesuai kombinasi filter — **cara cek**: test manual lewat Postman/curl beberapa kombinasi
- [ ] Farmer B tidak bisa update listing milik Farmer A — **cara cek**: coba update dari akun berbeda, harus ditolak RLS
- [ ] Farmer bisa create + edit listing dengan foto, tersimpan ke tabel `listings` & bucket `listing-photos` — **cara cek**: video demo end-to-end
- [ ] Input tidak lengkap (harga 0/foto kosong) ditolak dengan validasi jelas, tidak tersimpan

## Referensi PRD
§3.1, §4.1, §9, §15 (termasuk catatan "3 varian Create Listing — konfirmasi mana final").
