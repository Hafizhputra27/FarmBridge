# Project Plan: FG-13 + FG-14 — Sprint 4

> Dibuat 16 Juli 2026 · Fachri · Sprint 4 Listing Management

---

## Ringkasan

| | |
|---|---|
| **Ticket** | FG-13 (Listing filter) + FG-14 (Create/Edit Listing UI) |
| **PIC** | Fachri |
| **Sprint** | 4 — Listing Management & Metrics Functions |
| **Dependency** | FG-3 Auth (Sprint 2), FG-11 Role Picker (Sprint 3) |
| **Branch** | `fachri_dev` |
| **Estimasi** | 90-120 menit |

---

## Status Prasyarat

| Prasyarat | Status | Catatan |
|---|---|---|
| Tarik `hafizh_dev` terbaru (Sprint 1-3) | ✅ Sudah sinkron | Semua fix integrasi ada |
| RLS `listings` (public read, self write) | ✅ Dari Sprint 2 | `auth.uid() = farmer_id` |
| Bucket `listing-photos` | ✅ Dari Sprint 2 | Farmer upload, public read |
| Seed `price_reference_data` | ✅ Dari Sprint 3 | 6 kategori × 3 region |
| Auth + role picker live | ✅ Dari Sprint 3 | `signInAnonymously()` + `saveProfile()` |
| 3 varian Create Listing Figma | ✅ Dikonfirmasi Alexander | Single page, 6 field, lihat detail di bawah |
| Kolom `title` + `unit` di tabel `listings` | ⚠️ **Perlu migration** | Harus ada sebelum FG-14 coding |

---

## Task Breakdown

```
FG-13 (independen, 30 mnt) ──► FG-14 (60-90 mnt)

├── FG-13: Listing Query Builder
│   ├── T1: Buat listing_repository.dart
│   ├── T2: Verifikasi filter PostgREST
│   └── T3: Commit FG-13
│
├── FG-14: Create/Edit Listing UI
│   ├── T4: Konfirmasi varian Create Listing Figma ✅
│   ├── T5: Buat ListingForm widget
│   ├── T6: Buat CreateListingScreen
│   ├── T7: Buat MyListingsScreen
│   ├── T8: Wire routes ke GoRouter
│   └── T9: Verifikasi end-to-end
│
└── T10: flutter analyze + flutter test
```

---

## Checklist FG-13 + FG-14 (dari `sprint4_fachri_dev.md`)

- [ ] Pastikan `GET /listings` mendukung filter kombinasi: category, region, harga range
- [ ] Test kombinasi filter (kategori + region + range harga bersamaan)
- [ ] Pastikan RLS listings: public read, farmer-only write
- [x] Form create/edit listing: product photo, listing title, category, price + unit, quantity stepper
- [x] Validasi visual: border merah + error text per field, tombol disabled sampai semua valid
- [x] Foto: 2 tombol "Take Photo" (kamera) + "Choose from Gallery"
- [x] Kuantitas: stepper (minus/plus), bukan input angka manual
- [x] List listing milik farmer sendiri (untuk edit)
- [x] Listing yang di-submit langsung status `active`, tanpa approval
- [x] Edit mode: form sama, pre-filled, tombol "Save Changes"

### Mapping Checklist → Task

| Item Checklist | Task |
|---|---|
| Filter kombinasi category + region + harga | T1 (listing_repository) + T2 (verifikasi) |
| RLS listings verified | T2 |
| Form create/edit + foto upload + stepper + validasi visual | T5 (ListingForm) + T6 (CreateListingScreen) |
| Validasi input | T5 (validator per field) |
| List listing farmer sendiri | T7 (MyListingsScreen) |
| Status langsung `active` | T6 (onSubmit) |

---

## Deliverables

| File | Aksi | Output |
|---|---|---|
| `lib/features/listing/data/listing_repository.dart` | File baru | Query builder PostgREST |
| `lib/features/listing/screens/create_listing_screen.dart` | File baru | Form create + edit (shared) |
| `lib/features/listing/screens/my_listings_screen.dart` | File baru | List + edit button |
| `lib/core/router/app_router.dart` | Edit | Tambah route `/farmer/listings/*` |
| `test/widget_test.dart` | Edit | Update test |

---

## Spesifikasi Teknis

### T1 — `listing_repository.dart`

PostgREST auto-generate filter dari query parameter. Repository hanya query builder Dart:

```dart
class ListingRepository {
  final _client = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> filterListings({
    String? category,
    String? region,
    double? minPrice,
    double? maxPrice,
  }) async {
    var query = _client
        .from('listings')
        .select('*, farmer_profiles(nama, lokasi)')
        .eq('status', 'active');

    if (category != null) query = query.eq('category', category);
    if (region != null) query = query.eq('region', region);
    if (minPrice != null) query = query.gte('harga_per_unit', minPrice);
    if (maxPrice != null) query = query.lte('harga_per_unit', maxPrice);

    return query.order('created_at', ascending: false);
  }

  Future<List<Map<String, dynamic>>> getMyListings(String farmerId) {
    return _client
        .from('listings')
        .select()
        .eq('farmer_id', farmerId)
        .order('created_at', ascending: false);
  }

  Future<void> create(Map<String, dynamic> data) {
    return _client.from('listings').insert(data);
  }

  Future<void> update(String id, Map<String, dynamic> data) {
    return _client.from('listings').update(data).eq('id', id);
  }
}
```

### T2 — Verifikasi Filter PostgREST

Uji lewat Supabase Studio → SQL Editor atau REST API:

```
GET /rest/v1/listings?category=eq.Sayuran&harga_per_unit=gte.10000&harga_per_unit=lte.50000&status=eq.active
```

Verifikasi RLS: coba update listing milik farmer lain → harus ditolak 401/403.

### T4 — Desain Final Alexander (Confirmed ✅)

**Single page form, 6 field:**

| # | Field | Widget | Validasi |
|---|---|---|---|
| 1 | Product Photo | 2 tombol: "Take Photo" (kamera) + "Choose from Gallery" | Field error merah + teks jika belum upload |
| 2 | Listing Title | `TextFormField` | Tidak boleh kosong |
| 3 | Category | `DropdownButtonFormField` (tap pilih dari list) | Harus dipilih |
| 4 | Price per Unit | `TextFormField` (angka) + `DropdownButtonFormField` (unit: kg/head/flat/dll) | Harga > 0, unit harus dipilih |
| 5 | Quantity Available | **Stepper** (tombol -/plus, bukan input manual) | Minimal 1 |
| 6 | Publish Button | `ElevatedButton` sticky di bawah | Disabled sampai semua valid |

**Layout:**
- Foto di paling atas, full-width — elemen pertama
- Field lain 1 kolom vertikal ke bawah (bukan grid 2 kolom)
- Tombol "Publish Listing" (solid hijau) sticky di bagian paling bawah

**Validasi visual:**
- Field yang error: border merah + teks error kecil di bawah field
- Tombol publish disabled sampai semua field valid
- Bukan snackbar — error muncul inline di field

**Edit mode:** Form yang sama persis, semua field pre-filled, tombol jadi "Save Changes"

### ⚠️ Migration yang Diperlukan

Tabel `listings` perlu 2 kolom baru yang TIDAK ADA di schema saat ini:

```sql
ALTER TABLE listings ADD COLUMN title text;
ALTER TABLE listings ADD COLUMN unit text;
```

**Fachri harus koordinasi dengan Nevan** untuk menambahkan ini sebelum FG-14 coding. Tanpa kolom `title` dan `unit`, form tidak bisa menyimpan data.

### T5 — ListingForm Widget (shared create + edit)

**Form fields + widget + validasi:**

| Field | Widget | Validator |
|---|---|---|
| Product Photo | `InkWell` preview foto + 2 `ElevatedButton` ("Take Photo" / "Choose from Gallery") | `foto_url == null` → error "Minimal 1 foto wajib" |
| Listing Title | `TextFormField` | `isEmpty` → "Judul tidak boleh kosong" |
| Category | `DropdownButtonFormField<String>` (data dari `price_reference_data` distinct) | `null` → "Pilih kategori" |
| Price per Unit | `Row[ TextFormField(numeric) + DropdownButtonFormField(unit) ]` | Harga > 0 + unit tidak null |
| Quantity | **Stepper** (bukan TextFormField): `IconButton(minus)` + `Text(count)` + `IconButton(plus)` | Minimal 1 |

**Foto upload flow:**
1. "Take Photo" → `ImagePicker().pickImage(source: ImageSource.camera)`
2. "Choose from Gallery" → `ImagePicker().pickImage(source: ImageSource.gallery)`
3. Upload ke Supabase Storage: `client.storage.from('listing-photos').upload('${userId}/${timestamp}.jpg', file)`
4. Dapat public URL: `client.storage.from('listing-photos').getPublicUrl(path)`
5. Tampilkan preview + set `foto_url` di state

**Main form layout:**
```
Column(crossAxisAlignment: stretch)
├── Product Photo (full-width, paling atas)
│   ├── Preview foto (Container, if foto_url != null)
│   └── Row[ "Take Photo" | "Choose from Gallery" ]
├── SizedBox(24)
├── Listing Title (TextFormField)
├── SizedBox(16)
├── Category (DropdownButtonFormField)
├── SizedBox(16)
├── Region (DropdownButtonFormField)
├── SizedBox(16)
├── Row
│   ├── Expanded(flex:3, TextFormField("Harga per Unit"))
│   └── Expanded(flex:2, DropdownButtonFormField(unit))
├── SizedBox(16)
├── Row("Quantity")
│   ├── IconButton(minus)
│   ├── Text("$count")
│   └── IconButton(plus)
└── SizedBox(24)
```

**Sticky button di bawah:**
```
Scaffold
└── Stack
    ├── SingleChildScrollView
    │   └── Form(...) — semua field di atas
    └── Positioned(bottom: 0, left: 0, right: 0)
        └── Container(padding + background)
            └── ElevatedButton(
                  onPressed: _isValid ? _submit : null,
                  child: isEditing ? "Save Changes" : "Publish Listing",
                )
```

### T6 — CreateListingScreen

```
Scaffold
└── AppBar(isEditing ? "Edit Listing" : "Buat Listing Baru")
└── Stack
    ├── SingleChildScrollView
    │   └── Padding(24)
    │       └── ListingForm(
    │             listingData: listing,  // null = create, non-null = edit
    │             onSubmit: (data) => repo.create/update(data),
    │           )
    └── Positioned(bottom: 0)
        └── Publish/Save button (sticky)
```

**On submit:**
```dart
final data = {
  'title': title,
  'category': category,
  'region': region,
  'harga_per_unit': price,
  'unit': unit,
  'quantity_available': quantity,
  'status': 'active',
  'foto_url': uploadedUrl,
  'farmer_id': ref.read(authProvider).userId,
};

if (isEditing) {
  await listingRepo.update(listingId, data);
} else {
  await listingRepo.create(data);
}
context.pop();
```
await listingRepo.create({
  'farmer_id': authUserId,
  'category': category,
  'region': region,
  'harga_per_unit': price,
  'quantity_available': qty,
  'status': 'active',
  'foto_url': uploadedUrl,
});
context.pop();
```

### T7 — MyListingsScreen

```
Scaffold
└── AppBar("Listing Saya")
└── FloatingActionButton(icon: +, onTap: push /create)
└── FutureBuilder<List<Map>>
    ├── loading: CircularProgressIndicator
    ├── empty: "Belum ada listing. Tambah listing pertama Anda."
    └── list: ListView.builder
        └── Card
            ├── CachedNetworkImage(foto_url, width: 80)
            ├── Column
            │   ├── Text(category, bold)
            │   └── Text("Rp ${harga}/unit · ${qty} tersedia")
            └── IconButton(edit → push /:id/edit, extra: listingData)
```

### T8 — GoRouter Update

**File diedit:** `lib/core/router/app_router.dart`

Ganti `farmerRoutes` dari placeholder tunggal ke nested:

```dart
final farmerRoutes = <RouteBase>[
  GoRoute(
    path: '/farmer',
    builder: (_, __) => const PlaceholderScreen(title: 'Farmer Home'),
    routes: [
      GoRoute(
        path: 'listings',
        builder: (_, __) => const MyListingsScreen(),
        routes: [
          GoRoute(
            path: 'create',
            builder: (_, __) => const CreateListingScreen(),
          ),
          GoRoute(
            path: ':id/edit',
            builder: (_, state) {
              final listing = state.extra as Map<String, dynamic>;
              return CreateListingScreen(listing: listing);
            },
          ),
        ],
      ),
    ],
  ),
];
```

### T10 — Verifikasi

| Step | Command / Aksi | Yang dicek |
|---|---|---|
| 1 | `flutter analyze` | 0 issues |
| 2 | `flutter test` | PASS |
| 3 | `flutter run -d chrome` | Farmer login → `/farmer/listings` |
| 4 | Tap "+" → create listing | Form tampil 6 field sesuai desain |
| 5 | Kosongkan semua field | Tombol "Publish Listing" disabled, error border merah di field kosong |
| 6 | Upload foto + isi semua field → submit | Cek `listings` table: title, unit, foto_url tersimpan |
| 7 | Cek bucket `listing-photos` | Foto muncul di Storage |
| 8 | Edit listing: ubah harga → "Save Changes" | Cek data ter-update |
| 9 | Stepper kuantitas: tap +/– | Angka naik/turun, tidak bisa di bawah 1 |
| 10 | Login sebagai farmer lain | Tidak bisa edit listing farmer A (RLS tolak) |

---

## Acceptance Criteria

```
[ ] Filter kombinasi category + region + harga berfungsi
[ ] Farmer B tidak bisa update listing Farmer A (RLS verified)
[x] Farmer bisa create listing + upload foto via "Take Photo"/"Choose from Gallery"
[x] Field disimpan: title, category, region, price, unit, quantity, foto_url
[x] Stepper kuantitas berfungsi (minus/plus), minimal 1
[x] Validasi visual: border merah + error text per field, tombol disabled sampai valid
[x] Edit mode: form pre-filled, tombol "Save Changes"
[x] flutter analyze 0 issues
[x] flutter test PASS
[ ] Commit ke fachri_dev
```

---

## Risiko & Mitigasi

| Risiko | Prob. | Dampak | Mitigasi |
|---|---|---|---|
| Kolom `title` + `unit` belum ada | Sedang | Form tidak bisa simpan data | Koordinasi Nevan: tambah migration `ALTER TABLE listings ADD COLUMN` |
| Upload foto gagal (RLS bucket) | Rendah | Create listing gagal | Verifikasi bucket policy: farmer role bisa insert |
| PostgREST filter tidak bekerja | Rendah | Feed kosong nanti di FG-15 | Cek column name (snake_case) dan data type |
| `DropdownButtonFormField` data kosong | Rendah | Kategori/region dropdown kosong | Seed `price_reference_data` sudah 18 baris, query distinct |
| Unit dropdown tidak sinkron dgn kategori | Rendah | Unit tidak relevan untuk kategori tertentu | Statis dulu: list unit umum (kg, head, flat, box, ikat) |

---

## Catatan

- **FG-15 (Buyer Home Feed + Search)** adalah ticket Fachri di Sprint 5 — data listing dari FG-14 dipakai sebagai test data
- **Koordinasi dengan Hafizh** soal nama route `/farmer-profile/:id` — dipakai nanti di FG-15 (Sprint 5) dan FG-16 (Sprint 6)
- PlaceholderScreen untuk `/buyer` tetap tidak diubah sprint ini (Buyer Home Feed di Sprint 5)
- Tidak termasuk full text search (tidak diminta PRD)
- **Kolom `title` dan `unit` harus ditambahkan ke tabel `listings` sebelum FG-14 coding** — koordinasi dengan Nevan untuk migration ini

---

## Referensi

- `docs/Sprint 4/sprint4_README.md`
- `docs/Sprint 4/sprint4_fachri_dev.md`
- `docs/Sprint 2/sprint2_hasil_akhir.md` (RLS + bucket)
- `docs/Sprint 3/sprint3_hasil_akhir.md` (seed data + auth)
- PRD §3.1, §4.1, §9, §15
