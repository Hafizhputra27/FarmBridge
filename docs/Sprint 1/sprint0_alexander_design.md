# Sprint 0 (Pra-Sprint 1): Design Gate — Task Plan untuk Alexander

## Peran di sprint ini
**Dua ticket desain yang belum ada frame Figma sama sekali** — FG-9 (Role picker screen) dan FG-10 (Chat inbox screen). Keduanya baru muncul sebagai requirement di PRD v6, dan epic FG-8 mencatat eksplisit: "screen ini belum ada di Figma, perlu didesain sebelum sprint 1 mulai". Kamu satu-satunya yang pegang ticket desain di seluruh project ini (semua desain fitur lain sudah ada di file Figma "BUZZER-Prototype", tinggal di-cross-check lewat §15 PRD).

**Kenapa urutan FG-9 dulu, baru FG-10**: FG-8 memang menyebut dua-duanya sebagai blocker sebelum Sprint 1. Tapi kalau ditelusuri siapa konsumennya — FG-9 langsung dipakai FG-11 (Fachri, Sprint 1 ini juga), sedangkan FG-10 baru dipakai FG-26 (Chat inbox UI, levelnya Epic E5 — realistis baru dikerjakan Sprint 2+). Kalau kamu kerjakan dua-duanya sekaligus dengan bobot sama, Fachri ikut menunggu lebih lama padahal dia cuma butuh FG-9. Selesaikan FG-9 dulu sampai tuntas, baru lanjut FG-10 — boleh nyusul di hari yang sama, tapi jangan diparalelkan setengah-setengah.

## Ticket yang kamu kerjakan

### FG-9 — [DESIGN-BLOCKER] Role picker screen (prioritas 1)
- Screen landing dengan 2 pilihan role: "Saya Petani" / "Saya Pembeli"
- Screen isi nama (1 field: `farm_name` untuk petani, `business_name` untuk buyer) + state validasi error (field kosong)
- Ikuti visual language yang sudah ada di file Figma "BUZZER-Prototype" (gaya glassmorphic yang dipakai di Create/Edit Listing, dsb.) supaya konsisten dengan screen lain
- Kontras warna minimum **WCAG AA** — target user termasuk petani yang akses di kondisi pencahayaan luar ruangan (PRD §12 Accessibility)

### FG-10 — [DESIGN-BLOCKER] Chat inbox screen (prioritas 2)
- List view negotiation aktif: nama counterpart, listing terkait, status negotiation (OPEN/COUNTERED/ACCEPTED/dst), harga terakhir, waktu update
- State kosong (belum ada negotiation sama sekali) — pesan/ilustrasi yang jelas, bukan layar kosong tanpa penjelasan
- Desain harus dipakai bersama oleh role farmer maupun buyer (list sama, filter beda by auth.uid() — jadi visualnya tidak perlu dibedakan per role)
- Konsisten secara visual dengan Negotiation/Chat Screen [90:405] yang sudah ada (transisi tap-in dari inbox ke chat harus terasa natural)

## Yang perlu kamu putuskan/cek sebelum mulai
- Field nama di role picker cuma 1 (farm_name **atau** business_name tergantung role dipilih) — bukan 2 field terpisah yang ditampilkan sekaligus. Pastikan desain switch field label-nya, bukan menampilkan dua input sekaligus.
- Tidak ada field email/password/OTP dalam bentuk apapun (PRD §14 eksplisit melarang ini) — kalau kamu terbiasa selalu naruh "lupa password"/opsi login lain di pattern onboarding, sengaja dihilangkan di sini.

## Sync point dengan teammate
- **FG-9 selesai → langsung kabari Fachri.** Dia sudah standby dari awal Sprint 1 (scaffolding Flutter project sambil menunggu, lihat `sprint1_fachri_dev.md`) dan FG-11 miliknya tidak bisa mulai bagian UI sampai frame ini ada.
- **FG-10 selesai → kabari tim di stand-up berikutnya**, tidak perlu buru-buru — konsumennya (FG-26) belum akan mulai di Sprint 1.

## Evidence yang perlu disiapkan (per format ticket)
- Link frame Figma baru untuk masing-masing (role picker: 2 screen; chat inbox: list + empty state)
- Screenshot kedua screen role picker, screenshot list state & empty state chat inbox
- Untuk FG-9: catatan kontras warna vs WCAG AA (bisa pakai contrast checker, screenshot hasilnya)
- Untuk FG-9: catatan handoff (spacing/warna/font) untuk Fachri, ditulis singkat di komentar ticket atau README file Figma

## Referensi PRD
§3.1, §4.1, §13.1 (role picker); §3.1(v6), §4.1(v6), §9 GET /negotiations (chat inbox); §12 Accessibility; §15 (lampiran pemetaan requirement-ke-screen, catatan "screen ini BELUM ada di Figma").
