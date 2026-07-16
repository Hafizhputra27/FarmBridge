# Sprint 1 — Dokumentasi Nevan (FG-2 Migration SQL)

**Tanggal:** 16 Juli 2026  
**Status:** ✅ Selesai  
**Branch:** `nevan_dev`  
**Commit:** `[FG-2] Migration SQL 11 tabel + index`

---

## Ringkasan

Menulis migration SQL untuk 11 tabel database FarmBridge di Supabase project `rwxnjxmzkcfoddnzjosi`. Migration ini adalah fondasi seluruh project — semua fitur di Sprint 2+ bergantung ke skema ini.

---

## Hasil

### 11 Tabel Dibuat

| # | Tabel | Primary Key | Foreign Keys |
|---|-------|------------|--------------|
| 1 | `users` | `id` (uuid) | — |
| 2 | `farmer_profiles` | `id` (uuid) | `user_id` → `users(id)` UNIQUE |
| 3 | `buyer_profiles` | `id` (uuid) | `user_id` → `users(id)` UNIQUE |
| 4 | `listings` | `id` (uuid) | `farmer_id` → `users(id)` |
| 5 | `price_reference_data` | `id` (uuid) | — |
| 6 | `negotiations` | `id` (uuid) | `listing_id`, `buyer_id`, `farmer_id` |
| 7 | `negotiation_messages` | `id` (uuid) | `negotiation_id`, `sender_id` |
| 8 | `transactions` | `id` (uuid) | `negotiation_id`, `farmer_id`, `buyer_id` |
| 9 | `recurring_orders` | `id` (uuid) | `buyer_id`, `farmer_id`, `listing_id` |
| 10 | `trust_metrics` | `farmer_id` (uuid) | `farmer_id` → `users(id)` |
| 11 | `buyer_metrics` | `id` (uuid) | `buyer_id` → `buyer_profiles(id)` |

### 4 Index

- `idx_listings_status` ON `listings(status)`
- `idx_negotiations_status` ON `negotiations(status)`
- `idx_transactions_status` ON `transactions(status)`
- `idx_transactions_farmer_id` ON `transactions(farmer_id)`

### Poin Kritis Terverifikasi

- `users.email` **NULLABLE** ✅ — insert tanpa email sukses
- `buyer_metrics.buyer_id` FK → **`buyer_profiles`** (bukan `users`) ✅ — insert langsung ke user ID gagal
- `recurring_orders.status` DEFAULT `'active'` ✅
- `users.role` CHECK (`farmer`, `buyer`, `admin`) ✅
- `users.device_token` nullable ✅
- Semua FK ON DELETE CASCADE ✅

---

## Evidence

| Item | Hasil |
|---|---|
| Migration applied | `supabase_apply_migration` → success |
| 11 tabel di Table Editor | Verified via `supabase_list_tables` |
| FK constraint test | Insert invalid ID → error 23503 |
| Email nullable test | Insert tanpa email → sukses |
| File migration | `supabase/migrations/20260716080000_initial_schema.sql` |
| Commit | `44e57cc` on `nevan_dev` |

---

## Catatan

- **Supabase project:** `rwxnjxmzkcfoddnzjosi` (FarmBridge, ap-southeast-1)
- **RLS:** Belum dipasang — itu FG-3 di Sprint 2
- **Realtime:** Belum dikonfigurasi — itu FG-4 di Sprint 2
- **Seed data:** Belum ada — itu FG-7 oleh Hafizh di Sprint 3
- **`device_token`:** Sudah ada kolom nullable di `users`, siap untuk Hafizh (FG-6)
- **Tabel `price_reference_data`:** Sudah siap untuk Hafizh (FG-7, Sprint 3)
