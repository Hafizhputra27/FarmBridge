# FG-47: E2E Testing — Recurring Order Full Cycle

**Sprint:** 10 | **Tanggal:** 2026-07-17 | **Tester:** Hafizh (backup semua role)

## Skenario 1 — Create → trigger sukses (created)

| Step | Aksi | Expected | Actual | Status |
|---|---|---|---|---|
| 1 | Pakai recurring order Sprint 9 (`1eadb85a...`, qty 5, listing stok 104) — set `next_order_date=today`, trigger `check-recurring-orders` | `created≥1` | `{"due_orders":0,"notified":0,"due_today":1,"created":1,"skipped":0}` | PASS |
| 1 | Verifikasi transaksi baru | `recurring_order_id` sesuai, status `pending` | `b1a57a88-8c33-4cb6-affa-c6a1bdb57a89`, dibuat `04:15:07`, `pending`, `agreed_quantity=5` (transaksi Sprint 9 `dd141705...` tetap ada terpisah) | PASS |
| 1 | Verifikasi `next_order_date` maju | Maju dari hari ini | `2026-07-17 → 2026-07-24` (weekly, +7 hari) | PASS |

## Skenario 2 — Skip karena stok kurang

| Step | Aksi | Expected | Actual | Status |
|---|---|---|---|---|
| 1 | Recurring order `a1c1800c...` (qty 1, listing `10bae509...`) awalnya stok=1 (cukup, bukan skip) — sengaja di-set stok=0 untuk memaksa skenario skip, `next_order_date=today`, trigger | `skipped=1`, `created=0` | `{"due_orders":0,"notified":0,"due_today":1,"created":0,"skipped":1}` | PASS |
| 1 | Verifikasi `next_order_date` tetap maju meski skip | Maju (H-1 reminder logic tidak boleh macet permanen) | `2026-07-17 → 2026-07-24` | PASS |

**Catatan:** listing `10bae509...` yang dipakai skenario ini adalah listing yang sama yang ditemukan dalam kondisi overselling di FG-46 (lihat `e2e-buy-now.md`) — stok `1` sebelum test ini sendiri sudah bagian dari data yang perlu direkonsiliasi, bukan hasil skenario ini.

## Skenario 3 — Cancel recurring order saat transaksi masih pending (BARU, belum pernah dites sebelumnya)

Recurring order baru dibuat khusus untuk skenario ini, listing `255b9d9a...` (stok 104, tidak overlap dengan data FG-46).

| Step | Aksi | Expected | Actual | Status |
|---|---|---|---|---|
| 2 | Buat recurring order baru (qty 1, weekly) | `recurring_order_id` baru | `07c2d018-ea8b-4941-825f-c6de6da68dd9`, `next_order_date=2026-07-24` | PASS |
| 3 | Set `next_order_date=today`, trigger | `created=1` | `{"due_orders":0,"notified":0,"due_today":1,"created":1,"skipped":0}` | PASS |
| 3 | Ambil transaksi baru | `status=pending` | `92ada392-22e3-46fd-bc32-1bb4be4c21d4`, `pending` | dicatat |
| 4 | PATCH `status=cancelled` pada recurring order **sementara transaksi masih pending** | 200 | `{"recurring_order_id":"07c2d018...","status":"cancelled"}` | PASS |
| 5 | Verifikasi transaksi pending TIDAK ikut ter-cancel | Tetap `status=pending` | `pending` (tidak berubah) | **PASS** |
| 5 | Verifikasi `recurring_orders.status` | `cancelled` | `cancelled` | PASS |
| 6 | Set `next_order_date=today` lagi (manual), trigger ulang | `due_today` tidak menghitung RO ini, tidak ada transaksi baru | `{"due_orders":0,"notified":0,"due_today":0,"created":0,"skipped":0}`, jumlah transaksi untuk RO ini tetap `1` | **PASS** |

Perilaku sesuai §11: "Transaksi yang sudah PENDING tetap berjalan sampai selesai; hanya siklus berikutnya yang dihentikan." Query `check-recurring-orders` memfilter `status='active'`, sehingga RO yang sudah `cancelled` otomatis tidak diproses lagi tanpa perlu logic tambahan — desain yang benar dan sudah teruji.

## Kesimpulan

**Skenario 1 (sukses): PASS**
**Skenario 2 (skip): PASS**
**Skenario 3 (cancel-mid-cycle, baru): PASS**

Referensi bukti tambahan sukses/skip dari sesi sebelumnya: `docs/Sprint 9/sprint9_hasil_akhir.md` Task 3.
