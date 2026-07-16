# Project Plan: FG-25 + FG-26 — Sprint 6

> Dibuat 17 Juli 2026 · Fachri · Sprint 6 Chat & Negotiation UI

---

## Ringkasan

| | |
|---|---|
| **Ticket** | FG-25 (Chat screen) + FG-26 (Chat inbox) |
| **PIC** | Fachri |
| **Sprint** | 6 — Profile UI, Chat & Buy Now |
| **Dependency** | FG-22 (Nevan S5), FG-58 (Nevan S5), FG-4 Realtime (S2), FG-10 desain (Alexander S1) |
| **Branch** | `fachri_dev` |
| **Estimasi** | 90-120 menit |

---

## Status Prasyarat

| Prasyarat | Sprint | Status | Catatan |
|---|---|---|---|
| FG-10 desain Chat inbox | S1 | ✅ Final | Alexander confirmed |
| FG-4 Realtime channel | S2 | ✅ | `negotiations` + `negotiation_messages` |
| RLS negotiations | S2 | ✅ | Participant-only (SELECT, INSERT, UPDATE) |
| Auth + role picker | S3 | ✅ | `auth.uid()` tersedia |
| FG-22 state machine | S5 | ✅ Live | Nevan confirmed |
| FG-58 GET /negotiations | S5 | ✅ Live | Nevan confirmed |

---

## Task Breakdown

```
FG-25 (duluan, ~60 mnt) ──► FG-26 (~30 mnt)

├── FG-25: NegotiationChatScreen
│   ├── T1: Buat negotiation_repository.dart
│   ├── T2: Buat ChatBubble widget
│   ├── T3: Buat NegotiationActions (Accept/Counter/Decline)
│   ├── T4: Buat NegotiationChatScreen (realtime + UI)
│   └── T5: Wire route /negotiations/:id
│
├── FG-26: ChatInboxScreen
│   ├── T6: Buat ChatInboxScreen (list + empty state)
│   └── T7: Wire route /chat-inbox + entry point dari feed
│
└── T8: Verifikasi (flutter analyze + test)
```

---

## Checklist FG-25 + FG-26 (dari `sprint6_fachri_dev.md`)

- [ ] UI chat: bubble pesan, offer_price, recommended_price di thread
- [ ] Accept/Counter/Decline — hanya aktif untuk pihak penerima
- [ ] Subscribe Realtime channel untuk update live < 2 detik
- [ ] Status negotiation tampil jelas di header
- [ ] Warning stok berubah saat quantity_available listing berubah
- [ ] Area nama counterpart di header (tap → FG-27 Sprint 7)
- [ ] Chat inbox: daftar negotiation aktif milik user (RLS)
- [ ] Tap item inbox → buka NegotiationChatScreen
- [ ] Terurut updated_at desc
- [ ] State kosong chat inbox (belum ada negotiation)
- [ ] Ikuti desain FG-10 (Chat inbox)

---

## Deliverables

| File | Aksi | Output |
|---|---|---|
| `lib/features/negotiation/data/negotiation_repository.dart` | BARU | GET /negotiations, POST messages, subscribe realtime |
| `lib/features/negotiation/screens/negotiation_chat_screen.dart` | BARU | Chat UI + realtime + actions |
| `lib/features/negotiation/screens/chat_inbox_screen.dart` | BARU | List + empty state |
| `lib/features/negotiation/widgets/chat_bubble.dart` | BARU | Message bubble |
| `lib/features/negotiation/widgets/negotiation_actions.dart` | BARU | Accept/Counter/Decline |
| `lib/core/router/app_router.dart` | EDIT | +/negotiations/:id + /chat-inbox |
| `test/widget_test.dart` | EDIT | Update test |

---

## Spesifikasi Teknis

### T1 — NegotiationRepository

```dart
class NegotiationRepository {
  final _client = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> getMyNegotiations({String? status}) {
    var query = _client
        .from('negotiations')
        .select('*, listings(title, foto_url, harga_per_unit, unit), farmer_profiles(nama), buyer_profiles(nama_institusi)')
        .order('updated_at', ascending: false);
    if (status != null) query = query.eq('status', status);
    return query;
  }

  Future<Map<String, dynamic>> getNegotiation(String id) {
    return _client.from('negotiations')
        .select('*, listings(*, farmer_profiles(nama, lokasi))')
        .eq('id', id).single();
  }

  Future<List<Map<String, dynamic>>> getMessages(String negotiationId) {
    return _client.from('negotiation_messages')
        .select('*').eq('negotiation_id', negotiationId)
        .order('created_at', ascending: true);
  }

  RealtimeChannel subscribeMessages(
    String negotiationId, Function(Map<String, dynamic>) onInsert,
  ) {
    return _client
        .channel('messages-$negotiationId')
        .onPostgresChange(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'negotiation_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'negotiation_id',
            value: negotiationId,
          ),
          callback: (payload) => onInsert(payload.newRecord),
        )
        .subscribe();
  }

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

### T2 — ChatBubble Widget

```dart
// Layout:
// ┌─────────────────────────────────────────┐
// │ Counter Offer: Rp 50.000/kg  (oranye)   │  ← kalau offer_price != null
// │ "Harga bisa dinego lagi?"               │  ← message_text
// │                             10:30 AM    │  ← timestamp
// └─────────────────────────────────────────┘
//
// Warna: isMine ? green.shade100 : grey.shade100
// Posisi: isMine ? align right : align left
// action_type 'counter' → label "Counter Offer"
// action_type 'accept'  → label "Diterima" (centered, green text)
// action_type 'decline' → label "Ditolak" (centered, red text)
// action_type 'message' → text only bubble
```

### T3 — NegotiationActions

```dart
// [Accept] [Counter] [Decline]
//
// Visible jika:
//   - status == 'OPEN' || status == 'COUNTERED'
//   - currentUserId != lastMessageSenderId (pihak penerima)
//
// Accept → insert message { action_type: 'accept' }
// Counter → dialog: offer_price + message_text
// Decline → insert message { action_type: 'decline' }
//
// Tombol warna:
//   Accept  → green
//   Counter → blue/outlined
//   Decline → red/outlined
```

### T4 — NegotiationChatScreen

```
Scaffold
└── AppBar
│   ├── Text(nama counterpart)     ← area tap (FG-27 stub)
│   ├── Text(status, style: caption)
│   └── Text(listingTitle, style: caption)
└── body: Column
│   ├── if (stockChanged)
│   │   Banner oranye: "Stok berubah: X → Y unit"
│   ├── Expanded
│   │   └── ListView.builder(reverse: true)
│   │       ├── ChatBubble per message
│   │       └── if (status == 'EXPIRED')
│   │           Banner "Negosiasi sudah berakhir"
│   └── if (canAct && !isExpired)
│       └── NegotiationActions(accept, counter, decline)
│   └── Divider
│   └── SafeArea
│       └── Row
│           ├── Expanded(TextField("Ketik pesan..."))
│           └── IconButton(send)
```

**Realtime init:**
```dart
@override
void initState() {
  super.initState();
  _loadMessages();
  _channel = _repo.subscribeMessages(widget.negotiationId, (newMsg) {
    if (mounted) setState(() => _messages.add(newMsg));
  });
}

@override
void dispose() {
  _channel.unsubscribe();
  super.dispose();
}
```

**Stock warning logic:**
```dart
// Simpan quantity_available saat pertama load
final _initialStock = negotiation['listings']['quantity_available'];

// Di build method:
final currentStock = _negotiation['listings']['quantity_available'];
final stockChanged = _initialStock != currentStock;

if (stockChanged) {
  // Tampilkan banner: "Stok berubah dari $_initialStock menjadi $currentStock"
}
```

### T5 — Route `/negotiations/:id`

```dart
// Di routes: (luar ShellRoute — kedua role bisa akses)
GoRoute(
  path: '/negotiations/:id',
  builder: (context, state) {
    final id = state.pathParameters['id']!;
    return NegotiationChatScreen(negotiationId: id);
  },
),
```

### T6 — ChatInboxScreen

```
Scaffold
└── AppBar("Percakapan")
└── body: FutureBuilder<List<Map>>
    ├── loading: CircularProgressIndicator
    ├── error: Center("Gagal memuat")
    ├── empty: Center
    │   ├── Icon(Icons.chat_bubble_outline, size: 64, grey)
    │   ├── SizedBox(16)
    │   └── Text("Belum ada percakapan")
    └── list: ListView.builder
        └── Card
            └── ListTile
                ├── leading: CircleAvatar(foto_url || nama[0])
                ├── title: nama counterpart (bold)
                ├── subtitle: listing title
                ├── trailing: Column
                │   ├── Text("Rp ${harga}", bold green)
                │   └── Text(timeAgo, grey)
                ├── Chip(status) — warna sesuai status
                └── onTap → /negotiations/:id
```

**Status colors:**
```dart
Color _chipColor(String status) => switch (status) {
  'open'      => Colors.green.shade100,
  'countered' => Colors.orange.shade100,
  'accepted'  => Colors.blue.shade100,
  'declined'  => Colors.red.shade100,
  'expired'   => Colors.grey.shade200,
  _           => Colors.grey.shade100,
};
```

### T7 — Route `/chat-inbox` + Entry Point

```dart
// Di routes:
GoRoute(
  path: '/chat-inbox',
  builder: (_, __) => const ChatInboxScreen(),
),

// Entry point dari AppBar:
// BuyerHomeFeedScreen AppBar → tambah IconButton(chat) → /chat-inbox
// Farmer PlaceholderScreen → nanti diganti Dashboard asli
```

### T8 — Verifikasi

| Step | Aksi | Yang dicek |
|---|---|---|
| 1 | `flutter analyze` | 0 issues |
| 2 | `flutter test` | PASS |
| 3 | Buat 2 akun (farmer + buyer) | Via role picker |
| 4 | Farmer create listing | Via FG-14 |
| 5 | Buyer start negotiation | Via curl/Postman ke endpoint Nevan, atau dummy SQL |
| 6 | Chat screen tampil | Bubble + status |
| 7 | Realtime test | Kirim dari device B → muncul di device A |
| 8 | Accept/Counter buttons | Hanya aktif untuk receiver |
| 9 | Chat inbox | List muncul, tap → chat |

---

## Acceptance Criteria

```
[ ] Pesan baru muncul < 2 detik tanpa refresh manual
[ ] Pihak pengirim counter tidak punya Accept/Decline aktif
[ ] Warning stok muncul saat quantity_available berubah
[ ] Chat inbox hanya menampilkan negotiation milik user (RLS)
[ ] State kosong chat inbox tampil jelas
[ ] Tap item inbox → buka chat screen yang sama
[ ] flutter analyze 0 issues
[ ] flutter test PASS
[ ] Commit ke fachri_dev
```

---

## Risiko & Mitigasi

| Risiko | Prob. | Dampak | Mitigasi |
|---|---|---|---|
| FG-22 + FG-58 Nevan belum selesai | Sedang | Tidak bisa wiring data asli | Tanya Nevan dulu; kalau belum selesai, pakai mock data via SQL Editor untuk UI |
| FG-10 desain belum final | Rendah | Inbox tidak ikuti desain | Konfirmasi Alexander; kalau belum, pakai layout minimal |
| Realtime delay > 2 detik | Rendah | Tidak penuhi NFR §12 | Cek channel subscribe; pastikan REPLICA IDENTITY FULL sudah ada |
| Negotiation table kosong | Tinggi | Tidak ada data test | Buat dummy via SQL Editor atau curl ke endpoint Nevan |
| FK join error (seperti FG-15) | Rendah | Query inbox gagal | Semua FK `negotiations` → `listings`/`users` sudah ada dari Sprint 1 |
| RLS block query | Rendah | Data tidak muncul | RLS sudah participant-only — pastikan `auth.uid()` valid saat query |

---

## Catatan

- **Pelajaran Sprint 3:** test E2E antar 2 akun, jangan cuma `flutter analyze`
- **Pelajaran Sprint 2:** kalau ada data dummy lewat SQL, catat di dokumentasi
- Chat screen dipakai BOTH buyer (dari listing start chat) dan farmer (dari inbox reply)
- Counterparty tap area (FG-27, Hafizh, Sprint 7) — siapkan `GestureDetector` kosong
- Tidak ada filter/search di inbox (tidak diminta PRD)

---

## Referensi

- `docs/Sprint 6/sprint6_fachri_dev.md`
- `docs/Sprint 2/sprint2_hasil_akhir.md` (Realtime + RLS)
- `docs/Sprint 1/sprint0_alexander_design.md` (FG-10 desain)
- `docs/Sprint 3/sprint3_hasil_akhir.md` (pelajaran integrasi)
