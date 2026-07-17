> Ringkasan hasil akhir Sprint 9 — dibuat 2026-07-17, setelah 4 ticket (FG-38, FG-39, FG-40, FG-60) dikerjakan dan diverifikasi end-to-end oleh satu orang (user mengambil alih semua role `hafizh_dev`/`nevan_dev`/`fachri_dev` sprint ini juga, sama seperti Sprint 8). Merangkum eksekusi `sprint9_plan_lengkap.md` (9 task, semua tercentang) plus 1 bug ditemukan & diperbaiki langsung saat QA device.

# Sprint 9: Recurring Order UI — Hasil Akhir

## Status: ✅ Selesai — 9/9 task terverifikasi end-to-end (backend via curl+SQL, Flutter via device UI nyata di emulator)

| Ticket | Judul | Status |
|---|---|---|
| FG-38 | pg_cron trigger H-1 — bikin transaction siklus baru | ✅ |
| FG-39 | My Recurring Orders + Detail UI | ✅ |
| FG-40 | CTA "Jadikan Recurring Order" | ✅ |
| FG-60 | Guard archive listing dengan recurring aktif | ✅ (backend + frontend) |

---

## Temuan arsitektur sebelum mulai (dari fase analisis)

Dua gap ditemukan saat riset sebelum implementasi, keduanya dicatat eksplisit di plan dan ditutup sebagai bagian dari Sprint 9:

1. **`transactions.negotiation_id` NOT NULL, tidak ada kolom `recurring_order_id` sama sekali** — padahal PRD §6 eksplisit minta siklus recurring berikutnya "tertaut ke `recurring_order_id`". Ditutup Task 1 (migration schema).
2. **"Konfirmasi kesiapan farmer" (PRD §4.1) untuk H-1 belum punya mekanisme apapun** — bahkan sudah diakui gap terbuka oleh tim asli sendiri di `sprint9_fachri_dev.md` ("belum punya ticket sama sekali"). Diselesaikan dengan interpretasi eksplisit: gate satu-satunya adalah `recurring_orders.status == 'active'` (farmer/buyer bisa pause/cancel kapan saja lewat FG-37 yang sudah ada) — bukan mekanisme confirm baru.

## FG-38 — Day-of trigger siklus recurring order

**File:** `supabase/functions/_shared/inventory-locking.ts` (+`lockInventoryForRecurringCycle`), `supabase/functions/check-recurring-orders/index.ts` (+`triggerDueCycles`, digabung ke function Sprint 8 yang sudah ada — bukan function terpisah seperti draf checklist lama, supaya satu cron run cek reminder H-1 dan trigger hari-H sekaligus).

Logic: cari `recurring_orders` aktif dengan `next_order_date == hari ini`. Stok cukup → atomic deduct stok + insert `transactions` (`negotiation_id` NULL, `recurring_order_id` terisi, `status: pending`) + majukan `next_order_date` ke siklus berikutnya + push "Recurring order dibuat". Stok kurang → **tidak** ada transaksi baru, `next_order_date` tetap dimajukan, status tetap `active`, push "Siklus dilewati" — persis sesuai §11.

**Verifikasi (curl + SQL):**
- Skenario stok cukup: `{"created":1,"skipped":0}` → transaksi baru `negotiation_id: null`, `recurring_order_id` terisi, `agreed_quantity: 5`, `total_amount: 175000` (5×35000); `next_order_date` maju dari 2026-07-17 ke 2026-07-24.
- Skenario stok kurang (recurring order `quantity: 9999` sengaja dibuat melebihi stok): `{"created":0,"skipped":1}` → `status` tetap `active`, `next_order_date` tetap maju, **0** transaksi baru untuk order itu.

## FG-60 — Guard archive listing dengan recurring aktif

**Backend:** `supabase/migrations/20260718010000_guard_archive_listing_recurring.sql` — Postgres trigger `BEFORE UPDATE ON listings` (bukan Edge Function baru), menolak `status → 'archived'` kalau ada `recurring_orders.status='active'` yang mengacu ke listing itu. Enforcement di level trigger dipilih spesifik supaya tidak bisa di-bypass jalur manapun (client REST langsung, Edge Function, dashboard) — sesuai requirement "tidak bisa di-bypass" di `sprint9_nevan_dev.md`.

**Frontend:** `lib/features/listing/screens/my_listings_screen.dart` — fitur archive (tombol + modal konfirmasi) **belum ada sama sekali sebelumnya**, dibangun dari nol, bukan cuma nge-guard yang sudah ada. Diubah dari `ConsumerWidget` (`FutureBuilder` sekali-render) jadi `ConsumerStatefulWidget` supaya bisa refresh daftar setelah archive.

**Verifikasi:**
- SQL langsung: archive listing dengan 1 recurring order aktif → **error** `"Listing masih terikat 1 recurring order aktif — pause/cancel dulu sebelum archive"`, status tidak berubah. Archive listing tanpa recurring aktif → sukses.
- Device UI: tap icon archive pada "Cabai Test Fulfillment" (listing yang recurring order-nya masih aktif dari test FG-38 di atas) → modal konfirmasi muncul → tap "Arsipkan" → `PostgrestException` tertangkap dengan benar, **tidak crash**, listing tetap menampilkan tombol edit+archive (status tidak berubah) — guard bekerja end-to-end dari UI sungguhan.

## FG-39 — My Recurring Orders + Detail UI

**File baru:** `lib/features/recurring_order/data/recurring_order_repository.dart`, `lib/features/recurring_order/screens/recurring_orders_screen.dart` (list), `lib/features/recurring_order/screens/recurring_order_detail_screen.dart` (detail). **Modified:** `app_router.dart` (+2 route: `/recurring-orders`, `/recurring-orders/:id`), kedua Profil screen (+icon entry point `autorenew` di AppBar).

Pola card+status-chip mengikuti `ChatInboxScreen`/`_InboxItem` persis; pola aksi+modal konfirmasi mengikuti `TransactionDetailScreen._confirmReject()`. Detail screen: `status == 'active'` → tombol Jeda+Batalkan; `paused` → Aktifkan Lagi+Batalkan; `cancelled` → **tidak ada tombol aksi sama sekali** (§6, tidak pernah kembali `active`).

**Bug ditemukan & diperbaiki saat QA device:** kartu recurring order awalnya menampilkan **nama diri sendiri**, bukan counterpart — logic `counterpartName` (disalin dari pola `ChatInboxScreen`) selalu memprioritaskan `farmerProfile['nama']` terlepas siapa yang sedang login, alih-alih membandingkan dengan user aktif. Login sebagai `farmer.test` menampilkan "Pak Tani Maju" (diri sendiri) alih-alih "Restoran Warung Kita" (buyer). **Fix:** bandingkan `order['farmer_id']` dengan `currentUserId` (di-pass dari parent state yang punya akses `ref`), pilih nama pihak lain secara eksplisit. Diverifikasi ulang di device setelah fix — kartu langsung menampilkan "Restoran Warung Kita" dengan benar.

**Catatan teknis kedua:** perbaikan bug di atas sempat menghasilkan 4 error analyzer (`non_bool_condition`, `missing_identifier`, dst) dari ternary multi-baris dengan null-aware chaining (`buyerProfile?['key']?.toString() ?? ''`) yang tampaknya membingungkan parser Dart meski secara sintaksis terlihat valid. Diselesaikan dengan memecah jadi variabel `buyerName`/`farmerName` terpisah sebelum ternary — selain memperbaiki analyzer, hasilnya juga lebih mudah dibaca.

**Verifikasi end-to-end di device (emulator Android, akun `farmer.test`):**
1. List "Recurring Order Saya" (entry point dari icon Profil) → menampilkan 2 card dengan counterpart benar ("Restoran Warung Kita"), status "Aktif", listing "Cabai Test Fulfillment", `next_order_date` benar.
2. Tap card → Detail screen render lengkap (status, petani, pembeli, kuantitas 9999, harga terkunci, frekuensi, order berikutnya).
3. Tap "Jeda" → modal "Jeda Recurring Order? Siklus berikutnya tidak akan dibuat sampai diaktifkan lagi." → confirm → status `paused`, tombol berubah jadi "Aktifkan Lagi"+"Batalkan".
4. Tap "Batalkan" → confirm → status `cancelled`, **halaman tanpa tombol aksi apapun**.

## FG-40 — CTA "Jadikan Recurring Order"

**File:** `lib/features/transaction/screens/transaction_detail_screen.dart` — tombol muncul untuk `role == 'buyer' && status == 'fulfilled'`, konsisten dengan pola guard yang sama seperti tombol farmer Sprint 8 (`role == 'farmer' && status == 'pending'`). Tap → bottom sheet (kuantitas prefilled dari `agreed_quantity`, dropdown frekuensi Mingguan/2 Mingguan/Bulanan) → `RecurringOrderRepository.create()` dengan `lockedPrice` dihitung dari `total_amount / agreed_quantity` transaksi yang baru di-fulfill (harga yang benar-benar disepakati, bukan harga listing saat ini yang mungkin sudah berubah) → sukses → auto-navigate ke `/recurring-orders/:id`.

**Verifikasi:** kode lolos `flutter analyze` (termasuk `DropdownButtonFormField.initialValue` — bukan `value`, SDK sudah cukup baru untuk API ini). Verifikasi UI end-to-end untuk CTA spesifik ini **tidak dilakukan langsung** — lihat catatan di bagian "Yang masih menggantung" di bawah; sebagai gantinya, `RecurringOrderRepository.create()` yang dipanggilnya sudah terverifikasi penuh lewat FG-39 (dipanggil endpoint yang sama, dari kode yang sama).

---

## Verifikasi menyeluruh

| Test | Hasil |
|---|---|
| `flutter analyze` (tiap task) | ✅ 0 issue setiap kali (1 kali sempat 4 error dari bug counterpart name, langsung diperbaiki) |
| `flutter test` | ✅ 26/26 pass, dijalankan ulang setelah bug fix |
| Migration schema `transactions` | ✅ `negotiation_id` nullable, `recurring_order_id` ada, terverifikasi query `information_schema.columns` |
| FG-38 stok cukup | ✅ transaksi baru, siklus maju |
| FG-38 stok kurang | ✅ skip, tetap active, siklus tetap maju |
| FG-60 guard (SQL langsung) | ✅ ditolak dengan recurring aktif, berhasil tanpa |
| FG-60 guard (device UI) | ✅ modal → error tertangkap → tidak crash → status tidak berubah |
| FG-39 list → detail → pause → resume-tersedia → cancel → dead-end | ✅ full cycle di device |
| FG-39 entry point dari Profil | ✅ icon muncul & berfungsi (buyer & farmer) |
| FG-40 kode | ✅ analyze bersih; UI end-to-end belum dites langsung (lihat di bawah) |

## File yang berubah (belum di-commit)

```
Modified:
  lib/core/router/app_router.dart                              (FG-39 routes)
  lib/features/listing/screens/my_listings_screen.dart          (FG-60 frontend)
  lib/features/profile/screens/buyer_profile_screen.dart        (FG-39 entry point)
  lib/features/profile/screens/farmer_profile_screen.dart       (FG-39 entry point)
  lib/features/transaction/screens/transaction_detail_screen.dart (FG-40)
  supabase/functions/_shared/inventory-locking.ts               (FG-38, +lockInventoryForRecurringCycle)
  supabase/functions/check-recurring-orders/index.ts            (FG-38, +triggerDueCycles)
  supabase/functions/recurring-orders/index.ts                  (refactor pakai shared FREQUENCY_DAYS)

Baru (belum di-track):
  docs/Sprint 9/sprint9_plan_lengkap.md
  lib/features/recurring_order/                                  (repository + 2 screen, FG-39)
  supabase/functions/_shared/frequency.ts
  supabase/migrations/20260718000000_transactions_recurring_order_link.sql   (Task 1, sudah di-apply production)
  supabase/migrations/20260718010000_guard_archive_listing_recurring.sql    (Task 4, sudah di-apply production)
```

Migration sudah diterapkan ke production lewat MCP `apply_migration` (dipilih user saat ditanya, sama seperti Sprint 8) — tapi file migration-nya sendiri, dan seluruh kode Flutter/Edge Function, **masih di working tree**, belum di-commit. Sesuai `docs/CLAUDE.md`, commit dilakukan manual oleh user.

## Data test yang tercipta selama QA (aman dihapus atau dipakai lagi)

| Entity | ID | Catatan |
|---|---|---|
| Negotiation | `8ecb1418-6d96-44b3-b2cd-8ab1b778827d` | Accepted, untuk skenario FG-40 |
| Transaksi | `271d5531-fdaa-41e5-a48a-05fc74de3278` | Status `fulfilled` (di-set manual via SQL untuk mempercepat setup FG-40) — kandidat data test FG-40 UI kalau mau dites lagi |
| Recurring order | `1eadb85a-a417-44c7-a912-826ddafc949d` | Status `active`, sudah pernah trigger sukses sekali (Task 3), `next_order_date` sudah maju ke 2026-07-24 |
| Recurring order | `a736a35b-93ce-4cf1-90c6-0c9417a577f5` | `quantity: 9999` (sengaja melebihi stok) → dites via UI (Jeda→Aktifkan tersirat via SQL→Batalkan), status akhir **`cancelled`** |
| Recurring order | `a1c1800c-7a75-4db1-a741-05e523ef8575` | Status `active`, dari verifikasi refactor Task 2, belum disentuh lagi |

## Yang masih menggantung

1. **FG-40 CTA belum dites end-to-end via UI langsung** (tap CTA → isi form → submit → auto-navigate) — terhambat karena tidak ada UI daftar riwayat transaksi untuk navigasi manual ke transaksi `fulfilled` tertentu (limitasi sudah dicatat sejak `sprint7_hasil_akhir.md`/`sprint8_hasil_akhir.md`). Cara tes: gunakan transaksi `271d5531...` di atas — perlu jalur manual (mis. `flutter run` + trigger accept baru via UI, lalu fulfill, baru CTA muncul di sesi yang sama) kalau mau verifikasi visual penuh.
2. **Push notification** (FG-41/42, Sprint 8) masih belum terkonfirmasi visual — sama seperti dicatat Sprint 8, plus sekarang ada push baru dari FG-38 (`"Recurring order dibuat"`/`"Siklus dilewati"`) yang juga belum dites visual dengan alasan sama (token FCM basi akibat reset app berulang).
3. **Bug navbar** yang dilaporkan sebelum Sprint 8 — masih belum berhasil direproduksi.
4. **`buyer_profiles`/`farmer_profiles` metrics belum reflect transaksi baru secara real-time** — masih belum dicek ulang untuk transaksi Sprint 8/9.
5. **Migration `listings.title`/`listings.unit`** — drift lama dari Sprint 6, masih belum direkonstruksi jadi file resmi (tercatat berulang sejak Sprint 6-8).
6. **Invariant `transactions.negotiation_id`/`recurring_order_id`** (tepat satu terisi) tidak di-enforce lewat `CHECK constraint` — sengaja, dicatat di migration Task 1. Kalau ada jalur insert baru ke `transactions` di sprint mendatang, pastikan tetap ikuti invariant ini secara manual.
7. **`TransactionRepository.getTransaction()`** query lewat `negotiations(...)` join — untuk transaksi hasil siklus recurring (`negotiation_id` NULL), field terkait (listing, farmer profile) akan `null` dan render sebagai `'-'` di Transaction Detail (tidak crash, tapi kurang informatif). Dicatat di plan sebagai potensi kerjaan lanjutan, belum dikonfirmasi apakah ini masalah nyata di praktik.

## Yang menyusul — Sprint 10

Berdasarkan `sprint9_README.md` dan catatan FG-60 ("tambahkan ke checklist verifikasi FG-48, Sprint 10"), Sprint 10 kemungkinan fokus ke **Integration & E2E Testing** (FG-44 E2E negotiation→transaction→trust_metrics, FG-45 E2E realtime chat, FG-46 E2E Buy Now + race condition, FG-48 verifikasi edge case §11 termasuk FG-60 yang baru selesai). Item "masih menggantung" di atas — terutama FG-40 UI belum dites dan push notification belum terkonfirmasi visual — jadi kandidat kuat untuk ditutup lebih dulu sebelum atau selama fase E2E testing itu.
