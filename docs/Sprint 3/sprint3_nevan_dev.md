> Direvisi 2026-07-14 — sinkron ulang dengan label JIRA (skema granular 13-sprint), menggantikan versi kompresi 6-sprint sebelumnya.

# Sprint 3: Seed Data & Role Picker Flow — Task Plan untuk Nevan

## Peran di sprint ini
**Tidak ada ticket dev ditugaskan sprint ini.** Setelah dua sprint berat berturut-turut (FG-2 di Sprint 1, lalu FG-3+FG-4 di Sprint 2), ini breathing room sebelum kembali berat di Sprint 4 (FG-18) dan Sprint 5 (FG-22, FG-58, FG-35 — tiga ticket sekaligus, termasuk state machine paling kompleks di seluruh project).

## Yang bisa kamu kerjakan sambil menunggu (opsional)
- Mulai riset/desain-di-kepala untuk FG-18 (Edge Function trust_metrics, Sprint 4) — baca ulang formula di PRD §2.3.
- Baca ulang PRD §5.1 (state machine negosiasi) untuk FG-22 (Sprint 5) — ticket paling rawan salah di seluruh project (state transition "pihak penerima", inventory locking atomik, race condition). Draft pseudocode-nya sekarang supaya Sprint 5 tidak mulai dari nol.
- Tawarkan bantuan ke Hafizh (FG-7) atau Fachri (FG-11) kalau mereka menemukan isu terkait schema/RLS yang kamu bangun — kamu yang paling paham detail migration & RLS sprint-sprint sebelumnya.

## Sync point dengan teammate
- Tidak ada dependency masuk atau keluar untuk kamu sprint ini — pantau saja kalau Hafizh (FG-7) atau Fachri (FG-11) butuh klarifikasi soal schema/RLS yang kamu bangun.

## Definition of Done
- [x] Draft pseudocode state machine FG-22 (opsional) siap jadi starting point Sprint 5
- [x] Tidak ada isu schema/RLS yang menghambat FG-7 atau FG-11 berjalan

## Referensi PRD
§2.3 (persiapan FG-18), §5.1 (persiapan FG-22).
