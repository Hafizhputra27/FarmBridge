> Direvisi 2026-07-14 — sinkron ulang dengan label JIRA (skema granular 13-sprint), menggantikan versi kompresi 6-sprint sebelumnya.

# Sprint 5: Home Feed, Metrics Endpoints & Negotiation Core — Overview

## Isi sprint
| Ticket | Judul | PIC |
|---|---|---|
| FG-15 | Buyer: Home Feed + Search & Filter | Fachri |
| FG-20 | GET /trust-metrics/:id + GET /buyer-metrics/:id | Hafizh |
| FG-22 | POST /negotiations + /messages + state machine | Nevan |
| FG-58 | GET /negotiations (gap-fill, subtask FG-22) | Nevan |
| FG-35 | Inventory locking atomik (generalisasi dari FG-22) | Nevan |

## Gap yang saya tutup di sprint ini: FG-58 (GET /negotiations)
Tidak ada ticket JIRA untuk endpoint list negotiation (dipakai Chat inbox, FG-26 di Sprint 6) — scope asli FG-22 cuma `POST /negotiations`, `POST /negotiations/:id/messages`, `GET /negotiations/:id` (detail), bukan versi list. Gap ini sudah diformalkan jadi FG-58, subtask baru di bawah FG-22, dikerjakan Nevan bareng FG-22 karena sama-sama domain tabel `negotiations` — secara teknis ringan (query PostgREST, RLS Sprint 2 otomatis memfilter kepemilikan, filter `status` opsional, `order by updated_at desc`), mirip pola FG-13 (listing filter) Sprint 4.

## Catatan beban kerja Nevan: 3 ticket berat sekaligus
Nevan kebagian FG-22 (state machine paling kompleks di seluruh project), FG-58 (ringan, bundel dengan FG-22), dan FG-35 (generalisasi inventory locking). Beban ini wajar mengingat Nevan idle di Sprint 3 — anggap itu waktu persiapan untuk sprint ini.

## Catatan: FG-23 (Sprint 4, Hafizh) ↔ FG-22 (Sprint 5, Nevan) — beda 1 sprint, bukan Hari-1 coordination
`POST /negotiations` (FG-22) perlu mengembalikan `recommended_price` di response-nya (§9) dari logic yang sama dengan FG-23. Karena FG-23 sudah selesai penuh di Sprint 4 (bukan berjalan paralel di sprint yang sama), Nevan tinggal **import function `getRecommendedPrice()` yang sudah jadi** dari Hafizh — bukan lagi soal menyepakati signature Hari-1 seperti kalau keduanya berjalan bersamaan. Cukup konfirmasi ke Hafizh kalau ada perubahan signature dibutuhkan.

## Catatan: FG-35 bukan ticket baru dari nol
FG-22 sudah mengimplementasikan inti locking-nya sendiri ("quantity_available TIDAK berkurang saat OPEN/COUNTERED, baru berkurang atomik saat ACCEPTED, rollback kalau REJECTED" — eksplisit di scope FG-22). FG-35 adalah generalisasi: ekstrak logic itu jadi function reusable (`lockInventoryOnAccept()`, `releaseInventoryOnReject()`) supaya bisa dipakai juga oleh Buy Now (FG-29, Sprint 6) dan Reject (FG-33, Sprint 7 — sudah ada di file itu).

## Dependency & urutan
```
Hafizh: FG-20 (GET trust/buyer-metrics) ── butuh FG-18 (Nevan, Sprint 4) & FG-19 (Hafizh, Sprint 4) sudah ada
         │ testing: empty state + data terisi via insert manual (belum ada trigger asli)
         └──► dipakai Hafizh sendiri di FG-16 (Sprint 6, Profile UI)

Fachri: FG-15 (Home Feed + Search) ── konsumsi FG-13 (Fachri, Sprint 4), data dari FG-14 (Fachri, Sprint 4)

Nevan: FG-22 (negotiations + messages + state machine) + FG-58 (GET /negotiations, bundel)
        │
        ├──► import getRecommendedPrice() dari Hafizh (FG-23, Sprint 4, sudah selesai)
        │
        └──► Nevan: FG-35 (generalisasi locking dari FG-22)
                 └──► dipakai FG-29 (Nevan, Sprint 6, Buy Now)
```

## File di sprint ini
- `sprint5_nevan_dev.md`
- `sprint5_hafizh_dev.md`
- `sprint5_fachri_dev.md`
