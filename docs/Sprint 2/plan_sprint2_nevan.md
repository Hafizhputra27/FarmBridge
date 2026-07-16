# Plan Sprint 2 — Nevan (FG-3 Auth/RLS/Storage + FG-4 Realtime/pg_cron)

**Referensi:** PRD §7, §12, §13.1, §5.1, §6 | JIRA FG-3, FG-4 | `sprint2_nevan_dev.md`

---

## Fase 0 — Prasyarat
- [x] FG-2 migration (Sprint 1) ✅
- [x] Siapkan environment

## Fase 1 — FG-3: Auth + RLS + Storage

### 1A. Anonymous Auth
- [x] Edit `supabase/config.toml`: `enable_anonymous_sign_ins = true`

### 1B. RLS Migration (1 file: `20260716XXXXXX_rls_policies.sql`)

**Self-only:**
- [x] `users` — SELECT + INSERT + UPDATE + DELETE → `auth.uid() = id`

**Public read + self-write:**
- [x] `farmer_profiles` — SELECT `true`, INSERT/UPDATE/DELETE `auth.uid() = user_id`
- [x] `buyer_profiles` — SELECT `true`, INSERT/UPDATE/DELETE `auth.uid() = user_id`
- [x] `listings` — SELECT `true`, INSERT/UPDATE/DELETE `auth.uid() = farmer_id`

**Public read only:**
- [x] `trust_metrics` — SELECT `true`, INSERT/UPDATE/DELETE service_role
- [x] `price_reference_data` — SELECT `true`, INSERT/UPDATE/DELETE service_role

**Public read + self-write via subquery:**
- [x] `buyer_metrics` — SELECT `true`, INSERT/UPDATE/DELETE via `buyer_profiles.user_id = auth.uid()`

**Participant-only:**
- [x] `negotiations` — all via `auth.uid() IN (buyer_id, farmer_id)`
- [x] `transactions` — all via `auth.uid() IN (buyer_id, farmer_id)`
- [x] `recurring_orders` — all via `auth.uid() IN (buyer_id, farmer_id)`
- [x] `negotiation_messages` — SELECT/INSERT via subquery parent `negotiations`

### 1C. Storage
- [x] Bucket `listing-photos` — upload farmer only, SELECT public

## Fase 2 — FG-4: Realtime + pg_cron

### 2A. Realtime
- [x] `ALTER TABLE negotiations REPLICA IDENTITY FULL`
- [x] `ALTER TABLE negotiation_messages REPLICA IDENTITY FULL`
- [x] `ALTER PUBLICATION supabase_realtime ADD TABLE negotiations, negotiation_messages`

### 2B. pg_cron
- [x] `CREATE EXTENSION IF NOT EXISTS pg_cron`
- [x] Tabel log: `cron_execution_log`
- [x] Job 1: `expire-negotiations` — jadwal tiap 5 menit (skeleton, logic di Sprint 6)
- [x] Job 2: `check-recurring-orders` — jadwal harian jam 08.00 (skeleton, logic di Sprint 8)

## Fase 3 — Verifikasi
- [x] 39 RLS policies confirmed di pg_policies
- [x] Storage bucket listing-photos created (public)
- [x] 2 cron jobs registered (expire-negotiations + check-recurring-orders)
- [x] Realtime tables added (negotiations + negotiation_messages)

## Fase 4 — Update & Commit
- [x] Update `sprint2_nevan_dev.md` checklist → `[x]`
- [x] Commit & push → `nevan_dev` (user yang handle git)

## Fase 5 — Dokumentasi
- [x] Buat `dokumentasi_sprint2_nevan_dev.md`
