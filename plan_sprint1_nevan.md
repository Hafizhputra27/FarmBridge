# Plan Sprint 1 — Nevan (FG-2 Migration SQL)

**Referensi:** PRD §8, §8.1, §2.4 | JIRA FG-2 | `sprint1_nevan_dev.md`

---

## Fase 0 — Setup
- [x] `supabase init`
- [x] `supabase link --project-ref rwxnjxmzkcfoddnzjosi`

## Fase 1 — Migration SQL

File: `supabase/migrations/<timestamp>_initial_schema.sql`

11 tabel dengan FK + index, urutan sesuai dependency:

| # | Tabel | FK Ke |
|---|-------|-------|
| 1 | `users` | - |
| 2 | `farmer_profiles` | users(id) |
| 3 | `buyer_profiles` | users(id) |
| 4 | `listings` | users(id) |
| 5 | `price_reference_data` | - |
| 6 | `negotiations` | listings(id), users(id) x2 |
| 7 | `negotiation_messages` | negotiations(id), users(id) |
| 8 | `transactions` | negotiations(id), users(id) x2 |
| 9 | `recurring_orders` | users(id) x2, listings(id) |
| 10 | `trust_metrics` | users(id) |
| 11 | `buyer_metrics` | buyer_profiles(id) |

### Poin Kritis:
- `users.email` **NULLABLE**
- `buyer_metrics.buyer_id` FK → **buyer_profiles** (bukan users!)
- `recurring_orders.status` DEFAULT **'active'**
- Index: `negotiations.status`, `transactions.status`, `transactions.farmer_id`, `listings.status`

## Fase 2 — Push & Verifikasi
- [x] Migration applied via MCP — 11 tabel + 4 index confirmed di Table Editor
- [x] Test FK constraint → gagal insert invalid ID (sesuai AC)
- [x] Test email nullable → sukses insert tanpa email (sesuai AC)

## Fase 3 — Update & Commit
- [x] Update `sprint1_nevan_dev.md` checklist → `[x]`
- [ ] Commit: `[FG-2] Migration SQL 11 tabel + index`
- [ ] Push → `nevan_dev`

## Fase 4 — Dokumentasi
- [ ] Buat `docs/Sprint 1/sprint1_nevan_docs.md`
