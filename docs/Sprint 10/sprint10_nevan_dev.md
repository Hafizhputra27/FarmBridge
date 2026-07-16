# Sprint 10: Integration Testing — Task Plan untuk Nevan

## Peran di sprint ini
**FG-46 (E2E Buy Now + race condition) dan FG-48 (edge case §11).**

## Urutan kerja
**FG-46 dulu**, baru **FG-48** — butuh confidence dasar Buy Now jalan sebelum masuk ke edge case-nya.

## Task Checklist

### FG-46 — E2E test: Buy Now + race condition
- [ ] Alur normal: pilih listing → Buy Now → isi kuantitas → konfirmasi → cek `transaction PENDING` & `quantity_available` berkurang
- [ ] Race condition: dua buyer Buy Now listing & kuantitas sama nyaris bersamaan → first-accepted-wins, yang kedua 409 sesuai §11

### FG-48 — Implementasi & test edge case §11 (perbaikan cakupan)
Checklist asli cuma 7 kondisi — PRD §11 sebenarnya punya 9. Gunakan checklist yang sudah diperbaiki:

- [ ] 1. Counter offer lebih tinggi dari `initial_price` milik sendiri → diizinkan, hanya validasi harga > 0
- [ ] 2. Stok berubah saat negotiation berjalan → warning di chat, tidak auto-cancel
- [ ] 3. Farmer tidak respons 6 jam → EXPIRED, tidak pengaruhi `trust_metrics`
- [ ] 4. `delivered_quantity` > `agreed_quantity` → fulfilled + `anomaly_flag=true`
- [ ] 5. Race condition dua negotiation/Buy Now bersamaan → first-accepted-wins, 409 untuk yang kalah
- [ ] 6. `price_reference_data` kosong → 200 dengan fallback, bukan error
- [ ] 7. Cancel recurring order di tengah siklus pending → transaksi pending tetap jalan
- [ ] **8. Farmer archive/hapus listing dengan recurring_orders aktif → TANDAI "Out of scope MVP" eksplisit.** Fitur archive/delete listing tidak pernah dibangun. Catat sebagai keterbatasan MVP yang disengaja, bukan bug.
- [ ] **9. H-1 skip cycle → sudah dites di FG-47 (Hafizh, sprint ini juga).** Rujuk hasilnya, tidak perlu duplikasi.

## File/folder yang kamu sentuh
```
docs/qa/e2e-buy-now.md
docs/qa/edge-case-checklist.md
```

## Sync point dengan teammate
- **Kabari Hafizh** soal keputusan "baris 8 out of scope" — ini keputusan produk kecil yang sebaiknya diketahui project lead.

## Definition of Done
- [ ] FG-46: alur normal & race condition terverifikasi dengan bukti
- [ ] FG-48: 9 baris (bukan 7) tercatat lulus/gagal/N/A dengan alasan

## Referensi PRD
§5.1, §9, §11.
