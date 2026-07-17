# FG-44: E2E Testing — Negotiation → Transaction → Trust Metrics Pipeline

**Sprint:** 10 | **Tanggal:** 2026-07-17 | **Tester:** Hafizh (backup semua role)

## Ringkasan

Menguji pipeline penuh dari negosiasi sampai update `trust_metrics`, dua jalur: **accept→fulfill** dan **accept→reject**. Data test dibuat fresh di sesi ini menggunakan listing `10bae509-7e72-49d6-8716-b84e600db379` (Cabai Test Fulfillment, milik `farmer.test@farmbridge.dev` / `38e89c06-2257-49f8-a392-ed2ee8734031`) supaya kredensial JWT yang tersedia (akun test) match dengan `farmer_id` pemilik transaksi — percobaan awal pakai listing farmer lain (`Petani Test S5`) gagal di step fulfill karena tidak ada kredensial login untuk farmer tersebut (lihat catatan di bagian Temuan).

## Skenario 1 — Accept path (negotiation → counter → accept → fulfill → trust_metrics)

| Step | Aksi | Expected | Actual | Status |
|---|---|---|---|---|
| 1 | Buyer buat negosiasi (`initial_price=32000, qty=3`) | 200, `status=open` | `negotiation_id=80eb8f3e-af5d-4cbd-8699-92b466ef2b71`, `status=open` | PASS |
| 1 | Farmer counter `offer_price=34000` | `negotiation_status=countered` | `negotiation_status=countered` | PASS |
| 1 | Buyer accept `offer_price=34000` | `transaction_id` non-null, `negotiation_status=accepted` | `transaction_id=c95e71b1-b136-48d6-ba71-6008e9173b01`, `negotiation_status=accepted` | PASS |
| 2 | Verifikasi transaction pending | `status=pending`, `total_amount=3×34000=102000` | `status=pending`, `total_amount=102000` | PASS |
| 3 | Fulfill (`delivered_quantity=3`, farmer JWT) | 200, `status=fulfilled` | `{"transaction_id":"c95e71b1...","status":"fulfilled","trust_metrics_updated":true}` | PASS |
| 3 | Verifikasi `trust_metrics` farmer `38e89c06...` | Ter-update, `updated_at` mendekati sekarang | `on_time_delivery_rate=100.00`, `rejection_rate=0.00`, `fulfillment_consistency=100.00`, `total_transactions=4`, `updated_at=2026-07-17 04:01:44` | PASS* |

**\*Catatan koreksi terhadap plan:** Plan awal berasumsi `total_transactions` naik tepat +1 per fulfill (model increment). Hasil aktual naik dari 2 → 4 (bukan 3), sempat dicurigai bug. Investigasi source code `supabase/functions/update-trust-metrics/index.ts:73-119` mengonfirmasi ini **bukan bug**: `total_transactions` = `transactions.length` (**semua** transaksi farmer dalam window 90 hari, **termasuk status `pending`**, bukan hanya fulfilled/rejected). Verifikasi silang: `select status, count(*) from transactions where farmer_id=... group by status` → `fulfilled=3, pending=1` = 4, cocok persis. Metrik lain (`on_time_delivery_rate`, `rejection_rate`, `fulfillment_consistency`) juga full-recompute dari histori transaksi 90 hari, bukan incremental — desain valid untuk trust score yang selalu konsisten dengan histori aktual.

## Skenario 2 — Reject path (accept → reject → rejection_rate + stock rollback)

| Step | Aksi | Expected | Actual | Status |
|---|---|---|---|---|
| 4 | Buat negosiasi ke-2 (`qty=2`) → accept | `transaction_id` baru | `transaction_id=0bdeb692-f147-441b-a69d-bef1fe7d6cdd`, `agreed_quantity=2`, `total_amount=68000` | PASS |
| 4 | Cek `quantity_available` sebelum reject | — | `38` (43 awal − 3 − 2 dari 2 negosiasi accept) | dicatat |
| 5 | Buyer reject (`reason="Kualitas tidak sesuai (E2E test FG-44)"`) | `status=rejected` | `{"transaction_id":"0bdeb692...","status":"rejected","reason":"Kualitas tidak sesuai (E2E test FG-44)"}` | PASS |
| 5 | Verifikasi `transactions.status` | `rejected` | `rejected` | PASS |
| 5 | Verifikasi `quantity_available` rollback | `38 + 2 = 40` | `40` | PASS |
| 5 | Verifikasi `rejection_rate` naik | Naik dari 0% | `rejection_rate=20.00` (1 rejected / 5 total transaksi window) | PASS |

## Bukti tambahan dari sesi sebelumnya (referensi silang)

- `sprint7_hasil_akhir.md` — transaksi `4f58b43f-6c6a-497b-93ce-7ad7a945cb70` (fulfilled) dan `8561d904-3e84-4ebe-83f3-61ade76e0a46` (awalnya pending) untuk farmer yang sama, bagian dari histori 90-hari yang ikut mempengaruhi angka `total_transactions=4/5` di atas.
- `271d5531-fdaa-41e5-a48a-05fc74de3278` (fulfilled, `agreed_quantity=2`, dibuat sebelum sesi ini) — juga bagian histori window yang sama.

## Temuan

- Percobaan pertama Step 1 pakai listing `255b9d9a-a093-45a8-8599-da5f0f7d63d9` (milik farmer "Petani Test S5", `dd97243c-c350-4282-8fe2-4e8e1084f951`) — fulfill gagal 403 `"Hanya farmer pemilik transaksi yang bisa fulfill"` karena kredensial login yang tersedia hanya untuk `farmer.test`/`buyer.test`, bukan farmer test lain. Bukan bug aplikasi — keterbatasan data test. Diselesaikan dengan mengulang Step 1 pakai listing milik `farmer.test`.
- Endpoint `transactions-fulfill` selalu mengembalikan `trust_metrics_updated: true` meski panggilan ke `update-trust-metrics` fire-and-forget tanpa cek response (`index.ts:88-100`, try/catch kosong). Dalam pengujian ini update **memang** berhasil (diverifikasi lewat SQL), jadi tidak FAIL — tapi field response ini berpotensi menyesatkan kalau update-trust-metrics gagal diam-diam. Dicatat sebagai observasi, bukan blocker.

## Kesimpulan

**Skenario 1 (Accept→Fulfill): PASS**
**Skenario 2 (Accept→Reject): PASS**

Pipeline FG-44 berfungsi sesuai desain end-to-end, termasuk update trust_metrics (recompute penuh dari histori 90 hari) dan rollback stok saat reject.
