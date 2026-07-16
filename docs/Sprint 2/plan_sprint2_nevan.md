# Plan Sprint 2 — Nevan (FG-3 Auth/RLS/Storage + FG-4 Realtime/pg_cron)

**Referensi:** PRD §7, §12, §13.1, §5.1, §6 | JIRA FG-3, FG-4 | `sprint2_nevan_dev.md`

---

## Fase 0 — Prasyarat
- [x] FG-2 migration (Sprint 1) ✅
- [ ] Siapkan environment

## Fase 1 — FG-3: Auth + RLS + Storage

### 1A. Anonymous Auth
- [ ] Edit `supabase/config.toml`: `enable_anonymous_sign_ins = true`

### 1B. RLS Migration (1 file: `20260716XXXXXX_rls_policies.sql`)

**Self-only:**
- [ ] `users` — SELECT + INSERT + UPDATE + DELETE → `auth.uid() = id`

**Public read + self-write:**
- [ ] `farmer_profiles` — SELECT `true`, INSERT/UPDATE/DELETE `auth.uid() = user_id`
- [ ] `buyer_profiles` — SELECT `true`, INSERT/UPDATE/DELETE `auth.uid() = user_id`
- [ ] `listings` — SELECT `true`, INSERT/UPDATE/DELETE `auth.uid() = farmer_id`

**Public read only:**
- [ ] `trust_metrics` — SELECT `true`, INSERT/UPDATE/DELETE service_role
- [ ] `price_reference_data` — SELECT `true`, INSERT/UPDATE/DELETE service_role

**Public read + self-write via subquery:**
- [ ] `buyer_metrics` — SELECT `true`, INSERT/UPDATE/DELETE via `buyer_profiles.user_id = auth.uid()`

**Participant-only:**
- [ ] `negotiations` — all via `auth.uid() IN (buyer_id, farmer_id)`
- [ ] `transactions` — all via `auth.uid() IN (buyer_id, farmer_id)`
- [ ] `recurring_orders` — all via `auth.uid() IN (buyer_id, farmer_id)`
- [ ] `negotiation_messages` — SELECT/INSERT via subquery parent `negotiations`

### 1C. Storage
- [ ] Bucket `listing-photos` — upload farmer only, SELECT public

## Fase 2 — FG-4: Realtime + pg_cron

### 2A. Realtime
- [ ] `ALTER TABLE negotiations REPLICA IDENTITY FULL`
- [ ] `ALTER TABLE negotiation_messages REPLICA IDENTITY FULL`
- [ ] `ALTER PUBLICATION supabase_realtime ADD TABLE negotiations, negotiation_messages`

### 2B. pg_cron
- [ ] `CREATE EXTENSION IF NOT EXISTS pg_cron`
- [ ] Tabel log: `cron_execution_log`
- [ ] Job 1: `expire-negotiations` — jadwal tiap 5 menit (skeleton, logic di Sprint 6)
- [ ] Job 2: `check-recurring-orders` — jadwal harian jam 08.00 (skeleton, logic di Sprint 8)

## Fase 3 — Verifikasi
- [x] 39 RLS policies confirmed di pg_policies
- [x] Storage bucket listing-photos created (public)
- [x] 2 cron jobs registered (expire-negotiations + check-recurring-orders)
- [x] Realtime tables added (negotiations + negotiation_messages)

## Fase 4 — Update & Commit
- [x] Update `sprint2_nevan_dev.md` checklist → `[x]`
- [ ] Commit & push → `nevan_dev` (user yang handle git)

## Fase 5 — Dokumentasi
- [x] Buat `dokumentasi_sprint2_nevan_dev.md`
