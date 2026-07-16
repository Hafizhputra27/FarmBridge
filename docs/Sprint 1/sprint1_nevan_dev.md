> Direvisi 2026-07-14 — sinkron ulang dengan label JIRA (skema granular 13-sprint), menggantikan versi kompresi 6-sprint sebelumnya.

# Sprint 1: Foundation Kickoff — Task Plan untuk Nevan

## Peran di sprint ini
**Satu ticket: FG-2 (Migration SQL 11 tabel + buyer_metrics + device_token).** Beda dari skema lama, sprint ini kamu tidak langsung merangkap Auth/RLS dan Realtime/pg_cron sekaligus — dua ticket itu (FG-3, FG-4) sekarang resmi jadi Sprint 2, supaya migration bisa selesai bersih dulu sebelum lapisan keamanan & realtime dibangun di atasnya. Tapi migration ini tetap ticket paling menentukan di seluruh project: semua orang (Hafizh, Fachri, dan seluruh Sprint 2+) menunggu skema ini final sebelum bisa mulai apapun yang menyentuh data.

**Kenapa migration ini tidak boleh buru-buru**: schema salah tipe/kurang kolom akan menular ke semua fitur di Sprint 2-13 tanpa ketahuan sampai mid-sprint. Jangan korbankan ketelitian demi cepat "selesai" — tidak ada ticket lain sprint ini yang bisa mulai penuh sebelum ini beres.

## Urutan kerja yang disarankan
1. **Koordinasi cepat dengan Hafizh SEBELUM menulis migration**: sepakati di mana `device_token` (FCM, FG-6 — juga Sprint 1) disimpan. Rekomendasi: kolom nullable langsung di `users`, supaya tidak perlu migration susulan.
2. Tulis migration lengkap 11 tabel + index + FK + default values.
3. Begitu migration siap (belum perlu full RLS — itu FG-3, Sprint 2), **share ke Hafizh** — dia butuh tabel `price_reference_data` untuk FG-7 (Sprint 3) dan keputusan kolom `device_token` final untuk FG-6 (sprint ini juga).

## Task Checklist

### FG-2 — Migration SQL 11 tabel (10 + buyer_metrics v6)
- [x] Migration SQL untuk `users`, `farmer_profiles`, `buyer_profiles`, `listings`, `price_reference_data`, `negotiations`, `negotiation_messages`, `transactions`, `recurring_orders`, `trust_metrics`, **`buyer_metrics`** (tabel baru v6)
- [x] `users.email` **NULLABLE** (revisi v5 — tidak ada form signup/login)
- [x] `users.device_token` nullable — hasil koordinasi dengan Hafizh (lihat poin 1 di atas)
- [x] Tipe data eksplisit, FK ke parent table, `NOT NULL` di kolom wajib, `DEFAULT` values
- [x] Index di `negotiations.status`, `transactions.status`, `transactions.farmer_id`, `listings.status`
- [x] `buyer_metrics`: `id` (PK uuid), `buyer_id` (FK → buyer_profiles), `total_procurement numeric(14,2)`, `active_orders_count int`, `fulfillment_rate numeric(5,2)`, `avg_monthly_volume numeric(12,2)`, `window_days int default 90`, `updated_at timestamptz`

**Detail teknis — kerangka kolom minimum** (boleh nambah kolom lain sesuai kebutuhan RLS/query di Sprint 2):
```
users(id uuid pk, email text unique null, role text check in ('farmer','buyer','admin'), device_token text null, created_at timestamptz default now())
farmer_profiles(id uuid pk, user_id uuid fk users, nama text, lokasi text, bio text, verified boolean default false)
buyer_profiles(id uuid pk, user_id uuid fk users, nama_institusi text)
listings(id uuid pk, farmer_id uuid fk users, category text, region text, harga_per_unit numeric, quantity_available numeric, status text default 'active', foto_url text)
price_reference_data(id uuid pk, category text, region text, avg_price numeric, min_price numeric, max_price numeric)
negotiations(id uuid pk, listing_id uuid fk, buyer_id uuid fk, farmer_id uuid fk, status text default 'open', initial_price numeric, current_offer_price numeric, counter_count int default 0, recommended_price numeric null, expires_at timestamptz)
negotiation_messages(id uuid pk, negotiation_id uuid fk, sender_id uuid fk, action_type text, message_text text null, offer_price numeric null, created_at timestamptz default now())
transactions(id uuid pk, negotiation_id uuid fk, farmer_id uuid fk, buyer_id uuid fk, status text default 'pending', agreed_quantity numeric, total_amount numeric, delivered_quantity numeric null, actual_delivery_date date null, promised_delivery_date date, anomaly_flag boolean default false)
recurring_orders(id uuid pk, buyer_id uuid fk, farmer_id uuid fk, listing_id uuid fk, quantity numeric, frequency text, locked_price numeric, status text default 'active', next_order_date date)
trust_metrics(farmer_id uuid pk fk, on_time_delivery_rate numeric, rejection_rate numeric, fulfillment_consistency numeric, total_transactions int, window_days int default 90, updated_at timestamptz)
buyer_metrics(id uuid pk, buyer_id uuid fk buyer_profiles, total_procurement numeric(14,2), active_orders_count int, fulfillment_rate numeric(5,2), avg_monthly_volume numeric(12,2), window_days int default 90, updated_at timestamptz)
```
Catatan: `recurring_orders.status default 'active'` (bukan `'created'` seperti draft lama) — PRD §6 bilang recurring order tidak pernah kembali ke status "created" setelah aktif, jadi default langsung `active` begitu dibuat lebih konsisten dengan state machine final.

## File/folder yang kamu sentuh
```
supabase/migrations/*.sql
```

## Sync point dengan teammate
- **Sebelum menulis migration**: konfirmasi ke Hafizh soal kolom `device_token` (lihat Urutan kerja poin 1).
- **Begitu FG-2 selesai**: share ke Hafizh untuk FG-6 (butuh kolom `device_token` final, sprint ini juga) dan beri tahu bahwa tabel `price_reference_data` sudah siap dipakai untuk FG-7 (Sprint 3).
- **Begitu FG-2 di-merge**: kabari Hafizh (integration branch owner) untuk lanjut ke Sprint 2 — FG-3 (Auth/RLS/Storage) dan FG-4 (Realtime & pg_cron) baru bisa mulai penuh setelah migration ini final.

## Potensi conflict & cara handle
- Hafizh (FG-6, device_token) berkepentingan langsung dengan struktur `users` table — hindari konflik dengan menyepakati skema `device_token` di awal (bukan setelah migration jalan).

## Definition of Done
- [x] `supabase db push` jalan tanpa error, 11 tabel sesuai ERD §8 + §2.4 (termasuk `buyer_metrics`) — **cara cek**: `supabase db diff` kosong setelah push, cocokkan tiap kolom ke ERD satu-satu di Table Editor
- [x] Kolom `device_token` di `users` sudah final & disepakati dengan Hafizh sebelum migration di-commit
- [x] Migration bisa di-rerun bersih di environment baru (`supabase db reset` lalu `db push` tanpa error)

## Referensi PRD
§2.3, §2.4, §7 (Tech Stack), §8 & §8.1 (ERD), §13.1 (Auth tanpa login tradisional, konteks device_token).
