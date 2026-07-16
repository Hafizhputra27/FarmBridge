# Sprint 2 — Dokumentasi Nevan (FG-3 Auth/RLS/Storage + FG-4 Realtime/pg_cron)

**Tanggal:** 16 Juli 2026  
**Status:** ✅ Selesai  
**Branch:** `nevan_dev`  
**Migration:** `20260716090000_rls_policies` + `20260716XXXXXX_realtime_storage_cron`

---

## Ringkasan

Sprint 2 membangun backbone keamanan (RLS) dan komunikasi realtime (WebSocket + cron) di atas 11 tabel dari Sprint 1. Nevan solo — Hafizh & Fachri menunggu ini selesai untuk Sprint 3.

---

## Hasil

### FG-3 — Auth / RLS / Storage

#### Anonymous Auth
- `config.toml`: `enable_anonymous_sign_ins = true`
- ⚠️ Perlu enable manual di Supabase Dashboard: **Authentication → Settings → Enable Anonymous Sign-ins**

#### RLS Policies (39 policies di 11 tabel)

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

\* Via subquery `buyer_profiles.user_id = auth.uid()`  
† Via subquery parent `negotiations`

#### Storage
- Bucket: `listing-photos` (public read)
- Upload: farmer role only (`users.role = 'farmer'`)
- Update/Delete: owner only

### FG-4 — Realtime & pg_cron

#### Realtime
- `negotiations` → REPLICA IDENTITY FULL + added to publication
- `negotiation_messages` → REPLICA IDENTITY FULL + added to publication

#### pg_cron
- Extension: `pg_cron` enabled
- Log table: `cron_execution_log` (job_name, status, message, executed_at)
- Job 1: `expire-negotiations` — setiap 5 menit (skeleton, logic di Sprint 6)
- Job 2: `check-recurring-orders` — setiap hari jam 08.00 (skeleton, logic di Sprint 8)

---

## Evidence

| Item | Hasil |
|---|---|
| RLS policies | 39 policies di `pg_policies` — verified |
| Storage bucket | `listing-photos` di `storage.buckets` — verified |
| pg_cron jobs | 2 jobs di `cron.job`, active — verified |
| Migration files | 2 SQL files di `supabase/migrations/` |

---

## Catatan untuk Sprint 3

- **Hafizh (FG-7):** Tabel `price_reference_data` sudah ada, RLS public read siap
- **Fachri (FG-11):** Anonymous Auth ready (setelah enable di dashboard), siap untuk `signInAnonymously()`
- **Realtime:** Sudah aktif — client tinggal subscribe channel `negotiations` & `negotiation_messages`
- **Cron logic:** Baru skeleton, implementasi sebenarnya di Sprint 6 (expire) dan Sprint 8 (recurring)
