# Sprint 9: Recurring Order UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Selesaikan 4 ticket Sprint 9 (`docs/FarmBridge_Sprint_Roadmap.md`, `sprint9_README.md`): FG-38 (pg_cron trigger H-1 — bikin transaction siklus baru), FG-39 (My Recurring Orders + Detail UI), FG-40 (CTA "Jadikan Recurring Order"), FG-60 (guard archive listing dengan recurring aktif).

**Architecture:** FG-38 melengkapi `check-recurring-orders` (Sprint 8, saat ini cuma kirim reminder H-1) dengan pengecekan kedua: `recurring_orders` yang `next_order_date`-nya **hari ini** — kalau stok cukup, buat `transactions` baru (reuse pola atomic locking dari FG-35) dan majukan `next_order_date` ke siklus berikutnya; kalau stok kurang, skip siklus (tetap `active`) + notifikasi. FG-39/FG-40 adalah fitur UI baru penuh (belum ada sama sekali): repository + 2 screen (list, detail) + CTA di Transaction Detail yang sudah ada. FG-60 di-enforce lewat **Postgres trigger** (bukan Edge Function baru) supaya tidak bisa di-bypass jalur manapun (client REST langsung, Edge Function, dashboard).

**Tech Stack:** Flutter (Riverpod, GoRouter) + Supabase Edge Functions (Deno) + Postgres trigger — tidak ada dependency baru.

## Global Constraints

- **Jangan pernah menjalankan `git add`/`commit`/`push`/`merge`/dll** — `docs/CLAUDE.md` melarang keras, tanpa pengecualian.
- Migration yang mengubah data production (Task 1, Task 4) **jangan** langsung di-apply tanpa direview — ikuti pola Sprint 8: buat file migration, tampilkan ke user, biarkan user pilih cara apply (MCP langsung atau `supabase db push` manual).
- Semua copy Bahasa Indonesia, konsisten dengan codebase.
- Ikuti gaya Edge Function yang sudah ada: `Response` inline berulang, bukan helper baru.
- Ikuti pola repository/screen yang sudah ada persis (lihat referensi tiap task) — jangan bikin pola baru untuk hal yang sudah ada padanannya (mis. `NegotiationRepository.getMyNegotiations()` untuk pola manual-join profile, `ChatInboxScreen`/`_InboxItem` untuk pola card+status-chip).
- `flutter analyze` harus 0 issue dan `flutter test` harus tetap 26/26 pass setelah setiap task Flutter.

## Asumsi eksplisit (baca sebelum mulai)

1. **"Konfirmasi kesiapan farmer" (PRD §4.1) belum punya mekanisme** — dicatat sebagai gap terbuka oleh tim asli sendiri di `sprint9_fachri_dev.md` ("belum punya ticket sama sekali"). Plan ini **tidak** membangun mekanisme confirm baru — gate satu-satunya di FG-38 adalah `recurring_orders.status == 'active'` (farmer/buyer bisa `pause`/`cancel` kapan saja lewat FG-37 yang sudah ada, itu cara "menolak" siklus berikutnya). Kalau confirm UI eksplisit dibutuhkan, itu di luar scope plan ini.
2. **`frequency` tetap 3 nilai dari Sprint 8**: `weekly`(+7 hari), `biweekly`(+14), `monthly`(+30).
3. **Nama folder Flutter**: checklist lama menyebut `lib/features/recurring-order/**` (hyphen) — Dart tidak bisa import path dengan hyphen, jadi dipakai `lib/features/recurring_order/` (underscore, konsisten dengan folder fitur lain: `transaction`, `negotiation`).

---

### Task 1: Migration — schema transaksi untuk siklus recurring

**Files:**
- Create: `supabase/migrations/20260718000000_transactions_recurring_order_link.sql`

**Interfaces:**
- Produces: kolom `transactions.recurring_order_id` (nullable, FK → `recurring_orders`), `transactions.negotiation_id` jadi nullable. Dipakai Task 3 (FG-38 insert transaction tanpa negotiation).

Kenapa perlu: `transactions.negotiation_id` saat ini `NOT NULL` (dicek langsung: `information_schema.columns`), dan **tidak ada kolom apapun** yang menautkan `transactions` ke `recurring_orders` — padahal PRD §6 eksplisit: *"siklus fulfillment berikutnya direpresentasikan sebagai transaction baru yang tertaut ke recurring_order_id yang sama"*. Transaksi dari siklus recurring (bukan yang pertama, yang itu selalu dari negosiasi/Buy Now) tidak punya negosiasi sama sekali.

- [ ] **Step 1: Tulis migration**

```sql
-- ============================================================
-- FG-38: transactions dari siklus recurring order tidak punya
-- negotiation (bukan hasil tawar-menawar) — negotiation_id jadi
-- nullable, tambah recurring_order_id sebagai tautan gantinya.
-- Invariant (tidak di-enforce lewat CHECK constraint, sengaja —
-- lihat catatan di bawah): tepat satu dari negotiation_id/
-- recurring_order_id yang terisi per baris transactions.
-- ============================================================
ALTER TABLE transactions ALTER COLUMN negotiation_id DROP NOT NULL;

ALTER TABLE transactions
  ADD COLUMN recurring_order_id uuid REFERENCES recurring_orders(id) ON DELETE SET NULL;
```

(Sengaja tidak pakai `CHECK (negotiation_id IS NOT NULL OR recurring_order_id IS NOT NULL)` — nambah kompleksitas migration untuk kasus yang sudah dijamin benar oleh 2 jalur insert yang ada: `lockInventoryOnAcceptWithQuantity`/`buy-now` selalu isi `negotiation_id`, `lockInventoryForRecurringCycle` (Task 3) selalu isi `recurring_order_id`. Tambahkan constraint ini nanti kalau ternyata ada jalur insert baru yang bikin invariant ini gampang dilanggar.)

- [ ] **Step 2: Apply migration**

Tampilkan ke user, biarkan user pilih: MCP `apply_migration` langsung, atau `supabase db push` manual.

- [ ] **Step 3: Verifikasi**

```sql
select column_name, is_nullable from information_schema.columns
where table_name = 'transactions' and column_name in ('negotiation_id', 'recurring_order_id');
```
Expected: `negotiation_id` → `is_nullable = YES`; `recurring_order_id` → ada, `is_nullable = YES`.

- [ ] **Step 4: (Tidak commit)**

---

### Task 2: Shared `FREQUENCY_DAYS` + refactor `recurring-orders` (persiapan Task 3)

**Files:**
- Create: `supabase/functions/_shared/frequency.ts`
- Modify: `supabase/functions/recurring-orders/index.ts`

**Interfaces:**
- Produces: `export const FREQUENCY_DAYS: Record<string, number>` — dipakai `recurring-orders/index.ts` (sudah ada, Sprint 8) dan `check-recurring-orders/index.ts` (Task 3).

- [ ] **Step 1: Buat shared module**

```ts
export const FREQUENCY_DAYS: Record<string, number> = {
  weekly: 7,
  biweekly: 14,
  monthly: 30,
};
```

- [ ] **Step 2: Refactor `recurring-orders/index.ts` supaya pakai shared const**

Ganti baris ini (dekat atas file):
```ts
const FREQUENCY_DAYS: Record<string, number> = { weekly: 7, biweekly: 14, monthly: 30 };
```
menjadi:
```ts
import { FREQUENCY_DAYS } from "../_shared/frequency.ts";
```
(pindahkan import ini ke baris kedua, setelah `import { createClient } ...`, hapus const lokal yang lama).

- [ ] **Step 3: Deploy ulang & verifikasi tidak ada regresi**

```bash
supabase functions deploy recurring-orders --project-ref rwxnjxmzkcfoddnzjosi
curl -s -X POST "https://rwxnjxmzkcfoddnzjosi.supabase.co/functions/v1/recurring-orders" \
  -H "apikey: sb_publishable_-tmXQTkiRSNHtvjBVILpvA_oGVnliRX" \
  -H "Authorization: Bearer sb_publishable_-tmXQTkiRSNHtvjBVILpvA_oGVnliRX" \
  -H "Content-Type: application/json" \
  -d '{"buyer_id":"ed23f6a6-21cb-4576-89ac-d8bfdae08a78","farmer_id":"38e89c06-2257-49f8-a392-ed2ee8734031","listing_id":"10bae509-7e72-49d6-8716-b84e600db379","quantity":1,"frequency":"weekly","locked_price":30000}'
```
Expected: sama seperti sebelum refactor — `{"recurring_order_id": "...", "next_order_date": "<H+7>"}`.

- [ ] **Step 4: (Tidak commit)**

---

### Task 3: FG-38 — Day-of trigger siklus recurring order

**Files:**
- Modify: `supabase/functions/_shared/inventory-locking.ts` (tambah `lockInventoryForRecurringCycle`)
- Modify: `supabase/functions/check-recurring-orders/index.ts` (tambah pengecekan hari-H)

**Interfaces:**
- Consumes: `transactions.recurring_order_id` (Task 1), `FREQUENCY_DAYS` (Task 2).
- Produces: setiap `recurring_orders` aktif dengan `next_order_date == hari ini` → transaction baru (kalau stok cukup) atau di-skip (kalau tidak), `next_order_date` selalu dimajukan ke siklus berikutnya, notifikasi ke buyer+farmer di kedua kasus (§11).

- [ ] **Step 1: Tambah `lockInventoryForRecurringCycle` ke `_shared/inventory-locking.ts`**

Tambahkan di akhir file (setelah `releaseInventoryOnReject`, kalau ada, atau setelah `lockInventoryOnAcceptWithQuantity`):

```ts
export async function lockInventoryForRecurringCycle(
  supabase: SupabaseClient,
  recurringOrder: {
    id: string;
    listing_id: string;
    farmer_id: string;
    buyer_id: string;
    quantity: number;
    locked_price: number;
  },
): Promise<LockInventoryResult> {
  const { data: listing, error: listingErr } = await supabase
    .from("listings")
    .select("quantity_available")
    .eq("id", recurringOrder.listing_id)
    .single();

  if (listingErr || !listing) {
    return { success: false, error: "Listing tidak ditemukan" };
  }

  const currentQty = Number(listing.quantity_available);
  const quantity = Number(recurringOrder.quantity);
  if (currentQty < quantity) {
    return { success: false, error: "Stok tidak mencukupi" };
  }

  const { error: deductErr } = await supabase
    .from("listings")
    .update({ quantity_available: currentQty - quantity })
    .eq("id", recurringOrder.listing_id)
    .eq("quantity_available", currentQty); // optimistic concurrency guard

  if (deductErr) {
    return { success: false, error: "Gagal mengurangi stok: " + deductErr.message };
  }

  const totalAmount = quantity * Number(recurringOrder.locked_price);
  const promised = new Date();
  promised.setDate(promised.getDate() + 7);

  const { data: tx, error: txErr } = await supabase
    .from("transactions")
    .insert({
      recurring_order_id: recurringOrder.id,
      farmer_id: recurringOrder.farmer_id,
      buyer_id: recurringOrder.buyer_id,
      status: "pending",
      agreed_quantity: quantity,
      total_amount: totalAmount,
      promised_delivery_date: promised.toISOString().slice(0, 10),
    })
    .select("id")
    .single();

  if (txErr) {
    // Rollback: kembalikan stok
    await supabase
      .from("listings")
      .update({ quantity_available: currentQty })
      .eq("id", recurringOrder.listing_id);
    return { success: false, error: "Gagal membuat transaksi: " + txErr.message };
  }

  return { success: true, transaction_id: tx.id };
}
```

(Pola atomic identik dengan `lockInventoryOnAcceptWithQuantity` — bedanya tidak butuh lookup `negotiations` karena `recurringOrder` sudah punya `listing_id`/`farmer_id`/`buyer_id`/`locked_price` langsung. Ini realisasi rekomendasi "reuse locking FG-35" di `sprint9_README.md` — reuse pola-nya, bukan panggil fungsi yang sama persis, karena bentuk datanya beda (tidak ada negotiation).)

- [ ] **Step 2: Tambah fungsi `triggerDueCycles` + panggil dari router di `check-recurring-orders/index.ts`**

Baca dulu isi file saat ini (hasil Sprint 8 — reminder H-1 saja) sebelum edit. Tambahkan import di atas:

```ts
import { FREQUENCY_DAYS } from "../_shared/frequency.ts";
import { lockInventoryForRecurringCycle } from "../_shared/inventory-locking.ts";
```

Tambahkan fungsi baru setelah `Deno.serve` **sebelum** deklarasinya (atau di atas file, sebelum `Deno.serve(...)`):

```ts
async function triggerDueCycles(supabase: ReturnType<typeof createClient>) {
  const todayStr = new Date().toISOString().slice(0, 10);

  const { data: dueOrders, error: dueErr } = await supabase
    .from("recurring_orders")
    .select("id, listing_id, farmer_id, buyer_id, quantity, locked_price, frequency, listings(title, category)")
    .eq("status", "active")
    .eq("next_order_date", todayStr);

  if (dueErr) throw new Error("Gagal query recurring_orders (trigger): " + dueErr.message);

  let created = 0;
  let skipped = 0;

  for (const order of dueOrders ?? []) {
    const lockResult = await lockInventoryForRecurringCycle(supabase, order);

    const nextDate = new Date();
    nextDate.setDate(nextDate.getDate() + (FREQUENCY_DAYS[order.frequency as string] ?? 30));
    await supabase
      .from("recurring_orders")
      .update({ next_order_date: nextDate.toISOString().slice(0, 10) })
      .eq("id", order.id);

    const listing = order.listings as { title: string | null; category: string | null } | null;
    const listingLabel = listing?.title ?? listing?.category ?? "listing Anda";

    const { data: users } = await supabase
      .from("users")
      .select("id, device_token")
      .in("id", [order.buyer_id, order.farmer_id]);

    if (lockResult.success) {
      created++;
      for (const user of users ?? []) {
        if (!user.device_token) continue;
        try {
          await sendPush({
            deviceToken: user.device_token,
            title: "Recurring order dibuat",
            body: `Siklus baru untuk ${listingLabel} sudah dibuat, menunggu fulfillment`,
            deepLink: lockResult.transaction_id ? `/transaksi/${lockResult.transaction_id}` : undefined,
          });
        } catch {
          // push gagal tidak boleh hentikan siklus lain
        }
      }
    } else {
      skipped++;
      for (const user of users ?? []) {
        if (!user.device_token) continue;
        try {
          await sendPush({
            deviceToken: user.device_token,
            title: "Siklus recurring order dilewati",
            body: `Siklus untuk ${listingLabel} dilewati: ${lockResult.error}`,
          });
        } catch {
          // push gagal tidak boleh hentikan siklus lain
        }
      }
    }
  }

  return { due_today: dueOrders?.length ?? 0, created, skipped };
}
```

Cari blok `try { ... }` di dalam `Deno.serve` (isi Sprint 8 — query `dueOrders` untuk reminder besok, insert `cron_execution_log`). Tambahkan pemanggilan `triggerDueCycles` **setelah** logic reminder H-1 selesai, **sebelum** insert `cron_execution_log` yang sukses, dan gabungkan hasilnya ke log + response:

Ganti bagian akhir blok `try` (dari `await supabase.from("cron_execution_log").insert({...})` sampai `return new Response(JSON.stringify({ due_orders: ...`) menjadi:

```ts
    const cycleResult = await triggerDueCycles(supabase);

    await supabase.from("cron_execution_log").insert({
      job_name: "check-recurring-orders",
      status: "success",
      message: `Reminder H-1: ${dueOrders?.length ?? 0} order, ${notified} notifikasi. ` +
        `Trigger hari-H: ${cycleResult.due_today} due, ${cycleResult.created} dibuat, ${cycleResult.skipped} di-skip.`,
    });

    return new Response(JSON.stringify({
      due_orders: dueOrders?.length ?? 0,
      notified,
      ...cycleResult,
    }), { status: 200, headers: { "Content-Type": "application/json" } });
```

- [ ] **Step 3: Deploy**

```bash
supabase functions deploy check-recurring-orders --project-ref rwxnjxmzkcfoddnzjosi
```

- [ ] **Step 4: Verifikasi — stok cukup → transaction dibuat**

Pakai recurring order test dari Sprint 8 (`1eadb85a-a417-44c7-a912-826ddafc949d`, status `active`, listing `255b9d9a...` yang stoknya masih banyak):

```sql
update recurring_orders set next_order_date = current_date where id = '1eadb85a-a417-44c7-a912-826ddafc949d';
```
```bash
curl -s -X POST "https://rwxnjxmzkcfoddnzjosi.supabase.co/functions/v1/check-recurring-orders" \
  -H "apikey: sb_publishable_-tmXQTkiRSNHtvjBVILpvA_oGVnliRX" \
  -H "Authorization: Bearer sb_publishable_-tmXQTkiRSNHtvjBVILpvA_oGVnliRX"
```
Expected: `created: 1` di response. Cek SQL:
```sql
select id, recurring_order_id, negotiation_id, status, agreed_quantity, total_amount from transactions where recurring_order_id = '1eadb85a-a417-44c7-a912-826ddafc949d';
select next_order_date from recurring_orders where id = '1eadb85a-a417-44c7-a912-826ddafc949d';
```
Expected: 1 transaksi baru `status=pending`, `negotiation_id` NULL, `recurring_order_id` terisi; `next_order_date` recurring order sudah maju ke +7 hari dari hari ini.

- [ ] **Step 5: Verifikasi — stok tidak cukup → skip, tetap active**

```sql
-- Buat recurring order test dengan quantity lebih besar dari stok listing
insert into recurring_orders (buyer_id, farmer_id, listing_id, quantity, frequency, locked_price, status, next_order_date)
values ('ed23f6a6-21cb-4576-89ac-d8bfdae08a78', '38e89c06-2257-49f8-a392-ed2ee8734031', '10bae509-7e72-49d6-8716-b84e600db379', 9999, 'weekly', 30000, 'active', current_date)
returning id;
```
```bash
curl -s -X POST "https://rwxnjxmzkcfoddnzjosi.supabase.co/functions/v1/check-recurring-orders" \
  -H "apikey: sb_publishable_-tmXQTkiRSNHtvjBVILpvA_oGVnliRX" \
  -H "Authorization: Bearer sb_publishable_-tmXQTkiRSNHtvjBVILpvA_oGVnliRX"
```
Expected: `skipped: 1` di response. Cek SQL: recurring order tsb `status` **tetap `active`**, `next_order_date` sudah maju, **tidak ada** transaction baru untuk `recurring_order_id` itu.

- [ ] **Step 6: (Tidak commit)**

---

### Task 4: FG-60 (backend) — Trigger guard archive listing

**Files:**
- Create: `supabase/migrations/20260718010000_guard_archive_listing_recurring.sql`

**Interfaces:**
- Produces: trigger Postgres yang menolak `UPDATE listings SET status='archived'` kalau ada `recurring_orders.status='active'` yang mengacu ke listing itu. Berlaku untuk **semua** jalur update (client REST langsung, Edge Function, dashboard) — tidak bisa di-bypass.

- [ ] **Step 1: Tulis migration**

```sql
-- ============================================================
-- FG-60: cegah archive listing yang masih terikat recurring
-- order aktif (edge case §11 ke-8). Trigger, bukan cuma validasi
-- Edge Function/client, supaya tidak bisa di-bypass jalur manapun.
-- ============================================================
CREATE OR REPLACE FUNCTION guard_archive_listing_with_active_recurring()
RETURNS trigger AS $$
DECLARE
  active_count integer;
BEGIN
  IF NEW.status = 'archived' AND OLD.status IS DISTINCT FROM 'archived' THEN
    SELECT count(*) INTO active_count
    FROM recurring_orders
    WHERE listing_id = NEW.id AND status = 'active';

    IF active_count > 0 THEN
      RAISE EXCEPTION 'Listing masih terikat % recurring order aktif — pause/cancel dulu sebelum archive', active_count
        USING ERRCODE = 'check_violation';
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_guard_archive_listing
BEFORE UPDATE ON listings
FOR EACH ROW
EXECUTE FUNCTION guard_archive_listing_with_active_recurring();
```

- [ ] **Step 2: Apply migration**

Tampilkan ke user, biarkan user pilih cara apply (sama seperti Task 1).

- [ ] **Step 3: Verifikasi — archive dengan recurring aktif ditolak**

Pakai recurring order aktif dari Task 3 Step 4 (`1eadb85a...`, listing `255b9d9a...`, statusnya masih `active` setelah trigger cycle):
```sql
update listings set status = 'archived' where id = '255b9d9a-a093-45a8-8599-da5f0f7d63d9';
```
Expected: **error** `"Listing masih terikat 1 recurring order aktif — pause/cancel dulu sebelum archive"`, `listings.status` tidak berubah.

- [ ] **Step 4: Verifikasi — archive tanpa recurring aktif berhasil**

```sql
update listings set status = 'archived' where id = '0eeb2cd3-e9b4-431d-bf24-178d9e4ac5df';
select status from listings where id = '0eeb2cd3-e9b4-431d-bf24-178d9e4ac5df';
-- balikin lagi biar tidak ganggu listing lain yang mungkin dipakai QA selanjutnya
update listings set status = 'active' where id = '0eeb2cd3-e9b4-431d-bf24-178d9e4ac5df';
```
Expected: update pertama sukses tanpa error, `status='archived'` sebelum dikembalikan.

- [ ] **Step 5: (Tidak commit)**

---

### Task 5: FG-60 (frontend) — Tombol Archive + pesan error di My Listings

**Files:**
- Modify: `lib/features/listing/screens/my_listings_screen.dart`

**Interfaces:**
- Consumes: `ListingRepository.update()` (sudah ada) — sekarang bisa melempar `PostgrestException` dari trigger Task 4.

Belum ada tombol archive/delete sama sekali di layar ini sebelumnya — perlu ditambah, bukan cuma di-guard.

- [ ] **Step 1: Ubah `MyListingsScreen` jadi `ConsumerStatefulWidget` supaya bisa refresh setelah archive**

Ganti seluruh file:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:postgrest/postgrest.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/listing_repository.dart';

class MyListingsScreen extends ConsumerStatefulWidget {
  const MyListingsScreen({super.key});

  @override
  ConsumerState<MyListingsScreen> createState() => _MyListingsScreenState();
}

class _MyListingsScreenState extends ConsumerState<MyListingsScreen> {
  final _repo = ListingRepository();
  List<Map<String, dynamic>> _listings = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final userId = ref.read(authProvider).userId;
    if (userId == null) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final data = await _repo.getMyListings(userId);
      setState(() {
        _listings = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _confirmArchive(String listingId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Arsipkan Listing?'),
        content: const Text(
          'Listing tidak akan muncul lagi di pencarian buyer. '
          'Kalau masih ada recurring order aktif yang terikat, aksi ini akan ditolak.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Arsipkan'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _repo.update(listingId, {'status': 'archived'});
      await _load();
    } on PostgrestException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengarsipkan: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(authProvider.select((s) => s.userId));

    return Scaffold(
      appBar: AppBar(title: const Text('Listing Saya')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/farmer/listings/create'),
        child: const Icon(Icons.add),
      ),
      body: userId == null
          ? const Center(child: Text('Silakan login terlebih dahulu'))
          : _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Text('Error: $_error'));
    }
    if (_listings.isEmpty) {
      return const Center(
        child: Text(
          'Belum ada listing.\nTambah listing pertama Anda.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey, fontSize: 16),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _listings.length,
        itemBuilder: (context, index) {
          final item = _listings[index];
          final isArchived = item['status'] == 'archived';
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.all(12),
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: item['foto_url'] != null
                    ? Image.network(
                        item['foto_url'],
                        width: 64,
                        height: 64,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          width: 64,
                          height: 64,
                          color: Colors.grey.shade200,
                          child: const Icon(Icons.image, color: Colors.grey),
                        ),
                      )
                    : Container(
                        width: 64,
                        height: 64,
                        color: Colors.grey.shade200,
                        child: const Icon(Icons.image, color: Colors.grey),
                      ),
              ),
              title: Text(
                item['title'] ?? item['category'] ?? 'No Title',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                isArchived
                    ? 'Diarsipkan'
                    : 'Rp ${item['harga_per_unit']}/${item['unit'] ?? 'kg'} · ${item['quantity_available']} tersedia',
              ),
              trailing: isArchived
                  ? null
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () {
                            context.push(
                              '/farmer/listings/${item['id']}/edit',
                              extra: item,
                            );
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.archive_outlined),
                          onPressed: () => _confirmArchive(item['id']),
                        ),
                      ],
                    ),
            ),
          );
        },
      ),
    );
  }
}
```

(Pola `_load()`/`setState` mengikuti `ChatInboxScreen` — dari `FutureBuilder` sekali-render jadi state yang bisa di-refresh setelah aksi, karena archive butuh reload daftar.)

- [ ] **Step 2: `flutter analyze`**

Run: `flutter analyze`
Expected: `No issues found!` — kalau `package:postgrest/postgrest.dart` tidak ketemu, cek `pubspec.lock` untuk nama import yang benar (`supabase_flutter` re-export `PostgrestException` biasanya lewat `package:supabase_flutter/supabase_flutter.dart` juga — kalau import terpisah error, pakai `import 'package:supabase_flutter/supabase_flutter.dart';` saja, `PostgrestException` ada di situ).

- [ ] **Step 3: (Tidak commit)**

---

### Task 6: FG-39 (backend) — `RecurringOrderRepository`

**Files:**
- Create: `lib/features/recurring_order/data/recurring_order_repository.dart`

**Interfaces:**
- Produces: `create()`, `updateStatus()`, `getMyRecurringOrders(userId)`, `getRecurringOrder(id)`. Dipakai Task 7 (list+detail screen) dan Task 8 (CTA).

- [ ] **Step 1: Tulis repository**

```dart
import 'package:supabase_flutter/supabase_flutter.dart';

class RecurringOrderRepository {
  final SupabaseClient _client;

  RecurringOrderRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  Future<String> create({
    required String buyerId,
    required String farmerId,
    required String listingId,
    required int quantity,
    required String frequency,
    required double lockedPrice,
  }) async {
    final res = await _client.functions.invoke(
      'recurring-orders',
      method: HttpMethod.post,
      body: {
        'buyer_id': buyerId,
        'farmer_id': farmerId,
        'listing_id': listingId,
        'quantity': quantity,
        'frequency': frequency,
        'locked_price': lockedPrice,
      },
    );
    final data = res.data as Map<String, dynamic>?;
    if (data != null && data['error'] != null) {
      throw Exception(data['error']);
    }
    return data!['recurring_order_id'] as String;
  }

  Future<void> updateStatus(String id, String status) async {
    final res = await _client.functions.invoke(
      'recurring-orders/$id',
      method: HttpMethod.patch,
      body: {'status': status},
    );
    final data = res.data as Map<String, dynamic>?;
    if (data != null && data['error'] != null) {
      throw Exception(data['error']);
    }
  }

  // recurring_orders.buyer_id/farmer_id -> users(id), tidak ada FK
  // langsung ke buyer_profiles/farmer_profiles — pola sama seperti
  // NegotiationRepository.getMyNegotiations().
  Future<List<Map<String, dynamic>>> getMyRecurringOrders(String userId) async {
    final orders = await _client
        .from('recurring_orders')
        .select('*, listings(title, category, harga_per_unit, unit, foto_url)')
        .or('buyer_id.eq.$userId,farmer_id.eq.$userId')
        .order('created_at', ascending: false);

    final farmerIds =
        orders.map((o) => o['farmer_id'] as String).toSet().toList();
    final buyerIds =
        orders.map((o) => o['buyer_id'] as String).toSet().toList();

    final farmerProfiles = farmerIds.isEmpty
        ? <Map<String, dynamic>>[]
        : await _client
            .from('farmer_profiles')
            .select('user_id, nama')
            .inFilter('user_id', farmerIds);
    final buyerProfiles = buyerIds.isEmpty
        ? <Map<String, dynamic>>[]
        : await _client
            .from('buyer_profiles')
            .select('user_id, nama_institusi')
            .inFilter('user_id', buyerIds);

    final farmerByUserId = {
      for (final f in farmerProfiles) f['user_id'] as String: f,
    };
    final buyerByUserId = {
      for (final b in buyerProfiles) b['user_id'] as String: b,
    };

    return orders
        .map((o) => {
              ...o,
              'farmer_profiles': farmerByUserId[o['farmer_id']],
              'buyer_profiles': buyerByUserId[o['buyer_id']],
            })
        .toList();
  }

  Future<Map<String, dynamic>> getRecurringOrder(String id) async {
    final order = await _client
        .from('recurring_orders')
        .select('*, listings(title, category, harga_per_unit, unit, foto_url)')
        .eq('id', id)
        .single();

    final farmerProfile = await _client
        .from('farmer_profiles')
        .select('nama, lokasi')
        .eq('user_id', order['farmer_id'])
        .maybeSingle();
    final buyerProfile = await _client
        .from('buyer_profiles')
        .select('nama_institusi')
        .eq('user_id', order['buyer_id'])
        .maybeSingle();

    return {
      ...order,
      'farmer_profiles': farmerProfile,
      'buyer_profiles': buyerProfile,
    };
  }
}
```

- [ ] **Step 2: `flutter analyze`**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 3: (Tidak commit)**

---

### Task 7: FG-39 (frontend) — My Recurring Orders (list) + Detail screen

**Files:**
- Create: `lib/features/recurring_order/screens/recurring_orders_screen.dart`
- Create: `lib/features/recurring_order/screens/recurring_order_detail_screen.dart`
- Modify: `lib/core/router/app_router.dart` (2 route baru)
- Modify: `lib/features/profile/screens/buyer_profile_screen.dart` (entry point)
- Modify: `lib/features/profile/screens/farmer_profile_screen.dart` (entry point)

**Interfaces:**
- Consumes: `RecurringOrderRepository` (Task 6).

- [ ] **Step 1: List screen — `recurring_orders_screen.dart`**

Pola card+status-chip mengikuti `ChatInboxScreen`/`_InboxItem` persis (`lib/features/negotiation/screens/chat_inbox_screen.dart`):

```dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/recurring_order_repository.dart';

class RecurringOrdersScreen extends ConsumerStatefulWidget {
  const RecurringOrdersScreen({super.key});

  @override
  ConsumerState<RecurringOrdersScreen> createState() =>
      _RecurringOrdersScreenState();
}

class _RecurringOrdersScreenState
    extends ConsumerState<RecurringOrdersScreen> {
  final _repo = RecurringOrderRepository();
  List<Map<String, dynamic>> _orders = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final userId = ref.read(authProvider).userId;
    if (userId == null) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final data = await _repo.getMyRecurringOrders(userId);
      setState(() {
        _orders = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recurring Order Saya')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Gagal memuat: $_error'),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _load, child: const Text('Coba Lagi')),
          ],
        ),
      );
    }
    if (_orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.autorenew, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'Belum ada recurring order',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _orders.length,
        itemBuilder: (context, index) {
          final item = _orders[index];
          return _RecurringOrderItem(
            order: item,
            onTap: () => context.push('/recurring-orders/${item['id']}'),
          );
        },
      ),
    );
  }
}

class _RecurringOrderItem extends StatelessWidget {
  final Map<String, dynamic> order;
  final VoidCallback onTap;

  const _RecurringOrderItem({required this.order, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final listing = order['listings'] as Map<String, dynamic>? ?? {};
    final farmerProfile = order['farmer_profiles'] as Map<String, dynamic>?;
    final buyerProfile = order['buyer_profiles'] as Map<String, dynamic>?;
    final status = order['status']?.toString() ?? 'active';
    final fotoUrl = listing['foto_url']?.toString();

    final counterpartName = farmerProfile?['nama']?.toString().isNotEmpty == true
        ? farmerProfile!['nama'].toString()
        : buyerProfile?['nama_institusi']?.toString() ?? '';

    final listingTitle =
        listing['title']?.toString() ?? listing['category']?.toString() ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: fotoUrl != null
                    ? CachedNetworkImage(
                        imageUrl: fotoUrl,
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                        placeholder: (_, _) => Container(
                            width: 56, height: 56, color: Colors.grey.shade200),
                        errorWidget: (_, _, _) => Container(
                            width: 56,
                            height: 56,
                            color: Colors.grey.shade200,
                            child: const Icon(Icons.image, color: Colors.grey)),
                      )
                    : Container(
                        width: 56,
                        height: 56,
                        color: Colors.grey.shade200,
                        child: const Icon(Icons.image, color: Colors.grey),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            counterpartName,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 14),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: _chipColor(status),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _statusLabel(status),
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: _statusTextColor(status)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(listingTitle,
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Text(
                      'Next order: ${order['next_order_date']}',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _chipColor(String status) => switch (status) {
        'active' => Colors.green.shade100,
        'paused' => Colors.orange.shade100,
        'cancelled' => Colors.red.shade100,
        _ => Colors.grey.shade100,
      };

  Color _statusTextColor(String status) => switch (status) {
        'active' => Colors.green.shade800,
        'paused' => Colors.orange.shade800,
        'cancelled' => Colors.red.shade800,
        _ => Colors.grey.shade700,
      };

  String _statusLabel(String status) => switch (status) {
        'active' => 'Aktif',
        'paused' => 'Dijeda',
        'cancelled' => 'Dibatalkan',
        _ => status,
      };
}
```

- [ ] **Step 2: Detail screen — `recurring_order_detail_screen.dart`**

Pola aksi+modal konfirmasi mengikuti `TransactionDetailScreen._confirmReject()`:

```dart
import 'package:flutter/material.dart';
import '../data/recurring_order_repository.dart';

class RecurringOrderDetailScreen extends StatefulWidget {
  final String recurringOrderId;
  const RecurringOrderDetailScreen({super.key, required this.recurringOrderId});

  @override
  State<RecurringOrderDetailScreen> createState() =>
      _RecurringOrderDetailScreenState();
}

class _RecurringOrderDetailScreenState
    extends State<RecurringOrderDetailScreen> {
  final _repo = RecurringOrderRepository();
  Map<String, dynamic>? _order;
  bool _isLoading = true;
  bool _isUpdating = false;
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
      final order = await _repo.getRecurringOrder(widget.recurringOrderId);
      setState(() {
        _order = order;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _confirmStatusChange(String newStatus, String title, String message) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ya'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isUpdating = true);
    try {
      await _repo.updateStatus(widget.recurringOrderId, newStatus);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detail Recurring Order')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Gagal memuat: $_error'))
              : _buildBody(),
    );
  }

  Widget _buildBody() {
    final order = _order!;
    final listing = order['listings'] as Map<String, dynamic>? ?? {};
    final farmerProfile = order['farmer_profiles'] as Map<String, dynamic>?;
    final buyerProfile = order['buyer_profiles'] as Map<String, dynamic>?;
    final status = order['status']?.toString() ?? 'active';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          listing['title']?.toString() ?? listing['category']?.toString() ?? '-',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text('Status: $status'),
        const SizedBox(height: 8),
        Text('Petani: ${farmerProfile?['nama'] ?? '-'}'),
        Text('Pembeli: ${buyerProfile?['nama_institusi'] ?? '-'}'),
        const SizedBox(height: 8),
        Text('Kuantitas: ${order['quantity']}'),
        Text('Harga terkunci: Rp${order['locked_price']}'),
        Text('Frekuensi: ${order['frequency']}'),
        Text('Order berikutnya: ${order['next_order_date']}'),
        const SizedBox(height: 24),
        if (status == 'active') ...[
          ElevatedButton(
            onPressed: _isUpdating
                ? null
                : () => _confirmStatusChange(
                      'paused',
                      'Jeda Recurring Order?',
                      'Siklus berikutnya tidak akan dibuat sampai diaktifkan lagi.',
                    ),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Jeda'),
          ),
          const SizedBox(height: 8),
        ],
        if (status == 'paused')
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: ElevatedButton(
              onPressed: _isUpdating
                  ? null
                  : () => _confirmStatusChange(
                        'active',
                        'Aktifkan Lagi?',
                        'Recurring order akan lanjut ke siklus berikutnya.',
                      ),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text('Aktifkan Lagi'),
            ),
          ),
        if (status != 'cancelled')
          OutlinedButton(
            onPressed: _isUpdating
                ? null
                : () => _confirmStatusChange(
                      'cancelled',
                      'Batalkan Recurring Order?',
                      'Tidak bisa diaktifkan lagi setelah dibatalkan.',
                    ),
            style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Batalkan'),
          ),
      ],
    );
  }
}
```

(`status == 'cancelled'` → tidak ada tombol Pause/Resume/Cancel sama sekali, sesuai §6 "tidak pernah kembali active".)

- [ ] **Step 3: Tambah 2 route di `app_router.dart`**

Cari blok ini:
```dart
      GoRoute(
        path: '/transaksi/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return TransactionDetailScreen(transactionId: id);
        },
      ),
    ],
  );
});
```

Ganti jadi (tambah 2 route baru, tetap full-screen di luar shell — sama seperti `/negosiasi` dan `/transaksi`):
```dart
      GoRoute(
        path: '/transaksi/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return TransactionDetailScreen(transactionId: id);
        },
      ),
      GoRoute(
        path: '/recurring-orders',
        builder: (context, state) => const RecurringOrdersScreen(),
      ),
      GoRoute(
        path: '/recurring-orders/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return RecurringOrderDetailScreen(recurringOrderId: id);
        },
      ),
    ],
  );
});
```

Tambahkan import di bagian atas file (setelah import `TransactionDetailScreen`):
```dart
import '../../features/recurring_order/screens/recurring_orders_screen.dart';
import '../../features/recurring_order/screens/recurring_order_detail_screen.dart';
```

- [ ] **Step 4: Entry point di kedua Profil screen**

Di `lib/features/profile/screens/buyer_profile_screen.dart`, tambah import `go_router` dan ganti:
```dart
    return Scaffold(
      appBar: AppBar(title: const Text('Profil Pembeli')),
```
menjadi:
```dart
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil Pembeli'),
        actions: [
          IconButton(
            icon: const Icon(Icons.autorenew),
            tooltip: 'Recurring Order Saya',
            onPressed: () => context.push('/recurring-orders'),
          ),
        ],
      ),
```

Lakukan hal yang sama di `lib/features/profile/screens/farmer_profile_screen.dart` (title `'Profil Petani'`).

- [ ] **Step 5: `flutter analyze`**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 6: (Tidak commit)**

---

### Task 8: FG-40 — CTA "Jadikan Recurring Order" di Transaction Detail

**Files:**
- Modify: `lib/features/transaction/screens/transaction_detail_screen.dart`

**Interfaces:**
- Consumes: `RecurringOrderRepository.create()` (Task 6).

- [ ] **Step 1: Tambah import**

Di bagian atas `transaction_detail_screen.dart`:
```dart
import 'package:go_router/go_router.dart';
import '../../recurring_order/data/recurring_order_repository.dart';
```

- [ ] **Step 2: Tambah method `_openRecurringOrderSheet()`**

Tambahkan setelah `_confirmFulfill()` (dari Sprint 8):

```dart
  Future<void> _openRecurringOrderSheet() async {
    final tx = _tx!;
    final negotiation = tx['negotiations'] as Map<String, dynamic>?;
    final listingId = negotiation?['listing_id']?.toString();
    if (listingId == null) return;

    final agreedQuantity = (tx['agreed_quantity'] as num).toInt();
    final totalAmount = (tx['total_amount'] as num).toDouble();
    final unitPrice = totalAmount / agreedQuantity;

    final quantityController =
        TextEditingController(text: agreedQuantity.toString());
    String frequency = 'weekly';
    String? sheetError;
    bool isSubmitting = false;

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
                  const Text(
                    'Jadikan Recurring Order',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: quantityController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Kuantitas per siklus'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: frequency,
                    decoration: const InputDecoration(labelText: 'Frekuensi'),
                    items: const [
                      DropdownMenuItem(value: 'weekly', child: Text('Mingguan')),
                      DropdownMenuItem(value: 'biweekly', child: Text('2 Mingguan')),
                      DropdownMenuItem(value: 'monthly', child: Text('Bulanan')),
                    ],
                    onChanged: (v) {
                      if (v != null) setSheetState(() => frequency = v);
                    },
                  ),
                  if (sheetError != null) ...[
                    const SizedBox(height: 8),
                    Text(sheetError!, style: const TextStyle(color: Colors.red)),
                  ],
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: isSubmitting
                        ? null
                        : () async {
                            final qty = int.tryParse(quantityController.text);
                            if (qty == null || qty <= 0) {
                              setSheetState(
                                () => sheetError = 'Kuantitas harus lebih dari 0',
                              );
                              return;
                            }
                            setSheetState(() => isSubmitting = true);
                            try {
                              final id = await RecurringOrderRepository().create(
                                buyerId: tx['buyer_id'].toString(),
                                farmerId: tx['farmer_id'].toString(),
                                listingId: listingId,
                                quantity: qty,
                                frequency: frequency,
                                lockedPrice: unitPrice,
                              );
                              if (ctx.mounted) Navigator.pop(ctx);
                              if (mounted) context.push('/recurring-orders/$id');
                            } catch (e) {
                              setSheetState(() {
                                isSubmitting = false;
                                sheetError = e.toString();
                              });
                            }
                          },
                    child: isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Buat Recurring Order'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
```

- [ ] **Step 3: Tambah tombol CTA di `_buildBody`**

Cari blok tombol buyer yang sudah ada (`if (role == 'buyer' && status == 'pending') ElevatedButton(...Tolak Transaksi...)`). Tambahkan **setelah** blok itu (sebelum blok `if (role == 'farmer' ...)`):

```dart
        if (role == 'buyer' && status == 'fulfilled')
          ElevatedButton(
            onPressed: _openRecurringOrderSheet,
            child: const Text('Jadikan Recurring Order'),
          ),
```

- [ ] **Step 4: `flutter analyze`**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 5: (Tidak commit)**

---

### Task 9: Regression check + QA manual

**Files:** tidak ada file baru.

- [ ] **Step 1: Full test suite**

Run: `flutter test`
Expected: 26/26 pass.

- [ ] **Step 2: `flutter analyze` final**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 3: QA manual di device — alur penuh FG-40 → FG-39**

1. Login sebagai `buyer.test@farmbridge.dev`, buka transaksi `4f58b43f-6c6a-497b-93ce-7ad7a945cb70` (sudah `fulfilled` dari Sprint 8 QA) — kalau sudah tidak bisa diakses dari UI (tidak ada listing riwayat transaksi), buat transaksi `fulfilled` baru dulu (ulangi alur Sprint 8 Task 6 QA).
2. Tombol "Jadikan Recurring Order" harus muncul (status `fulfilled` + role buyer).
3. Isi kuantitas + pilih frekuensi → submit → harus auto-navigate ke Recurring Order Detail, data sesuai input.
4. Tap "Jeda" → modal konfirmasi → confirm → status jadi `paused`, tombol berubah jadi "Aktifkan Lagi" + "Batalkan".
5. Tap "Batalkan" → confirm → status `cancelled`, **tidak ada tombol aksi apapun** lagi.
6. Dari Profil (buyer & farmer) → icon recurring order di AppBar → daftar My Recurring Orders muncul dengan status badge benar.

- [ ] **Step 4: QA manual — FG-60 archive guard**

1. Login sebagai farmer, buka Listing Saya.
2. Tap icon archive pada listing yang punya recurring order aktif → harus muncul SnackBar error jelas, listing tidak berubah status.
3. Tap archive pada listing tanpa recurring aktif → berhasil, listing pindah ke state "Diarsipkan" (tombol edit/archive hilang).

- [ ] **Step 5: QA manual — FG-38 (sudah tercover Task 3 Step 4-5 via curl+SQL)**

Opsional: verifikasi ulang dari sisi UI — buka transaksi hasil siklus recurring (`negotiation_id` NULL, `recurring_order_id` terisi) di Transaction Detail, pastikan tetap render normal (halaman ini query lewat `negotiations(...)` join — cek tidak error kalau `negotiation_id` NULL, karena `getTransaction()` saat ini asumsikan selalu ada negotiation terkait).

**Catatan penting:** `TransactionRepository.getTransaction()` (`lib/features/transaction/data/transaction_repository.dart`) query `'*, negotiations(listing_id, listings(*, farmer_profiles(nama, lokasi)))'` — untuk transaksi hasil siklus recurring (`negotiation_id` NULL), join ini akan mengembalikan `null` untuk `negotiations`, dan `_buildBody()` di `TransactionDetailScreen` akan menampilkan listing title `'-'`, petani `'-'`, dst (bukan crash, karena kode sudah pakai `?.`/`??` di semua tempat itu — dicek langsung di file). **Tapi** ini artinya Transaction Detail untuk transaksi siklus recurring akan terlihat kosong/tidak informatif. Kalau ini dianggap masalah nyata setelah QA Step 5, perbaikannya: tambah fallback di `getTransaction()`/`_buildBody` untuk fetch listing lewat `recurring_order_id → recurring_orders.listing_id` kalau `negotiation_id` NULL — **di luar scope plan ini**, dicatat sebagai temuan untuk sprint berikutnya kalau QA mengonfirmasi ini masalah nyata.

---

## Self-Review

**Spec coverage:**
- FG-38 (day-of trigger, stok cukup→transaction, stok kurang→skip tetap active, §11) → Task 3, ditambah migration schema (Task 1) yang sebelumnya tidak ada.
- FG-39 (list+detail, status Active/Paused/Cancelled, Pause/Cancel/Resume, cancel→tidak ada resume) → Task 6+7.
- FG-40 (CTA setelah fulfilled, form frequency, submit→create) → Task 8.
- FG-60 (guard archive backend tidak bisa di-bypass + pesan UI jelas) → Task 4+5.

**Placeholder scan:** tidak ada TBD/TODO tersembunyi. Satu catatan eksplisit di Task 9 Step 5 soal `getTransaction()` yang berpotensi kurang informatif untuk transaksi siklus recurring — ditandai jelas sebagai "di luar scope, cek dulu apa benar masalah nyata", bukan pekerjaan yang disembunyikan.

**Placeholder/asumsi PRD:** 2 dicatat eksplisit di bagian "Asumsi eksplisit" di atas (gate konfirmasi farmer, nilai `frequency`) — konsisten dengan gap yang sudah diakui tim asli sendiri di `sprint9_fachri_dev.md`, bukan tebakan sepihak.

**Type consistency:** `lockInventoryForRecurringCycle` (Task 3) dipanggil dengan field yang sama persis dari hasil query `recurring_orders` (`id, listing_id, farmer_id, buyer_id, quantity, locked_price`). `RecurringOrderRepository.create()` (Task 6) dipanggil dengan named params yang sama di `_openRecurringOrderSheet()` (Task 8).

**Dependency antar-task:** Task 1 → Task 3 (butuh kolom `recurring_order_id`). Task 2 → Task 3 (butuh shared `FREQUENCY_DAYS`). Task 4 independen (guard listing, tidak bergantung task lain). Task 6 → Task 7 & Task 8 (keduanya pakai repository). Task 7 harus sebelum Task 8 kalau mau langsung tes navigasi CTA→Detail (tapi kode Task 8 tetap valid ditulis duluan, cuma navigasinya belum bisa dites end-to-end sampai Task 7 ada). Task 9 di akhir, butuh semua task lain selesai.
