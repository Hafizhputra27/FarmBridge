> Direvisi 2026-07-14 — sinkron ulang dengan label JIRA (skema granular 13-sprint), menggantikan versi kompresi 6-sprint sebelumnya.

# Sprint 3: Seed Data & Role Picker Flow — Overview

## Isi sprint
| Ticket | Judul | PIC |
|---|---|---|
| FG-7 | Seed price_reference_data awal | Hafizh |
| FG-11 | Build role picker flow (Flutter) | Fachri |

## Catatan: Nevan tidak ada ticket sprint ini
Setelah dua sprint padat (FG-2, lalu FG-3+FG-4), sprint ini giliran Nevan breathing room — tidak ada ticket JIRA yang ditugaskan. Optional: mulai riset/desain-di-kepala untuk FG-18 (Edge Function trust_metrics, Sprint 4) atau baca ulang PRD §5.1 untuk state machine negosiasi (FG-22, Sprint 5) — ticket paling kompleks di seluruh project, extra lead time membantu. Ini saran opsional, bukan penugasan resmi (lihat `sprint3_nevan_dev.md`).

## Catatan: FG-7 dan FG-11 independen satu sama lain
Dua ticket sprint ini beda domain total (seed data backend vs. Flutter UI flow) dan tidak saling bergantung — bisa dikerjakan penuh paralel oleh Hafizh dan Fachri tanpa sync point teknis di antara keduanya.

## Dependency & urutan
```
Hafizh: FG-7 (seed price_reference_data)
   │ prasyarat: tabel price_reference_data sudah ada (FG-2, Sprint 1) — sudah lama siap
   └──► independen, tidak menunggu siapapun sprint ini

Fachri: FG-11 (role picker flow penuh: 2 screen + signInAnonymously())
   │ prasyarat: FG-9 (desain, Sprint 1) sudah selesai
   │ prasyarat: FG-3 (Auth live, Sprint 2) sudah selesai
   │ prasyarat: FG-57 (scaffold, Sprint 1) sudah jadi basis
   └──► dua-duanya sudah clear sebelum Sprint 3 mulai — tidak ada lagi blocker menunggu,
        tinggal build penuh
```

## File di sprint ini
- `sprint3_nevan_dev.md`
- `sprint3_hafizh_dev.md`
- `sprint3_fachri_dev.md`
