# Project Plan: FG-15 — Sprint 5

> Dibuat 16 Juli 2026 · Fachri · Sprint 5 Buyer Home Feed

---

## Ringkasan

| | |
|---|---|
| **Ticket** | FG-15 — Buyer: Home Feed + Search & Filter |
| **PIC** | Fachri |
| **Sprint** | 5 — Home Feed, Metrics Endpoints & Negotiation Core |
| **Dependency** | FG-13 ListingRepository (Sprint 4), FG-14 data (Sprint 4) |
| **Branch** | `fachri_dev` |
| **Estimasi** | 60-70 menit |

---

## Status Prasyarat

| Prasyarat | Status | Catatan |
|---|---|---|
| `ListingRepository.filterListings()` | ✅ Dari FG-13 | Sudah siap dipakai feed |
| Data listing (dari FG-14) | ✅ | Bisa dibuat sendiri via Create Listing |
| RLS `listings` public read | ✅ Dari Sprint 2 | Buyer bisa lihat semua listing |
| Bucket `listing-photos` public read | ✅ Dari Sprint 2 | Foto tampil di feed |
| Auth buyer login | ✅ Dari Sprint 3 | GoRouter protect role |
| Route farmer profile `/farmer-profile/:id` | ⚠️ Konfirmasi Hafizh | Screen asli di FG-16 (Sprint 6) |

---

## Task Breakdown

```
FG-15 Buyer Home Feed + Search
│
├── T1: BuyerHomeFeedScreen (30 mnt)
│   ├── GridView 2 kolom listing cards
│   ├── Card: foto, title, harga/unit, lokasi, nama farmer
│   ├── Infinite scroll (offset pagination)
│   └── Tap → navigasi ke farmer profile stub
│
├── T2: SearchFilterScreen (20 mnt)
│   ├── Filter bar: kategori, region, range harga
│   ├── Hasil terfilter via filterListings()
│   ├── Empty state: "Tidak ada hasil"
│   └── Pull-to-refresh
│
├── T3: Wire GoRouter (5 mnt)
│   ├── Ganti /buyer PlaceholderScreen → BuyerHomeFeedScreen
│   └── Tambah /buyer/search route
│
├── T4: Route stub farmer profile (5 mnt)
│   └── PlaceholderScreen di /farmer-profile/:id (screen asli di FG-16)
│
└── T5: Verifikasi (10 mnt)
    ├── flutter analyze
    ├── flutter test
    └── flutter run: scroll feed + search filter
```

---

## Checklist FG-15 (dari `sprint5_fachri_dev.md`)

- [x] Home Feed: listing (foto, harga per unit, lokasi petani) dengan infinite scroll/pagination sederhana
- [x] Search page terpisah dengan filter: kategori, region/lokasi petani, rentang harga — konsumsi endpoint dari FG-13 (Sprint 4)
- [x] State hasil kosong yang jelas ("Tidak ada hasil"), bukan layar kosong tanpa penjelasan
- [x] State feed kosong per kategori (belum ada listing sama sekali di kategori itu)
- [x] Tap listing/nama farmer → siapkan navigasi ke Farmer Public Profile — **screen-nya sendiri baru dibangun Hafizh di FG-16 (Sprint 6)**, jadi cukup siapkan route/stub link sesuai nama yang sudah disepakati bersama di Sprint 4, sambungkan penuh begitu FG-16 selesai

### Mapping Checklist → Task

| Item Checklist FG-15 | Task di Plan |
|---|---|
| Home Feed dengan infinite scroll | T1 (BuyerHomeFeedScreen) |
| Search page + filter | T2 (SearchFilterScreen) |
| State "Tidak ada hasil" | T2 (empty state widget) |
| State feed kosong per kategori | T1 (empty state widget) |
| Tap → navigasi farmer profile | T4 (route stub) |

---

## Deliverables

| File | Aksi | Output |
|---|---|---|
| `lib/features/listing/screens/buyer_home_feed_screen.dart` | BARU | Grid/List feed + pagination |
| `lib/features/listing/screens/search_filter_screen.dart` | BARU | Filter bar + results |
| `lib/core/router/app_router.dart` | EDIT | Ganti /buyer + tambah /search |
| `test/widget_test.dart` | EDIT | Update test |

---

## Spesifikasi Teknis

### T1 — BuyerHomeFeedScreen

**Widget tree:**
```
Scaffold
└── AppBar("FarmBridge", actions: [IconButton(search)])
└── body: _buildBody()
    ├── loading: CircularProgressIndicator
    ├── empty: Center("Belum ada listing tersedia")
    ├── error: Center("Gagal memuat: $error")
    └── list: GridView.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(2),
            controller: _scrollController,
            itemCount: listings.length + (hasMore ? 1 : 0),
            itemBuilder: ...
          )
```

**Listing card:**
```
Card(margin: 8, clipBehavior: antiAlias)
└── Column(crossAxisAlignment: stretch)
    ├── CachedNetworkImage(foto_url, height: 140, fit: cover)
    ├── Padding(12)
    │   ├── Text(title, maxLines: 2, bold)
    │   ├── SizedBox(4)
    │   ├── Text("Rp ${harga}/${unit}", color: green.shade700, bold)
    │   ├── SizedBox(2)
    │   ├── Row
    │   │   ├── Icon(location, size: 14, grey)
    │   │   └── Text(lokasi, style: caption)
    │   └── SizedBox(4)
    │   └── GestureDetector(
    │         onTap: → /farmer-profile/:farmerId,
    │         child: Text(nama farmer, italic, underline)
    │       )
```

**Pagination logic:**
```dart
final _pageSize = 20;
int _page = 0;
bool _hasMore = true;
final _scrollController = ScrollController();

Future<void> _loadListings() async {
  final data = await ListingRepository().filterListings(
    category: widget.category,
  );
  final batch = data.skip(_page * _pageSize).take(_pageSize).toList();
  setState(() {
    if (_page == 0) _listings = batch;
    else _listings.addAll(batch);
    _hasMore = batch.length == _pageSize;
  });
}

// Scroll listener
_scrollController.addListener(() {
  if (_scrollController.position.pixels >=
      _scrollController.position.maxScrollExtent - 200) {
    if (_hasMore && !_isLoading) {
      _page++;
      _loadListings();
    }
  }
});
```

### T2 — SearchFilterScreen

**Widget tree:**
```
Scaffold
└── body: Column
    ├── Container(padding: 16, color: surface)
    │   └── Column
    │       ├── Category filter: Wrap(Chip)
    │       │   └── ChoiceChip("Semua", "Beras", "Cabai Merah", ...)
    │       ├── SizedBox(8)
    │       ├── Region filter: Wrap(Chip)
    │       │   └── ChoiceChip("Semua", "Jawa Barat", "Jawa Tengah", "Jawa Timur")
    │       └── SizedBox(8)
    │       └── Price range
    │           └── RangeSlider(min: 0, max: 100000, divisions: 20)
    │               └── Text("Rp ${min} - Rp ${max}")
    └── Expanded
        └── FutureBuilder<Listings>(
              future: ListingRepository().filterListings(
                category: _category,
                region: _region,
                minPrice: _minPrice > 0 ? _minPrice : null,
                maxPrice: _maxPrice < 100000 ? _maxPrice : null,
              ),
              builder: ...
                ├── loading: progress
                ├── empty: _EmptyState("Tidak ada hasil")
                └── list: GridView 2 kolom (sama seperti feed)
            )
```

**Empty state widget:**
```dart
class _EmptyState extends StatelessWidget {
  final String message;
  Center(
    child: Column(mainAxisSize: min)
      ├── Icon(Icons.search_off, size: 64, grey)
      └── Text(message, style: grey, textAlign: center)
  )
}
```

**Categories + regions:** hardcode dari seed data (6 kategori, 3 region) + "Semua".

**Real-time filter:** setiap kali user ubah filter → langsung panggil `filterListings()` ulang — tidak perlu tombol "Apply" terpisah.

### T3 — GoRouter Update

```dart
final buyerRoutes = <RouteBase>[
  GoRoute(
    path: '/buyer',
    builder: (_, __) => const BuyerHomeFeedScreen(),
    routes: [
      GoRoute(
        path: 'search',
        builder: (_, __) => const SearchFilterScreen(),
      ),
    ],
  ),
];
```

### T4 — Route Stub Farmer Profile

Di top-level routes (sebelum ShellRoute):

```dart
GoRoute(
  path: '/farmer-profile/:farmerId',
  builder: (_, state) => PlaceholderScreen(
    title: 'Farmer Profile — ${state.pathParameters['farmerId']}',
  ),
),
```

Route ini bisa diakses buyer (dari feed) maupun farmer (dari listing detail). Nanti FG-16 (Hafizh, Sprint 6) ganti stub ini dengan screen asli berisi trust_metrics + profil.

---

## Acceptance Criteria

```
[x] Buyer lihat feed listing dengan foto, harga, lokasi
[x] Infinite scroll berfungsi (load more saat scroll ke bawah)
[x] Kombinasi filter menghasilkan data sesuai
[x] State "Tidak ada hasil" muncul saat filter tidak match
[x] State feed kosong muncul saat belum ada listing
[x] Tap listing/nama farmer → navigasi ke /farmer-profile/:id
[x] flutter analyze 0 issues
[x] flutter test PASS
[ ] Commit ke fachri_dev
```

---

## Risiko & Mitigasi

| Risiko | Prob. | Dampak | Mitigasi |
|---|---|---|---|
| Belum ada listing untuk feed | Sedang | Feed kosong, tidak bisa test | Buat 3-4 listing via FG-14 dulu sebagai test data |
| `CachedNetworkImage` error | Rendah | Foto tidak tampil | `errorBuilder` fallback ke placeholder icon |
| Pagination performance | Rendah | Lambat saat banyak data | `limit(20)` + `offset`, cukup untuk MVP |
| Route farmer profile belum disepakati | Rendah | Perlu rename route nanti | Pakai `/farmer-profile/:id`, ganti kalau Hafizh minta beda |
| Filter real-time terlalu sering fetch | Rendah | Beban API tidak perlu | Debounce 300ms sebelum panggil `filterListings()` |

---

## Catatan

- Feed buyer melihat **semua listing aktif** dari semua farmer (RLS public read)
- Farmer punya screen sendiri: `/farmer/listings` (listing milik sendiri, FG-14) — tidak sama dengan `/buyer`
- Search filter tidak butuh halaman terpisah — bisa diakses dari icon search di AppBar feed
- `ListingRepository` sudah join `farmer_profiles` (nama, lokasi) — tidak perlu query tambahan

---

## Referensi

- `docs/Sprint 5/sprint5_fachri_dev.md`
- `docs/Sprint 4/dokumentasi_sprint4_fachri.md` (ListingRepository + data)
- `docs/Sprint 2/sprint2_hasil_akhir.md` (RLS + bucket)
- `docs/Sprint 3/sprint3_hasil_akhir.md` (Auth + seed data)
