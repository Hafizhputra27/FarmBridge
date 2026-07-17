> Ringkasan hasil akhir Sprint 7 — dibuat 2026-07-17, setelah sinkronisasi `hafizh_dev`/`nevan_dev`/`fachri_dev` selesai dan **verifikasi UI manual end-to-end di device fisik** (item yang masih menggantung di `sprint7_hafizh_dev_report.md` poin 5) akhirnya dikerjakan. Merangkum `sprint7_hafizh_dev_report.md`, `dokumentasi_sprint7_nevan_dev.md`, `sprint7_fachri_dev.md`, ditambah 6 bug baru yang ketemu *khusus* karena testing dilakukan lewat tap sungguhan di device + query database langsung, bukan cuma `flutter analyze`/`flutter test`. Dibuat sebelum plan Sprint 8 karena Sprint 8 (FG-34 Fulfillment Form) langsung bergantung ke alur accept-negosiasi yang di sini baru benar-benar jalan untuk pertama kali.

# Sprint 7: Buy Now UI & Fulfillment — Hasil Akhir

## Status: ✅ Selesai — scope asli + QA end-to-end + 6 bug produksi ditemukan & diperbaiki

| Ticket | Judul | PIC | Status |
|---|---|---|---|
| FG-27 | Tap nama → profil counterpart dari chat | Hafizh | ✅ |
| FG-30 | Buy Now UI di detail listing | Fachri (backup: Hafizh) | ✅ |
| FG-59 | Transaction Detail / Order Aktif screen | Fachri (backup: Hafizh) | ✅ |
| FG-32 | POST /transactions/:id/fulfill | Nevan | ✅ |
| FG-33 | POST /transactions/:id/reject | Hafizh | ✅ |

Detail per-ticket sudah lengkap di `sprint7_hafizh_dev_report.md` dan `dokumentasi_sprint7_nevan_dev.md` — tidak diulang di sini. Dokumen ini fokus ke **apa yang baru ketahuan setelah scope asli "selesai"**, persis pola Sprint 3 (`sprint3_hasil_akhir.md`): checklist per-fitur bisa ✅ dan lolos static check, tapi titik integrasi baru kelihatan pecah setelah dites tap-per-tap di device sungguhan.

---

## Kenapa dokumen ini ada: negosiasi tidak pernah benar-benar bisa "Diterima"

Testing visual dimulai dari hal sederhana — buka Home Feed, tap listing, coba alur Buy Now. Itu semua langsung jalan (lihat tabel verifikasi Buy Now di bawah). Tapi begitu masuk ke **Chat Inbox** dan buka salah satu negosiasi berstatus "Diterima", layarnya **kosong total** di bawah status bar — tidak ada pesan, tidak ada tombol, tidak ada cara maju ke transaksi. Menelusuri kenapa, ketemu rantai 5 bug terpisah yang saling menutupi satu sama lain — satu fix membuka bug berikutnya, sampai akhirnya seluruh alur *negosiasi → accept → transaksi* benar-benar tercipta dan bisa diverifikasi end-to-end untuk **pertama kalinya** di project ini.

### Bug 1 — `NegotiationRepository.sendMessage()` insert langsung ke tabel, skip Edge Function sama sekali

**File:** `lib/features/negotiation/data/negotiation_repository.dart:98-112` (sebelum fix)

`sendMessage()` (dipakai untuk kirim pesan, accept, decline, counter) melakukan `_client.from('negotiation_messages').insert({...})` langsung ke tabel via REST — bukan memanggil Edge Function `negotiations/:id/messages` seperti seharusnya (pola yang sama seperti `BuyNowRepository.buyNow()` yang sudah benar). Akibatnya **seluruh logic di `supabase/functions/negotiations/index.ts` ter-skip total**: validasi "hanya pihak penerima yang boleh aksi", guard "negosiasi sudah selesai tidak boleh diapa-apakan lagi", dan yang paling parah — **pembuatan `transactions` lewat `lockInventoryOnAcceptWithQuantity` tidak pernah terpanggil**. Status "Diterima" yang tampil di UI cuma tebakan client-side dari jenis pesan terakhir (`_subscribeRealtime()`), bukan dari kolom `negotiations.status` yang sungguhan berubah.

**Fix:** `sendMessage()` diganti jadi `_client.functions.invoke('negotiations/$negotiationId/messages', ...)`, return `Future<Map<String, dynamic>>` berisi response Edge Function.

### Bug 2 — `_onAccept()` tidak kirim `offer_price` dan tidak navigate setelah sukses

**File:** `lib/features/negotiation/screens/negotiation_chat_screen.dart:135-151` (sebelum fix)

Edge Function mewajibkan `offer_price` untuk `action_type: accept`/`counter` — tapi `_onAccept()` tidak pernah mengirimkannya. Ini lolos diam-diam selama ini karena Bug 1 (insert langsung, tanpa validasi apapun). Begitu Bug 1 diperbaiki, `_onAccept()` akan mulai gagal 400 kalau tidak ikut diperbaiki. Juga: tidak ada kode yang membaca `transaction_id` dari response dan mengarahkan buyer ke Transaction Detail — bahkan seandainya transaksi berhasil dibuat, buyer tetap tidak tahu ke mana harus pergi.

**Fix:** kirim `offerPrice: (_negotiation?['current_offer_price'] as num?)?.toDouble()`, dan kalau response berisi `transaction_id`, `context.push('/transaksi/$transactionId')` — pola push yang sama seperti alur Buy Now.

### Bug 3 — Chat kosong total kalau `_messages` kosong dan status sudah final

**File:** `lib/features/negotiation/screens/negotiation_chat_screen.dart:296-326` (sebelum fix)

Untuk status `accepted`/`declined`/`expired`, kotak input pesan disembunyikan (baris kondisi `status != 'accepted' && ...`) dan `NegotiationActions` juga return `SizedBox.shrink()` untuk status non-`open`/`countered`. Kalau `_messages` juga kosong (mis. negosiasi baru dibuat lewat `POST /negotiations` — belum ada pesan sama sekali di titik itu, cuma `initial_price` yang tersimpan di kolom negosiasi, bukan sebagai baris pesan), `ListView.builder` dengan `itemCount: 0` merender kosong sempurna — inilah yang terlihat sebagai "layar blank" di screenshot awal.

**Fix:** tambah cabang `_messages.isEmpty ? Center(child: Text('Belum ada pesan')) : ListView.builder(...)`.

### Bug 4 — `POST /negotiations` (bikin negosiasi baru) selalu `405 Method not allowed`

**File:** `supabase/functions/negotiations/index.ts:134-160` (sebelum fix)

Ditemukan **tidak sengaja** saat mencoba membuat data test untuk QA Bug 1-3 — tidak ada satupun negosiasi berstatus `open` tersisa di database (semua 4 yang ada sudah `accepted` dari testing lama), dan tidak ada tombol "mulai negosiasi" di UI manapun untuk bikin yang baru. `curl -X POST .../negotiations` langsung balas `Method not allowed`. Root cause: `parsePath("/negotiations")` selalu menghasilkan `{action: "list"}` untuk path tanpa ID, **terlepas dari HTTP method**-nya. Router mengecek `action === "list"` (baris 135, wajib GET) **sebelum** mengecek `pathname === "/negotiations"` (baris 156, wajib POST) — jadi setiap `POST /negotiations` ke-405 duluan di blok "list", `handleCreate` jadi dead code yang tidak pernah tereksekusi sejak function ini ditulis. Ini juga menjelaskan kenapa tidak ada satupun jalur "mulai nego" pernah dibangun di Flutter — fitur itu memang tidak pernah bisa dites bahkan lewat curl sekalipun.

**Fix:** cek `pathname === "/negotiations" && method === "POST"` dipindah ke paling atas, sebelum blok `action === "list"`.

### Bug 5 — `promised_delivery_date` selalu `NULL`, bikin *setiap* accept gagal buat transaksi

**File:** `supabase/functions/_shared/inventory-locking.ts:70-84` (sebelum fix)

Setelah Bug 1-4 diperbaiki dan di-deploy, tombol "Terima" akhirnya benar-benar memanggil Edge Function dengan benar (error mulai muncul jelas lewat snackbar, bukan gagal diam-diam) — tapi accept **masih gagal**, kali ini dengan pesan jelas: `null value in column "promised_delivery_date" of relation "transactions" violates not-null constraint`. Kolom ini `date NOT NULL` tanpa default (`supabase/migrations/20260716083135_initial_schema.sql:109`), tapi `lockInventoryOnAcceptWithQuantity` — satu-satunya jalur pembuatan transaksi dari alur negosiasi — hardcode `promised_delivery_date: null`. Ini bug lama, ada sejak file `_shared/inventory-locking.ts` pertama ditulis, dan **menjelaskan kenapa tidak pernah ada satupun transaksi berhasil tercipta dari negosiasi manapun sejak fitur ini ada** — termasuk 4 negosiasi lama yang "Diterima" di database, yang ternyata semuanya tanpa transaksi (dikonfirmasi lewat query SQL langsung).

Konvensi yang benar sudah ada di file lain: `supabase/functions/buy-now/index.ts:11,15` menghitung `promised_delivery_date` sebagai **H+7 dari tanggal transaksi dibuat** — jalur Buy Now langsung (FG-29) punya `lockInventory` sendiri yang terpisah dan tidak kena bug ini.

**Fix:** `_shared/inventory-locking.ts` dibuat konsisten dengan `buy-now/index.ts` — `promised_delivery_date` diisi H+7.

---

## Verifikasi end-to-end (Android fisik, Infinix X6885, 2026-07-17)

| Test | Hasil |
|---|---|
| `flutter analyze` | ✅ 0 issue |
| `flutter test` | ✅ 26/26 passed |
| Home Feed → Detail Listing → Buy Now bottom sheet | ✅ render benar (tidak sampai submit — mutasi data nyata, sengaja dihindari saat baru visual check) |
| `POST /negotiations` (curl, setelah fix Bug 4) | ✅ 200, `negotiation_id` + status `open` (sebelumnya 405) |
| Negosiasi kosong pesan → tampilan chat | ✅ empty-state "Belum ada pesan", bukan blank total (setelah fix Bug 3) |
| Buyer coba accept negosiasi yang dia buat sendiri (bukan penerima) | ✅ ditolak backend — "Hanya pihak penerima yang bisa melakukan aksi ini" (validasi Bug 1 sekarang benar-benar jalan) |
| Farmer counter via API → buyer jadi penerima → buyer tap **Terima** di app (UI asli) | ✅ tanpa error, app auto-navigate ke `/transaksi/:id` |
| Transaction Detail setelah accept | ✅ status `pending`, jumlah & total benar, estimasi kirim H+7, tombol "Tolak Transaksi" muncul (role buyer + status pending) |
| `transactions` row setelah accept (query SQL) | ✅ 1 row baru, `promised_delivery_date` terisi (setelah fix Bug 5; sebelumnya error NOT NULL) |
| `listings.quantity_available` setelah accept | ✅ berkurang sesuai kuantitas negosiasi (115 → 113 untuk test pertama, dst) |
| Chat Inbox — negosiasi yang sudah accepted | ✅ badge "Diterima" konsisten dengan `negotiations.status` sungguhan di DB |

## File yang berubah (belum di-commit — sesuai `docs/CLAUDE.md`)

Repo ini melarang Claude menjalankan `git add`/`commit`/`push` — semua perubahan di bawah masih di working tree, menunggu di-commit manual:

```
lib/features/negotiation/data/negotiation_repository.dart      — Bug 1
lib/features/negotiation/screens/negotiation_chat_screen.dart  — Bug 2 + Bug 3
supabase/functions/negotiations/index.ts                       — Bug 4 (sudah di-deploy manual ke Supabase)
supabase/functions/_shared/inventory-locking.ts                — Bug 5 (sudah di-deploy manual ke Supabase)
analysis_options.yaml                                           — exclude build/** dari analyzer (noise 85 error dari source vendor firebase_messaging, bukan kode sendiri)
```

Draft pesan commit per-file (5 commit terpisah, siap pakai) ada di riwayat percakapan sesi ini — belum dituliskan ulang di sini karena berpotensi basi kalau di-commit dengan urutan berbeda. Plan lengkap tugas-per-tugas: `docs/superpowers/plans/2026-07-17-fix-negotiation-accept-flow.md`.

## Status Definition of Done

**FG-27, FG-30, FG-32, FG-33, FG-59:** ✅ semua sesuai `sprint7_hafizh_dev_report.md`/`dokumentasi_sprint7_nevan_dev.md`.
**Verifikasi UI manual end-to-end di device** (item terbuka sebelumnya): ✅ selesai — sekaligus jadi alasan 5 bug integrasi di atas ketahuan.

---

## Yang masih menggantung

1. **Migration `listings.title`/`listings.unit`** — drift lama dari Sprint 6, masih belum direkonstruksi jadi file migration resmi (sudah 2 sprint tercatat, belum hilang dari radar).
2. **Bug navbar dilaporkan user** ("klik navbar lain masih stay di Home") — **tidak berhasil direproduksi** setelah testing menyeluruh: buyer (Home→Search→Percakapan→Profil) dan farmer (Listing Saya→Percakapan), dari berbagai state, semua tab berpindah normal di build saat ini. Kemungkinan besar observasi di build/sesi lama sebelum sinkronisasi, atau state device tertentu yang belum kejelasan skenarionya — **butuh detail repro lebih spesifik** (role, tab, layar asal) sebelum ditelusuri lagi. Tidak ada perubahan kode dilakukan untuk ini.
3. **`buyer_profiles`/`farmer_profiles` metrics ("Belum ada riwayat transaksi") belum reflect transaksi baru** — di `Profil` tab buyer, walau 2 transaksi baru sudah tercipta (dikonfirmasi lewat SQL langsung), layar profil masih menampilkan "Belum ada riwayat transaksi". `buyer_profile_screen.dart` membaca dari `buyerMetricsProvider` (edge function `buyer-metrics`, FG-19/FG-20) yang kemungkinan berupa data teragregasi/cache, bukan live query ke `transactions` — **belum dikonfirmasi apakah ini butuh trigger recompute manual atau memang by-design delay**. Dicatat sebagai observasi, bukan bug terverifikasi (di luar scope investigasi hari ini).
4. **Kesesuaian visual Figma** untuk `ListingDetailScreen`/`TransactionDetailScreen` — masih belum direview terhadap frame desain asli (sama seperti dicatat di laporan sebelumnya).
5. **3 negosiasi duplikat "Diterima"** untuk listing "Cabai Merah Keriting" (ditemukan saat visual testing awal) — dikonfirmasi bukan bug kode (tidak ada jalur pembuatan negosiasi manapun di client sebelum Bug 4 diperbaiki), murni data seed/manual-test dari sprint-sprint backend sebelumnya. Aman dibersihkan manual lewat Supabase dashboard kalau mengganggu demo, tidak wajib.
6. **Guard 403** (`transactions-reject`, bukan buyer terkait) — masih belum dites eksplisit (butuh transaksi milik user lain, di-block classifier karena mutasi data orang lain tanpa izin eksplisit). Logic straightforward, risiko rendah — dicatat ulang dari laporan sebelumnya.

## Yang menyusul — Sprint 8

Dengan alur accept-negosiasi sekarang benar-benar membuat transaksi (baru pertama kali di project ini), Sprint 8 (FG-34 Fulfillment Form UI + modal, FG-37 recurring-orders, FG-41/42 FCM wiring) punya fondasi data nyata untuk dites — sebelumnya "Tandai Terkirim" di Transaction Detail cuma stub `SnackBar` karena memang belum ada transaksi `pending` yang bisa benar-benar di-fulfill. Rekomendasi sebelum mulai FG-34: pastikan transaksi test (`f0f5e27a...`, `29634bd7`→transaksi terkait) dari sesi ini dipakai sebagai data uji Fulfillment Form, alih-alih bikin negosiasi baru dari nol setiap kali.
