> Ringkasan hasil akhir Sprint 2 — dibuat 2026-07-16, setelah `nevan_dev` (FG-3 + FG-4) merge ke `hafizh_dev` lalu `main`. Merangkum `dokumentasi_sprint2_nevan_dev.md` + verifikasi tambahan yang dilakukan saat proses merge.

# Sprint 2: Auth, RLS & Realtime Backbone — Hasil Akhir

## Status: ✅ Selesai & merge ke `main`

Sprint ini murni satu tangan (Nevan) — FG-3 dan FG-4 sekuensial internal, sengaja tidak dipecah ke Hafizh/Fachri untuk menghindari konflik di area yang sama. Hafizh & Fachri tidak punya ticket formal (lihat "Prep opsional" di bawah).

| Ticket | PIC | Status |
|---|---|---|
| FG-3 — Setup Supabase Auth/RLS/Storage | Nevan | ✅ |
| FG-4 — Setup Realtime & pg_cron | Nevan | ✅ |

---

## FG-3 — Auth / RLS / Storage

**Anonymous Auth:** `enable_anonymous_sign_ins = true` di `config.toml` — sesuai PRD §13.1, tidak ada email/password sama sekali, sesi dibuat via `auth.signInAnonymously()` saat role dipilih di landing screen.

**RLS — 39 policy di 11 tabel** (terverifikasi live: `select count(*) from pg_policies where schemaname = 'public'` → **39**):

| Tabel | SELECT | INSERT | UPDATE | DELETE |
|---|---|---|---|---|
| `users` | self | — | self | self |
| `farmer_profiles` | public | self | self | self |
| `buyer_profiles` | public | self | self | self |
| `listings` | public | self | self | self |
| `trust_metrics` | public | self | self | — |
| `price_reference_data` | public | — | — | — |
| `buyer_metrics` | public | self* | self* | self* |
| `negotiations` | participant | buyer | participant | participant |
| `transactions` | participant | participant | participant | participant |
| `recurring_orders` | participant | participant | participant | participant |
| `negotiation_messages` | participant† | sender† | sender | sender |

\* via subquery `buyer_profiles.user_id = auth.uid()` — † via subquery parent `negotiations`

**Storage:** bucket `listing-photos` (public read via `storage.buckets.public = true`), 4 RLS policy di `storage.objects`: public read, insert khusus role `farmer`, update/delete khusus `owner`.

## FG-4 — Realtime & pg_cron

- **Realtime:** `negotiations` dan `negotiation_messages` ditambahkan ke publication `supabase_realtime` — client tinggal subscribe channel, tidak perlu polling
- **pg_cron** (extension `pg_cron` v1.6.4 aktif): tabel `cron_execution_log` untuk audit trail, 2 job terjadwal:
  - `expire-negotiations` — tiap 5 menit, masih skeleton (`status: 'skipped'`), logic asli di Sprint 6 (FG-24)
  - `check-recurring-orders` — tiap hari jam 08:00, masih skeleton, logic asli di Sprint 8

---

## Catatan proses: migration sempat tidak ter-commit ke git

Saat integrasi ke `hafizh_dev`, ditemukan migration FG-3/FG-4 yang **sudah aktif di database production** (RLS 39 policy, storage bucket, realtime publication, 2 pg_cron job — `cron_execution_log` bahkan sudah punya baris log dari eksekusi berjalan) tapi **belum pernah ter-commit ke git** sama sekali di bawah nama file yang sesuai riwayat migration Supabase.

Root cause: migration di-push ke remote dengan timestamp file berbeda dari yang akhirnya di-commit ke `nevan_dev`. Diperbaiki dengan:
1. Rename 2 file migration lokal supaya timestamp cocok dengan riwayat `supabase migration list` di remote
2. Rekonstruksi 1 migration yang hilang total (`20260716092216_realtime_storage_cron.sql`) langsung dari introspeksi SQL live database (`cron.job`, `storage.buckets`, `pg_publication_tables`, `pg_policies`) — bukan tebakan, tapi dibaca persis dari state yang sudah berjalan
3. Verifikasi akhir: `supabase db push --dry-run` → `Remote database is up to date`, dan run CI sungguhan di `main` juga hijau

Pelajaran untuk sprint berikutnya: **selalu commit migration file segera setelah `db push`, dengan nama file yang sama persis** — jangan reorganisir/rename file migration setelah sudah di-push ke remote, karena riwayat migration Supabase mengikat by filename timestamp, bukan isi SQL-nya.

---

## Definition of Done — status akhir

| Item | Status |
|---|---|
| RLS: buyer A tidak bisa akses `negotiations`/`transactions` milik buyer B | ✅ (per dokumentasi Nevan) |
| RLS: profil (`trust_metrics`/`buyer_metrics`/`farmer_profiles`/`buyer_profiles`) public read, write self-only | ✅ |
| Upload `listing-photos` hanya berhasil dari role `farmer` | ✅ |
| Realtime `negotiation_messages` < 2 detik tanpa polling | ✅ (per dokumentasi Nevan — publication aktif) |
| `pg_cron` aktif, `cron.job` bisa didaftari | ✅ — 2 job aktif, terverifikasi live |

## Prep opsional Hafizh & Fachri (bukan ticket formal)

- **Hafizh:** draft dataset seed FG-7 (kategori × region produk pertanian) — status belum dikonfirmasi dikerjakan
- **Fachri:** tuntaskan open question 3 varian "Create Listing" di Figma — status belum dikonfirmasi dikerjakan

## Yang menyusul di Sprint 3

- FG-7 (Hafizh): seed `price_reference_data`, tabel & RLS public-read sudah siap dipakai
- FG-11 (Fachri): role picker penuh + `signInAnonymously()` sungguhan — Anonymous Auth sudah live, tinggal wiring
- Verifikasi manual RLS lintas-akun oleh Hafizh (disarankan, bukan wajib) belum dikonfirmasi dilakukan
