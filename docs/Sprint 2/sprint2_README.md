> Direvisi 2026-07-14 — sinkron ulang dengan label JIRA (skema granular 13-sprint), menggantikan versi kompresi 6-sprint sebelumnya.

# Sprint 2: Auth, RLS & Realtime Backbone — Overview

## Isi sprint
| Ticket | Judul | PIC |
|---|---|---|
| FG-3 | Setup Supabase Auth/RLS/Storage | Nevan |
| FG-4 | Setup Realtime & pg_cron | Nevan |

## Catatan: Hafizh & Fachri tidak ada ticket sprint ini — bukan idle tanpa arah
Sprint ini murni backbone keamanan & realtime, dan cuma bisa dikerjakan satu tangan (Nevan) karena keduanya sekuensial internal (RLS butuh schema final dari FG-2/Sprint 1, Realtime/pg_cron butuh RLS sudah terpasang). Hafizh (persiapan FG-7, Sprint 3) dan Fachri (persiapan FG-11, Sprint 3) tidak kebagian ticket formal — pakai waktu ini untuk breathing room & prep, bukan menunggu tanpa kerjaan (lihat file masing-masing untuk saran prep opsional).

## Dependency & urutan
```
Nevan: FG-3 (Auth/RLS/Storage) ──► FG-4 (Realtime & pg_cron)
   │        [prasyarat: FG-2 migration, Sprint 1, sudah merge]
   │
   └──► begitu FG-3+FG-4 selesai & merge ke hafizh_dev, lolos dry-run:
            Hafizh bisa mulai FG-7 (Sprint 3, butuh Auth live untuk uji akses)
            Fachri bisa mulai FG-11 penuh (Sprint 3, butuh signInAnonymously() FG-3 live)
```

## File di sprint ini
- `sprint2_nevan_dev.md`
- `sprint2_hafizh_dev.md`
- `sprint2_fachri_dev.md`
