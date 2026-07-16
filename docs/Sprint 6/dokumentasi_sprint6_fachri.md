# Sprint 6 — Dokumentasi Fachri (FG-25 + FG-26)

**Tanggal:** 17 Juli 2026  
**Status:** ✅ Selesai  
**Branch:** `fachri_dev`

---

## Ringkasan

FG-25 (Negotiation/Chat screen UI) + FG-26 (Chat inbox UI). Chat screen dengan realtime update via Supabase Stream, bubble pesan, Accept/Counter/Decline actions, dan status negotiation. Chat inbox menampilkan daftar semua negotiation milik user (RLS) dengan status chip dan navigasi ke chat screen.

---

## Deliverables

| File | Aksi | Detail |
|---|---|---|
| `lib/features/negotiation/data/negotiation_repository.dart` | File baru | GET /negotiations, messages, stream realtime, send message |
| `lib/features/negotiation/screens/negotiation_chat_screen.dart` | File baru | Chat UI + realtime stream + actions + stock warning |
| `lib/features/negotiation/screens/chat_inbox_screen.dart` | File baru | List negotiation + empty state + status chip |
| `lib/features/negotiation/widgets/chat_bubble.dart` | File baru | Message bubble (text, offer, counter, accept/decline system) |
| `lib/features/negotiation/widgets/negotiation_actions.dart` | File baru | Accept/Counter/Decline buttons (receiver-only) |
| `lib/core/router/app_router.dart` | Edit | `/negosiasi/:id` + `/percakapan` routes |
| `lib/features/listing/screens/buyer_home_feed_screen.dart` | Edit | IconButton chat entry point |

---

## Checklist FG-25 + FG-26

- [x] UI chat: bubble pesan, offer_price, recommended_price di thread
- [x] Accept/Counter/Decline — hanya aktif untuk pihak penerima
- [x] Subscribe realtime untuk update live (via `.stream()` Supabase)
- [x] Status negotiation tampil jelas di header chat
- [x] Warning stok berubah saat quantity_available listing berubah
- [x] Area nama counterpart di header (tap → FG-27 Sprint 7 stub)
- [x] Chat inbox: daftar negotiation aktif milik user (RLS)
- [x] Tap item inbox → buka NegotiationChatScreen
- [x] Terurut updated_at desc
- [x] State kosong chat inbox (belum ada negotiation)
- [x] Ikuti desain FG-10 (Chat inbox)

---

## Verifikasi

| Item | Hasil |
|---|---|
| `flutter analyze` | No issues found |
| `flutter test` | All tests passed |

---

## Flow Chat

```
Buyer di feed → tap listing → start negotiation (via curl/Postman ke FG-22)
                                         │
Farmer di chat inbox ─────────────────────│
       │                                   │
       └── tap item → /negosiasi/:id       │
              │                            │
              ├── chat screen tampil       │
              ├── realtime: message muncul │
              ├── Accept/Counter/Decline   │
              └── stok warning jika berubah│
```

## Route Map

```
/negosiasi/:id       → NegotiationChatScreen (kedua role)
/percakapan          → ChatInboxScreen (kedua role)
  entry point: IconButton(chat) di BuyerHomeFeedScreen AppBar
```

---

## Catatan Teknis

- **Realtime:** Menggunakan `.stream()` dari Supabase Client (bukan `RealtimeChannel` raw). Stream-based API lebih stabil di supabase_flutter 2.16 dan otomatis handle reconnect.
- **"Pihak penerima" logic:** `isReceiver` dihitung dari `lastMessage.sender_id != currentUserId`. Pihak yang baru kirim counter/offer tidak bisa Accept tawarannya sendiri.
- **Counter dialog:** `AlertDialog` dengan input harga + pesan opsional.
- **Status chip di inbox:** Warna berbeda per status (hijau=OPEN, oranye=COUNTERED, biru=ACCEPTED, merah=DECLINED, abu=EXPIRED).
- **Stock warning:** Bandingkan `_initialQuantity` waktu load vs `quantity_available` current. Tampil banner oranye jika berbeda.
- **FK joins:** `negotiations` join ke `listings` + `farmer_profiles` + `buyer_profiles` — semua FK sudah ada dari Sprint 1.

---

## Dependency

| Prasyarat | Sprint | Status |
|---|---|---|
| FG-10 desain Chat inbox (Alexander) | S1 | ✅ |
| FG-4 Realtime channel | S2 | ✅ |
| RLS negotiations | S2 | ✅ |
| Auth + role picker | S3 | ✅ |
| FG-22 state machine (Nevan) | S5 | ✅ |
| FG-58 GET /negotiations (Nevan) | S5 | ✅ |

---

## Referensi

- `docs/Sprint 6/sprint6_fachri_dev.md`
- `docs/Sprint 6/projek_plan_fachri_sprint6.md`
- `docs/Sprint 2/sprint2_hasil_akhir.md` (Realtime + RLS)
- `docs/Sprint 1/sprint0_alexander_design.md` (FG-10 desain)
