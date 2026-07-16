> Direvisi 2026-07-14 — sinkron ulang dengan label JIRA (skema granular 13-sprint), menggantikan versi kompresi 6-sprint sebelumnya.

# Sprint 2: Auth, RLS & Realtime Backbone — Task Plan untuk Fachri

## Peran di sprint ini
**Tidak ada ticket dev ditugaskan sprint ini.** FG-57 (Sprint 1) sudah selesai, dan FG-11 (build role picker flow penuh) baru resmi jadi ticketmu di Sprint 3 — menunggu FG-3 (Auth, Nevan) live sprint ini. Daripada idle tanpa arah, pakai sprint ini untuk menuntaskan hal-hal yang akan langsung berguna begitu Sprint 3-4 mulai.

## Yang bisa kamu kerjakan sambil menunggu (opsional tapi disarankan)
- **Tuntaskan open question 3 varian "Create Listing" di Figma** (dicatat sejak Sprint 1) — tanyakan ke Alexander/Hafizh sekarang, supaya sudah jelas jauh sebelum FG-14 (Sprint 4) dimulai. Jangan tunggu sampai Sprint 4 baru sadar ada ambiguitas ini.
- Baca ulang §15 PRD untuk ticket-ticketmu ke depan: FG-11 (Sprint 3), FG-13/FG-14 (Sprint 4), FG-15 (Sprint 5), FG-25/FG-26 (Sprint 6) — catat kalau ada gap mockup lain (state kosong, error state), jangan diasumsikan sendiri.
- Cek ulang skeleton GoRouter dari FG-57 (Sprint 1) — pastikan strukturnya masih masuk akal untuk menampung route role picker (FG-11) begitu Sprint 3 mulai.

## Sync point dengan teammate
- **Tunggu kabar dari Alexander** — FG-9 (desain role picker) seharusnya sudah selesai dari Sprint 1, tapi konfirmasi ulang tidak ada perubahan sebelum Sprint 3 mulai.
- **Tunggu kabar dari Hafizh/Nevan** begitu `nevan_dev` (FG-3 + FG-4) sudah di-merge ke `hafizh_dev` dan lolos dry-run — baru bisa wiring `signInAnonymously()` sungguhan di Sprint 3.

## Definition of Done
- [ ] Open question 3 varian Create Listing sudah terjawab sebelum Sprint 4 dimulai
- [ ] Tidak ada gap mockup lain yang belum tercatat untuk ticket-ticket Sprint 3-6

## Referensi PRD
§15 (pemetaan requirement → screen, termasuk catatan open question 3 varian Create Listing).
