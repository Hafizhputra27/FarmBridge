# FG-46: E2E Testing — Buy Now + Race Condition

**Sprint:** 10 | **Tanggal:** 2026-07-17 | **Tester:** Hafizh (backup semua role)

## Skenario 1 — Alur normal

| Step | Aksi | Expected | Actual | Status |
|---|---|---|---|---|
| 1 | Ambil JWT buyer & farmer (password grant) | Token non-kosong | `buyer` 778 char, `farmer` 779 char | PASS |
| 2 | Cek stok awal listing `10bae509...` | — | `40` | dicatat |
| 2 | Buy Now `quantity=1` | 200, `transaction_id` non-null, `status=pending` | `{"negotiation_id":"f7202758...","transaction_id":"8c382aa0-c840-4971-97df-026cf1904542","status":"pending","total_amount":30000}` | PASS |
| 2 | Verifikasi stok berkurang tepat 1 | `39` | `39` | PASS |

**Skenario 1: PASS.**

## Skenario 2 — Race condition (first-accepted-wins)

| Step | Aksi | Expected | Actual | Status |
|---|---|---|---|---|
| 3 | Set stok listing = 5 | — | `5` | dicatat |
| 4 | 2 request Buy Now paralel, masing-masing `quantity=4` (total 8 > stok 5) | Salah satu sukses, satu lagi gagal (409/error stok) | **Kedua-duanya sukses** — `transaction_id=e37efa63...` dan `transaction_id=41e98b7d...`, keduanya `status=pending`, `total_amount=120000` | **FAIL** |
| 5 | Verifikasi stok akhir | `1` (5−4, bukan negatif) | `1` | Nilai match, tapi ini **kebetulan**, bukan bukti guard bekerja (lihat root cause) |

### Root cause (dikonfirmasi via source code, bukan dugaan)

`supabase/functions/buy-now/index.ts:3-19` punya fungsi `lockInventory` lokal yang **terpisah/terduplikasi** dari `supabase/functions/_shared/inventory-locking.ts` (dipakai oleh alur accept-negosiasi dan recurring order). Bandingkan:

- `_shared/inventory-locking.ts:62-64` (BENAR):
  ```ts
  .update({ quantity_available: currentQty - quantity })
  .eq("id", listingId)
  .eq("quantity_available", currentQty); // optimistic concurrency guard
  ```
- `buy-now/index.ts:8` (SALAH — guard hilang):
  ```ts
  const { error: deductErr } = await supabase.from("listings").update({ quantity_available: currentQty - quantity }).eq("id", listingId);
  ```

Tanpa `.eq("quantity_available", currentQty)`, ini classic TOCTOU (time-of-check-to-time-of-use) race: kedua request baca `currentQty=5` hampir bersamaan, keduanya lolos cek `currentQty < quantity` (5≥4), keduanya menulis `5-4=1` tanpa syarat — **lost update**, bukan penjumlahan (kalau tidak, hasilnya akan negatif). Karena UPDATE tanpa WHERE guard pada nilai lama selalu "berhasil" dari sisi Postgres, **kedua** request lolos ke tahap insert transaksi.

**Dampak nyata (bukan cuma teoretis):** dikonfirmasi lewat SQL — dua transaksi `pending` (`e37efa63...`, `41e98b7d...`) masing-masing `agreed_quantity=4`, total **8 unit diklaim** dari listing yang cuma py 5 unit stok. `quantity_available` akhir (`1`) TIDAK merefleksikan salah satu dari kedua klaim itu secara benar — ini overselling murni: kalau kedua transaksi nanti di-fulfill oleh farmer, farmer akan berkomitmen mengirim 8 unit padahal listing cuma py 5.

**Skenario 2: FAIL.** Bug ini genuine, reproducible, dan berbeda dari kekhawatiran "expected-tapi-belum-diverifikasi" — race condition betulan terjadi karena guard atomic hilang di jalur Buy Now.

## Verifikasi Pasca-Fix (2026-07-17, lanjutan sesi)

**Fix 1 — reuse shared lock function:** `buy-now/index.ts` diubah untuk memanggil `lockInventoryOnAcceptWithQuantity` dari `_shared/inventory-locking.ts`, menghapus fungsi lokal yang cacat. Deploy sukses, tapi **race test ulang masih menunjukkan kedua request sukses** — ternyata ada bug kedua yang lebih dalam.

**Fix 2 — bug tersembunyi ditemukan saat verifikasi:** fungsi shared `lockInventoryOnAcceptWithQuantity` (dan `lockInventoryForRecurringCycle`) memanggil `.update(...).eq(...).eq("quantity_available", currentQty)` **tanpa `.select()`**. PostgREST membalas sukses (204 No Content) walau 0 baris cocok dengan guard — jadi guard `.eq("quantity_available", currentQty)` ada secara SQL tapi kodenya tidak pernah mengecek apakah update itu benar-benar kena baris. Request yang "kalah" race tetap lolos ke tahap insert transaksi. Ini juga berarti kesimpulan awal "race condition accept-negosiasi PASS" (edge-case-checklist.md baris 5, sebelum fix ini) kemungkinan **false positive** akibat timing, bukan bukti guard bekerja.

Fix: tambah `.select().single()` di kedua fungsi (`inventory-locking.ts`), sehingga 0-baris-ter-update memicu error yang benar terdeteksi. Redeploy 4 Edge Function yang mengimpor file ini: `negotiations`, `buy-now`, `transactions-reject`, `check-recurring-orders`.

**Re-test setelah fix kedua (bukti kuat, bukan kebetulan timing):**
- Buy Now, 3 request paralel `quantity=4` pada stok=5: 1 sukses, 2 gagal dengan pesan guard yang benar (`"Stok tidak mencukupi — transaksi lain mungkin sudah mengambil (first-accepted-wins)"`). Stok akhir `1` (5−4).
- Accept-negosiasi, 3 accept paralel pada 3 negosiasi terpisah qty=4 masing-masing, listing stok=5: 1 sukses, 2 gagal dengan pesan guard yang sama. Stok akhir `1`.

**Kesimpulan Skenario 2: PASS (setelah fix).** Diverifikasi ulang dengan tekanan konkurensi yang lebih tinggi (3 request paralel, bukan 2) untuk memastikan bukan kebetulan timing seperti temuan awal yang keliru.

## Data test

Listing `10bae509-7e72-49d6-8716-b84e600db379` sudah direkonsiliasi (lihat `sprint10_hasil_akhir.md` bagian rekonsiliasi) — transaksi duplikat `41e98b7d...` di-set `rejected`, `quantity_available` dikoreksi ke `35`.
