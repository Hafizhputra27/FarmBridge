> Direvisi 2026-07-14 — sinkron ulang dengan label JIRA (skema granular 13-sprint), menggantikan versi kompresi 6-sprint sebelumnya.

# Sprint 2: Auth, RLS & Realtime Backbone — Task Plan untuk Hafizh

## Peran di sprint ini
**Tidak ada ticket dev ditugaskan sprint ini.** FG-3 dan FG-4 (Auth/RLS/Storage, Realtime & pg_cron) adalah pekerjaan satu tangan Nevan yang sekuensial internal — memecahnya ke orang lain cuma menambah risiko konflik di area yang sama. Kamu tetap punya peran sebagai **integration branch owner**: begitu Nevan selesai FG-3/FG-4, kamu yang menarik & memverifikasi merge ke `hafizh_dev` sebelum masuk `main`.

## Yang bisa kamu kerjakan sambil menunggu (opsional)
- Siapkan draft dataset seed untuk FG-7 (Sprint 3): daftar kandidat 5-8 kategori produk pertanian × 2-3 region, dengan `avg_price`/`min_price`/`max_price` yang masuk akal — supaya begitu Sprint 3 mulai kamu tinggal eksekusi, bukan riset dari nol.
- Bantu verifikasi manual RLS Nevan begitu FG-3 live (mis. coba akses lintas akun dummy) — bukan tanggung jawab formalmu, tapi extra pasang mata di titik paling kritis keamanan project ini bernilai.

## Menarik branch (integration branch owner)
```
git checkout hafizh_dev
git fetch origin
git merge origin/nevan_dev
supabase db push --dry-run   # wajib hijau (RLS + realtime + pg_cron dari FG-3/FG-4)
git push origin hafizh_dev
git checkout main
git merge hafizh_dev
git push origin main
```
Kalau dry-run gagal, jangan lanjut ke `main` — kembalikan ke Nevan.

## Sync point dengan teammate
- **Tunggu Nevan** selesai FG-3 + FG-4 sebelum bisa mulai FG-7 (Sprint 3) — RLS `price_reference_data` dan koneksi Auth harus live dulu.
- **Kabari Fachri** begitu merge ke `main` selesai — FG-11 (Sprint 3) butuh Auth (FG-3) live untuk `signInAnonymously()`.

## Definition of Done
- [x] `hafizh_dev` berhasil merge `nevan_dev` (FG-3 + FG-4) dan masuk `main` — terkonfirmasi via git history + CI/CD "Deploy Supabase" hijau di `main`
- [x] Draft dataset seed FG-7 siap dipakai di Sprint 3 (opsional, tapi disarankan) — terpenuhi langsung lewat eksekusi FG-7 di Sprint 3 (18 baris, 6 kategori × 3 region), bukan cuma draft

## Referensi PRD
§2.3, §9 (konteks price_reference_data untuk prep FG-7), §12 (NFR — Observability).
