# Fix Negotiation Accept Flow (Dead-End Chat & Missing Transaction) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Setelah buyer menekan "Terima" di layar negosiasi, transaksi sungguhan harus dibuat di backend (via Edge Function, bukan cuma insert mentah) dan buyer diarahkan ke Transaction Detail — bukan berhenti di layar chat kosong.

**Architecture:** `NegotiationRepository.sendMessage()` saat ini insert langsung ke tabel `negotiation_messages`, sehingga men-skip seluruh logic di Edge Function `negotiations/:id/messages` (validasi "hanya penerima yang boleh aksi", guard status sudah selesai, dan yang paling penting: `lockInventoryOnAcceptWithQuantity` yang benar-benar membuat baris `transactions`). Status "Diterima" yang tampil di UI sekarang murni tebakan client dari jenis pesan terakhir (lihat `_subscribeRealtime()`), bukan dari kolom `negotiations.status` yang sungguhan berubah. Fix-nya: route `sendMessage()` lewat `_client.functions.invoke('negotiations/:id/messages', ...)` — pola yang sama persis dengan `BuyNowRepository.buyNow()` yang sudah ada — lalu pakai `transaction_id` dari response untuk push ke `/transaksi/:id`.

**Tech Stack:** Flutter (Riverpod, GoRouter), Supabase Edge Functions (Deno) — tidak ada dependency baru, mengikuti pola `functions.invoke` yang sudah dipakai `BuyNowRepository`.

## Global Constraints

- Semua copy/error message tetap Bahasa Indonesia, konsisten dengan seluruh codebase.
- Tidak ada test-double/mocking infra untuk Supabase di repo ini (`test/` hanya berisi widget/router test) — jangan bangun infra baru untuk ini, verifikasi lewat manual QA di device seperti pola sprint report yang sudah ada di `docs/Sprint 7/`.
- Root cause fix di satu tempat (`NegotiationRepository.sendMessage`) — semua 4 caller (`_sendMessage`, `_onAccept`, `_onDecline`, `_onCounter`) otomatis ikut benar, jangan tambal di masing-masing caller.

## Di luar scope (dicatat, bukan dikerjakan)

- **3 negosiasi "Diterima" duplikat** untuk listing "Cabai Merah Keriting" yang ditemukan saat visual testing: berdasarkan pengecekan kode, **tidak ada satupun jalur di app yang membuat row `negotiations` baru** (tidak ada tombol "mulai nego" di UI, tidak ada pemanggilan `POST /negotiations` dari Flutter). Baris-baris itu hampir pasti data seed/manual-test dari sprint backend sebelumnya (dicatat di `sprint7_README.md`: "Nevan: FG-32 — bisa test pakai transaction dari negosiasi manual"), bukan bug kode. Rekomendasi: hapus manual lewat Supabase dashboard, bukan bagian dari plan ini.
- Membuat UI "mulai negosiasi baru" — fitur ini belum ada sama sekali di app manapun; di luar scope perbaikan dead-end yang diminta.

---

### Task 1: `NegotiationRepository.sendMessage()` panggil Edge Function, bukan insert langsung

**Files:**
- Modify: `lib/features/negotiation/data/negotiation_repository.dart:98-112`

**Interfaces:**
- Produces: `Future<Map<String, dynamic>> sendMessage({required String negotiationId, required String senderId, required String actionType, String? messageText, double? offerPrice})` — return sekarang berisi body response Edge Function: `{message_id, negotiation_status, transaction_id}` (dipakai Task 2).

- [ ] **Step 1: Ganti implementasi `sendMessage`**

Ganti method `sendMessage` (baris 98-112) di `lib/features/negotiation/data/negotiation_repository.dart` dari:

```dart
  Future<void> sendMessage({
    required String negotiationId,
    required String senderId,
    required String actionType,
    String? messageText,
    double? offerPrice,
  }) {
    return _client.from('negotiation_messages').insert({
      'negotiation_id': negotiationId,
      'sender_id': senderId,
      'action_type': actionType,
      'message_text': messageText,
      'offer_price': offerPrice,
    });
  }
}
```

menjadi:

```dart
  Future<Map<String, dynamic>> sendMessage({
    required String negotiationId,
    required String senderId,
    required String actionType,
    String? messageText,
    double? offerPrice,
  }) async {
    try {
      final res = await _client.functions.invoke(
        'negotiations/$negotiationId/messages',
        method: HttpMethod.post,
        body: {
          'sender_id': senderId,
          'action_type': actionType,
          if (messageText != null) 'message_text': messageText,
          if (offerPrice != null) 'offer_price': offerPrice,
        },
      );
      return res.data as Map<String, dynamic>;
    } on FunctionException catch (e) {
      final details = e.details;
      final message = (details is Map && details['error'] != null)
          ? details['error'].toString()
          : 'Gagal mengirim (${e.status})';
      throw Exception(message);
    }
  }
}
```

Ini pola yang sama persis dengan `BuyNowRepository.buyNow()` di `lib/features/listing/data/buy_now_repository.dart:9-29` — tidak ada import baru yang dibutuhkan (`HttpMethod` dan `FunctionException` sudah dari `package:supabase_flutter/supabase_flutter.dart` yang sudah di-import di baris 1 file ini).

- [ ] **Step 2: Verifikasi tidak ada caller yang rusak**

Run:
```bash
grep -n "sendMessage(" lib/features/negotiation/screens/negotiation_chat_screen.dart
```
Expected: 4 pemanggilan (`_sendMessage`, `_onAccept`, `_onDecline`, `_onCounter`), semuanya memakai `await _repo.sendMessage(...)` tanpa menyimpan return value ke variable bertipe `void` — aman berubah dari `Future<void>` ke `Future<Map<String, dynamic>>` karena tidak ada yang assign ke tipe spesifik.

- [ ] **Step 3: `flutter analyze`**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 4: Commit**

```bash
git add lib/features/negotiation/data/negotiation_repository.dart
git commit -m "fix: sendMessage lewat Edge Function negotiations, bukan insert langsung"
```

---

### Task 2: `_onAccept()` kirim `offer_price` & navigate ke Transaction Detail

**Files:**
- Modify: `lib/features/negotiation/screens/negotiation_chat_screen.dart:135-151`

**Interfaces:**
- Consumes: `NegotiationRepository.sendMessage(...)` dari Task 1 — return `Map<String, dynamic>` dengan key `transaction_id` (String?, null kalau bukan action `accept`).

**Konteks penting:** Edge Function `handleMessages` di `supabase/functions/negotiations/index.ts:64` menolak `action_type: accept` tanpa `offer_price` (`"offer_price wajib untuk counter/accept"`). `_onAccept()` saat ini TIDAK mengirim `offerPrice` sama sekali — ini pernah lolos diam-diam karena `sendMessage` lama insert langsung tanpa validasi apapun. Setelah Task 1, ini akan mulai gagal dengan error 400 kalau tidak diperbaiki di task ini.

- [ ] **Step 1: Ganti `_onAccept()`**

Ganti (baris 135-151):

```dart
  Future<void> _onAccept() async {
    final userId = ref.read(authProvider).userId;
    if (userId == null) return;
    try {
      await _repo.sendMessage(
        negotiationId: widget.negotiationId,
        senderId: userId,
        actionType: 'accept',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal: $e')),
        );
      }
    }
  }
```

menjadi:

```dart
  Future<void> _onAccept() async {
    final userId = ref.read(authProvider).userId;
    if (userId == null) return;
    final offerPrice =
        (_negotiation?['current_offer_price'] as num?)?.toDouble();
    try {
      final result = await _repo.sendMessage(
        negotiationId: widget.negotiationId,
        senderId: userId,
        actionType: 'accept',
        offerPrice: offerPrice,
      );
      final transactionId = result['transaction_id']?.toString();
      if (transactionId != null && mounted) {
        // push, bukan go — sama seperti alur Buy Now (lihat
        // listing_detail_screen.dart), biar back button jalan normal.
        context.push('/transaksi/$transactionId');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal: $e')),
        );
      }
    }
  }
```

- [ ] **Step 2: `flutter analyze`**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/features/negotiation/screens/negotiation_chat_screen.dart
git commit -m "fix: accept negosiasi kirim offer_price & navigate ke transaction detail"
```

---

### Task 3: Empty-state di message list (cegah layar blank total)

**Files:**
- Modify: `lib/features/negotiation/screens/negotiation_chat_screen.dart:296-317`

Ini jaring pengaman terpisah dari Task 1-2: kalau status negosiasi sudah final (`declined`/`expired`/`accepted`) DAN `_messages` kosong (mis. data lama/edge case), input box dan `NegotiationActions` sama-sama disembunyikan (lihat kondisi di baris 325 dan `negotiation_actions.dart:20`) — tanpa ini area tengah cuma `Container` kosong.

**Interfaces:**
- Consumes: `_messages` (state field, sudah ada).

- [ ] **Step 1: Tambah kondisi kosong**

Ganti (baris 296-317):

```dart
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              reverse: true,
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[_messages.length - 1 - index];
                final actionType = msg['action_type']?.toString() ?? 'message';
                final msgSenderId = msg['sender_id']?.toString();

                return ChatBubble(
                  isMine: msgSenderId == currentUserId,
                  text: msg['message_text']?.toString(),
                  offerPrice: (msg['offer_price'] as num?)?.toDouble(),
                  recommendedPrice: (negotiation['recommended_price'] as num?)?.toDouble(),
                  actionType: actionType,
                  createdAt: DateTime.parse(msg['created_at'].toString()),
                );
              },
            ),
          ),
```

menjadi:

```dart
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Text(
                      'Belum ada pesan',
                      style: TextStyle(color: Colors.grey.shade500),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    reverse: true,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[_messages.length - 1 - index];
                      final actionType =
                          msg['action_type']?.toString() ?? 'message';
                      final msgSenderId = msg['sender_id']?.toString();

                      return ChatBubble(
                        isMine: msgSenderId == currentUserId,
                        text: msg['message_text']?.toString(),
                        offerPrice: (msg['offer_price'] as num?)?.toDouble(),
                        recommendedPrice:
                            (negotiation['recommended_price'] as num?)
                                ?.toDouble(),
                        actionType: actionType,
                        createdAt:
                            DateTime.parse(msg['created_at'].toString()),
                      );
                    },
                  ),
          ),
```

- [ ] **Step 2: `flutter analyze`**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/features/negotiation/screens/negotiation_chat_screen.dart
git commit -m "fix: tampilkan empty-state di chat negosiasi alih-alih layar blank"
```

---

### Task 4: Regression check + manual QA di device

**Files:** tidak ada file baru — verifikasi menyeluruh sebelum dianggap selesai.

- [ ] **Step 1: Full test suite**

Run: `flutter test`
Expected: semua test pass (26/26 sebelum perubahan — jumlah sama, tidak ada yang gagal, karena tidak ada test yang menyentuh `NegotiationRepository`/`NegotiationChatScreen`).

- [ ] **Step 2: `flutter analyze` final**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 3: Manual QA di device Android (tidak bisa diotomasi — butuh Edge Function live + data Supabase asli)**

Karena `_onAccept()` sekarang membuat baris nyata di tabel `transactions` dan mengurangi `listings.quantity_available`, verifikasi ini WAJIB dilakukan di device dengan sadar bahwa ini mutasi data sungguhan (pakai listing/negosiasi test, bukan data demo yang dipakai user lain):

1. Buka `flutter run -d <device_id>`, login sebagai buyer yang punya negosiasi berstatus `open`/`countered` (bukan salah satu dari 3 duplikat "Diterima" yang sudah final).
2. Dari Chat Inbox (`/percakapan`), buka negosiasi tsb.
3. Tekan "Terima". Expected:
   - Tidak ada error snackbar "offer_price wajib..." (ini yang akan muncul kalau Task 2 lupa dikerjakan).
   - App otomatis push ke `/transaksi/:id` menampilkan judul listing, status `pending`, harga, dan tombol "Tolak Transaksi" (karena role buyer + status pending, lihat `transaction_detail_screen.dart:125-136`).
4. Cek di Supabase dashboard (table `transactions`): ada row baru dengan `negotiation_id` yang sesuai, `status = 'pending'`.
5. Cek `listings.quantity_available` untuk listing tsb berkurang sesuai `quantity` negosiasi.
6. Buka lagi negosiasi yang sama dari Chat Inbox → harusnya sekarang menampilkan status "Diterima" DAN tidak lagi blank (minimal ada 1 pesan action_type `accept` di list, karena kali ini benar-benar tersimpan lewat Edge Function).

- [ ] **Step 4: Update dokumentasi sprint (opsional tapi konsisten dengan pola repo)**

Kalau QA di atas semua pass, tambahkan catatan singkat di `docs/Sprint 7/sprint7_hafizh_dev_report.md` atau file report Sprint 8 yang relevan (sesuai konvensi existing) bahwa accept-negotiation → transaction flow sudah diperbaiki, supaya Sprint 8 (FG-34 Fulfillment Form) tidak dibangun di atas asumsi transaksi tidak pernah tercipta dari jalur ini.

---

### Task 5: Fix routing `POST /negotiations` (create) selalu 405 — ditemukan saat QA Task 4

**Konteks:** Saat menyiapkan data test untuk QA Task 4 (butuh 1 negosiasi berstatus `open`), `POST /negotiations` lewat curl langsung mengembalikan `Method not allowed`. Root cause: `parsePath("/negotiations")` di `supabase/functions/negotiations/index.ts:1-11` selalu menghasilkan `{action: "list"}` untuk path tanpa ID, terlepas dari HTTP method. Router mengecek `action === "list"` (baris 135, wajib GET) SEBELUM mengecek `pathname === "/negotiations"` (baris 156, wajib POST) — jadi setiap `POST /negotiations` kena 405 di baris 136 sebelum pernah sampai ke `handleCreate`. Ini bug lama, terpisah dari Task 1-4, ditemukan tidak sengaja karena tidak ada satupun negosiasi yang berhasil dibuat sejak fitur ini ada (konsisten dengan temuan awal: tidak ada UI "mulai nego" di app manapun).

**Files:**
- Modify: `supabase/functions/negotiations/index.ts:134-160`

- [ ] **Step 1: Pindahkan pengecekan create ke atas, sebelum `action === "list"`**

Ganti (baris 134-160):

```ts
  try {
    if (action === "list") {
      if (req.method !== "GET") return new Response("Method not allowed", { status: 405 });
      const userId = await getUserId(req, supabase);
      if (typeof userId !== "string") return userId;
      return await handleList(supabase, userId, url);
    }

    if (action === "detail") {
      if (req.method !== "GET") return new Response("Method not allowed", { status: 405 });
      const userId = await getUserId(req, supabase);
      if (typeof userId !== "string") return userId;
      return await handleDetail(supabase, negotiationId!, userId);
    }

    if (action === "messages") {
      if (req.method !== "POST") return new Response("Method not allowed", { status: 405 });
      const body = await req.json();
      return await handleMessages(supabase, negotiationId!, body);
    }

    // No negotiation ID → create
    if (pathname === "/negotiations" || pathname === "/negotiations/") {
      if (req.method !== "POST") return new Response("Method not allowed", { status: 405 });
      const body = await req.json();
      return await handleCreate(supabase, body);
    }

    return new Response(JSON.stringify({ error: "Route not found" }), { status: 404, headers: { "Content-Type": "application/json" } });
```

menjadi:

```ts
  try {
    // Path tanpa ID + POST → create. Dicek sebelum `action === "list"`
    // karena parsePath() memberi action yang sama ("list") untuk path ini
    // terlepas dari method — kalau dicek belakangan, POST /negotiations
    // selalu 405 duluan di blok "list" dan handleCreate jadi tidak
    // pernah tercapai.
    if ((pathname === "/negotiations" || pathname === "/negotiations/") && req.method === "POST") {
      const body = await req.json();
      return await handleCreate(supabase, body);
    }

    if (action === "list") {
      if (req.method !== "GET") return new Response("Method not allowed", { status: 405 });
      const userId = await getUserId(req, supabase);
      if (typeof userId !== "string") return userId;
      return await handleList(supabase, userId, url);
    }

    if (action === "detail") {
      if (req.method !== "GET") return new Response("Method not allowed", { status: 405 });
      const userId = await getUserId(req, supabase);
      if (typeof userId !== "string") return userId;
      return await handleDetail(supabase, negotiationId!, userId);
    }

    if (action === "messages") {
      if (req.method !== "POST") return new Response("Method not allowed", { status: 405 });
      const body = await req.json();
      return await handleMessages(supabase, negotiationId!, body);
    }

    return new Response(JSON.stringify({ error: "Route not found" }), { status: 404, headers: { "Content-Type": "application/json" } });
```

- [ ] **Step 2: Deploy Edge Function ke Supabase**

Run: `supabase functions deploy negotiations`
Expected: deploy sukses (edge function ini jalan di Supabase, bukan di device — perubahan tidak berefek sampai di-deploy).

- [ ] **Step 3: Verifikasi lewat curl**

```bash
curl -s -X POST "https://rwxnjxmzkcfoddnzjosi.supabase.co/functions/v1/negotiations" \
  -H "apikey: sb_publishable_-tmXQTkiRSNHtvjBVILpvA_oGVnliRX" \
  -H "Authorization: Bearer sb_publishable_-tmXQTkiRSNHtvjBVILpvA_oGVnliRX" \
  -H "Content-Type: application/json" \
  -d '{"listing_id":"255b9d9a-a093-45a8-8599-da5f0f7d63d9","buyer_id":"ed23f6a6-21cb-4576-89ac-d8bfdae08a78","initial_price":32000,"quantity":2}'
```
Expected: JSON berisi `negotiation_id`, bukan lagi `Method not allowed`.

- [ ] **Step 4: (Tidak commit — sesuai instruksi user)**

Biarkan perubahan `supabase/functions/negotiations/index.ts` sebagai working-tree change, jangan `git commit`/`git push`.

---

### Task 6: Fix `promised_delivery_date` selalu NULL di accept-flow — ditemukan saat QA end-to-end Task 4

**Konteks:** Setelah Task 1, 2, 5 terverifikasi jalan (tombol Terima di app memanggil Edge Function dengan benar, validasi recipient-only benar), langkah accept yang sebenarnya tetap gagal dengan error dari server: `Gagal membuat transaksi: null value in column "promised_delivery_date" of relation "transactions" violates not-null constraint`. Kolom ini `date NOT NULL` tanpa default (`supabase/migrations/20260716083135_initial_schema.sql:109`). Root cause: `lockInventoryOnAcceptWithQuantity` di `supabase/functions/_shared/inventory-locking.ts:81` hardcode `promised_delivery_date: null`. Ini bug lama, terpisah dari Task 1-5, ada sejak `_shared/inventory-locking.ts` ditulis — konsisten dengan kenapa tidak pernah ada transaksi sukses tercipta dari flow negosiasi.

Konvensi yang benar sudah ada di file lain: `supabase/functions/buy-now/index.ts:11,15` menghitung `promised_delivery_date` sebagai **7 hari dari tanggal transaksi dibuat** (`new Date(); promised.setDate(promised.getDate() + 7)`). Pakai konvensi yang sama di `_shared/inventory-locking.ts` supaya kedua jalur (Buy Now langsung & accept negosiasi) konsisten.

**Files:**
- Modify: `supabase/functions/_shared/inventory-locking.ts:70-84`

- [ ] **Step 1: Isi `promised_delivery_date` dengan H+7**

Ganti (baris 70-84):

```ts
  // 3. Buat transaction PENDING
  const totalAmount = quantity * Number(neg.current_offer_price);
  const { data: tx, error: txErr } = await supabase
    .from("transactions")
    .insert({
      negotiation_id: negotiationId,
      farmer_id: neg.farmer_id,
      buyer_id: neg.buyer_id,
      status: "pending",
      agreed_quantity: quantity,
      total_amount: totalAmount,
      promised_delivery_date: null,
    })
    .select("id")
    .single();
```

menjadi:

```ts
  // 3. Buat transaction PENDING
  const totalAmount = quantity * Number(neg.current_offer_price);
  // Konvensi sama dengan buy-now/index.ts:11 — H+7 dari tanggal accept.
  const promised = new Date();
  promised.setDate(promised.getDate() + 7);
  const { data: tx, error: txErr } = await supabase
    .from("transactions")
    .insert({
      negotiation_id: negotiationId,
      farmer_id: neg.farmer_id,
      buyer_id: neg.buyer_id,
      status: "pending",
      agreed_quantity: quantity,
      total_amount: totalAmount,
      promised_delivery_date: promised.toISOString().slice(0, 10),
    })
    .select("id")
    .single();
```

- [ ] **Step 2: Deploy Edge Function**

Run: `supabase functions deploy negotiations --project-ref rwxnjxmzkcfoddnzjosi`

(`_shared/inventory-locking.ts` di-bundle ke dalam function `negotiations` yang meng-importnya — tidak ada function terpisah bernama `_shared` untuk di-deploy.)

- [ ] **Step 3: Verifikasi lewat curl — accept negosiasi test yang sama**

```bash
curl -s -X POST "https://rwxnjxmzkcfoddnzjosi.supabase.co/functions/v1/negotiations/935dd66e-dc53-4429-9a1c-89c912b2e67c/messages" \
  -H "apikey: sb_publishable_-tmXQTkiRSNHtvjBVILpvA_oGVnliRX" \
  -H "Authorization: Bearer sb_publishable_-tmXQTkiRSNHtvjBVILpvA_oGVnliRX" \
  -H "Content-Type: application/json" \
  -d '{"sender_id":"ed23f6a6-21cb-4576-89ac-d8bfdae08a78","action_type":"accept","offer_price":33000}'
```
Expected: JSON berisi `transaction_id` (bukan lagi error), `negotiation_status: "accepted"`.

- [ ] **Step 4: Verifikasi transaksi & stok di database**

Lewat Supabase SQL (mis. `execute_sql` MCP tool atau dashboard):
```sql
select id, status, agreed_quantity, total_amount, promised_delivery_date
from transactions where negotiation_id = '935dd66e-dc53-4429-9a1c-89c912b2e67c';

select quantity_available from listings where id = '255b9d9a-a093-45a8-8599-da5f0f7d63d9';
```
Expected: 1 row transaksi dengan `status = 'pending'`, `promised_delivery_date` terisi tanggal (H+7); `quantity_available` berkurang 2 (dari nilai sebelumnya).

- [ ] **Step 5: Verifikasi di app (buyer) — Transaction Detail muncul**

Buka app sebagai buyer, buka negosiasi `935dd66e...` dari Chat Inbox (statusnya sekarang harus "Diterima"), atau langsung cek `Profil` → riwayat transaksi harus tidak lagi "Belum ada riwayat transaksi". Kalau masih di layar chat, cukup verifikasi lewat query SQL di atas — tidak wajib re-trigger accept dari UI lagi (negosiasi ini sudah accepted, tombol Terima sudah tidak akan muncul lagi).

- [ ] **Step 6: (Tidak commit — sesuai instruksi user)**

---

## Self-Review

**Spec coverage:**
- Dead-end blank chat setelah "Diterima" → Task 3 (empty-state) langsung menutup gejalanya, Task 1+2 menutup akar masalahnya (kenapa tidak ada transaksi untuk dituju).
- "Beli Sekarang" flow terpisah dari negosiasi (temuan sampingan) → sudah dikonfirmasi ini desain terpisah yang sah (dua jalur beli independen: Buy Now langsung vs negosiasi→accept), tidak diubah.
- 3 negosiasi duplikat "Diterima" → dicatat eksplisit sebagai data cleanup di luar scope, dengan bukti kode (grep) bahwa tidak ada jalur pembuatan negosiasi di client saat ini.

**Placeholder scan:** tidak ada TBD/TODO — semua step berisi kode lengkap siap tempel.

**Type consistency:** `sendMessage` return `Future<Map<String, dynamic>>` (Task 1) dipakai persis sebagai `result['transaction_id']` di Task 2 — konsisten dengan shape response Edge Function `{message_id, negotiation_status, transaction_id}` di `supabase/functions/negotiations/index.ts:103`.
