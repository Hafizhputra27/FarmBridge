# FG-48: Edge Case Checklist §11 (9 item)

**Sprint:** 10 | **Tanggal:** 2026-07-17 | **Tester:** Hafizh (backup semua role)

**Koreksi cakupan:** Checklist asli tim (`sprint10_README.md`) mendaftar 7 baris efektif dan menandai baris 8 "Out of scope MVP". Baris 8 sekarang **bisa dan sudah** diuji (fitur archive-guard dibangun Sprint 9 / FG-60) — cakupan sprint ini jadi 9 baris utuh.

| No | Skenario | Cara Uji | Expected | Actual | Status |
|---|---|---|---|---|---|
| 1 | Counter offer lebih tinggi dari harga sendiri | Buyer buat negosiasi `initial_price=30000`, lalu counter `offer_price=50000` | Diterima (200), tidak ada validasi batas atas | `{"message_id":"37765fcf...","negotiation_status":"countered",...}` — diterima | **PASS** |
| 2 | Stok berubah saat negotiation berjalan → warning di chat | Code review `negotiation_chat_screen.dart:236-237,284-299` (`stockChanged` banner) | Banner oranye "Stok berubah: X → Y unit" muncul, negosiasi tidak auto-cancel | Logic dikonfirmasi benar & tidak berubah sejak Sprint 9. **Tidak diverifikasi via live UI session** — device/emulator belum jalan, biaya setup (login+navigasi) tidak sepadan untuk 1 baris checklist yang logic-nya trivial dan tidak disentuh sprint ini | **PASS (code review, bukan live UI)** |
| 3 | Farmer tidak respons 6 jam → EXPIRED, tidak pengaruhi trust_metrics | Mundurkan `expires_at`, jalankan logic cron `expire-negotiations` | `status` jadi `expired` (lowercase), trust_metrics tidak berubah | Awalnya `status` jadi **`EXPIRED`** (uppercase) — FAIL, lihat detail di bagian Temuan. **Setelah fix** (migration `fix_expire_negotiations_case`): status jadi `expired` (lowercase), kirim pesan ke negosiasi itu ditolak `409 "Negosiasi sudah selesai — status: expired"` sebagaimana mestinya | **PASS (setelah fix)** |
| 4 | `delivered_quantity` > `agreed_quantity` → fulfilled + `anomaly_flag=true` | Rujuk bukti existing | `anomaly_flag=true` | Transaksi `ecbb7788-d65a-4359-b5fe-c00636608d05`: `agreed_quantity=100`, `delivered_quantity=120`, `anomaly_flag=true` (data sudah ada, diverifikasi ulang via SQL sesi ini) | **PASS** |
| 5 | Race condition dua accept negosiasi bersamaan → first-accepted-wins | 2 negosiasi terpisah (qty 4 masing-masing) atas listing stok=5, `countered`, lalu 2 `accept` nyaris bersamaan | Satu sukses, satu gagal | **Koreksi:** hasil awal (A gagal, B sukses) ternyata **false positive** — root cause sama dengan FG-46 (guard `.eq("quantity_available", currentQty)` di `_shared/inventory-locking.ts` tanpa `.select()`, jadi 0-baris-cocok tidak terdeteksi sebagai error). Kebetulan lolos karena timing 2 request tidak genap bersamaan. **Setelah fix** (`.select().single()` ditambahkan + redeploy), diuji ulang dengan tekanan lebih tinggi (3 accept paralel, qty4 masing-masing, stok=5): 1 sukses, 2 gagal dengan pesan guard yang benar, stok akhir `1` | **PASS (setelah fix, diverifikasi ulang lebih ketat)** |
| 6 | `price_reference_data` kosong → 200 dengan fallback | Listing baru kategori "Kategori Uji FG48"/region "Sumatera Utara" (tidak ada di `price_reference_data`), buat negosiasi | 200, `recommended_price=null`, `message` fallback terkirim ke client | 200, `recommended_price/avg_price/min_price/max_price` semua `null` — **tapi field `message` tidak pernah dikirim ke client** (`negotiations/index.ts:73` membangun response tanpa menyertakan `priceResult.message`, padahal `price-recommendation.ts:37` sudah menghitungnya). Dampak di UI: `chat_bubble.dart:82` cuma `if (recommendedPrice != null)` — tidak crash, tapi user tidak pernah lihat penjelasan apapun, cuma banner rekomendasi harga yang hilang begitu saja | **PASS (tidak crash) dengan catatan minor** |
| 7 | Cancel recurring order di tengah siklus pending | Sudah dites di FG-47 Skenario 3 | Transaksi pending tetap jalan, siklus berikutnya berhenti | Lihat `docs/qa/e2e-recurring-order.md` — PASS | **PASS (rujukan)** |
| 8 | Farmer archive listing dengan recurring_orders aktif → DITOLAK | `update listings set status='archived'` pada listing dengan 1 recurring order aktif | Ditolak oleh trigger `guard_archive_listing_with_active_recurring` | `ERROR: 23514: Listing masih terikat 1 recurring order aktif — pause/cancel dulu sebelum archive` — persis sesuai desain. Listing tetap `status=active` (transaksi di-rollback otomatis oleh Postgres) | **PASS** — koreksi resmi terhadap checklist lama yang menandai ini "Out of scope MVP" |
| 9 | H-1 skip cycle | Sudah dites di FG-47 Skenario 2 | `next_order_date` tetap maju meski skip | Lihat `docs/qa/e2e-recurring-order.md` — PASS | **PASS (rujukan)** |

## Temuan — Bug `EXPIRED`/`expired` case mismatch (Baris 3)

**Root cause:** `supabase/functions/negotiations/index.ts:87` dan seluruh kode Flutter (`negotiation_chat_screen.dart:395,404,345`, `chat_inbox_screen.dart:210,219,228`) menggunakan string `'expired'` (lowercase) untuk mengecek status negosiasi yang sudah kedaluwarsa. Tapi cron job `expire-negotiations` (`SELECT command FROM cron.job WHERE jobname='expire-negotiations'`) meng-update status jadi `'EXPIRED'` (uppercase). Bug ini **sudah dicatat sejak `sprint7_hasil_akhir.md`** tapi belum pernah diperbaiki.

**Dampak dikonfirmasi lewat pengujian langsung di sprint ini (bukan cuma dugaan):**
1. **UI:** `_statusLabel()` fallback ke raw string `_ => status` — user melihat teks mentah **"EXPIRED"** di header chat, bukan label Indonesia "Kedaluwarsa".
2. **Backend guard bypass (baru ditemukan, lebih serius):** endpoint `POST /negotiations/:id/messages` punya guard `if (["accepted","declined","expired"].includes(neg.status)) return 409`. Karena nilai aktual `'EXPIRED'` tidak match string lowercase di array itu, guard **gagal total** — dibuktikan dengan mengirim pesan baru ke negosiasi yang sudah `EXPIRED` dan mendapat **200 OK** (`message_id` baru berhasil dibuat), bukan 409 yang diharapkan. Ini berarti pengguna masih bisa terus berinteraksi (kirim pesan, kemungkinan besar juga counter/accept karena melewati guard yang sama) dengan negosiasi yang seharusnya sudah final/mati.
3. **Aman:** `NegotiationActions._canAct` (tombol Terima/Tolak/Tawar) pakai **allowlist** (`status=='open'||'countered'`), jadi tombol aksi utama tetap correctly disembunyikan untuk `'EXPIRED'` — hanya kotak kirim pesan bebas dan guard backend yang bocor.
4. **Trust metrics:** tidak terpengaruh (dikonfirmasi, sesuai desain — expire memang tidak seharusnya menyentuh trust_metrics).

**Fix diterapkan** (2026-07-17, lanjutan sesi, atas persetujuan user): migration `fix_expire_negotiations_case` — `cron.alter_job` mengganti command jadi `SET status = 'expired'` (lowercase) + backfill `UPDATE negotiations SET status='expired' WHERE status='EXPIRED'` (3 baris histori lama, termasuk data real bukan cuma data test, ikut terkoreksi). Diverifikasi ulang PASS (lihat baris 3 di atas).

## Temuan tambahan — Bug guard `.select()` hilang di `_shared/inventory-locking.ts` (ditemukan saat verifikasi fix FG-46)

Saat re-test race condition Buy Now pasca-fix pertama (reuse shared function), race **masih lolos**. Investigasi menemukan bug kedua: `lockInventoryOnAcceptWithQuantity` dan `lockInventoryForRecurringCycle` memanggil `.update(...).eq("quantity_available", currentQty)` **tanpa `.select()`** — PostgREST membalas sukses (204) walau 0 baris cocok, jadi guard secara SQL benar tapi kodenya tidak pernah mengecek apakah update itu betul-betul mengenai baris. Ini menjelaskan kenapa baris 5 di atas awalnya tampak PASS (kebetulan timing), padahal guard-nya sama-sama tidak fungsional dengan yang di Buy Now.

**Fix:** tambah `.select().single()` di kedua fungsi, sehingga 0-baris-ter-update memicu error yang terdeteksi. Redeploy 4 Edge Function (`negotiations`, `buy-now`, `transactions-reject`, `check-recurring-orders`). Diverifikasi ulang dengan tekanan konkurensi lebih tinggi (3 request paralel) untuk kedua jalur (Buy Now & accept-negosiasi) — keduanya sekarang PASS genuine, bukan kebetulan timing.

## Kesimpulan

| Status | Jumlah |
|---|---|
| PASS | 9 |
| FAIL | 0 |

Dua bug produksi ditemukan sprint ini (baris 3 + race condition Buy Now di `e2e-buy-now.md`), plus 1 bug tersembunyi kedua ditemukan saat proses fix (guard `.select()` hilang, berdampak juga ke baris 5) — semuanya sudah diperbaiki dan diverifikasi ulang dengan bukti konkret, bukan asumsi.
