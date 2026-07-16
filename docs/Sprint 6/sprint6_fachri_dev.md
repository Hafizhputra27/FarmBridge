> Direvisi 2026-07-14 — sinkron ulang dengan label JIRA (skema granular 13-sprint), menggantikan versi kompresi 6-sprint sebelumnya.

# Sprint 6: Profile UI, Chat & Buy Now — Task Plan untuk Fachri

## Peran di sprint ini
**2 ticket berurutan: FG-25 (Negotiation/Chat screen UI) dan FG-26 (Chat inbox UI).** Semua dependency-nya sudah selesai di sprint-sprint sebelumnya: FG-10 (desain Chat inbox, Alexander) sejak Sprint 1, FG-22 (state machine, Nevan) dan FG-58 (GET /negotiations, Nevan) sejak Sprint 5. Beda dari skema lama yang sempat menyebut ini sebagai potensi bottleneck ("tunggu kabar Nevan") — sekarang tinggal build langsung, tidak ada lagi drama menunggu.

**Kenapa FG-25 dulu, baru FG-26**: Chat inbox (FG-26) pada dasarnya cuma list yang tap-in ke screen yang sama dengan FG-25 (`NegotiationChatScreen`) — bangun FG-25 dulu sampai fungsional, FG-26 tinggal nyambung ke situ.

## Task Checklist

### FG-25 — Negotiation/Chat screen UI (realtime <2 detik)
- [ ] UI chat: bubble pesan, `offer_price`, `recommended_price` ditampilkan di thread
- [ ] Tombol Accept/Counter/Decline — **hanya aktif untuk pihak penerima** (validasi UI ini pelengkap, backend Nevan yang jadi penjaga utama)
- [ ] Subscribe Realtime channel `negotiations`/`negotiation_messages` (aktif sejak FG-4, Sprint 2) untuk update live, target < 2 detik (§12 NFR)
- [ ] Status negotiation (`OPEN`/`COUNTERED`/`ACCEPTED`/`DECLINED`/`EXPIRED`) tampil jelas di header chat
- [ ] Warning inline kalau `quantity_available` listing berubah selagi negosiasi berjalan (§11 edge case) — "Stok tersedia berubah menjadi X"
- [ ] Siapkan area nama counterpart yang bisa di-tap di header (dipakai Hafizh untuk FG-27 di Sprint 7 — koordinasikan posisinya sekarang)
- [ ] TIDAK termasuk: chat inbox list (ticket terpisah, FG-26)

### FG-26 — Chat inbox UI (GET /negotiations)
- [ ] Konsumsi `GET /negotiations` (FG-58, Nevan, Sprint 5 — query param `status` opsional) untuk daftar seluruh negotiation aktif milik user (farmer atau buyer, sesuai `auth.uid()`)
- [ ] Tap item → buka `NegotiationChatScreen` yang sama seperti di listing detail (FG-25)
- [ ] Terurut `updated_at desc`
- [ ] State kosong (belum ada negotiation)
- [ ] Ikuti desain dari FG-10 (Chat inbox screen, Alexander, Sprint 1)
- [ ] TIDAK termasuk: filter/search dalam chat inbox (tidak diminta PRD)

## File/folder yang kamu sentuh
```
lib/features/negotiation/**  (chat screen, chat inbox)
```

## Sync point dengan teammate
- **Koordinasi dengan Hafizh** soal posisi & style nama counterpart yang bisa di-tap di header chat (dipakai FG-27 miliknya, Sprint 7).

## Potensi conflict & cara handle
- Kamu dan Hafizh sama-sama akan menyentuh header chat screen di sprint depan (FG-27) — selesaikan lewat kesepakatan struktur widget sekarang, supaya Hafizh tinggal nambah `onTap` handler tanpa restrukturisasi.

## Definition of Done
- [ ] Pesan baru dari lawan bicara muncul di layar dalam < 2 detik tanpa refresh manual — **cara cek**: video demo chat real-time antar 2 device/akun
- [ ] User yang baru kirim counter (bukan pihak penerima) tidak punya tombol Accept/Decline aktif
- [ ] Warning stok berubah muncul saat `quantity_available` listing berubah selagi negosiasi jalan
- [ ] Tab Chat menampilkan hanya negotiation milik user yang login (RLS), terurut `updated_at desc`
- [ ] State kosong chat inbox tampil jelas untuk user baru yang belum punya negotiation apapun

## Referensi PRD
§3.1(v6), §4.1(v6), §5.1, §9, §11, §12, §15.
