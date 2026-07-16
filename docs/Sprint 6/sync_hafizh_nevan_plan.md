# Sinkronisasi hafizh_dev ↔ nevan_dev — Rekonsiliasi Migration Drift

> Dibuat 2026-07-17. Konteks: setelah merge `nevan_dev` → `hafizh_dev` (PR #17), `supabase db push --dry-run` masih merah karena migration `20260716164950` sudah live di remote DB tapi filenya tidak pernah ter-commit ke branch manapun (dicek: tidak ada di `hafizh_dev`, `origin/nevan_dev`, `origin/fachri_dev`).

## Temuan investigasi (PENTING — mengubah rencana awal)

Rencana awal: "kalau tidak dibutuhkan, hapus saja." **Investigasi membuktikan sebaliknya — migration ini DIBUTUHKAN, bukan sisa yang aman dihapus.**

Query `supabase_migrations.schema_migrations` (read-only) mengembalikan isi migration itu:

```sql
-- version: 20260716164950, name: add_quantity_to_negotiations
ALTER TABLE negotiations ADD COLUMN IF NOT EXISTS quantity numeric NOT NULL DEFAULT 1;
```

Kolom `quantity` ini **aktif dipakai** oleh `supabase/functions/negotiations/index.ts` (FG-22, Nevan, baru saja masuk `hafizh_dev` lewat merge PR #17):

```ts
const { data: negotiation, error: negErr } = await supabase.from("negotiations").insert({
  listing_id: listing.id, buyer_id, farmer_id: listing.farmer_id,
  initial_price, current_offer_price: initial_price,
  recommended_price: priceResult.recommended_price,
  expires_at: expiresAt.toISOString(), status: "open", quantity,
}).select("id, status, expires_at").single();
```

Tabel `negotiations` juga sudah punya 5 baris data live (bukan tabel kosong). **Kalau kolom ini dihapus: `POST /negotiations` langsung error di setiap panggilan** (constraint `NOT NULL` tanpa kolom), dan berisiko kehilangan data `quantity` yang sudah ada di baris existing.

**Kesimpulan:** ini kasus yang sama persis dengan migration `20260716092216_realtime_storage_cron.sql` (lihat catatan di file itu sendiri: *"Direkonstruksi 2026-07-16 dari state live project — versi ini sudah applied di remote sejak awal Sprint 1, tapi filenya sempat tidak ter-commit ke git"*). Solusinya bukan hapus, tapi **rekonstruksi file migration yang hilang**, supaya git dan remote DB sinkron lagi.

## Rencana Eksekusi

**Batasan:** Migration file cuma boleh ditulis Nevan (Playbook §2 Aturan Dasar #5) — Hafizh/Claude tidak menulis file ini sendiri. Bagian ini didelegasikan ke Nevan, Hafizh cuma menyiapkan draft & instruksi siap-pakai.

### Task 1: Nevan rekonstruksi file migration

- [ ] **Step 1:** Nevan buat file `supabase/migrations/20260716164950_add_quantity_to_negotiations.sql` di branch `nevan_dev`, isi persis (timestamp di nama file **harus** `20260716164950`, sama dengan version yang sudah tercatat di `supabase_migrations.schema_migrations` — supaya `supabase db push` mengenalinya sebagai migration yang sama, bukan migration baru):

```sql
-- ============================================================
-- Tambah kolom quantity ke negotiations
-- Direkonstruksi 2026-07-17 dari state live project (versi ini
-- sudah applied di remote sejak Sprint 5, dipakai POST /negotiations
-- FG-22, tapi filenya sempat tidak ter-commit ke git).
-- ============================================================

ALTER TABLE negotiations ADD COLUMN IF NOT EXISTS quantity numeric NOT NULL DEFAULT 1;
```

- [ ] **Step 2:** Nevan commit & push ke `nevan_dev`:
```bash
git add supabase/migrations/20260716164950_add_quantity_to_negotiations.sql
git commit -m "[FG-22] rekonstruksi migration add_quantity_to_negotiations (sempat tidak ter-commit)"
git push origin nevan_dev
```

### Task 2: Hafizh tarik ulang & verifikasi

- [ ] **Step 1:** `git fetch origin && git merge origin/nevan_dev` di `hafizh_dev` (cuma nambah 1 file baru, tidak ada overlap dengan yang sudah di-merge — harusnya fast-forward/no-conflict)
- [ ] **Step 2:** `supabase db push --dry-run` — **wajib hijau**, tidak ada lagi migration versi asing
- [ ] **Step 3:** Kalau masih merah, JANGAN diperbaiki manual di `hafizh_dev` (Playbook §4) — lempar balik ke Nevan, cek apakah ada migration live lain yang juga belum ter-commit

## Kenapa bukan `supabase migration repair --status reverted`

Supabase CLI menyarankan command ini di pesan error dry-run — **sengaja tidak dipakai** di sini. `migration repair --status reverted` cuma mengubah bookkeeping (bilang ke Supabase "anggap migration ini tidak pernah di-apply"), **tidak** menghapus kolom `quantity` yang sudah live. Efeknya: state tracking jadi bohong (history bilang belum applied, padahal kolomnya masih ada dan dipakai) — migration berikutnya bisa coba re-create kolom yang sudah ada, atau developer lain bingung kenapa kolom "belum applied" tapi datanya ada. Rekonstruksi file adalah perbaikan yang jujur terhadap state asli, `repair --status reverted` cuma nutupin gejala.

## Definition of Done

- [ ] File migration `20260716164950_add_quantity_to_negotiations.sql` ada di `nevan_dev` dan `hafizh_dev`
- [ ] `supabase db push --dry-run` hijau di `hafizh_dev`
- [ ] Tidak ada data `quantity` di tabel `negotiations` yang hilang/berubah (read-only check sebelum & sesudah)
