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

## 5. Kapan Merge `hafizh_dev` → `main`

- **Minimal di akhir setiap sprint** (13 kali sepanjang hackathon) — tag dengan `sprint-N-done` (`git tag sprint-3-done && git push origin --tags`) supaya ada checkpoint yang bisa di-rollback kalau sprint berikutnya bermasalah.
- **Boleh lebih sering** kalau sebuah vertical slice utuh sudah demo-able di tengah sprint (mis. Buy Now end-to-end sudah bisa dicoba) — jangan tunggu akhir sprint kalau sudah ada checkpoint yang aman untuk di-lock.
- Merge ke `main` pakai `git merge --no-ff hafizh_dev` (bukan fast-forward, bukan squash) — supaya history tetap jelas per-sprint saat nanti butuh telusur balik untuk debugging atau demo script.

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

## 10. Aturan AI Assistant (Claude Code)

Repo ini dipakai untuk lomba/hackathon — histori commit dan daftar Contributors di GitHub harus murni berasal dari empat anggota tim (Hafizh, Nevan, Fachri, Alexander), bukan dari AI assistant yang membantu ngoding.

- **Claude tidak pernah menjalankan operasi git yang mengubah state repo** di project ini: `add`, `commit`, `push`, `merge`, `branch`, `checkout -b`, `tag`, `reset`, `revert`, dll — tanpa pengecualian, walau diminta atau tampak disetujui user di tengah percakapan.
- Operasi git **read-only** tetap boleh dijalankan Claude: `status`, `diff`, `log`, `show`, `blame` — untuk kebutuhan analisis/debugging.
- Kalau ada perubahan yang siap di-commit, Claude berhenti di titik itu dan menyerahkan ke pemilik branch: tampilkan diff/ringkasan perubahan dan draft commit message (format `[FG-XX] deskripsi singkat`, lihat Aturan Dasar #4) sebagai teks, lalu **user sendiri** yang menjalankan `git add`/`git commit`/`git push` di terminalnya.
- Aturan ini berlaku untuk semua anggota tim yang pakai Claude Code di repo ini, bukan cuma Hafizh.
