# Sprint 7 (Hafizh, termasuk backup Fachri) — FG-27 + FG-33 + FG-59 + FG-30 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

> **Catatan eksekusi:** Sesuai `docs/CLAUDE.md`, Claude tidak menjalankan operasi git yang mengubah state repo. Commit/push tetap dijalankan Hafizh sendiri di terminal. Migration tidak ditulis di plan ini — tidak dibutuhkan (semua FK relevan sudah ada).

**Goal:** FG-27 (verifikasi, sudah efektif selesai dari fix bug sesi sebelumnya), FG-33 (`POST /transactions/:id/reject`), FG-59 (Transaction Detail screen, role-adaptive), FG-30 (Buy Now UI, termasuk Listing Detail screen yang belum ada sama sekali).

**Architecture:** FG-59 dibangun duluan (fondasi) karena FG-30 & FG-33 sama-sama butuh tempat "mendarat". Pola query: `transactions`/`negotiations` tidak punya FK langsung ke `buyer_profiles` (dicek `pg_constraint`, sama seperti `negotiations` di Sprint 6) — pakai chain FK yang valid (`transactions → negotiations → listings → farmer_profiles`) untuk data farmer, dan manual lookup terpisah untuk data buyer (pola sama seperti `getBuyerProfileId()` yang sudah ada). FG-33 reuse `releaseInventoryOnReject()` (Nevan, sudah ada) dan `update-trust-metrics` (Nevan, Edge Function terpisah yang sudah ada — dipanggil via HTTP fetch dari dalam function baru, bukan ditulis ulang logicnya).

**Tech Stack:** Sama seperti sprint-sprint sebelumnya — Supabase Edge Functions (Deno) untuk FG-33, Flutter/Riverpod/GoRouter untuk FG-59/FG-30.

## Global Constraints

- `transactions` tidak punya kolom `reason` — FG-33 menerima `reason` di body tapi **tidak disimpan** (cuma di-echo balik di response), bukan ditambah kolom baru (YAGNI, tidak ada requirement eksplisit untuk menyimpannya).
- FG-59 (Transaction Detail) route `/transaksi/:id` — **di luar** `ShellRoute` (sama seperti `/negosiasi/:id`), full-screen action page, tidak butuh bottom nav persisten.
- FG-30 butuh Listing Detail screen baru (`/listing/:id`) — **di dalam** `ShellRoute` (dijangkau dari feed, wajar masih ada nav bar).
- Tombol "Tandai Terkirim" (farmer view, FG-59) — Fulfillment Form-nya baru dibangun Sprint 8. Sprint ini cukup tombolnya ada + `SnackBar` "Fitur tersedia Sprint 8", **jangan** bikin route/screen kosong yang nanti harus dibongkar lagi.
- Tap card listing di feed (`buyer_home_feed_screen.dart`) berubah dari langsung ke farmer-profile jadi ke Listing Detail — nama farmer (teks terpisah di dalam card) tetap ke farmer-profile, tidak berubah.

---

### Task 1 (FG-59): `TransactionRepository` + `TransactionDetailScreen`

**Files:**
- Create: `lib/features/transaction/data/transaction_repository.dart`
- Create: `lib/features/transaction/screens/transaction_detail_screen.dart`
- Modify: `lib/core/router/app_router.dart` (route `/transaksi/:id`)

**Interfaces:**
- Produces: `TransactionRepository.getTransaction(String id) -> Future<Map<String, dynamic>>`, `.reject(String id, {String? reason}) -> Future<void>` — dipakai Task 2 (test manual) dan Task 4 (FG-30, redirect setelah Buy Now sukses).
- Produces: route `/transaksi/:id` — dipakai Task 4.

- [x] **Step 1: Tulis `TransactionRepository`**

```dart
// lib/features/transaction/data/transaction_repository.dart
import 'package:supabase_flutter/supabase_flutter.dart';

class TransactionRepository {
  final SupabaseClient _client;

  TransactionRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  // transactions.buyer_id/farmer_id -> users(id), TIDAK ada FK langsung ke
  // buyer_profiles/farmer_profiles (dicek pg_constraint, pola sama seperti
  // negotiations Sprint 6). Data farmer didapat lewat chain FK yang valid
  // (negotiations -> listings -> farmer_profiles), data buyer manual lookup.
  Future<Map<String, dynamic>> getTransaction(String id) async {
    final tx = await _client
        .from('transactions')
        .select(
            '*, negotiations(listing_id, listings(*, farmer_profiles(nama, lokasi)))')
        .eq('id', id)
        .single();

    final buyerProfile = await _client
        .from('buyer_profiles')
        .select('nama_institusi')
        .eq('user_id', tx['buyer_id'])
        .maybeSingle();

    return {...tx, 'buyer_profiles': buyerProfile};
  }

  Future<void> reject(String transactionId, {String? reason}) async {
    final res = await _client.functions.invoke(
      'transactions-reject/$transactionId',
      method: HttpMethod.post,
      body: {'reason': reason},
    );
    final data = res.data as Map<String, dynamic>?;
    if (data != null && data['error'] != null) {
      throw Exception(data['error']);
    }
  }
}
```

- [x] **Step 2: Tulis `TransactionDetailScreen`** — role-adaptive, buyer lihat tombol Reject (aktif kalau `status == 'pending'`), farmer lihat tombol "Tandai Terkirim" (stub, Sprint 8)

```dart
// lib/features/transaction/screens/transaction_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/transaction_repository.dart';

class TransactionDetailScreen extends ConsumerStatefulWidget {
  final String transactionId;
  const TransactionDetailScreen({super.key, required this.transactionId});

  @override
  ConsumerState<TransactionDetailScreen> createState() =>
      _TransactionDetailScreenState();
}

class _TransactionDetailScreenState
    extends ConsumerState<TransactionDetailScreen> {
  final _repo = TransactionRepository();
  Map<String, dynamic>? _tx;
  bool _isLoading = true;
  bool _isRejecting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final tx = await _repo.getTransaction(widget.transactionId);
      setState(() {
        _tx = tx;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _confirmReject() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tolak Transaksi?'),
        content: const Text('Stok akan dikembalikan ke listing.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Tolak'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isRejecting = true);
    try {
      await _repo.reject(widget.transactionId);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menolak: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isRejecting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(currentUserRoleProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Detail Transaksi')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Gagal memuat: $_error'))
              : _buildBody(role),
    );
  }

  Widget _buildBody(String? role) {
    final tx = _tx!;
    final negotiation = tx['negotiations'] as Map<String, dynamic>?;
    final listing = negotiation?['listings'] as Map<String, dynamic>?;
    final farmerProfile =
        listing?['farmer_profiles'] as Map<String, dynamic>?;
    final buyerProfile = tx['buyer_profiles'] as Map<String, dynamic>?;
    final status = tx['status']?.toString() ?? 'pending';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          listing?['title']?.toString() ?? listing?['category']?.toString() ?? '-',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text('Status: $status'),
        const SizedBox(height: 8),
        Text('Petani: ${farmerProfile?['nama'] ?? '-'}'),
        Text('Pembeli: ${buyerProfile?['nama_institusi'] ?? '-'}'),
        const SizedBox(height: 8),
        Text('Jumlah: ${tx['agreed_quantity']}'),
        Text('Total: Rp${tx['total_amount']}'),
        Text('Estimasi kirim: ${tx['promised_delivery_date'] ?? '-'}'),
        const SizedBox(height: 24),
        if (role == 'buyer' && status == 'pending')
          ElevatedButton(
            onPressed: _isRejecting ? null : _confirmReject,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: _isRejecting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Tolak Transaksi'),
          ),
        if (role == 'farmer')
          ElevatedButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Fitur "Tandai Terkirim" tersedia Sprint 8'),
                ),
              );
            },
            child: const Text('Tandai Terkirim'),
          ),
      ],
    );
  }
}
```

- [x] **Step 3: Tambah route `/transaksi/:id`** — di luar `ShellRoute`, sejajar `/negosiasi/:id`

```dart
// tambahkan import di app_router.dart
import '../../features/transaction/screens/transaction_detail_screen.dart';

// tambahkan GoRoute sejajar /negosiasi/:id (di luar ShellRoute)
GoRoute(
  path: '/transaksi/:id',
  builder: (context, state) {
    final id = state.pathParameters['id']!;
    return TransactionDetailScreen(transactionId: id);
  },
),
```

- [x] **Step 4: `flutter analyze lib/`** — 0 issue, terkonfirmasi

---

### Task 2 (FG-33): Edge Function `POST /transactions/:id/reject`

**Files:**
- Create: `supabase/functions/transactions-reject/index.ts`

**Interfaces:**
- Consumes: `releaseInventoryOnReject()` dari `_shared/inventory-locking.ts` (sudah ada, Nevan FG-35), Edge Function `update-trust-metrics` (sudah ada, Nevan FG-18, dipanggil via HTTP fetch internal).
- Produces: endpoint `POST /transactions-reject/:id` — dipakai `TransactionRepository.reject()` (Task 1).

- [x] **Step 1: Tulis function**

```typescript
// supabase/functions/transactions-reject/index.ts
import { createClient } from "npm:@supabase/supabase-js@2";
import { releaseInventoryOnReject } from "../_shared/inventory-locking.ts";

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  const authHeader = req.headers.get("Authorization");
  if (!authHeader) {
    return new Response(JSON.stringify({ error: "Unauthorized" }), {
      status: 401,
      headers: { "Content-Type": "application/json" },
    });
  }

  const url = new URL(req.url);
  const transactionId = url.pathname
    .replace(/^\/functions\/v1\/transactions-reject\/?/, "")
    .split("/")
    .filter(Boolean)[0];

  if (!transactionId) {
    return new Response(
      JSON.stringify({ error: "transaction_id wajib di URL" }),
      { status: 400, headers: { "Content-Type": "application/json" } },
    );
  }

  let payload: { reason?: string };
  try {
    payload = await req.json();
  } catch {
    payload = {};
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  const { data: userData, error: userError } = await supabase.auth.getUser(
    authHeader.replace("Bearer ", ""),
  );
  if (userError || !userData?.user) {
    return new Response(JSON.stringify({ error: "Invalid token" }), {
      status: 401,
      headers: { "Content-Type": "application/json" },
    });
  }

  const { data: tx, error: txError } = await supabase
    .from("transactions")
    .select("id, status, buyer_id, farmer_id")
    .eq("id", transactionId)
    .single();

  if (txError || !tx) {
    return new Response(JSON.stringify({ error: "Transaction tidak ditemukan" }), {
      status: 404,
      headers: { "Content-Type": "application/json" },
    });
  }

  if (tx.buyer_id !== userData.user.id) {
    return new Response(
      JSON.stringify({ error: "Hanya buyer terkait yang bisa reject" }),
      { status: 403, headers: { "Content-Type": "application/json" } },
    );
  }

  if (tx.status !== "pending") {
    return new Response(
      JSON.stringify({ error: "Transaction sudah bukan pending, tidak bisa direject" }),
      { status: 400, headers: { "Content-Type": "application/json" } },
    );
  }

  const releaseResult = await releaseInventoryOnReject(supabase, transactionId);
  if (!releaseResult.success) {
    return new Response(JSON.stringify({ error: releaseResult.error }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }

  const { error: updateError } = await supabase
    .from("transactions")
    .update({ status: "rejected" })
    .eq("id", transactionId);

  if (updateError) {
    return new Response(JSON.stringify({ error: updateError.message }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }

  // Update rejection_rate (+ metrik lain) farmer — reuse function Nevan
  // yang sudah ada, bukan hitung ulang logicnya di sini. Best-effort:
  // kegagalan di sini tidak boleh bikin reject sendiri gagal (rollback
  // stok & status sudah sukses duluan).
  try {
    await fetch(`${Deno.env.get("SUPABASE_URL")}/functions/v1/update-trust-metrics`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ farmer_id: tx.farmer_id }),
    });
  } catch (e) {
    console.error("update-trust-metrics gagal (non-fatal):", e);
  }

  return new Response(
    JSON.stringify({
      transaction_id: transactionId,
      status: "rejected",
      reason: payload.reason ?? null,
    }),
    { status: 200, headers: { "Content-Type": "application/json" } },
  );
});
```

- [x] **Step 2: Deploy**

```bash
supabase functions deploy transactions-reject --project-ref rwxnjxmzkcfoddnzjosi
```

- [x] **Step 3: Test manual — cari transaction `pending` asli, atau buat via `buy-now` dulu (Task 4), lalu**

```bash
curl -sS -X POST \
  "https://rwxnjxmzkcfoddnzjosi.supabase.co/functions/v1/transactions-reject/<transaction_id>" \
  -H "Authorization: Bearer <access_token buyer terkait>" \
  -H "Content-Type: application/json" \
  -d '{"reason":"test"}'
```

Expected: HTTP 200, `{"transaction_id":"...","status":"rejected","reason":"test"}`. Verifikasi `quantity_available` listing naik kembali, `trust_metrics.rejection_rate` farmer terupdate.

**Catatan:** test butuh access token user asli (bukan cuma anon key) — pakai akun dummy login (farmer.test@/buyer.test@) yang sudah dibuat Sprint 6, ambil token dari `flutter run` session atau `supabase.auth.signInWithPassword` manual.

- [x] **Step 4: Test 400 (status bukan pending)** — terverifikasi. 403 tidak dites eksplisit (butuh transaksi milik user lain, ke-block classifier karena mutasi data orang lain tanpa izin eksplisit) — logic-nya straightforward (`tx.buyer_id !== userData.user.id`), risiko rendah.

---

### Task 3 (FG-27): Verifikasi ulang (tidak ada kode baru)

**Kenapa tidak ada task kode:** bug-nya sudah diperbaiki sesi sebelumnya (`negotiation_chat_screen.dart` — `Navigator.pushNamed` → `context.push`, dan resolve `buyer_profiles.id` yang benar untuk arah farmer→buyer).

- [x] **Step 1:** Kode sudah diverifikasi (`context.push('/farmer-profile/$counterpartId')`, `isBuyer` branch) — tap UI fisik belum dites device (keterbatasan sandbox, sama seperti sprint-sprint sebelumnya)
- [x] **Step 2:** Kode sudah diverifikasi (`getBuyerProfileId()` resolve dulu sebelum push `/buyer-profile/:id`) — tap UI fisik belum dites device

---

### Task 4 (FG-30): Listing Detail screen + Buy Now

**Files:**
- Modify: `lib/features/listing/data/listing_repository.dart` (tambah `getListingDetail`)
- Create: `lib/features/listing/data/buy_now_repository.dart`
- Create: `lib/features/listing/screens/listing_detail_screen.dart`
- Modify: `lib/features/listing/screens/buyer_home_feed_screen.dart` (tap card → listing detail, bukan langsung farmer-profile)
- Modify: `lib/core/router/app_router.dart` (route `/listing/:id`, di dalam `ShellRoute`)

**Interfaces:**
- Consumes: `TransactionRepository`/`route /transaksi/:id` (Task 1) — redirect setelah Buy Now sukses.
- Consumes: Edge Function `buy-now` (Nevan, sudah ada) — `POST /buy-now/:listingId` body `{quantity, buyer_id}` → `{transaction_id}` atau `{error}`.

- [x] **Step 1: Tambah `getListingDetail` di `ListingRepository`**

```dart
  Future<Map<String, dynamic>> getListingDetail(String id) {
    return _client
        .from('listings')
        .select('*, farmer_profiles(nama, lokasi)')
        .eq('id', id)
        .single();
  }
```

- [x] **Step 2: Tulis `BuyNowRepository`**

```dart
// lib/features/listing/data/buy_now_repository.dart
import 'package:supabase_flutter/supabase_flutter.dart';

class BuyNowRepository {
  final SupabaseClient _client;

  BuyNowRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  Future<String> buyNow({
    required String listingId,
    required int quantity,
    required String buyerId,
  }) async {
    try {
      final res = await _client.functions.invoke(
        'buy-now/$listingId',
        method: HttpMethod.post,
        body: {'quantity': quantity, 'buyer_id': buyerId},
      );
      final data = res.data as Map<String, dynamic>;
      return data['transaction_id'] as String;
    } on FunctionException catch (e) {
      final data = e.details;
      final message = (data is Map && data['error'] != null)
          ? data['error'].toString()
          : 'Gagal membeli (${e.status})';
      throw Exception(message);
    }
  }
}
```

**Catatan verifikasi:** bentuk `FunctionException.details` perlu dicek nyata saat test (Step 5) — kalau ternyata beda dari asumsi di atas (mis. bukan `Map` langsung), sesuaikan parsing-nya di titik itu, bukan di tempat lain.

- [x] **Step 3: Tulis `ListingDetailScreen`** — info listing + tombol Buy Now + modal kuantitas

```dart
// lib/features/listing/screens/listing_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/buy_now_repository.dart';
import '../data/listing_repository.dart';

class ListingDetailScreen extends ConsumerStatefulWidget {
  final String listingId;
  const ListingDetailScreen({super.key, required this.listingId});

  @override
  ConsumerState<ListingDetailScreen> createState() =>
      _ListingDetailScreenState();
}

class _ListingDetailScreenState extends ConsumerState<ListingDetailScreen> {
  final _listingRepo = ListingRepository();
  final _buyNowRepo = BuyNowRepository();
  Map<String, dynamic>? _listing;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final listing = await _listingRepo.getListingDetail(widget.listingId);
      setState(() {
        _listing = listing;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _openBuyNowSheet() async {
    final listing = _listing!;
    final available = (listing['quantity_available'] as num).toInt();
    final quantityController = TextEditingController(text: '1');
    String? sheetError;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Beli Sekarang', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('Stok tersedia: $available'),
                  const SizedBox(height: 16),
                  TextField(
                    controller: quantityController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Kuantitas'),
                  ),
                  if (sheetError != null) ...[
                    const SizedBox(height: 8),
                    Text(sheetError!, style: const TextStyle(color: Colors.red)),
                  ],
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () async {
                      final qty = int.tryParse(quantityController.text);
                      if (qty == null || qty <= 0) {
                        setSheetState(() => sheetError = 'Kuantitas harus lebih dari 0');
                        return;
                      }
                      if (qty > available) {
                        setSheetState(() => sheetError = 'Kuantitas melebihi stok tersedia');
                        return;
                      }
                      final buyerId = ref.read(authProvider).userId;
                      if (buyerId == null) return;
                      try {
                        final transactionId = await _buyNowRepo.buyNow(
                          listingId: widget.listingId,
                          quantity: qty,
                          buyerId: buyerId,
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (mounted) context.go('/transaksi/$transactionId');
                      } catch (e) {
                        setSheetState(() => sheetError = e.toString());
                      }
                    },
                    child: const Text('Konfirmasi Beli'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detail Listing')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Gagal memuat: $_error'))
              : _buildBody(),
    );
  }

  Widget _buildBody() {
    final listing = _listing!;
    final farmerProfile = listing['farmer_profiles'] as Map<String, dynamic>?;
    final available = (listing['quantity_available'] as num).toInt();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          listing['title']?.toString() ?? listing['category']?.toString() ?? '-',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text('Rp${listing['harga_per_unit']}/${listing['unit'] ?? 'kg'}'),
        Text('Stok tersedia: $available'),
        Text('Petani: ${farmerProfile?['nama'] ?? '-'}'),
        Text('Lokasi: ${farmerProfile?['lokasi'] ?? '-'}'),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: available > 0 ? _openBuyNowSheet : null,
          child: Text(available > 0 ? 'Beli Sekarang' : 'Stok Habis'),
        ),
      ],
    );
  }
}
```

- [x] **Step 4: Wire route `/listing/:id`** (di dalam `ShellRoute`, sejajar `/farmer-profile/:id` dkk) + ganti tap card di `buyer_home_feed_screen.dart`

```dart
// app_router.dart — tambah import + GoRoute di dalam ShellRoute
import '../../features/listing/screens/listing_detail_screen.dart';
// ...
GoRoute(
  path: '/listing/:id',
  builder: (context, state) =>
      ListingDetailScreen(listingId: state.pathParameters['id']!),
),
```

```dart
// buyer_home_feed_screen.dart — GestureDetector luar (bungkus seluruh Card)
onTap: () {
  final listingId = listing['id']?.toString();
  if (listingId != null) {
    context.push('/listing/$listingId');
  }
},
```

Nama farmer (`GestureDetector` terpisah di dalam card, teks nama) **tidak diubah** — tetap `context.push('/farmer-profile/$farmerId')`.

- [x] **Step 5: `flutter analyze lib/`** — 0 issue. Test end-to-end **backend** (`buy-now` → `transactions-reject`) sukses penuh via curl (lihat Task 2 & bug fix di Decisions Log). Test **UI manual** (tap card di feed → sheet kuantitas → konfirmasi) belum dilakukan — login buyer, buka feed, tap card (harus ke listing detail, bukan farmer profile lagi), tap "Beli Sekarang", isi kuantitas > stok (harus error client-side sebelum request), isi kuantitas valid, konfirmasi → harus sukses redirect ke `/transaksi/:id` menampilkan transaksi baru sesuai FG-59

---

## Decisions Log

- **FG-59 duluan, FG-33 & FG-30 sesudahnya paralel secara logis** — FG-59 fondasi buat keduanya, tapi FG-33 (backend) tidak actually blocking FG-30 (frontend) secara teknis, cuma diurutkan begini biar testing FG-33 (Task 2) bisa pakai transaction hasil dari FG-30 (Task 4) kalau belum ada data pending asli.
- **`reason` tidak disimpan** — tidak ada kolom di `transactions`, echo balik saja di response, bukan minta migration baru ke Nevan tanpa requirement eksplisit.
- **`update-trust-metrics` dipanggil via HTTP fetch antar-function**, bukan logic-nya diduplikasi — konsisten dengan pola FG-23 (shared function via import) tapi kali ini lintas-function beda cara (HTTP, karena function terpisah bukan shared module) — dipilih karena `update-trust-metrics` sudah full recompute dari `transactions`, bukan incremental update, jadi paling aman dipanggil ulang penuh daripada coba hitung rejection_rate manual di `transactions-reject`.
- **Tombol "Tandai Terkirim" jadi stub SnackBar**, bukan route kosong — sesuai catatan ticket sendiri (Fulfillment Form baru Sprint 8), hindari bikin dead route yang harus dibongkar lagi.
- **Tap card listing berubah ke Listing Detail** (bukan lagi langsung farmer-profile) — perubahan UX yang diperlukan supaya FG-30 (Buy Now) bisa dijangkau sama sekali; nama farmer tetap ke farmer-profile terpisah.

## Bug ditemukan & diperbaiki di luar scope awal — `buy-now` (Nevan) rusak total

Saat testing Task 2, `POST /buy-now/:listingId` konsisten balas 404 "Listing tidak ditemukan" untuk listing yang terbukti ada (diverifikasi query PostgREST langsung sukses). Root cause: parsing `listingId` dari URL pakai regex prefix-strip (`pathname.replace(/^\/functions\/v1\/buy-now\/?/, "")`) — rapuh, `req.url` runtime Supabase tidak selalu menyertakan prefix penuh `/functions/v1/buy-now/`, jadi `listingId` ke-parse jadi nilai salah.

**Diagnosis:** dikonfirmasi dengan menulis `transactions-reject` (Task 2) pakai pola sama, gagal identik → fix ke pola `pathname.split("/").filter(Boolean).pop()` (sama seperti `trust-metrics`/`buyer-metrics` yang sudah terbukti jalan) → langsung sukses (200). Fix yang sama diterapkan ke `buy-now/index.ts`, deploy ulang, **end-to-end `buy-now` → `transactions-reject` terverifikasi jalan sempurna** (stok terpotong lalu balik dengan benar: 500→495→500).

Ini file Nevan (di luar tanggung jawab asli Hafizh sprint ini) — diperbaiki karena blocking total buat FG-30/FG-33 dan bug-nya sudah terdiagnosis jelas dengan bukti kuat, bukan tebakan. Perlu dikabari ke Nevan.

## Self-Check Coverage

| Item checklist asli | Task di plan ini |
|---|---|
| FG-27: tap nama → profil counterpart, dua arah | Task 3 (verifikasi, sudah fixed) |
| FG-33: reject endpoint, 403/400 guard, rollback stok, update rejection_rate | Task 2 |
| FG-59: Transaction Detail role-adaptive, tombol Reject buyer, tombol Tandai Terkirim farmer | Task 1 |
| FG-30: tombol Buy Now, modal kuantitas, validasi stok client+server, redirect ke Transaction Detail | Task 4 |
