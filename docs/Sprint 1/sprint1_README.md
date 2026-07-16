> Direvisi 2026-07-14 — sinkron ulang dengan label JIRA (skema granular 13-sprint), menggantikan versi kompresi 6-sprint sebelumnya.

# Sprint 1: Foundation Kickoff — Overview

## Isi sprint
| Ticket | Judul | PIC |
|---|---|---|
| FG-2 | Migration SQL 10 tabel + buyer_metrics + device_token | Nevan |
| FG-5 | Setup CI/CD Pipeline | Hafizh |
| FG-6 | Setup FCM Push Notification | Hafizh |
| FG-9 | [DESIGN-BLOCKER] Role picker screen | Alexander |
| FG-10 | [DESIGN-BLOCKER] Chat inbox screen | Alexander |
| FG-57 | Flutter project init + struktur folder + GoRouter skeleton (gap-fill, subtask FG-11) | Fachri |

## Gap yang saya tutup di sprint ini: FG-57 (Flutter project init)
Sebelumnya "Flutter project init" (flutter create, struktur folder, GoRouter skeleton, dependencies dasar) tidak punya ticket JIRA sendiri — di skema lama ini cuma dikerjakan informal sebagai bagian tersembunyi dari FG-11. Sekarang sudah diformalkan jadi FG-57, subtask baru di bawah FG-11, dikerjakan Fachri paralel dari T+0 tanpa menunggu FG-9. Ini murni scaffold: `flutter create`, struktur folder `lib/features/`, `lib/core/`, `lib/shared/`, install dependencies dasar, GoRouter skeleton role-based redirect — belum ada UI role picker sungguhan (itu FG-11, Sprint 3).

## Catatan: koordinasi device_token (FG-2 ↔ FG-6)
Kolom `device_token` (dipakai FG-6, FCM) belum ada rumah pasti sampai Nevan (FG-2) dan Hafizh (FG-6) sepakat di mana disimpan (rekomendasi: kolom nullable langsung di `users`). Ini harus disepakati SEBELUM Nevan menulis migration, supaya Hafizh tidak perlu migration susulan.

## Catatan: FG-9 vs FG-10 — prioritas tidak sama
FG-8 mensyaratkan FG-9 dan FG-10 (dua-duanya) selesai sebelum Sprint 1 dianggap clear — tapi konsumennya beda jauh: FG-9 dibutuhkan Fachri untuk FG-11 di Sprint 3 (mendesak), sedangkan FG-10 baru dipakai FG-26 (Chat inbox UI) di Sprint 6 (longgar). Prioritaskan FG-9 ketat, FG-10 boleh menyusul di awal Sprint 1 tanpa memblokir siapapun.

## Dependency & urutan
```
Alexander: FG-9 (blocker FG-11, Sprint 3) ── prioritas tinggi
Alexander: FG-10 (blocker FG-26, Sprint 6) ── paralel, tidak memblokir siapapun di Sprint 1-2

Nevan: FG-2 (migration 11 tabel) ── solo, semua orang Sprint 2+ menunggu ini
   │
   ├──► share ke Hafizh: keputusan device_token (sebelum FG-2 final)
   └──► share ke Hafizh: tabel price_reference_data siap (dipakai FG-7, Sprint 3)

Hafizh: FG-5 (CI/CD) ── paralel dari awal, tidak butuh schema untuk mulai
Hafizh: FG-6 (FCM) ── bagian setup Firebase paralel dari awal, bagian device_token nunggu FG-2

Fachri: FG-57 (scaffold Flutter) ── paralel penuh dari T+0, tidak menunggu FG-9 maupun FG-2
```

## File di sprint ini
- `sprint1_nevan_dev.md`
- `sprint1_hafizh_dev.md`
- `sprint1_fachri_dev.md`
