# FarmBridge — Sprint Roadmap & Tema (GarudaHacks 7.0, 30 jam)

Tema tiap sprint = **halaman/fitur** yang dibangun. Sudah diterapkan ke JIRA sebagai **label `theme-*` per issue** (non-destruktif, label `sprint-N` & `pic-*` lama tetap ada) dan diperkuat **dependency links** antar-tiket.
Tim: Hafizh (integration owner + backend/PM), Nevan (backend infra/DB/state machine), Fachri (Flutter frontend), Alexander (desain Figma).

---

## Peta Tema (label JIRA)

| Label tema | Halaman/Fitur | Epic |
|---|---|---|
| `theme-foundation` | Setup DB, RLS, Realtime/cron, CI/CD, FCM, Flutter scaffold, seed | E1 |
| `theme-onboarding` | Landing / Role Picker, isi nama | E2 |
| `theme-listing` | Create/Edit Listing, Home Feed, Search & Filter | E3 |
| `theme-profile-metrics` | Farmer/Buyer Public Profile, Trust Score & Buyer Metrics | E4 (+E3 UI) |
| `theme-chat-negotiation` | Negotiation/Chat, Chat Inbox, price recommendation | E5 |
| `theme-buynow` | Buy Now, Detail Listing, Transaction Detail/Order Aktif | E6 |
| `theme-fulfillment` | Fulfillment Form + modal, reject, inventory locking | E7 |
| `theme-recurring` | My Recurring Orders + Detail, cron H-1, archive guard | E8 |
| `theme-notifications` | FCM push wiring | E9 |
| `theme-qa-demo` | E2E test, edge case, UI polish, verifikasi AC, demo | E10 |

---

## Roadmap per Sprint (13 sprint)

### FASE 1 — FONDASI (Sprint 1–3)

**Sprint 1 — Fondasi & Blocker Desain** · semua PIC paralel dari T+0
Halaman/output: infra + 2 desain kunci.

- FG-2 Migration SQL 10+buyer_metrics — Nevan
- FG-5 CI/CD Pipeline — Hafizh
- FG-6 FCM setup — Hafizh
- FG-57 Flutter init (scaffold, GoRouter, deps) — Fachri
- FG-9 ⛔ Desain Role Picker — Alexander *(BLOCKER)*
- FG-10 ⛔ Desain Chat Inbox — Alexander *(BLOCKER)*

**Sprint 2 — Backend Core** (infra lanjutan)
- FG-3 Auth/RLS/Storage — Nevan
- FG-4 Realtime & pg_cron — Nevan

**Sprint 3 — Onboarding / Role Picker**
Halaman: Landing → Role Picker → Isi Nama.
- FG-7 Seed price_reference_data — Hafizh
- FG-11 Build Role Picker flow (Flutter) — Fachri  *(blocked by FG-9, FG-57)*

### FASE 2 — FITUR INTI (Sprint 4–9)

**Sprint 4 — Listing & Metrics Engine**
Halaman: Create/Edit Listing, Buyer Home Feed, Search & Filter.
- FG-13 Listing filter endpoint — Fachri  *(blocked by FG-2)*
- FG-14 Create/Edit Listing UI + upload foto — Fachri  *(blocked by FG-13)*
- FG-15 Buyer Home Feed + Search & Filter — Fachri  *(blocked by FG-13)*
- FG-18 Edge Function trust_metrics — Nevan  *(blocked by FG-2)*
- FG-19 Edge Function buyer_metrics — Hafizh
- FG-23 POST /price-recommendation — Hafizh

**Sprint 5 — Profile + Negotiation Backend**
Halaman: Farmer/Buyer Public Profile.
- FG-16 Public Profile UI (Trust Score & Buyer Metrics) — Hafizh  *(blocked by FG-20)*
- FG-20 GET /trust-metrics + /buyer-metrics — Hafizh
- FG-22 POST /negotiations + state machine — Nevan  *(blocked by FG-2)*
- FG-35 Inventory locking atomik — Nevan
- FG-58 GET /negotiations (chat inbox endpoint) — Nevan

**Sprint 6 — Chat/Negotiation UI + Buy Now Backend**
Halaman: Negotiation/Chat, Chat Inbox.
- FG-24 pg_cron auto-expire 6 jam — Nevan
- FG-25 Negotiation/Chat screen UI (realtime <2s) — Fachri  *(blocked by FG-22)*
- FG-26 Chat Inbox UI — Fachri  *(blocked by FG-10, FG-58)*
- FG-29 POST /listings/:id/buy-now — Nevan  *(blocked by FG-22, FG-35)*

**Sprint 7 — Buy Now UI + Fulfillment Backend**
Halaman: Detail Listing/Buy Now, Order Aktif / Transaction Detail.
- FG-27 Tap nama → profil counterpart — Hafizh
- FG-30 Buy Now UI di detail listing — Fachri  *(blocked by FG-29, FG-59)*
- FG-32 POST /transactions/:id/fulfill — Nevan
- FG-33 POST /transactions/:id/reject — Hafizh
- FG-59 Transaction Detail / Order Aktif screen — Fachri

**Sprint 8 — Fulfillment UI + Recurring Backend + Notifikasi**
Halaman: Fulfillment Form + modal konfirmasi.
- FG-34 Fulfillment Form UI + modal — Fachri  *(blocked by FG-32)*
- FG-37 POST/PATCH /recurring-orders — Hafizh
- FG-41 / FG-42 FCM wiring (negotiation + H-1 reminder) — Hafizh  *(blocked by FG-6)*

**Sprint 9 — Recurring Order UI**
Halaman: My Recurring Orders + Detail (Active/Paused).
- FG-38 pg_cron trigger H-1 — Hafizh
- FG-39 My Recurring Orders + Detail UI — Fachri  *(blocked by FG-37)*
- FG-40 CTA "Jadikan Recurring Order" — Hafizh
- FG-60 Guard archive listing dgn recurring aktif — Fachri + Nevan

### FASE 3 — INTEGRASI & DEMO (Sprint 10–13)

**Sprint 10 — Integration & E2E Testing**
- FG-44 E2E negotiation→transaction→trust_metrics — Hafizh
- FG-45 E2E realtime chat <2s — Fachri
- FG-46 E2E Buy Now + race condition — Nevan
- FG-47 E2E recurring full cycle — Hafizh
- FG-48 Implementasi & test 7 edge case §11 — Nevan

**Sprint 11 — UI Polish & Visual QA**
- FG-49 Polish Listing & Feed — Fachri
- FG-50 Polish Chat & Chat inbox — Hafizh
- FG-51 Polish Fulfillment & Recurring — Fachri
- FG-52 Polish Profile & Metrics — Hafizh
- FG-53 Visual QA seluruh screen vs Figma — Alexander

**Sprint 12 — AC Verification & Regression**
- FG-54 Verifikasi AC §10.1–10.5 — Hafizh
- FG-55 Regression edge case §11 — Nevan

**Sprint 13 — Demo Readiness**
- FG-56 Demo script + rehearsal + deploy checklist — Hafizh

---

## Lane Paralel per Orang (ringkas)

- **Nevan (backend/DB):** FG-2 → FG-3/4 → FG-18/22/35/58 → FG-24/29 → FG-32 → (E2E/edge case). Pemilik tunggal migration & inventory locking (cegah conflict).
- **Fachri (frontend):** FG-57 → FG-11 → FG-13/14/15 → FG-25/26 → FG-30/59 → FG-34 → FG-39. Pemilik tunggal GoRouter (push berurutan).
- **Hafizh (backend/PM + integrasi):** FG-5/6 → FG-7 → FG-19/23 → FG-16/20 → FG-27/33 → FG-37/40/41/42 → FG-38 → QA. Integration owner `hafizh_dev`.
- **Alexander (desain):** FG-9/10 (Sprint 1, BLOCKER) → FG-53 (visual QA).

---

## Perubahan yang sudah dieksekusi di JIRA (16 Juli 2026)

1. **Label tema** `theme-*` ditambahkan ke seluruh 60 issue (FG-1…FG-60) — tanpa menghapus label `pic-*`/`sprint-*`.
2. **18 dependency links** (Blocks / is blocked by) dibuat untuk mengunci urutan paralel, a.l.:
   - FG-11 ← FG-9, FG-57 · FG-26 ← FG-10, FG-58
   - FG-22/13/18 ← FG-2 (migration) · FG-14/15 ← FG-13
   - FG-25 ← FG-22 · FG-29 ← FG-22, FG-35 · FG-30 ← FG-29, FG-59
   - FG-34 ← FG-32 · FG-16 ← FG-20 · FG-39 ← FG-37 · FG-42 ← FG-6
3. **Koreksi v6** (email NULLABLE, tabel buyer_metrics, label "Reliability" bukan "Payment Rate", konfirmasi varian Create Listing) — terverifikasi **sudah tertanam** di deskripsi tiket terkait (FG-2, FG-16, FG-14), tidak perlu ditimpa.

---

## Checklist manual tersisa (belum bisa diotomasi)

1. ⛔ **Alexander selesaikan FG-9 (Role Picker) + FG-10 (Chat Inbox)** sebelum coding — gate entry-point routing.
2. ⚠️ **Verifikasi ~8 frame Figma** bertanda "belum diverifikasi" (§15) + pilih varian final Create Listing (FG-14).
3. ⚠️ **Pastikan repo `docs-farmbridge` berisi PRD v6 final** — repo private, belum bisa diverifikasi otomatis.
4. 🔹 Redraw diagram state machine PRD §5 (48 jam → 6 jam) — kosmetik, teks §5.1 yang mengikat.

**Setelah poin 1–3 beres → 100% siap sprint paralel 30 jam.**
