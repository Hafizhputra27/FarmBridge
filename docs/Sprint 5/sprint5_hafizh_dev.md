> Direvisi 2026-07-14 — sinkron ulang dengan label JIRA (skema granular 13-sprint), menggantikan versi kompresi 6-sprint sebelumnya.

# Sprint 5: Home Feed, Metrics Endpoints & Negotiation Core — Task Plan untuk Hafizh

## Peran di sprint ini
**Satu ticket: FG-20 (GET /trust-metrics/:id + GET /buyer-metrics/:id).** Sprint yang lebih ringan setelah 2 ticket di Sprint 4 (FG-19, FG-23). Kedua dependency-nya (FG-18 Nevan, FG-19 kamu sendiri) sudah selesai penuh di Sprint 4 — tidak ada lagi yang perlu ditunggu, tinggal build endpoint-nya.

## Task Checklist

### FG-20 — GET /trust-metrics/:id + GET /buyer-metrics/:id
- [x] `GET /trust-metrics/:farmer_id` → `{ on_time_delivery_rate, rejection_rate, fulfillment_consistency, total_transactions, window_days }`; 404 jika farmer_id tidak ditemukan — diverifikasi 3 skenario (data ada, 404, 0/null); bug ID-space (`:farmer_id` = `users.id`, bukan `farmer_profiles.id`) ditemukan & diperbaiki saat testing
- [x] `GET /buyer-metrics/:buyer_id` → `{ total_procurement, active_orders_count, fulfillment_rate, avg_monthly_volume, window_days }`; 404 jika buyer_profiles tidak ditemukan; field 0/null jika belum ada transaksi (bukan error) — diverifikasi 2 skenario (404, 0/null)

## File/folder yang kamu sentuh
```
supabase/functions/trust-metrics/**
supabase/functions/buyer-metrics/**
```

## Sync point dengan teammate
- Tidak ada dependency masuk sprint ini — FG-18 & FG-19 sudah selesai dari Sprint 4.
- **Begitu FG-20 selesai**: kabari diri-sendiri untuk Sprint 6 (FG-16, Profile UI) — endpoint ini yang akan dikonsumsi di sana.

## Waktu longgar — opsional
Kalau FG-20 selesai lebih cepat, mulai baca ulang desain Farmer/Buyer Public Profile (Figma) dan siapkan wireframe kasar untuk FG-16 (Sprint 6) — supaya begitu sprint depan mulai kamu tinggal eksekusi.

## Definition of Done
- [x] `GET /trust-metrics/:id` & `GET /buyer-metrics/:id` mengembalikan response sesuai skema, 404 untuk id tidak ditemukan — **cara cek**: test request/response lewat curl untuk kedua endpoint — dilakukan, semua skenario cocok
- [x] Farmer/buyer tanpa transaksi apapun → field 0/null, bukan error — diverifikasi via curl langsung

## Referensi PRD
§2.3, §2.4, §9, §12 (Data Integrity).
