# Sprint 10 — Hasil Akhir

**Tanggal:** 2026-07-17 | **Dikerjakan oleh:** Hafizh (backup semua role: hafizh_dev, nevan_dev, fachri_dev)

## Ringkasan

Sprint 10 murni testing E2E/integrasi — tidak ada fitur baru dibangun. 5 ticket (FG-44 s/d FG-48) semua dieksekusi lewat command curl/SQL langsung terhadap Supabase project (`rwxnjxmzkcfoddnzjosi`), plus 1 script Node.js kecil untuk mengukur latensi realtime. **Dua bug produksi genuine ditemukan** — keduanya didokumentasikan lengkap dengan root cause, tidak diperbaiki tanpa konfirmasi user (sesuai pola established sejak Sprint 7).

## Status per Ticket

| Ticket | Deskripsi | Status | Dokumen |
|---|---|---|---|
| FG-44 | E2E negotiation→transaction→trust_metrics | **PASS** (2/2 skenario) | `docs/qa/e2e-negotiation-pipeline.md` |
| FG-45 | E2E realtime chat latency <2 detik | **PASS** (rata-rata 723ms, 10/10 trial) | `docs/qa/e2e-realtime-latency.md` |
| FG-46 | E2E Buy Now + race condition | **PASS** (setelah fix — lihat "Update Pasca-Fix" di bawah) | `docs/qa/e2e-buy-now.md` |
| FG-47 | E2E recurring order full cycle | **PASS** (3/3 skenario, termasuk cancel-mid-cycle yang belum pernah dites) | `docs/qa/e2e-recurring-order.md` |
| FG-48 | Edge case checklist §11 | **PASS 9/9** (setelah fix — lihat "Update Pasca-Fix" di bawah) | `docs/qa/edge-case-checklist.md` |

## Regression Check

```
flutter analyze   → No issues found!
flutter test      → 26/26 passed (identik dengan akhir Sprint 9 — tidak ada regresi)
```

Sprint ini tidak mengubah kode aplikasi, jadi hasil ini adalah baseline yang sama sejak Sprint 9.

## Bug Produksi Ditemukan (temuan awal — SUDAH DIPERBAIKI, lihat "Update Pasca-Fix" di bawah)

### 1. Race condition di Buy Now (FG-46) — Overselling

**File:** `supabase/functions/buy-now/index.ts:3-19` (fungsi `lockInventory` lokal)

**Root cause:** Fungsi ini adalah duplikat terpisah dari `_shared/inventory-locking.ts` (dipakai alur accept-negosiasi & recurring order) tapi **kehilangan** baris `.eq("quantity_available", currentQty)` — optimistic concurrency guard. Tanpa itu, dua request Buy Now bersamaan sama-sama lolos, keduanya membuat transaksi `pending`, dan stok akhir jadi tidak konsisten (lost-update, bukan penjumlahan defisit).

**Bukti nyata:** 2 request paralel `quantity=4` pada listing stok=5 → **keduanya sukses** (`transaction_id` masing-masing), stok akhir `1` (bukan `-3` — karena update kedua menimpa update pertama), tapi **2 transaksi pending mengklaim 8 unit** dari stok yang cuma 5.

**Rekomendasi fix:** ganti `lockInventory` lokal di `buy-now/index.ts` dengan import dari `_shared/inventory-locking.ts` (source of truth yang sudah benar, dipakai 2 flow lain). Satu import, bukan tambal di banyak tempat.

### 2. Status `EXPIRED` (uppercase) vs `expired` (lowercase) — case mismatch dengan dampak fungsional (FG-48 baris 3)

**File:** `cron.job` (`expire-negotiations`) vs seluruh kode aplikasi

**Root cause:** Sudah dicatat sejak `sprint7_hasil_akhir.md` sebagai temuan kosmetik, tapi **sprint ini dikonfirmasi berdampak fungsional nyata**: cron set `status='EXPIRED'`, sementara `negotiations/index.ts:87` cek guard `["accepted","declined","expired"]` (lowercase) untuk menolak aksi baru pada negosiasi yang sudah selesai.

**Bukti nyata:** setelah negosiasi di-set `EXPIRED`, saya kirim pesan baru ke endpoint `POST /negotiations/:id/messages` — **berhasil 200** (`message_id` baru terbentuk), padahal seharusnya ditolak `409 "Negosiasi sudah selesai"`. User masih bisa terus berinteraksi dengan negosiasi yang harusnya sudah mati. Di sisi UI, label juga tampil sebagai teks mentah "EXPIRED", bukan "Kedaluwarsa". Tombol Terima/Tolak/Tawar tetap aman tersembunyi (pakai allowlist, bukan denylist).

**Rekomendasi fix:** ganti `'EXPIRED'` → `'expired'` di command cron `expire-negotiations` — satu tempat (root cause), bukan menambah lowercase-check di setiap caller.

### 3. (Minor) Pesan fallback `price_reference_data` kosong tidak sampai ke client (FG-48 baris 6)

`price-recommendation.ts` menghitung `message: "Data referensi belum tersedia untuk kategori ini"`, tapi `negotiations/index.ts:73` tidak menyertakan field ini di response. Tidak crash (UI cuma skip render banner rekomendasi harga tanpa penjelasan) — severity rendah, dicatat untuk kelengkapan.

## Data Test yang Perlu Direkonsiliasi

Listing `10bae509-7e72-49d6-8716-b84e600db379` (Cabai Test Fulfillment) sekarang punya state stok yang tidak konsisten akibat pengujian race condition FG-46 (`quantity_available` tidak merefleksikan total transaksi pending yang tercatat). Kalau listing ini mau dipakai lagi untuk demo, perlu direkonsiliasi manual (batalkan transaksi test berlebih, set ulang `quantity_available`) — bisa dilakukan bersamaan dengan fix bug #1 di atas.

## Data Test Baru yang Dibuat Sprint Ini

- Listing `1786952b-1802-43e6-b6b0-236780899905` ("Kategori Uji FG48", region "Sumatera Utara") — sengaja dibuat untuk test fallback price-recommendation, aman dibiarkan (tidak overlap data lain).
- Beberapa negosiasi/transaksi test baru di listing `10bae509...` dan `255b9d9a...` — detail lengkap ada di masing-masing `docs/qa/*.md`.

## Deviasi dari Plan (transparan)

- Deno tidak terpasang di environment — FG-45 dieksekusi pakai Node.js (`@supabase/supabase-js` di scratchpad) sebagai pengganti, logic identik.
- Percobaan pertama FG-45 (anon key polos) gagal total (RLS Realtime memblokir non-partisipan) — diperbaiki dengan autentikasi JWT partisipan, bukan bug aplikasi.
- FG-48 baris 2 (stock-changed banner) diverifikasi lewat code review, bukan live UI session (emulator belum berjalan; logic sederhana & tidak diubah sprint ini).

## Update Pasca-Fix (2026-07-17, lanjutan sesi)

Atas instruksi eksplisit: "perbaiki sebelum lanjut sprint, crosscheck semua fitur apakah sudah aman... check logic sama check visual juga". Plan terpisah ditulis dan dieksekusi inline: `docs/Sprint 10/sprint10_bugfix_crosscheck_plan.md`.

### Fix 1 — Buy Now race condition

`buy-now/index.ts` diubah untuk reuse `lockInventoryOnAcceptWithQuantity` dari `_shared/inventory-locking.ts` (menghapus fungsi lokal yang cacat), deploy sukses. **Re-test awal masih FAIL** — race masih lolos.

### Bug kedua ditemukan saat verifikasi (lebih dalam dari temuan awal)

Investigasi menemukan root cause sebenarnya: `lockInventoryOnAcceptWithQuantity` DAN `lockInventoryForRecurringCycle` di `_shared/inventory-locking.ts` memanggil `.update(...).eq("quantity_available", currentQty)` **tanpa `.select()`**. PostgREST membalas sukses (204 No Content) walau 0 baris cocok dengan guard — jadi guard secara SQL benar tapi kodenya tidak pernah verifikasi apakah update itu betul-betul kena baris. Request yang "kalah" race tetap lolos ke tahap insert transaksi.

**Implikasi penting:** kesimpulan awal sprint ini untuk FG-48 baris 5 ("race condition accept-negosiasi PASS") ternyata **false positive** — lolos karena kebetulan timing 2 request tidak genap simultan, bukan karena guard benar-benar bekerja.

**Fix:** tambah `.select().single()` di kedua fungsi shared, sehingga 0-baris-ter-update memicu error yang terdeteksi. Redeploy 4 Edge Function yang mengimpor file ini: `negotiations`, `buy-now`, `transactions-reject`, `check-recurring-orders`.

### Fix 2 — EXPIRED/expired case mismatch

Migration `fix_expire_negotiations_case`: `cron.alter_job` mengganti command jadi lowercase `SET status = 'expired'`, plus backfill `UPDATE negotiations SET status='expired' WHERE status='EXPIRED'` (3 baris histori lama ikut terkoreksi, termasuk data non-test).

### Rekonsiliasi data test

Listing `10bae509...`: transaksi duplikat `41e98b7d...` (artefak race) di-set `rejected`; `quantity_available` dikoreksi ke `35` (derivasi penuh ada di `sprint10_bugfix_crosscheck_plan.md` Task 3).

### Re-verifikasi (bukti kuat, tekanan konkurensi lebih tinggi dari test awal)

- **Buy Now:** 3 request paralel `quantity=4` pada stok=5 → 1 sukses, 2 gagal dengan pesan guard yang benar. Stok akhir `1`.
- **Accept-negosiasi:** 3 accept paralel pada 3 negosiasi terpisah qty=4, stok=5 → 1 sukses, 2 gagal dengan pesan guard yang benar. Stok akhir `1`.
- **EXPIRED guard bypass:** negosiasi expired (lowercase) → kirim pesan baru ditolak `409 "Negosiasi sudah selesai — status: expired"` (sebelumnya 200, sekarang benar).

### Regresi logic (setelah semua fix + redeploy)

```
flutter analyze   → No issues found!
flutter test      → 26/26 passed (identik, kode Flutter tidak disentuh)
```
Smoke-check tambahan: negotiation create (200), Buy Now jalur normal non-race (200, stok berkurang tepat 1), `transactions-reject` + rollback stok (berfungsi benar), `check-recurring-orders` (response shape normal). **Tidak ada regresi ditemukan.**

### Crosscheck visual — TERHAMBAT (blocker lingkungan, bukan kode)

Emulator (`emulator-5554`) mengalami kegagalan DNS/network total saat sesi ini — `ping: unknown host ...supabase.co`, bahkan raw IP ping ke `8.8.8.8` membalas data corrupt. App macet permanen di splash screen (gagal refresh sesi auth ke Supabase). Sudah dicoba: force-stop + relaunch (3×), toggle WiFi via `svc wifi`, restart `adb server`, verifikasi clock sync (jam host dan emulator identik, bukan penyebab) — semua tidak menyelesaikan masalah. Ini murni masalah infrastruktur emulator, di luar kendali lewat `adb shell` dan tidak berkaitan dengan perubahan kode Sprint 10.

**Belum terverifikasi secara visual:** tampilan login, chat negosiasi, Buy Now, fulfill/reject, recurring order list/detail, archive-block dialog. **Perlu:** restart emulator (Android Studio Device Manager / cold boot) untuk melanjutkan Task 6 di sesi berikutnya.

## Kesimpulan Akhir

| Area | Status |
|---|---|
| FG-44 s/d FG-47 | PASS bersih (sebelum & sesudah fix — tidak terpengaruh) |
| FG-48 (9 baris edge case) | **9/9 PASS** (baris 3 & 5 awalnya FAIL/false-positive, sekarang genuine PASS setelah fix) |
| Bug race condition Buy Now | **Fixed & diverifikasi ulang dengan tekanan konkurensi lebih tinggi** |
| Bug EXPIRED case mismatch | **Fixed & diverifikasi ulang** (termasuk dampak guard-bypass yang ditemukan) |
| Bug ketiga (guard `.select()` hilang) | **Ditemukan saat proses fix, langsung diperbaiki & diverifikasi** — mempengaruhi 2 fungsi shared, 4 Edge Function di-redeploy |
| Regresi logic | **Tidak ada** (`flutter analyze`/`flutter test` bersih, semua smoke-check pasca-fix PASS) |
| Crosscheck visual | **Belum selesai** — blocker emulator (network/DNS), bukan kode |

**Rekomendasi go/no-go untuk Sprint 11:** Dari sisi **logic**, semua fitur Sprint 1-10 aman untuk dilanjutkan — 3 bug produksi ditemukan sprint ini semuanya sudah diperbaiki dan diverifikasi ulang dengan bukti konkret (bukan asumsi), tidak ada regresi. Dari sisi **visual**, masih ada gap karena blocker emulator — sebaiknya restart emulator dan selesaikan Task 6 (screenshot flow inti: login, chat negosiasi, Buy Now, fulfill, recurring order, archive-block) sebelum benar-benar dianggap "aman 100%", tapi ini tidak menghalangi persiapan/perencanaan Sprint 11 untuk dimulai.
