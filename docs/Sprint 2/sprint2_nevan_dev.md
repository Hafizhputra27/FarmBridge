> Direvisi 2026-07-14 — sinkron ulang dengan label JIRA (skema granular 13-sprint), menggantikan versi kompresi 6-sprint sebelumnya.

# Sprint 2: Auth, RLS & Realtime Backbone — Task Plan untuk Nevan

## Peran di sprint ini
**FG-3 (Setup Supabase Auth/RLS/Storage) dan FG-4 (Setup Realtime & pg_cron).** Dua ticket ini satu jalur sekuensial internal — RLS butuh skema final dari FG-2 (Sprint 1, sudah selesai), dan Realtime/pg_cron butuh tabel final dulu (kolom `expires_at`, `next_order_date`, dst sudah ada dari FG-2). Kamu solo lagi sprint ini — Hafizh dan Fachri sengaja tidak dikasih ticket supaya tidak ada yang menyentuh area RLS/Realtime yang sedang kamu bangun.

**Kenapa FG-3 sebelum FG-4**: RLS yang bolong baru ketahuan pas QA kalau tidak dites manual sejak awal — pasang dan uji dulu sebelum lanjut ke realtime & cron yang levelnya di atas itu.

## Urutan kerja yang disarankan
1. **FG-3 (Auth + RLS + Storage)** — begitu sprint mulai, langsung pasang RLS di atas tabel dari FG-2. Jangan ditunda ke akhir sprint.
2. **FG-4 (Realtime + pg_cron)** — begitu FG-3 solid, karena tidak ada yang bergantung ke ini di hari pertama Sprint 3.
3. Begitu keduanya selesai, **merge ke hafizh_dev** dan kabari Hafizh & Fachri — mereka berdua menunggu ini untuk mulai penuh FG-7 dan FG-11 di Sprint 3.

## Task Checklist

### FG-3 — Auth/RLS/Storage
- [x] Konfigurasi Supabase Anonymous Auth (`auth.signInAnonymously()`) sebagai mekanisme sesi satu-satunya — tidak ada email/password sama sekali
- [x] RLS: `farmer_profiles`, `buyer_profiles`, `listings`, `trust_metrics`, `buyer_metrics`, `price_reference_data` → **public read**, write terbatas ke pemilik (farmer/buyer terkait)
- [x] RLS: `negotiations`, `negotiation_messages`, `transactions`, `recurring_orders` → **participant-only** (`auth.uid() = buyer_id or auth.uid() = farmer_id`)
- [x] `users` → self read/write only
- [x] Storage bucket `listing-photos`, policy upload hanya oleh role `farmer` pemilik listing, read publik
- [x] Pastikan `service_role` key TIDAK PERNAH dipakai di client — hanya di Edge Functions

**Contoh pola RLS (pakai ulang untuk tabel sejenis)**:
```sql
-- Tabel profil/metrik: public read, write self-only
create policy "farmer_profiles_public_read" on farmer_profiles
  for select using (true);
create policy "farmer_profiles_self_write" on farmer_profiles
  for update using (auth.uid() = user_id);

-- Tabel transaksional: participant-only
create policy "negotiations_participant_only" on negotiations
  for select using (auth.uid() = buyer_id or auth.uid() = farmer_id);
```

### FG-4 — Realtime & pg_cron
- [x] `alter publication supabase_realtime add table negotiations, negotiation_messages;`
- [x] `create extension if not exists pg_cron;` — kerangka job saja, logic bisnis (auto-expire 6 jam FG-24 di Sprint 6, trigger H-1 recurring di sprint lanjutan) dikerjakan di ticket fitur masing-masing
- [x] Pastikan tiap eksekusi job pg_cron mencatat log terpisah yang bisa ditinjau (PRD §12 Observability)

## File/folder yang kamu sentuh
```
supabase config (auth settings, RLS policies)
supabase/storage (bucket listing-photos)
supabase/migrations/*.sql (tambahan kalau RLS butuh kolom baru)
```

## Sync point dengan teammate
- **Begitu FG-3 + FG-4 selesai**: merge ke `hafizh_dev`, kabari Hafizh & Fachri. Fachri butuh FG-3 (Auth) live untuk menyelesaikan FG-11 di Sprint 3; Hafizh butuh RLS aktif untuk uji akses `price_reference_data` di FG-7.

## Definition of Done
- [x] RLS teruji: buyer A tidak bisa akses `negotiations`/`transactions` milik buyer B — **cara cek**: login sebagai buyer A via Postman/curl dengan JWT-nya, `GET` row milik buyer B, harus dapat array kosong
- [x] RLS teruji: `trust_metrics`/`buyer_metrics`/`farmer_profiles`/`buyer_profiles` bisa dibaca lintas user (public read) tapi tidak bisa ditulis selain pemilik — **cara cek**: coba `PATCH` profil orang lain dari akun berbeda, harus ditolak
- [x] Upload foto ke `listing-photos` hanya berhasil dari role `farmer` — **cara cek**: coba upload dari akun `buyer`, harus ditolak
- [x] Pesan baru di `negotiation_messages` diterima via Realtime tanpa polling, < 2 detik (PRD §12 NFR) — **cara cek**: subscribe dari 2 client, insert row baru, ukur waktu event masuk
- [x] `pg_cron` extension aktif, tabel `cron.job` bisa didaftari — **cara cek**: `select * from cron.job;` tidak error

## Referensi PRD
§12 (NFR — Security/RLS, Observability), §13.1 (Auth tanpa login tradisional).
