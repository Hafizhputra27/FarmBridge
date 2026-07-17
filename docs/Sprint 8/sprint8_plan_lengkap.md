> Dipindahkan dari `docs/superpowers/plans/2026-07-17-sprint8-fulfillment-recurring-fcm.md` ke folder ini atas permintaan user (2026-07-17) — user mengerjakan ketiga role (`hafizh_dev`/`nevan_dev`/`fachri_dev`) sendiri, plan ini jadi panduan tunggal untuk semuanya, menggantikan pembagian per-orang di `sprint8_hafizh_dev.md`/`sprint8_fachri_dev.md`.
>
> **Catatan penyesuaian dari checklist lama (`sprint8_hafizh_dev.md`):** checklist itu mengasumsikan wiring FCM untuk `expire-negotiations` ada di `supabase/functions/expire-negotiations/**` sebagai Edge Function terpisah. Setelah dicek langsung ke database, **itu tidak ada** — auto-expire negotiations sejak Sprint 6 diimplementasikan sebagai SQL murni (`DO` block) langsung di dalam `cron.job`, bukan Edge Function, jadi tidak bisa memanggil `sendPush` (kode TypeScript) dari situ tanpa dikonversi dulu jadi Edge Function + `pg_net.http_post` — pola yang sama seperti Task 5 di bawah untuk `check-recurring-orders`. **Plan ini SENGAJA tidak mengambil scope itu** (push saat negosiasi *expired* otomatis) — hanya push untuk aksi manual (create/message/counter/accept/decline, Task 4). Kalau push saat expired juga dibutuhkan, itu kerjaan tambahan setara Task 5 (Edge Function baru + migration `pg_net` + reschedule cron `expire-negotiations`), belum termasuk di sini.

# Sprint 8: Fulfillment UI + Recurring Backend + Notifikasi Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Selesaikan 3 ticket Sprint 8 (`docs/FarmBridge_Sprint_Roadmap.md`, `sprint8_README.md`): FG-34 (Fulfillment Form UI + modal), FG-37 (POST/PATCH /recurring-orders), FG-41/FG-42 (FCM wiring — negosiasi & reminder recurring order H-1).

**Architecture:** FG-34 melengkapi tombol "Tandai Terkirim" yang sejak Sprint 7 masih stub `SnackBar` di `TransactionDetailScreen`, dengan form kuantitas+tanggal → modal konfirmasi → panggil Edge Function `transactions-fulfill` (sudah ada dari FG-32). FG-37 adalah Edge Function baru `recurring-orders` — tabel `recurring_orders` sudah ada sejak migration awal (`initial_schema.sql`), belum ada endpoint yang menulisinya. FG-41 menambahkan pemanggilan `sendPush` (sudah ada, `_shared/fcm.ts`) ke dalam Edge Function `negotiations` yang sudah ada, di titik create & setiap message/action. FG-42 mengisi cron job `check-recurring-orders` yang sejak Sprint 1 baru berupa placeholder (`INSERT ... 'skipped'`) — diisi jadi Edge Function baru yang benar-benar dipanggil lewat `pg_net.http_post` dari pg_cron, khusus kirim reminder H-1 (**bukan** membuat transaction baru — itu scope FG-38 di Sprint 9, sengaja tidak diambil di sini).

**Tech Stack:** Flutter (Riverpod, GoRouter) + Supabase Edge Functions (Deno) + pg_cron/pg_net — tidak ada dependency baru.

## Global Constraints

- **Jangan pernah menjalankan `git add`/`commit`/`push`/`merge`/dll** — repo ini (`docs/CLAUDE.md`) melarang keras operasi git apapun yang mengubah state, tanpa pengecualian. Kalau plan ini dieksekusi lewat agent, agent HARUS berhenti sebelum langkah commit dan biarkan user commit manual.
- Semua copy notifikasi/error Bahasa Indonesia, konsisten dengan seluruh codebase.
- Ikuti gaya Edge Function yang sudah ada persis: `Response` inline berulang (`new Response(JSON.stringify(...), {status, headers})`), bukan helper baru — semua function existing (`negotiations`, `buy-now`, `transactions-fulfill`, `transactions-reject`) konsisten pakai pola ini.
- Tidak ada `intl` di `pubspec.yaml` — format tanggal manual (`'${d.year}-${d.month.toString().padLeft(2,'0')}-...'`), jangan tambah dependency baru untuk itu.
- Publishable/anon key project (`sb_publishable_-tmXQTkiRSNHtvjBVILpvA_oGVnliRX`) aman diinlinekan di migration SQL — sudah jadi konvensi project (ada di `lib/main.dart:17` juga). **Jangan pernah** inlinekan `service_role` key di file yang ke-commit.
- `flutter analyze` harus 0 issue dan `flutter test` harus tetap 26/26 pass setelah setiap task Flutter.

---

### Task 1: Edge Function `recurring-orders` (FG-37)

**Files:**
- Create: `supabase/functions/recurring-orders/index.ts`

**Interfaces:**
- Produces: `POST /recurring-orders` `{buyer_id, farmer_id, listing_id, quantity, frequency, locked_price}` → `{recurring_order_id, next_order_date}`; `PATCH /recurring-orders/:id` `{status}` → `{recurring_order_id, status}`. Dipakai Sprint 9 (FG-39 My Recurring Orders UI) sebagai data source.

Skema tabel `recurring_orders` (sudah ada, `supabase/migrations/20260716083135_initial_schema.sql`): `id uuid PK`, `buyer_id uuid FK→users`, `farmer_id uuid FK→users`, `listing_id uuid FK→listings`, `quantity numeric NOT NULL`, `frequency text NOT NULL`, `locked_price numeric NOT NULL`, `status text DEFAULT 'active'`, `next_order_date date NOT NULL`, `created_at timestamptz`. RLS participant-only sudah ada (`20260716092201_rls_policies.sql`) — tidak perlu migration RLS baru.

- [ ] **Step 1: Tulis Edge Function**

```ts
import { createClient } from "npm:@supabase/supabase-js@2";

function parsePath(path: string): { id?: string } {
  const parts = path.replace(/^\/recurring-orders\/?/, "").split("/").filter(Boolean);
  return { id: parts[0] };
}

const FREQUENCY_DAYS: Record<string, number> = { weekly: 7, biweekly: 14, monthly: 30 };
const VALID_STATUSES = ["active", "paused", "cancelled"];

// --- POST /recurring-orders ---
async function handleCreate(supabase: ReturnType<typeof createClient>, body: Record<string, unknown>) {
  const { buyer_id, farmer_id, listing_id, quantity, frequency, locked_price } = body;

  if (!buyer_id || !farmer_id || !listing_id || quantity == null || !frequency || locked_price == null) {
    return new Response(JSON.stringify({ error: "buyer_id, farmer_id, listing_id, quantity, frequency, locked_price wajib" }), { status: 400, headers: { "Content-Type": "application/json" } });
  }
  if (!(frequency as string in FREQUENCY_DAYS)) {
    return new Response(JSON.stringify({ error: `frequency harus salah satu: ${Object.keys(FREQUENCY_DAYS).join(", ")}` }), { status: 400, headers: { "Content-Type": "application/json" } });
  }
  if (Number(quantity) <= 0) {
    return new Response(JSON.stringify({ error: "quantity harus > 0" }), { status: 400, headers: { "Content-Type": "application/json" } });
  }
  if (Number(locked_price) <= 0) {
    return new Response(JSON.stringify({ error: "locked_price harus > 0" }), { status: 400, headers: { "Content-Type": "application/json" } });
  }

  const { data: listing, error: listingErr } = await supabase.from("listings").select("status").eq("id", listing_id as string).single();
  if (listingErr || !listing) return new Response(JSON.stringify({ error: "Listing tidak ditemukan" }), { status: 404, headers: { "Content-Type": "application/json" } });
  if (listing.status !== "active") return new Response(JSON.stringify({ error: "listing_id sudah tidak berstatus active" }), { status: 400, headers: { "Content-Type": "application/json" } });

  const nextOrderDate = new Date();
  nextOrderDate.setDate(nextOrderDate.getDate() + FREQUENCY_DAYS[frequency as string]);

  const { data: order, error: insertErr } = await supabase.from("recurring_orders").insert({
    buyer_id, farmer_id, listing_id, quantity, frequency, locked_price,
    next_order_date: nextOrderDate.toISOString().slice(0, 10),
    status: "active",
  }).select("id, next_order_date").single();

  if (insertErr) throw new Error("Gagal membuat recurring order: " + insertErr.message);

  return new Response(JSON.stringify({ recurring_order_id: order.id, next_order_date: order.next_order_date }), { status: 200, headers: { "Content-Type": "application/json" } });
}

// --- PATCH /recurring-orders/:id ---
async function handlePatch(supabase: ReturnType<typeof createClient>, id: string, body: Record<string, unknown>) {
  const { status } = body;
  if (!status || !VALID_STATUSES.includes(status as string)) {
    return new Response(JSON.stringify({ error: `status harus salah satu: ${VALID_STATUSES.join(", ")}` }), { status: 400, headers: { "Content-Type": "application/json" } });
  }

  const { data: order, error: getErr } = await supabase.from("recurring_orders").select("status").eq("id", id).single();
  if (getErr || !order) return new Response(JSON.stringify({ error: "Recurring order tidak ditemukan" }), { status: 404, headers: { "Content-Type": "application/json" } });

  if (order.status === "cancelled") {
    return new Response(JSON.stringify({ error: "Recurring order sudah cancelled, transisi status tidak valid" }), { status: 409, headers: { "Content-Type": "application/json" } });
  }

  const { error: updateErr } = await supabase.from("recurring_orders").update({ status }).eq("id", id);
  if (updateErr) throw new Error("Gagal update status: " + updateErr.message);

  return new Response(JSON.stringify({ recurring_order_id: id, status }), { status: 200, headers: { "Content-Type": "application/json" } });
}

// --- ROUTER ---
Deno.serve(async (req: Request) => {
  const supabase = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);

  const url = new URL(req.url);
  const pathname = url.pathname.replace(/^\/functions\/v1\/recurring-orders/, "/recurring-orders");
  const { id } = parsePath(pathname);

  try {
    if (!id && req.method === "POST") {
      const body = await req.json();
      return await handleCreate(supabase, body);
    }
    if (id && req.method === "PATCH") {
      const body = await req.json();
      return await handlePatch(supabase, id, body);
    }
    return new Response(JSON.stringify({ error: "Route not found" }), { status: 404, headers: { "Content-Type": "application/json" } });
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), { status: 500, headers: { "Content-Type": "application/json" } });
  }
});
```

- [ ] **Step 2: Deploy**

```bash
supabase functions deploy recurring-orders --project-ref rwxnjxmzkcfoddnzjosi
```

- [ ] **Step 3: Verifikasi create — pakai listing/buyer/farmer test yang sudah ada**

```bash
curl -s -X POST "https://rwxnjxmzkcfoddnzjosi.supabase.co/functions/v1/recurring-orders" \
  -H "apikey: sb_publishable_-tmXQTkiRSNHtvjBVILpvA_oGVnliRX" \
  -H "Authorization: Bearer sb_publishable_-tmXQTkiRSNHtvjBVILpvA_oGVnliRX" \
  -H "Content-Type: application/json" \
  -d '{"buyer_id":"ed23f6a6-21cb-4576-89ac-d8bfdae08a78","farmer_id":"dd97243c-c350-4282-8fe2-4e8e1084f951","listing_id":"255b9d9a-a093-45a8-8599-da5f0f7d63d9","quantity":5,"frequency":"weekly","locked_price":35000}'
```
Expected: `{"recurring_order_id": "...", "next_order_date": "<H+7 dari hari ini>"}`.

- [ ] **Step 4: Verifikasi PATCH — pause lalu coba resume dari cancelled (harus gagal)**

```bash
# Ganti <ID> dengan recurring_order_id dari Step 3
curl -s -X PATCH "https://rwxnjxmzkcfoddnzjosi.supabase.co/functions/v1/recurring-orders/<ID>" \
  -H "apikey: sb_publishable_-tmXQTkiRSNHtvjBVILpvA_oGVnliRX" \
  -H "Authorization: Bearer sb_publishable_-tmXQTkiRSNHtvjBVILpvA_oGVnliRX" \
  -H "Content-Type: application/json" \
  -d '{"status":"cancelled"}'
# Expected: {"recurring_order_id":"<ID>","status":"cancelled"}

curl -s -X PATCH "https://rwxnjxmzkcfoddnzjosi.supabase.co/functions/v1/recurring-orders/<ID>" \
  -H "apikey: sb_publishable_-tmXQTkiRSNHtvjBVILpvA_oGVnliRX" \
  -H "Authorization: Bearer sb_publishable_-tmXQTkiRSNHtvjBVILpvA_oGVnliRX" \
  -H "Content-Type: application/json" \
  -d '{"status":"active"}'
# Expected: 409 "Recurring order sudah cancelled, transisi status tidak valid"
```

- [ ] **Step 5: (Tidak commit — sesuai `docs/CLAUDE.md`)**

---

### Task 2: `TransactionRepository.fulfill()` (FG-34 backend wiring)

**Files:**
- Modify: `lib/features/transaction/data/transaction_repository.dart`

**Interfaces:**
- Consumes: Edge Function `transactions-fulfill/fulfill/:id` (sudah ada, FG-32) — `{delivered_quantity, actual_delivery_date}` → `{transaction_id, status, trust_metrics_updated}`.
- Produces: `Future<void> fulfill(String transactionId, {required int deliveredQuantity, required DateTime actualDeliveryDate})` — dipakai Task 3.

- [ ] **Step 1: Tambah method `fulfill()`**

Tambahkan method baru setelah `reject()` (baris 40, sebelum penutup `}` class):

```dart
  Future<void> fulfill(
    String transactionId, {
    required int deliveredQuantity,
    required DateTime actualDeliveryDate,
  }) async {
    final dateStr = '${actualDeliveryDate.year}-'
        '${actualDeliveryDate.month.toString().padLeft(2, '0')}-'
        '${actualDeliveryDate.day.toString().padLeft(2, '0')}';
    final res = await _client.functions.invoke(
      'transactions-fulfill/fulfill/$transactionId',
      method: HttpMethod.post,
      body: {
        'delivered_quantity': deliveredQuantity,
        'actual_delivery_date': dateStr,
      },
    );
    final data = res.data as Map<String, dynamic>?;
    if (data != null && data['error'] != null) {
      throw Exception(data['error']);
    }
  }
```

- [ ] **Step 2: `flutter analyze`**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 3: (Tidak commit)**

---

### Task 3: Fulfillment Form UI + modal konfirmasi (FG-34 frontend)

**Files:**
- Modify: `lib/features/transaction/screens/transaction_detail_screen.dart`

**Interfaces:**
- Consumes: `TransactionRepository.fulfill()` dari Task 2.

Ganti tombol "Tandai Terkirim" yang sekarang cuma `SnackBar` stub, jadi form kuantitas+tanggal → modal "Anda yakin?" → submit — sesuai PRD §4.1 "Fulfillment": *"Petani menandai pesanan sebagai terkirim dengan mengisi delivered_quantity dan actual_delivery_date, dikonfirmasi lewat modal 'Anda yakin?' sebelum submit (aksi ini tidak bisa dibatalkan setelah tersimpan)."*

- [ ] **Step 1: Tambah state field `_isFulfilling`**

Di `_TransactionDetailScreenState`, tambahkan field baru setelah `bool _isRejecting = false;`:

```dart
  bool _isFulfilling = false;
```

- [ ] **Step 2: Tambah method `_openFulfillSheet()` dan `_confirmFulfill()`**

Tambahkan setelah method `_confirmReject()` (sebelum `@override Widget build`):

```dart
  Future<void> _openFulfillSheet() async {
    final tx = _tx!;
    final quantityController = TextEditingController(
      text: tx['agreed_quantity'].toString(),
    );
    DateTime selectedDate = DateTime.now();
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
                  const Text(
                    'Tandai Terkirim',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: quantityController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Kuantitas terkirim',
                    ),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Tanggal kirim'),
                    subtitle: Text(
                      '${selectedDate.year}-'
                      '${selectedDate.month.toString().padLeft(2, '0')}-'
                      '${selectedDate.day.toString().padLeft(2, '0')}',
                    ),
                    trailing: const Icon(Icons.calendar_today, size: 18),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setSheetState(() => selectedDate = picked);
                      }
                    },
                  ),
                  if (sheetError != null) ...[
                    const SizedBox(height: 8),
                    Text(sheetError!, style: const TextStyle(color: Colors.red)),
                  ],
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      final qty = int.tryParse(quantityController.text);
                      if (qty == null || qty <= 0) {
                        setSheetState(
                          () => sheetError = 'Kuantitas harus lebih dari 0',
                        );
                        return;
                      }
                      Navigator.pop(ctx);
                      _confirmFulfill(qty, selectedDate);
                    },
                    child: const Text('Lanjutkan'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _confirmFulfill(int deliveredQuantity, DateTime deliveryDate) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tandai Terkirim?'),
        content: const Text(
          'Data tidak bisa diubah setelah disimpan. Trust score petani '
          'akan diperbarui otomatis berdasarkan kuantitas & tanggal ini.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ya, Tandai Terkirim'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isFulfilling = true);
    try {
      await _repo.fulfill(
        widget.transactionId,
        deliveredQuantity: deliveredQuantity,
        actualDeliveryDate: deliveryDate,
      );
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menandai terkirim: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isFulfilling = false);
    }
  }
```

- [ ] **Step 3: Ganti tombol stub jadi tombol asli + guard status `pending`**

Ganti (blok `if (role == 'farmer')` di `_buildBody`):

```dart
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
```

menjadi:

```dart
        if (role == 'farmer' && status == 'pending')
          ElevatedButton(
            onPressed: _isFulfilling ? null : _openFulfillSheet,
            child: _isFulfilling
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Tandai Terkirim'),
          ),
```

(Guard `status == 'pending'` baru — tombol lama tampil terus untuk role farmer terlepas status, termasuk transaksi yang sudah `fulfilled`/`rejected`. Konsisten dengan tombol Tolak Transaksi milik buyer yang sudah lebih dulu pakai guard status yang sama.)

- [ ] **Step 4: `flutter analyze`**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 5: (Tidak commit)**

---

### Task 4: FCM wiring — negosiasi (FG-41)

**Files:**
- Modify: `supabase/functions/negotiations/index.ts`

**Interfaces:**
- Consumes: `sendPush` dari `_shared/fcm.ts` (sudah ada, FG-6) — `{deviceToken, title, body, deepLink?}` → `{ok, error?}`.

Push dikirim di 2 titik: (a) `handleCreate` — notify farmer ada negosiasi baru; (b) `handleMessages` — notify pihak lain (bukan `sender_id`) setiap ada pesan/counter/accept/decline. Kegagalan push **tidak boleh** menggagalkan alur negosiasi utama — selalu dibungkus try/catch silent, sama seperti `transactions-fulfill` memanggil `update-trust-metrics`.

**Di luar scope task ini:** push saat negosiasi *expired* otomatis (cron `expire-negotiations`) — itu SQL murni, bukan Edge Function, tidak bisa dipanggil `sendPush` langsung. Lihat catatan di kepala dokumen ini.

- [ ] **Step 1: Tambah import**

Di baris paling atas (setelah import `lockInventoryOnAcceptWithQuantity`):

```ts
import { sendPush } from "../_shared/fcm.ts";
```

- [ ] **Step 2: Notify farmer di `handleCreate`**

Cari baris ini di `handleCreate` (sebelum `return new Response(JSON.stringify({ negotiation_id: negotiation.id, ...`):

```ts
  if (negErr) throw new Error("Gagal membuat negosiasi: " + negErr.message);

  return new Response(JSON.stringify({ negotiation_id: negotiation.id, recommended_price: priceResult.recommended_price, avg_price: priceResult.avg_price, min_price: priceResult.min_price, max_price: priceResult.max_price, status: negotiation.status, expires_at: negotiation.expires_at }), { status: 200, headers: { "Content-Type": "application/json" } });
```

Ganti jadi:

```ts
  if (negErr) throw new Error("Gagal membuat negosiasi: " + negErr.message);

  try {
    const { data: farmer } = await supabase.from("users").select("device_token").eq("id", listing.farmer_id).single();
    if (farmer?.device_token) {
      await sendPush({
        deviceToken: farmer.device_token,
        title: "Negosiasi baru",
        body: `Ada tawaran baru untuk listing ${listing.title ?? listing.category ?? "Anda"}`,
        deepLink: `/negosiasi/${negotiation.id}`,
      });
    }
  } catch {
    // push gagal tidak boleh gagalkan pembuatan negosiasi
  }

  return new Response(JSON.stringify({ negotiation_id: negotiation.id, recommended_price: priceResult.recommended_price, avg_price: priceResult.avg_price, min_price: priceResult.min_price, max_price: priceResult.max_price, status: negotiation.status, expires_at: negotiation.expires_at }), { status: 200, headers: { "Content-Type": "application/json" } });
```

- [ ] **Step 3: Notify pihak lain di `handleMessages`**

Cari baris ini (baris terakhir `handleMessages`, sebelum penutup fungsi):

```ts
  const updateData: Record<string, unknown> = { status: newStatus };
  if (action_type === "counter" && offer_price != null) { updateData.current_offer_price = Number(offer_price); updateData.counter_count = (neg.counter_count ?? 0) + 1; }
  await supabase.from("negotiations").update(updateData).eq("id", negotiationId);

  return new Response(JSON.stringify({ message_id: msg.id, negotiation_status: newStatus, transaction_id: transactionId ?? null }), { status: 200, headers: { "Content-Type": "application/json" } });
```

Ganti jadi:

```ts
  const updateData: Record<string, unknown> = { status: newStatus };
  if (action_type === "counter" && offer_price != null) { updateData.current_offer_price = Number(offer_price); updateData.counter_count = (neg.counter_count ?? 0) + 1; }
  await supabase.from("negotiations").update(updateData).eq("id", negotiationId);

  try {
    const recipientId = sender_id === neg.buyer_id ? neg.farmer_id : neg.buyer_id;
    const { data: recipient } = await supabase.from("users").select("device_token").eq("id", recipientId).single();
    if (recipient?.device_token) {
      const titles: Record<string, string> = {
        message: "Pesan baru",
        counter: "Tawaran baru",
        accept: "Negosiasi diterima",
        decline: "Negosiasi ditolak",
      };
      const bodies: Record<string, string> = {
        message: message_text ? String(message_text) : "Ada pesan baru di negosiasi Anda",
        counter: `Tawaran baru: Rp${offer_price}`,
        accept: "Tawaran Anda diterima — transaksi telah dibuat",
        decline: "Negosiasi ditolak oleh pihak lain",
      };
      await sendPush({
        deviceToken: recipient.device_token,
        title: titles[action_type as string] ?? "Update negosiasi",
        body: bodies[action_type as string] ?? "Ada update di negosiasi Anda",
        deepLink: `/negosiasi/${negotiationId}`,
      });
    }
  } catch {
    // push gagal tidak boleh gagalkan response utama
  }

  return new Response(JSON.stringify({ message_id: msg.id, negotiation_status: newStatus, transaction_id: transactionId ?? null }), { status: 200, headers: { "Content-Type": "application/json" } });
```

- [ ] **Step 4: Deploy**

```bash
supabase functions deploy negotiations --project-ref rwxnjxmzkcfoddnzjosi
```

- [ ] **Step 5: Verifikasi tidak crash (curl) + verifikasi push nyata (device)**

```bash
curl -s -X POST "https://rwxnjxmzkcfoddnzjosi.supabase.co/functions/v1/negotiations" \
  -H "apikey: sb_publishable_-tmXQTkiRSNHtvjBVILpvA_oGVnliRX" \
  -H "Authorization: Bearer sb_publishable_-tmXQTkiRSNHtvjBVILpvA_oGVnliRX" \
  -H "Content-Type: application/json" \
  -d '{"listing_id":"255b9d9a-a093-45a8-8599-da5f0f7d63d9","buyer_id":"ed23f6a6-21cb-4576-89ac-d8bfdae08a78","initial_price":30000,"quantity":1}'
```
Expected: response sukses seperti biasa (`negotiation_id`, dll) — **push gagal (device_token kosong/null) tidak boleh bikin request ini error**, itu intinya try/catch di Step 2/3.

**Catatan penting untuk QA di device:** saat testing Sprint 7, notification permission Android sempat ditolak ("Jangan izinkan") di kedua akun test. Push tidak akan pernah muncul secara visual sampai izin notifikasi diberikan ulang (Settings App → FarmBridge → Notifications → Allow) dan `FcmService.syncDeviceToken()` sempat jalan lagi (login ulang cukup, dipanggil dari `AuthNotifier`). Tanpa itu, `users.device_token` boleh jadi `null` dan kode di atas akan diam-diam skip push (`if (farmer?.device_token)`) — bukan bug, tapi jangan kaget kalau push tidak muncul saat baru pertama coba.

- [ ] **Step 6: (Tidak commit)**

---

### Task 5: FCM wiring — reminder recurring order H-1 (FG-42)

**Files:**
- Create: `supabase/functions/check-recurring-orders/index.ts`
- Create: `supabase/migrations/20260717120000_recurring_orders_cron_pgnet.sql`

**Interfaces:**
- Consumes: `sendPush` dari `_shared/fcm.ts`; tabel `recurring_orders` (dari Task 1, sudah ada skemanya).
- Scope sengaja dibatasi ke **notifikasi H-1 saja** — pembuatan `transaction` baru saat H-1 tercapai adalah FG-38 (Sprint 9), bukan bagian plan ini.

- [ ] **Step 1: Tulis Edge Function**

```ts
import { createClient } from "npm:@supabase/supabase-js@2";
import { sendPush } from "../_shared/fcm.ts";

Deno.serve(async (req: Request) => {
  const supabase = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);

  try {
    const tomorrow = new Date();
    tomorrow.setDate(tomorrow.getDate() + 1);
    const tomorrowStr = tomorrow.toISOString().slice(0, 10);

    const { data: dueOrders, error: dueErr } = await supabase
      .from("recurring_orders")
      .select("id, buyer_id, farmer_id, listings(title, category)")
      .eq("status", "active")
      .eq("next_order_date", tomorrowStr);

    if (dueErr) throw new Error("Gagal query recurring_orders: " + dueErr.message);

    let notified = 0;
    for (const order of dueOrders ?? []) {
      const listing = order.listings as { title: string | null; category: string | null } | null;
      const listingLabel = listing?.title ?? listing?.category ?? "listing Anda";

      const { data: users } = await supabase
        .from("users")
        .select("id, device_token")
        .in("id", [order.buyer_id, order.farmer_id]);

      for (const user of users ?? []) {
        if (!user.device_token) continue;
        try {
          await sendPush({
            deviceToken: user.device_token,
            title: "Recurring order besok",
            body: `Recurring order untuk ${listingLabel} jatuh tempo besok`,
            deepLink: "/percakapan",
          });
          notified++;
        } catch {
          // satu push gagal tidak boleh hentikan yang lain
        }
      }
    }

    await supabase.from("cron_execution_log").insert({
      job_name: "check-recurring-orders",
      status: "success",
      message: `${dueOrders?.length ?? 0} recurring order jatuh tempo besok, ${notified} notifikasi terkirim`,
    });

    return new Response(JSON.stringify({ due_orders: dueOrders?.length ?? 0, notified }), { status: 200, headers: { "Content-Type": "application/json" } });
  } catch (error) {
    await supabase.from("cron_execution_log").insert({
      job_name: "check-recurring-orders",
      status: "error",
      message: error.message,
    });
    return new Response(JSON.stringify({ error: error.message }), { status: 500, headers: { "Content-Type": "application/json" } });
  }
});
```

(`deepLink: "/percakapan"` dipakai sementara — belum ada layar detail recurring order sampai FG-39/Sprint 9 dibangun, jadi diarahkan ke Chat Inbox yang sudah ada alih-alih menebak route yang belum tentu ada.)

- [ ] **Step 2: Deploy function**

```bash
supabase functions deploy check-recurring-orders --project-ref rwxnjxmzkcfoddnzjosi
```

- [ ] **Step 3: Migration — aktifkan `pg_net`, reschedule cron supaya benar-benar memanggil function**

`pg_net` **belum aktif** di project ini (dicek langsung: `select extname from pg_extension` cuma ada `pg_cron`) — tanpa ini, `net.http_post` tidak ada dan cron tidak bisa memanggil Edge Function sama sekali. Cron job `check-recurring-orders` sudah ter-schedule sejak Sprint 1 (`20260716092216_realtime_storage_cron.sql`) tapi isinya masih placeholder `INSERT ... 'skipped'` — migration ini menggantinya.

Buat file `supabase/migrations/20260717120000_recurring_orders_cron_pgnet.sql`:

```sql
-- ============================================================
-- FG-42: aktifkan pg_net + reschedule check-recurring-orders
-- supaya benar-benar memanggil Edge Function (kirim reminder
-- H-1), bukan cuma insert log placeholder seperti sejak Sprint 1.
-- ============================================================
CREATE EXTENSION IF NOT EXISTS pg_net;

SELECT cron.unschedule('check-recurring-orders');

SELECT cron.schedule(
  'check-recurring-orders',
  '0 8 * * *',
  $$
  SELECT net.http_post(
    url := 'https://rwxnjxmzkcfoddnzjosi.supabase.co/functions/v1/check-recurring-orders',
    headers := '{"Content-Type": "application/json", "Authorization": "Bearer sb_publishable_-tmXQTkiRSNHtvjBVILpvA_oGVnliRX"}'::jsonb,
    body := '{}'::jsonb
  );
  $$
);
```

Apply migration (lewat Supabase Dashboard SQL Editor, atau `supabase db push` kalau CLI sudah linked — **jangan** lewat MCP `apply_migration` tanpa direview dulu, ini mengubah cron job production).

- [ ] **Step 4: Verifikasi manual — trigger langsung tanpa nunggu jam 08:00**

Buat 1 recurring order test dengan `next_order_date` = besok (pakai hasil Task 1 Step 3, atau insert manual), lalu panggil function langsung:

```bash
curl -s -X POST "https://rwxnjxmzkcfoddnzjosi.supabase.co/functions/v1/check-recurring-orders" \
  -H "apikey: sb_publishable_-tmXQTkiRSNHtvjBVILpvA_oGVnliRX" \
  -H "Authorization: Bearer sb_publishable_-tmXQTkiRSNHtvjBVILpvA_oGVnliRX"
```
Expected: `{"due_orders": <n>, "notified": <m>}` — kalau `due_orders` masih 0, cek `next_order_date` recurring order test memang persis besok (`current_date + 1`).

- [ ] **Step 5: Verifikasi cron beneran jalan (opsional, tunggu sampai jam terjadwal atau ubah schedule sementara ke `* * * * *` buat tes cepat lalu kembalikan ke `0 8 * * *`)**

```sql
select * from cron_execution_log where job_name = 'check-recurring-orders' order by executed_at desc limit 5;
```
Expected: baris `status='success'` muncul, bukan lagi `'skipped'`.

- [ ] **Step 6: (Tidak commit)**

---

### Task 6: Regression check + catatan QA manual

**Files:** tidak ada file baru.

- [ ] **Step 1: Full test suite**

Run: `flutter test`
Expected: 26/26 pass (tidak ada test baru ditambahkan — tidak ada test existing yang menyentuh area yang diubah).

- [ ] **Step 2: `flutter analyze` final**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 3: QA manual di device — Fulfillment Form (FG-34)**

1. Login sebagai `farmer.test@farmbridge.dev` (atau farmer pemilik transaksi `pending` yang sudah ada dari sesi Sprint 7 — transaksi `f0f5e27a...`/`29634bd7`→transaksi terkait dimiliki `dd97243c...`, **bukan** `farmer.test`; kalau mau pakai farmer itu langsung, perlu tahu kredensialnya, atau buat transaksi baru dengan `farmer.test` sebagai farmer_id sejak listing/negosiasi).
2. Buka Transaction Detail transaksi `pending` milik farmer tsb.
3. Tap "Tandai Terkirim" → isi kuantitas → pilih tanggal → "Lanjutkan" → modal "Anda yakin?" muncul → confirm.
4. Expected: layar reload, status jadi `fulfilled`, tombol "Tandai Terkirim" hilang (guard status baru).
5. Cek `trust_metrics` farmer ter-update (query SQL atau `GET /trust-metrics/:farmer_id`).

- [ ] **Step 4: QA manual — Recurring Orders (FG-37)**

Sudah tercover lewat curl di Task 1 Step 3-4 — tidak ada UI untuk ini sampai Sprint 9 (FG-39), jadi endpoint saja yang perlu benar untuk sekarang.

- [ ] **Step 5: QA manual — FCM (FG-41/FG-42)**

1. Pastikan notification permission Android di-allow (lihat catatan Task 4 Step 5).
2. Login ulang supaya `device_token` ter-sync (`FcmService.syncDeviceToken()` dipanggil dari alur login).
3. Trigger 1 aksi negosiasi (counter/accept/decline) dari akun lain → expected: notifikasi muncul di system tray device penerima.
4. Trigger `check-recurring-orders` manual (Task 5 Step 4) dengan recurring order test yang buyer/farmer-nya salah satu akun ber-`device_token` valid → expected: notifikasi "Recurring order besok" muncul.

---

## Self-Review

**Spec coverage:**
- FG-34 (Fulfillment Form UI + modal konfirmasi, non-cancelable, update trust_metrics otomatis) → Task 2+3, sesuai PRD §4.1.
- FG-37 (POST/PATCH /recurring-orders, validasi listing active, transisi status invalid → 409) → Task 1, sesuai PRD §9.
- FG-41 (FCM wiring negosiasi) → Task 4.
- FG-42 (FCM wiring H-1 reminder) → Task 5, scope dibatasi eksplisit ke notifikasi saja (bukan FG-38/pembuatan transaction, itu Sprint 9).

**Placeholder scan:** tidak ada TBD/TODO — semua step berisi kode lengkap siap tempel. Satu catatan eksplisit soal `deepLink` sementara ("/percakapan") karena layar recurring order detail memang belum ada — bukan placeholder yang menyembunyikan pekerjaan belum selesai, tapi keputusan sadar dengan alasan tertulis.

**Type consistency:** `TransactionRepository.fulfill()` (Task 2) dipanggil persis dengan named params yang sama (`deliveredQuantity`, `actualDeliveryDate`) di `_confirmFulfill()` (Task 3). `sendPush({deviceToken, title, body, deepLink})` (Task 4 & 5) konsisten dengan signature `_shared/fcm.ts` yang sudah ada.

**Dependency antar-task:** Task 1 (recurring-orders) dan Task 4 (FCM negosiasi) independen satu sama lain — bisa dikerjakan/dites dalam urutan apapun. Task 2 harus sebelum Task 3 (Task 3 memanggil method dari Task 2). Task 5 butuh tabel `recurring_orders` (sudah ada sejak awal, bukan dari Task 1) tapi tematis lebih masuk akal dikerjakan setelah Task 1 supaya ada data test untuk Step 4.
