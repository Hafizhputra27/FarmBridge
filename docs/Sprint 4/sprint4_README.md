> Direvisi 2026-07-14 — sinkron ulang dengan label JIRA (skema granular 13-sprint), menggantikan versi kompresi 6-sprint sebelumnya.

# Sprint 4: Listing Management & Trust/Buyer Metrics Functions — Overview

## Isi sprint
| Ticket | Judul | PIC |
|---|---|---|
| FG-13 | Endpoint & query listing filter (PostgREST) | Fachri |
| FG-14 | Farmer: Create/Edit Listing UI + upload foto | Fachri |
| FG-18 | Edge Function update trust_metrics | Nevan |
| FG-19 | Edge Function update buyer_metrics | Hafizh |
| FG-23 | POST /price-recommendation + fallback | Hafizh |

## Catatan: FG-18 & FG-19 tidak akan pernah punya trigger asli sprint ini
Perubahan status `transaction` ke `fulfilled`/`rejected` baru ada mulai Sprint 6 (FG-29, Buy Now) dan Sprint 7 (FG-32/FG-33, fulfill/reject). Jadi testing FG-18 (Nevan) dan FG-19 (Hafizh) sprint ini adalah **unit test terisolasi**: insert/update manual row `transactions` untuk mensimulasikan kondisi fulfilled/rejected. Jangan anggap ini "belum selesai" kalau trigger belum pernah kepanggil beneran — itu memang belum ada pemicunya sampai beberapa sprint lagi.

## Catatan: sebelum FG-14 dimulai — cek open question 3 varian Create Listing
Ini sudah diminta ditanyakan sejak Sprint 1-2 (waktu longgar Fachri). Kalau belum terjawab, ini prioritas #1 sebelum baris kode pertama FG-14 — jangan mulai build lalu ganti varian di tengah jalan.

## Catatan: FG-23 disiapkan sebagai shared function untuk dipakai Nevan di Sprint 5
`POST /negotiations` (FG-22, Nevan, Sprint 5) perlu mengembalikan `recommended_price` dari logic yang sama dengan `POST /price-recommendation` (FG-23, Hafizh, sprint ini). Supaya tidak ada dua implementasi lookup harga yang beda sendiri-sendiri, **Hafizh ekstrak logic-nya jadi function terpisah** (`getRecommendedPrice()`) yang bisa diimport, bukan cuma endpoint HTTP. Karena FG-22 baru mulai sprint depan (bukan sprint yang sama), ini bukan soal koordinasi Hari-1 — cukup pastikan signature function-nya stabil sebelum sprint ini selesai, dan beri tahu Nevan begitu siap diimport.

## Dependency & urutan
```
Fachri: FG-13 (listing filter endpoint) ──► FG-14 (Create/Edit Listing UI)
        [FG-14 pakai listing hasil sendiri sebagai data uji feed di FG-15, Sprint 5]

Nevan: FG-18 (trust_metrics function) ── independen, test manual (insert dummy transactions)
Hafizh: FG-19 (buyer_metrics function) ── independen, test manual (insert dummy transactions)
        paralel penuh, tidak saling bergantung

Hafizh: FG-23 (price-recommendation + fallback)
        └──► expose getRecommendedPrice() — akan diimport Nevan di FG-22 (Sprint 5)
```

## File di sprint ini
- `sprint4_nevan_dev.md`
- `sprint4_hafizh_dev.md`
- `sprint4_fachri_dev.md`
