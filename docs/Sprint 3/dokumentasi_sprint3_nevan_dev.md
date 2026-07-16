# Sprint 3 — Dokumentasi Nevan (Draft State Machine FG-22)

**Tanggal:** 16 Juli 2026  
**Status:** ✅ Selesai  
**Branch:** `nevan_dev`

---

## Ringkasan

Sprint 3 adalah breathing room setelah Sprint 1-2. Tidak ada tiket formal. Yang dikerjakan:
1. Memastikan tidak ada isu schema/RLS yang menghambat FG-7/FG-11
2. Draft pseudocode state machine FG-22 sebagai persiapan Sprint 5

---

## DoD

| # | Item | Status |
|---|---|---|
| 1 | Tidak ada isu schema/RLS | ✅ INSERT policy + anonymous auth |
| 2 | Draft pseudocode state machine FG-22 | ✅ `plan_sprint3_nevan.md` |

---

## Detail

### Blocker FG-11 yang Ditemukan & Diresolve

- **INSERT policy `users`** tidak ada → ditambahkan `users_insert_self` (1 migration)
- **Anonymous Sign-ins** disabled di dashboard → di-enable manual oleh user

### Pseudocode State Machine FG-22

File: `docs/Sprint 3/plan_sprint3_nevan.md`

Mencakup 7 bagian:
- POST /negotiations (validasi + recommended_price)
- Prinsip "pihak penerima" (§5.1)
- POST /negotiations/:id/messages (4 action_type)
- State transitions diagram
- Inventory locking atomik (lockInventoryOnAccept + releaseInventoryOnReject)
- GET /negotiations (FG-58 Chat inbox)
- File mapping untuk Sprint 5

---

## Evidence

| Item | Detail |
|---|---|
| users_insert_self policy | 40 policies total di pg_policies |
| Anonymous sign-in test | API return JWT + `is_anonymous: true` |
| Pseudocode FG-22 | `docs/Sprint 3/plan_sprint3_nevan.md` |

---

## Catatan untuk Sprint 5

- State machine sudah dipetakan lengkap — tinggal implementasi
- Inventory locking harus atomik (satu transaction DB)
- Buy Now (FG-29, Sprint 6) loncat ACCEPTED tanpa OPEN
- Fungsi `getRecommendedPrice()` sudah siap dari Hafizh (FG-23, Sprint 4)
