# Sprint 11: UI Polish & Visual QA — Overview

## Isi sprint
| Ticket | Judul | PIC |
|---|---|---|
| FG-49 | UI Polish: Listing & Feed | Fachri |
| FG-50 | UI Polish: Negotiation/Chat & Chat inbox | Hafizh |
| FG-51 | UI Polish: Fulfillment & Recurring Order | Fachri |
| FG-52 | UI Polish: Profile & Trust/Buyer Metrics | Hafizh |
| FG-53 | Visual QA seluruh screen vs Figma | Alexander |

## Catatan tentang FG-50
Deskripsi ticket ini sendiri bilang "dikerjakan oleh yang membangun UI-nya" — tapi UI chat (bubble, tombol, chat inbox) sebenarnya dibangun Fachri (FG-25, FG-26, Sprint 6), bukan Hafizh (yang membangun backend price recommendation FG-23 dan fitur tap-profil FG-27). Ini beda dengan FG-49/51/52 yang assignee-nya memang cocok dengan siapa yang bangun UI aslinya. **JIRA saat ini tetap assign ke Hafizh** — kalau kamu setuju dengan observasi ini, pertimbangkan pindahkan ke Fachri; kalau tidak, Hafizh tetap bisa kerjakan (dia toh sudah familiar dengan domain chat lewat FG-23/FG-27).

## Dependency & urutan
```
Fachri: FG-49, FG-51 — independen, dua domain berbeda
Hafizh: FG-50, FG-52 — independen, dua domain berbeda
Alexander: FG-53 — TUNGGU keempat UI Polish di atas selesai dulu, baru mulai review
           (review sebelum polish = temuan yang otomatis kepatch, buang waktu review dua kali)
```

## File di sprint ini
- `sprint11_hafizh_dev.md`
- `sprint11_fachri_dev.md`
- `sprint11_alexander_qa.md`
