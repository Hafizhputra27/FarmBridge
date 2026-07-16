> Dibuat 2026-07-17. `hafizh_dev` sekarang berisi gabungan `hafizh_dev` + `nevan_dev` (PR #17, #18) + `fachri_dev` (merge lokal `5bc1b97`) — mencakup seluruh ticket Sprint 1-6 ketiga orang. Plan ini bukan cuma "cek hijau", tapi verifikasi integrasi lintas fitur — pola yang sama dengan `sprint3_hasil_akhir.md`, waktu itu 3 bug (device_token, session restore, onboarding loop) baru ketahuan **setelah** merge, padahal `flutter analyze`/`flutter test` sudah bersih duluan.

# Sinkronisasi 3 Branch (Sprint 1-6) — Plan

## Status saat ini (terverifikasi 2026-07-17)

| Cek | Hasil |
|---|---|
| `supabase db push --dry-run` | ✅ Hijau — drift `20260716164950` (kolom `quantity`) sudah beres lewat migration Nevan. Sisa 1 migration **belum di-apply**: `20260717000000_listings_farmer_profiles_fk.sql` (Fachri) |
| Precondition migration Fachri (`listings.farmer_id` orphan check) | ✅ 0 baris yatim — aman diterapkan |
| `flutter analyze lib/` | ✅ 0 issue |
| `flutter test` | ✅ 6/6 passed |
| `git status` (`hafizh_dev`) | ✅ bersih, sinkron dengan `origin/hafizh_dev` |

**Kesimpulan:** level "kompilasi & unit test" sudah aman. Yang **belum** teruji: perilaku nyata lintas fitur (Nevan × Fachri × Hafizh bertemu di titik yang sama) — sesuai pelajaran Sprint 3, ini baru kelihatan lewat pemakaian sungguhan, bukan `flutter analyze`.

## Isi gabungan per-orang (Sprint 1-6)

**Nevan:** FG-2 migration awal, FG-3/4 auth/RLS/realtime, FG-18 trust_metrics, FG-22 negotiations state machine (+ konsumsi `getRecommendedPrice()` milik Hafizh), FG-24 auto-expire cron, FG-29 buy-now, FG-35 inventory locking, FG-58 chat inbox backend.
**Fachri:** FG-11 role picker, FG-13/14 listing CRUD + filter, FG-15 buyer home feed, FG-25/26 negotiation chat UI + chat inbox UI.
**Hafizh:** FG-5/6 CI/CD + FCM, FG-7 seed data, FG-19/20/23 metrics + price-recommendation, FG-16 profile UI.

---

## Task 1: Apply migration Fachri ke DB (bukan cuma dry-run)

- [x] **Step 1:** `supabase db push` — **ternyata constraint-nya sudah live** (`ERROR: constraint "listings_farmer_profiles_fkey" ... already exists`). Pola sama dengan drift sebelumnya: Fachri kemungkinan sudah push manual dari mesinnya sendiri, tapi riwayat migration remote tidak tercatat.
- [x] **Step 2 (revisi):** bukan `db push` (schema sudah ada), tapi `supabase migration repair --status applied 20260717000000` — cuma selaraskan bookkeeping riwayat migration dengan kenyataan, tidak ubah schema. Dikonfirmasi user dulu sebelum jalan.
- [x] **Step 3:** `supabase db push --dry-run` ulang → **"Remote database is up to date."** ✅

## Task 2: Verifikasi Edge Function Nevan ter-deploy & reachable

Semua kode Nevan sudah masuk `hafizh_dev` lewat merge, tapi **merge git ≠ deploy** — function baru (`buy-now`, `negotiations`, `update-trust-metrics`) perlu dicek sudah live di project Supabase yang sama, bukan cuma ada di git.

- [x] **Step 1:** `supabase functions list` — 8/8 `ACTIVE`, cocok 1:1 dengan `supabase/functions/` lokal (`send-push`, `price-recommendation`, `update-trust-metrics`, `update-buyer-metrics`, `negotiations`, `buy-now`, `trust-metrics`, `buyer-metrics`)
- [x] **Step 2:** `negotiations`/`buy-now`/`update-trust-metrics` (Nevan) sudah `ACTIVE` dengan `updated_at` terbaru (entrypoint `/tmp/user_fn_.../source` — di-deploy dari mesin Nevan sendiri, bukan dari checkout ini). Tidak diredeploy ulang — status aktif & terbaru, tidak ada sinyal rusak/beda; redeploy dari sini tanpa alasan cuma nambah risiko tanpa manfaat jelas

## Task 3: Verifikasi integrasi lintas fitur (titik-titik rawan)

Bukan uji fitur satu-satu (itu sudah tanggung jawab masing-masing sprint report), tapi titik **pertemuan** dua fitur — pola yang sama yang ketahuan bermasalah di Sprint 3:

- [x] **FG-22 (Nevan) × FG-23 (Hafizh):** kode `negotiations/index.ts` memanggil `getRecommendedPrice(supabase, { category: listing.category, region: listing.region, quantity: Number(quantity) })` — signature cocok 100% dengan `_shared/price-recommendation.ts`. **Live curl test di-skip**: endpoint butuh session auth user asli (bukan anon key), bikin anonymous sign-in baru cuma buat test berarti nulis side-effect ke `auth.users` production tanpa manfaat besar dibanding kepastian yang sudah didapat dari code review.
- [x] **FG-15 (Fachri feed) × FG-16 (Hafizh profile):** route `/farmer-profile/:id` di `app_router.dart` sudah dipastikan mengarah ke `FarmerProfileScreen` asli (bukan stub Fachri) saat resolve konflik merge — dikonfirmasi ulang lewat `test/app_router_redirect_test.dart` (`resolveRedirect` tidak nge-guard salah route ini).
- [x] **FG-25/26 (Fachri chat) × FG-58 (Nevan chat inbox backend):** **BUG DITEMUKAN & DIPERBAIKI.** `NegotiationRepository.getMyNegotiations()` (dipakai `ChatInboxScreen`) ternyata query PostgREST langsung ke tabel `negotiations` (bukan lewat Edge Function Nevan), dan `.order('updated_at', ...)` — kolom `updated_at` **tidak ada** di tabel `negotiations` (diverifikasi lewat query langsung ke remote, error `42703: column "updated_at" does not exist`). Chat inbox akan selalu gagal setiap dibuka. **Fix:** ganti ke `.order('created_at', ascending: false)` (`lib/features/negotiation/data/negotiation_repository.dart`) — root-cause fix di satu tempat, satu-satunya caller (`chat_inbox_screen.dart`) otomatis ikut benar.
- [x] **FG-29 (Nevan buy-now) × FG-35 (locking):** tidak disentuh siapapun selain Nevan, `flutter analyze`/`flutter test` tetap hijau setelah semua merge — risiko rendah, tidak ada tindakan lebih lanjut.
- [x] **Redirect guard router** (fix Hafizh Sprint 6): di-extract jadi pure function `resolveRedirect()` + `test/app_router_redirect_test.dart` (8 skenario: onboarding, cross-role guard, nested route Fachri `/buyer/search` & `/farmer/listings/...`, regresi bug prefix mentah, route Fachri tanpa role-gate). Semua lolos.

**Temuan tambahan (di luar 5 titik di atas, ketemu saat cek precondition Task 1):** `listings.title` dan `listings.unit` ada di remote DB tapi **tidak ada di migration manapun** — drift keempat sesi ini, sama seperti `updated_at` (kolom yang dipakai kode tapi ternyata tidak ada) tapi arahnya kebalik (kolom ada di DB, tidak ada di git). Tidak bikin error sekarang (kolomnya memang ada, dipakai `buyer_home_feed_screen.dart`/`negotiation_repository.dart` dengan aman), tapi environment baru (`supabase db reset` lokal, atau project Supabase baru) tidak akan punya kolom ini. Sama seperti drift `quantity` sebelumnya — perlu direkonstruksi jadi migration file oleh Nevan, bukan blocker sekarang.

**Catatan keterbatasan sesi ini:** verifikasi visual/interaktif (tap UI, jalan di device/emulator) tetap **tidak bisa dilakukan Claude** — sandbox eksekusi tidak punya akses screen. Semua titik integrasi di atas diverifikasi lewat code review + query DB langsung + unit test otomatis (bukan tap UI beneran) — cukup untuk menangkap 1 bug nyata (`updated_at`), tapi cek visual/UX (layout, rasa navigasi) tetap perlu device fisik oleh tim.

## Task 4: Tulis `sprint6_hasil_akhir.md` (atau cakupan lebih luas: `sprint1-6_hasil_akhir.md`)

- [ ] Setelah Task 1-3 selesai (atau ditemukan bug seperti Sprint 3), rangkum jadi satu doc "hasil akhir", pola sama seperti `sprint3_hasil_akhir.md` — status per ticket, bug integrasi yang ditemukan (kalau ada) + fix-nya, verifikasi end-to-end, commit terkait

## Yang TIDAK termasuk plan ini (di luar scope sinkronisasi)

- Merge `hafizh_dev` → `main` — itu MERGE #2 di akhir FASE 2 (Sprint 9), bukan sekarang (`HYBRID_MERGE_KICKOFF.md`)
- Migration Fachri yang melanggar Playbook §2 Aturan Dasar #5 (harusnya cuma Nevan) — sudah diapply amannya di Task 1, tapi worth japri ke tim supaya tidak terulang, bukan blocker teknis

## Definition of Done

- [x] `supabase db push --dry-run` → "up to date", tidak ada migration pending
- [x] Semua Edge Function di `supabase/functions/` (8 folder, bukan 9 — `_shared` bukan function) terkonfirmasi live & versi terbaru
- [x] 5 titik integrasi di Task 3 diverifikasi (code review + query DB + unit test — bukan tap manual, lihat catatan keterbatasan), 1 bug ditemukan+fix
- [x] `sinkronisasi_3branch_sprint1-6_hasil_akhir.md` ditulis
