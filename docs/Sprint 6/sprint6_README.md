> Direvisi 2026-07-14 — sinkron ulang dengan label JIRA (skema granular 13-sprint), menggantikan versi kompresi 6-sprint sebelumnya.

# Sprint 6: Profile UI, Chat & Buy Now — Overview

## Isi sprint
| Ticket | Judul | PIC |
|---|---|---|
| FG-16 | Buyer & Farmer Public Profile UI (Trust Score & Buyer Metrics) | Hafizh |
| FG-24 | pg_cron auto-expire negotiation 6 jam | Nevan |
| FG-25 | Negotiation/Chat screen UI (realtime <2 detik) | Fachri |
| FG-26 | Chat inbox UI (GET /negotiations) | Fachri |
| FG-29 | POST /listings/:id/buy-now endpoint | Nevan |

## Catatan: FG-26 tidak lagi menunggu apapun
FG-26 (Chat inbox UI) butuh FG-10 (desain, Alexander, Sprint 1) dan FG-58 (GET /negotiations, Nevan, Sprint 5) — dua-duanya sudah selesai di sprint-sprint sebelumnya. Beda dari skema lama yang sempat menyebut ini sebagai potensi bottleneck ("kabari begitu FG-10 selesai" / "tunggu kabar Nevan soal GET /negotiations") — sekarang di Sprint 6 tinggal build langsung, tidak ada lagi drama menunggu.

## Catatan: FG-29 reuse locking dari FG-35 (Sprint 5)
FG-29 (Buy Now) reuse function `lockInventoryOnAccept()` dari FG-35 (Nevan, Sprint 5, sudah selesai) — bukan implementasi locking baru dari nol.

## Dependency & urutan
```
Hafizh: FG-16 (Profile UI) ── butuh FG-20 (Hafizh, Sprint 5, sudah ada)
         testing: state kosong "Belum ada riwayat transaksi" (masih natural, transaksi asli
         baru terbentuk begitu FG-29/FG-22 dipakai sungguhan)

Nevan: FG-24 (auto-expire) ── butuh FG-22 (Nevan, Sprint 5, state machine solid)
Nevan: FG-29 (Buy Now) ── reuse locking dari FG-35 (Nevan, Sprint 5)
       └──► begitu selesai, kabari Fachri untuk Sprint 7 (FG-30, Buy Now UI)

Fachri: FG-25 (Chat screen UI) ──► FG-26 (Chat inbox UI)
        [FG-25 duluan karena FG-26 pada dasarnya list yang tap-in ke screen yang sama]
        butuh FG-22 (Nevan, Sprint 5, solid) untuk wiring data asli, FG-10 (Sprint 1) untuk desain inbox
```

## File di sprint ini
- `sprint6_nevan_dev.md`
- `sprint6_hafizh_dev.md`
- `sprint6_fachri_dev.md`
