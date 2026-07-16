# Sprint 10: Integration Testing — Overview

## Isi sprint
| Ticket | Judul | PIC (assignee JIRA) |
|---|---|---|
| FG-44 | E2E test: negotiation → transaction → trust_metrics pipeline | Hafizh |
| FG-45 | E2E test: realtime chat sync <2 detik | Fachri |
| FG-46 | E2E test: Buy Now + race condition | Nevan |
| FG-47 | E2E test: recurring order full cycle | Hafizh |
| FG-48 | Implementasi & test edge case §11 | Nevan |

## Temuan kritis: FG-48 cuma cover 7 dari 9 edge case §11
PRD §11 punya 9 baris edge case, checklist FG-48 cuma menyebut 7. Dua yang hilang:
- **Baris 8** (cegah archive listing dengan recurring order aktif) — **tidak bisa dites**, fitur archive/delete listing tidak pernah dibangun di ticket manapun sepanjang 13 sprint ini. Rekomendasi: tandai eksplisit "Out of scope MVP" di checklist final (lihat file Nevan).
- **Baris 9** (H-1 skip cycle) — fiturnya ada (FG-38, Sprint 9) dan sudah tercakup FG-47 (Hafizh, sprint ini juga) — cukup dirujuk, tidak perlu dites dobel.

## Dependency & urutan
Kelima E2E test ini menguji domain masing-masing (bisa paralel), FG-48 sebaiknya mulai setelah FG-46 (Nevan sendiri) beres, supaya ada confidence dulu fitur dasarnya jalan.

## File di sprint ini
- `sprint10_nevan_dev.md`
- `sprint10_hafizh_dev.md`
- `sprint10_fachri_dev.md`
