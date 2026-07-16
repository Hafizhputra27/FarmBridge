> Direvisi 2026-07-14 — sinkron ulang dengan label JIRA (skema granular 13-sprint), menggantikan versi kompresi 6-sprint sebelumnya.

# Sprint 5: Home Feed, Metrics Endpoints & Negotiation Core — Task Plan untuk Nevan

## Peran di sprint ini
**3 ticket: FG-22 (POST /negotiations + /messages + state machine), FG-58 (GET /negotiations — gap-fill, subtask FG-22), dan FG-35 (Inventory locking atomik, generalisasi dari FG-22).** Ini balik ke beban berat seperti Sprint 1-2 — state machine §5.1 adalah spesifikasi mengikat, kesalahan transisi di sini langsung menular ke `transaction` dan `trust_metrics` di sprint-sprint depan.

**Kenapa FG-58 ditambahkan ke ticket-mu**: ini gap yang sudah ketahuan sejak analisis awal PRD-vs-JIRA — tidak ada ticket khusus untuk endpoint list negotiation (dipakai Chat inbox, FG-26, Sprint 6). Scope asli FG-22 cuma `POST /negotiations`, `POST /negotiations/:id/messages`, `GET /negotiations/:id` (detail) — bukan versi list-nya. Sekarang sudah diformalkan jadi FG-58, subtask baru di bawah FG-22, paling efisien dikerjakan bareng karena sama-sama domain tabel `negotiations`.

## Sebelum mulai — koordinasi ringan (bukan lagi Hari-1)
FG-23 (Hafizh) sudah selesai penuh di Sprint 4 — kamu tinggal **import function `getRecommendedPrice()` yang sudah jadi**, bukan menyepakati signature Hari-1 seperti kalau keduanya berjalan di sprint yang sama. `POST /negotiations` kamu perlu mengembalikan `recommended_price` di response-nya (§9) dari function itu — cukup konfirmasi ke Hafizh kalau ternyata butuh penyesuaian signature.

## Urutan kerja yang disarankan
1. **FG-22 — state machine dulu**, import `getRecommendedPrice()` dari Hafizh begitu dibutuhkan
2. **FG-58 (GET /negotiations)** — kerjakan bareng FG-22 karena sama-sama di domain tabel `negotiations`, jangan dipisah jadi effort terpisah
3. **FG-35** — ekstrak & keraskan logic locking yang sudah kamu tulis inline di FG-22, expose jadi function reusable

## Task Checklist

### FG-22 — POST /negotiations + /messages + state machine
- [ ] `POST /negotiations`: `{ listing_id, buyer_id, initial_price, quantity }` → `{ negotiation_id, recommended_price, status:'open', expires_at }`; 400 jika `initial_price ≤ 0` atau `quantity > listings.quantity_available`
- [ ] `POST /negotiations/:id/messages`: `{ sender_id, message_text?, offer_price?, action_type }` → `{ message_id, negotiation_status }`; 409 jika negotiation sudah `accepted`/`declined`/`expired`
- [ ] `GET /negotiations/:id`: detail + `messages[]`; 403 jika requester bukan peserta
- [ ] Implementasi prinsip **"pihak penerima"** (§5.1): validasi di backend siapa yang boleh Accept/Decline/Counter berikutnya — bukan pengirim `initial_price`/`current_offer_price` terakhir. WAJIB divalidasi backend, bukan cuma disembunyikan di UI (Fachri tetap butuh guard sisi client di FG-25/FG-26, Sprint 6, tapi jangan andalkan itu sebagai satu-satunya proteksi)
- [ ] Inventory locking: `quantity_available` TIDAK berkurang saat `OPEN`/`COUNTERED`, baru berkurang atomik saat `ACCEPTED` (dalam transaksi DB yang sama), rollback kalau `REJECTED` — ini yang nanti digeneralisasi jadi FG-35

**Detail teknis — pola state transition**:
```
OPEN → ACCEPTED     : trigger transactions.PENDING + quantity_available berkurang atomik
OPEN → DECLINED      : permanen, tidak bisa dibuka ulang
OPEN → COUNTERED      : current_offer_price update, counter_count += 1
COUNTERED → (ACCEPTED / DECLINED / COUNTERED) : oleh pihak penerima counter tsb
OPEN/COUNTERED → EXPIRED : 6 jam tanpa respons (FG-24, Sprint 6)
```
Pengecualian: Buy Now (FG-29, Sprint 6) melompat langsung ke ACCEPTED tanpa OPEN — desain schema/function-mu jangan sampai mengasumsikan semua negotiation pasti mulai dari OPEN.

### FG-58 — GET /negotiations (gap-fill, subtask FG-22)
- [ ] Query param opsional `status` (mis. `open,countered,accepted`), kembalikan array negotiation milik requester (`buyer_id` atau `farmer_id` = `auth.uid()`), terurut `updated_at desc`
- [ ] RLS dari Sprint 2 (FG-3) otomatis memfilter kepemilikan — tidak perlu parameter `user_id` manual

### FG-35 — Inventory locking atomik (generalisasi)
- [ ] Ekstrak dari FG-22: `quantity_available` berkurang **hanya** saat negotiation `ACCEPTED` & `transactions.PENDING` terbentuk, dalam **satu transaksi database** (bukan 2 query terpisah)
- [ ] Function baru: rollback `quantity_available` kalau transaction kemudian `REJECTED`
- [ ] Pastikan validasi `quantity > listings.quantity_available` tetap bisa gagal untuk dua negosiasi/Buy Now paralel pada listing sama (first-accepted-wins, §11)
- [ ] Expose 2 function reusable: `lockInventoryOnAccept(negotiation_id)` dan `releaseInventoryOnReject(transaction_id)` — dipakai FG-29 (Buy Now, Sprint 6, kamu sendiri) dan FG-33 (Reject, Sprint 7 — beda 2 sprint, bukan lagi koordinasi Hari-1, tinggal expose function-nya dengan rapi)

**Test race condition** (paling kritis di ticket ini):
```
Given dua negotiation/Buy Now untuk listing & quantity sama dikirim nyaris bersamaan
When yang pertama di-accept
Then yang kedua gagal 409 (§11, first-accepted-wins)

Given transaction REJECTED
When rollback jalan
Then quantity_available listing kembali ke angka sebelum ACCEPTED
```

## File/folder yang kamu sentuh
```
supabase/functions/negotiations/**  (POST /negotiations, /messages, GET /negotiations, GET /negotiations/:id)
supabase/functions/_shared/price-recommendation.ts  (import dari Hafizh, jangan duplikasi)
supabase/functions/_shared/inventory-locking.ts  (FG-35, dipakai bareng sprint depan)
```

## Sync point dengan teammate
- **Konfirmasi ke Hafizh** kalau butuh penyesuaian signature `getRecommendedPrice()` — bukan urgent Hari-1, tapi tetap perlu dikomunikasikan sebelum dipakai.
- **Begitu FG-58 selesai**: kabari Fachri — FG-26 (Chat inbox UI, Sprint 6) bisa langsung wiring data asli tanpa menunggu apapun lagi.
- **Begitu FG-22 solid**: kabari Fachri — FG-25 (Chat screen, Sprint 6) bisa wiring ke endpoint asli.
- **Begitu FG-35 selesai**: function rollback-nya akan dipakai FG-33 (Sprint 7) — tidak perlu koordinasi mendesak sekarang, cukup pastikan function-nya terdokumentasi rapi.

## Definition of Done
- [ ] `quantity > listings.quantity_available` → 400 saat `POST /negotiations`
- [ ] Counter offer dari buyer → status `COUNTERED`, `counter_count+1`, giliran pindah ke farmer
- [ ] Pihak pengirim counter terakhir TIDAK bisa Accept tawarannya sendiri
- [ ] `GET /negotiations` cuma mengembalikan milik requester (RLS), terurut `updated_at desc`
- [ ] Dua negotiation/Buy Now paralel untuk listing & quantity sama → yang kedua gagal 409 setelah yang pertama accepted
- [ ] Transaction REJECTED → `quantity_available` listing kembali ke angka sebelum ACCEPTED

## Referensi PRD
§5, §5.1, §8, §9, §10.3, §11, §12.
