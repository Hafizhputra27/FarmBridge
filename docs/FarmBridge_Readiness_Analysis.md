# FarmBridge — Analisis Kesiapan Build (GarudaHacks 7.0, 30 jam)

Cross-check antara **PRD v6**, **Branching Playbook**, **JIRA (project FG)**, dan **Figma** (`b5Vmzd1KVKfodLMUnZGJ0K`).
Disusun 15 Juli 2026, sebelum sprint 1.

---

## Kesimpulan singkat

**Sudah 90% siap kerja paralel.** Backlog JIRA sangat rapi dan konsisten dengan PRD v6 — semua keputusan v6 (buyer_metrics, chat inbox, role picker, Buy Now, fulfillment 1-langkah) sudah punya tiket, termasuk 4 tiket GAP-FILL (FG-57–FG-60) yang menambal celah yang PRD sendiri tandai. Pembagian per-PIC dan sekuens backend→UI mendukung 4 orang jalan bareng.

**Tapi ada 1 blocker keras dan beberapa item verifikasi yang WAJIB dibereskan sebelum/di awal sprint 1**, kalau tidak, jalur entry-point routing macet dan beberapa UI berisiko dibangun dari desain yang salah.

| Aspek | Status |
|---|---|
| PRD ↔ JIRA konsistensi | ✅ Sangat konsisten (semua fitur v6 tertiket) |
| Kesiapan kerja paralel (4 PIC) | ✅ Struktur mendukung, dengan syarat |
| PRD ↔ Figma | ⚠️ 2 screen wajib belum ada + ~8 frame belum diverifikasi |
| Blocker sebelum sprint 1 | ❌ Desain role picker + chat inbox belum selesai |

---

## 1. Konsistensi PRD ↔ JIRA — LULUS

Struktur JIRA: **10 Epic (FG-1, 8, 12, 17, 21, 28, 31, 36, 41, 43)** + child + gap-fill = **60 issue**, semua status **To Do**.

Setiap keputusan produk v6 sudah tercermin di tiket:

| Keputusan / fitur PRD v6 | Tiket JIRA | Cocok? |
|---|---|---|
| Tabel baru `buyer_metrics` (§2.4, §8) | FG-2 (migration), FG-19 (EF update), FG-20 (GET endpoint), FG-16 (UI) | ✅ |
| Chat inbox + `GET /negotiations` (§3.1/§9) | FG-10 (desain), FG-26 (UI), FG-58 (endpoint, GAP-FILL) | ✅ |
| Role picker tanpa login (§13.1) | FG-9 (desain), FG-11 (build), FG-57 (Flutter init, GAP-FILL) | ✅ |
| Buy Now (§3.1, §9) | FG-28/29/30 + FG-59 (Transaction Detail, GAP-FILL) | ✅ |
| Expiry negosiasi 6 jam (§5.1) | FG-24 (pg_cron auto-expire 6 jam) | ✅ |
| Fulfillment 1-langkah, reject independen (§5.1 v5) | FG-31/32/33/34 | ✅ |
| Inventory locking atomik (§9) | FG-35 | ✅ |
| Trust Score 3-dimensi + price recommendation | FG-18, FG-20, FG-23 | ✅ |
| 7 edge case §11 (termasuk guard archive listing) | FG-48, FG-55, FG-60 (archive guard, GAP-FILL) | ✅ |
| Notifikasi murni FCM (bukan WhatsApp) | FG-41/42 (dicatat eksplisit: tidak ada WA API) | ✅ |

**Catatan positif:** tiket GAP-FILL (FG-57 Flutter init, FG-58 GET /negotiations, FG-59 Transaction Detail, FG-60 archive guard) persis menambal 4 celah yang PRD tandai sebagai "belum tercakup". Ini menandakan backlog sudah di-reconcile dengan PRD v6, bukan versi lama.

---

## 2. Kesiapan Kerja Paralel — SIAP (dengan syarat)

Playbook menetapkan 1 integration branch (`hafizh_dev`), branch per orang, migration hanya ditulis Nevan, backend mendahului UI. Pembagian sprint mendukung 4 orang paralel.

### Beban Sprint 1 (semua PIC jalan bareng, tanpa saling blok)
| PIC | Tiket Sprint 1 | Sifat |
|---|---|---|
| **Nevan** | FG-2 Migration SQL (10+1 tabel) | Fondasi — semua backend nanti bergantung ke sini |
| **Hafizh** | FG-5 CI/CD, FG-6 FCM setup | Infra, independen |
| **Fachri** | FG-57 Flutter init (scaffold, GoRouter, deps) | Independen |
| **Alexander** | FG-9 Role picker (desain), FG-10 Chat inbox (desain) | **BLOCKER — lihat §3** |

Tidak ada saling-blok di dalam sprint 1 → **paralel sempurna di jam-jam pertama.** ✅

### Rantai dependensi lintas sprint (sudah benar)
- Backend di sprint N, UI-nya di sprint N+1 (mis. FG-22 negosiasi sprint-5 → FG-25 chat UI sprint-6). ✅
- FG-35 inventory locking (Nevan, sprint-5) jadi dependency FG-22/29/32. Playbook §6 sudah menandai FG-22→FG-35 & FG-33↔FG-35 sebagai area rawan; keduanya dipegang Nevan sendiri → risiko conflict rendah. ✅
- Routing GoRouter disentuh FG-57 → FG-11 → banyak tiket Fachri, satu orang berurutan. ✅

### Titik yang perlu diperhatikan (bukan blocker, tapi rawan)
1. **FG-13 "Endpoint & query listing filter (PostgREST)" di-label `pic-fachri`**, padahal ini backend. Karena cuma query-param PostgREST (tanpa Edge Function) memang bisa dikerjakan frontend, tapi pastikan Fachri tahu ini tanggung jawabnya, bukan Nevan.
2. **FG-18 (trust_metrics, Nevan) & FG-19 (buyer_metrics, Hafizh)** dua Edge Function di domain sama, sprint sama (4), dua owner. Pastikan file terpisah supaya tidak tabrakan.
3. **Sprint 4 padat**: FG-13, FG-14, FG-15, FG-18, FG-19, FG-23 jalan bareng — cek kapasitas real 30 jam.

---

## 3. BLOCKER Utama — Desain belum ada di Figma ❌

PRD §15 dan Epic FG-8 sama-sama menyatakan **2 screen kunci belum ada frame Figma-nya sama sekali:**

- **Role picker screen (FG-9)** — landing → pilih "Saya Petani"/"Saya Pembeli" → isi nama. Ini **entry point yang menentukan seluruh routing aplikasi**. Kalau ini belum jadi, FG-11 (build role picker, Fachri) dan seluruh navigasi role-based tertahan.
- **Chat inbox screen (FG-10)** — daftar semua negosiasi aktif. Selalu ada di bottom-nav tapi belum pernah didesain. Blokir FG-26.

Keduanya di-assign **Alexander di sprint-1** dan ditandai `[DESIGN-BLOCKER]`. **Ini pekerjaan malam-ini/subuh, harus selesai sebelum coding dimulai.** Ini satu-satunya hal yang bisa bikin start hackathon tersendat.

---

## 4. Item Verifikasi Figma (kerjakan di awal, sebelum tiket UI terkait)

PRD §15 menandai sejumlah frame **"belum diverifikasi visual"** — konfirmasi dulu sebelum UI-nya dibangun supaya tidak membangun dari asumsi:

- `nego DECLINED`, `nego counter`, `nego chat` (dampak ke FG-25)
- `no results found`, `no listing` (dampak ke FG-15)
- `form eror` (dampak ke FG-14)
- `Recurring Order Detail - Active/Paused`, Pause/Cancel/Resume confirmation (dampak ke FG-39)
- **`Create Listing` ada 3 varian di "Sprint 6" Figma — pilih mana yang final** sebelum FG-14 mulai.

> ⚠️ **Catatan keterbatasan:** Figma MCP kena rate limit (Starter plan) saat analisis ini, jadi saya **tidak bisa memverifikasi sendiri keberadaan 42 frame**. Daftar di atas berdasar klaim PRD §15, bukan pengecekan visual independen. Sebaiknya satu orang buka Figma dan centang 42 frame ini manual sebelum sprint 1.

---

## 5. Inkonsistensi Dokumen Kecil (bukan blocker build)

1. **PRD §5 Gambar 3 (state machine)** masih menampilkan label **"48 jam"**, padahal nilai mengikat adalah **6 jam** (§5.1). PRD sendiri sudah menandai perlu digambar ulang. Teks §5.1 yang mengikat implementasi, jadi tidak menghambat coding — tapi jangan sampai ada yang meng-hardcode 48 jam dari diagram.
2. **Label Figma "Payment Rate"** vs field PRD **`fulfillment_rate`**. PRD §2.4 minta label UI diganti "Reliability"/"Completion Rate" supaya tidak menyiratkan verifikasi pembayaran (padahal payment out-of-scope). Terapkan saat FG-16/FG-52.
3. **`users.email` jadi NULLABLE** (§8 v5) karena tidak ada signup — pastikan migration FG-2 tidak menandai email `NOT NULL`.

---

## 6. Repo GitHub — belum bisa diverifikasi

Repo `github.com/Hafizhputra27/docs-farmbridge` **private** dan tidak ter-sync ke knowledge, jadi tidak bisa saya buka. Analisis ini memakai 3 file yang kamu upload (PRD v6 `.md` + `.docx`, Branching Playbook) sebagai isi repo. **Pastikan repo benar-benar berisi versi PRD v6 final ini** (bukan v5 ke bawah) supaya tim membaca sumber yang sama.

---

## 7. Checklist Sebelum Sprint 1 (urut prioritas)

1. ❌ **[BLOCKER] Alexander selesaikan desain Role Picker (FG-9) + Chat Inbox (FG-10).** Tanpa ini, entry-point macet.
2. ⚠️ **Verifikasi 42 frame Figma** & pilih varian final Create Listing (FG-14). Centang manual daftar §4 di atas.
3. ⚠️ **Konfirmasi repo berisi PRD v6 final** + semua orang clone & baca Branching Playbook.
4. ✅ Set dependency antar-tiket di JIRA (mis. FG-11 blocked-by FG-9 & FG-57; FG-26 blocked-by FG-10 & FG-58) supaya urutan tarik-merge jelas.
5. ✅ Pastikan FG-2 (migration) sudah `NULLABLE` untuk email & sudah termasuk `buyer_metrics`.
6. 🔹 (Opsional) Redraw diagram state machine 48→6 jam.

**Kalau poin 1–3 beres sebelum jam mulai, tim bisa langsung sprint paralel penuh.**
