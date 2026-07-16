# FarmBridge (FG) — Branching & Merging Playbook

Playbook ini dibuat untuk konteks spesifik: 4 orang (Hafizh, Nevan, Fachri, Alexander), 30 jam, 13 sprint paralel, stack Flutter + Supabase. Tujuannya bukan proses git yang "benar secara umum", tapi proses yang **meminimalkan waktu terbuang untuk resolve conflict dan menunggu**, karena itu sumber daya paling langka di hackathon.

Prinsip utama: **satu integration branch, satu integration owner, merge kecil & sering — bukan merge besar di akhir sprint.**

---

## 1. Struktur Branch

```
main                  ← selalu demo-able. HANYA Hafizh yang merge ke sini.
 └── hafizh_dev        ← integration branch. HANYA Hafizh yang merge ke sini.
      ├── nevan_dev     ← branch kerja Nevan (backend infra, state machine, edge functions)
      └── fachri_dev    ← branch kerja Fachri (Flutter frontend)
```

Catatan soal Hafizh & Alexander:
- Hafizh mengerjakan tiketnya sendiri (FG-5, FG-6, FG-7, dst) **langsung di `hafizh_dev`** — dia tidak butuh branch kerja terpisah karena `hafizh_dev` sudah menjadi branch integrasi sekaligus branch kerjanya. Ini sengaja, supaya tidak ada lapisan merge tambahan untuk pekerjaannya sendiri.
- Alexander tidak commit kode (kerja di Figma). Kalau sewaktu-waktu dia perlu menyentuh repo (mis. export asset), lakukan lewat PR kecil langsung ke `hafizh_dev`, bukan bikin branch permanen.

**Kenapa bukan feature-branch-per-ticket?** Dengan 46 tiket dalam 30 jam, overhead bikin+hapus branch per tiket lebih mahal daripada risikonya. Satu branch per-orang yang hidup sepanjang hackathon lebih murah dan cukup aman karena tiket-tiket sudah dipisah rapi per PIC (lihat JIRA label `pic-*`).

---

## 2. Aturan Dasar

1. **Tidak ada commit langsung ke `main`.** Satu-satunya jalan masuk ke `main` adalah merge dari `hafizh_dev` oleh Hafizh.
2. **Tidak ada commit langsung ke `hafizh_dev` dari Nevan/Fachri.** Mereka commit ke branch masing-masing; Hafizh yang menarik (`git merge origin/nevan_dev` / `origin/fachri_dev`) ke `hafizh_dev`.
3. **Commit ke branch sendiri bebas sesering mungkin** — tidak perlu PR review, tidak perlu commit message sempurna. Kecepatan di branch pribadi diprioritaskan; ketelitian baru masuk di titik merge ke `hafizh_dev`.
4. **Format commit message**: `[FG-XX] deskripsi singkat` — supaya gampang ditelusuri balik ke tiket saat ada bug atau saat menulis evidence/demo script di akhir.
5. **Migration file (`supabase/migrations/*.sql`) HANYA ditulis Nevan.** Kalau Hafizh butuh perubahan schema (mis. kolom `device_token`), dia minta Nevan yang menambahkan di migration Nevan — Hafizh tidak pernah menulis file migration sendiri. Ini mencegah dua orang menulis migration terpisah dengan timestamp tabrakan atau schema yang saling override.

---

## 3. Kapan Merge ke `hafizh_dev`

**Merge per-tiket-selesai, bukan per-jadwal-waktu.** Begitu satu tiket lolos acceptance criteria versi smoke-test sendiri (bukan full QA), push ke branch masing-masing dan kabari Hafizh untuk ditarik. Jangan menahan beberapa tiket sekaligus untuk "merge sekali gede" — itu yang bikin conflict menumpuk dan susah dilacak sumbernya.

**Urutan prioritas kalau ada beberapa merge request menumpuk bersamaan:**
1. Migration/schema (Nevan) — hampir semua orang bergantung ke ini, tarik duluan.
2. Endpoint backend yang jadi dependency langsung UI yang sedang ditunggu Fachri.
3. Sisanya, urutan FIFO (siapa selesai duluan).

## 4. Pre-Merge Checklist (dijalankan Hafizh sebelum `git merge origin/<nama>_dev`)

- [ ] `git fetch origin` dulu, cek tidak ada commit `hafizh_dev` yang ketinggalan di local Hafizh.
- [ ] Kalau ada migration baru (dari Nevan): jalankan `supabase db push --dry-run` — **wajib hijau** sebelum lanjut. Kalau merah, kembalikan ke Nevan, jangan coba diperbaiki manual di `hafizh_dev`.
- [ ] Kalau ada perubahan Flutter (dari Fachri): `flutter analyze` tidak menunjukkan error baru (warning boleh, error tidak).
- [ ] Ticket yang di-merge sudah dicoba jalan minimal sekali oleh pemiliknya sendiri (screenshot/video singkat cukup, tidak perlu formal) — jangan merge kode yang belum pernah dicoba jalan sama sekali.
- [ ] Kalau ticket ini termasuk yang dicatat py dependency silang di sprint doc (mis. FG-33 ↔ FG-35), pastikan urutan merge sesuai catatan di README sprint terkait — jangan asal tarik duluan yang taskable duluan.

Kalau semua checklist hijau → `git push origin hafizh_dev`.

## 5. Kapan Merge `hafizh_dev` → `main` (HYBRID: Per Fase, bukan Per Sprint)

**Merge ke main hanya 3 kali selama 30 jam — di akhir setiap FASE:**

```
FASE 1 (Sprint 1-3) — END ~6 jam
├─ Tag checkpoint: sprint-1-done, sprint-2-done, sprint-3-done (internal only)
└─ MERGE #1 → main (tag: phase-1-complete)

FASE 2 (Sprint 4-9) — END ~18 jam
├─ Tag checkpoint: sprint-4-done, sprint-5-done, ... sprint-9-done (internal only)
└─ MERGE #2 → main (tag: phase-2-complete)

FASE 3 (Sprint 10-13) — END ~28 jam
├─ Tag checkpoint: sprint-10-done, sprint-11-done, sprint-12-done, sprint-13-done (internal only)
└─ MERGE #3 → main (tag: phase-3-complete)
```

**Checkpoint tagging per sprint (internal tracking, jangan push ke origin):**
- `git tag sprint-3-done` (hanya local, untuk reference sendiri)
- `git tag sprint-9-done` (before FASE 2 merge to main)
- Kalau perlu rollback ke sprint spesifik: reset ke tag itu

**Merge ke `main` pakai:** `git merge --no-ff hafizh_dev` (bukan fast-forward, bukan squash) — supaya history tetap jelas per-fase saat nanti butuh telusur balik untuk debugging atau demo script.

**Strategi:**
- Selama FASE 1: semua ticket sprint 1-3 accumulate di `hafizh_dev`, jangan push ke `main`
- Begitu sprint 3 selesai (semua 3 sprint green): baru merge `hafizh_dev` → `main` (MERGE #1)
- Repeat untuk FASE 2 & 3

## 6. Resolusi Konflik

- **Yang merge belakangan yang menyelesaikan conflict**, dan diselesaikan di branch pribadi dulu (`git merge origin/hafizh_dev` ke branch sendiri, resolve, baru minta ditarik lagi) — bukan Hafizh yang menyelesaikan conflict punya orang lain di `hafizh_dev`. Hafizh hanya menolak merge yang conflict dan melempar balik.
- Area rawan conflict yang sudah teridentifikasi dari sprint docs — siapkan mental sebelumnya:
  - `supabase/migrations/` — mitigasi: hanya Nevan yang menulis (lihat Aturan #5).
  - Fungsi inventory locking (FG-22 → digeneralisasi FG-35) — Nevan sendiri yang encode ulang, tidak disentuh Hafizh/Fachri.
  - Routing GoRouter (disentuh FG-57 scaffold awal, lalu FG-11, lalu banyak ticket Fachri berikutnya) — Fachri sendiri yang push berurutan, risiko conflict rendah karena satu orang.

## 7. Kalau Merge ke `hafizh_dev` Ternyata Merusak Build

- Hafizh **revert merge commit itu juga** (`git revert -m 1 <merge-commit-hash>`), jangan coba debug live di `hafizh_dev` sambil semua orang menunggu.
- Push revert, kabari pemilik ticket untuk memperbaiki di branch sendiri, request merge ulang setelah fix.
- `main` tidak pernah tersentuh oleh masalah ini karena `main` cuma menerima state `hafizh_dev` yang sudah lolos checklist Bagian 4 — kerusakan di `hafizh_dev` tidak pernah merembet ke `main`.

## 8. Code Freeze

- **2 jam terakhir dari 30 jam** = code freeze di `hafizh_dev`. Hanya bug fix kritis (blocker demo) yang boleh merge, tidak ada fitur baru.
- Selama code freeze, fokus semua orang pindah ke: rehearsal demo, isi checklist edge case (FG-48/FG-55/FG-60), dan pastikan `main` = state final yang akan didemokan (tag `final-demo`).

## 9. Definition of Done per Merge (ringkas)

Sebuah ticket dianggap selesai untuk kebutuhan merge (bukan untuk kebutuhan QA formal Sprint 10-13) kalau:
- [ ] Acceptance Criteria di deskripsi ticket JIRA sudah dicoba jalan minimal 1x oleh pemiliknya
- [ ] Tidak ada error baru di `flutter analyze` (kalau Flutter) atau migration dry-run gagal (kalau schema)
- [ ] Sudah di-push ke branch pribadi dengan commit message `[FG-XX] ...`
- [ ] Dependency yang dicatat di sprint doc terkait sudah tersedia (jangan merge kode yang butuh function/endpoint yang belum ada)

---

## 10. Execution Timeline (Hybrid Per-Fase)

```
T+0 (Kickoff)
├─ Alexander: selesai desain FG-9 (Role Picker) + FG-10 (Chat Inbox)
├─ Team: clone repo, checkout hafizh_dev
└─ Nevan, Hafizh, Fachri: mulai Sprint 1

T+1-6 (FASE 1: Sprint 1-3)
├─ Sprint 1 (2h): Nevan FG-2 migration, Hafizh FG-5/6, Fachri FG-57 scaffold
├─ Sprint 2 (2h): Nevan FG-3/4 (Auth/RLS/Realtime)
├─ Sprint 3 (2h): Hafizh FG-7 (seed), Fachri FG-11 (Role Picker UI)
├─ Checkpoint: sprint-1-done, sprint-2-done, sprint-3-done (local tags)
└─ **MERGE #1** (hafizh_dev → main): `git merge --no-ff hafizh_dev && git tag phase-1-complete && git push origin main --tags`

T+6-18 (FASE 2: Sprint 4-9)
├─ Sprint 4-9: Listing, Profile, Negotiation, Buy Now, Fulfillment, Recurring
├─ Checkpoint tags: sprint-4-done ... sprint-9-done (local)
└─ **MERGE #2** (hafizh_dev → main): sama seperti MERGE #1

T+18-28 (FASE 3: Sprint 10-13)
├─ Sprint 10-13: E2E testing, Polish, AC verify, Demo readiness
├─ Checkpoint tags: sprint-10-done ... sprint-13-done (local)
└─ **MERGE #3** (hafizh_dev → main): git merge --no-ff hafizh_dev && git tag final-demo && git push

T+28-30 (Code Freeze + Demo Rehearsal)
├─ Code freeze: hanya critical bug fix
├─ Tag final release: git tag release-garudahacks-7.0
└─ Demo prep: run through script
```

---

## 11. Merge Commands Per Fase (copy-paste ready)

**MERGE #1 — End of FASE 1 (Sprint 3):**
```bash
# Hafizh runs:
git checkout hafizh_dev
git fetch origin
git merge origin/nevan_dev
git merge origin/fachri_dev
supabase db push --dry-run  # verify
flutter analyze            # verify
git push origin hafizh_dev
git checkout main
git merge --no-ff hafizh_dev
git tag phase-1-complete
git push origin main --tags
echo "✅ FASE 1 merge complete"
```

**MERGE #2 — End of FASE 2 (Sprint 9):**
```bash
# Same as above, tapi tag phase-2-complete
```

**MERGE #3 — End of FASE 3 (Sprint 13):**
```bash
# Same, tapi tag final-demo
git tag release-garudahacks-7.0  # final release tag
```
