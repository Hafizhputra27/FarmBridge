# Sprint 3 (Hafizh) — FG-7 Seed `price_reference_data` Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

> **Catatan eksekusi:** Sesuai `docs/CLAUDE.md`, Claude tidak menjalankan operasi git yang mengubah state repo (`add`/`commit`/`push`/`merge`/dst). Claude bisa menulis file (`supabase/seed.sql`) dan menjalankan `supabase` CLI / query read-only untuk verifikasi, tapi commit/push tetap dijalankan Hafizh sendiri di terminal.

**Goal:** Isi `price_reference_data` dengan dataset dummy realistis (6 kategori produk pertanian × 3 region) lewat `supabase/seed.sql`, siap dikonsumsi `POST /price-recommendation` (FG-23, Sprint 4).

**Arsitektur:** Satu file `supabase/seed.sql` berisi `DELETE FROM price_reference_data;` diikuti `INSERT` massal — bukan `ON CONFLICT DO NOTHING`, karena tabel ini tidak punya unique constraint di `(category, region)` (menambah constraint itu domain migration/Nevan, di luar scope `seed.sql` milik Hafizh). Delete-then-insert lebih sederhana dan tetap memenuhi syarat "bisa di-rerun tanpa duplikasi" tanpa menyentuh skema.

**Tech Stack:** PostgreSQL (`INSERT` standar), Supabase CLI (`supabase db push --include-seed` atau eksekusi manual lewat `execute_sql`/psql untuk apply ke project remote — project ini tidak pakai local dev stack, langsung ke project `rwxnjxmzkcfoddnzjosi`).

## Global Constraints

- Kerja langsung di branch `hafizh_dev` (Playbook §1).
- Format commit: `[FG-7] deskripsi singkat` (Playbook §2 Aturan Dasar #4).
- `supabase/seed.sql` **bukan** file migration — boleh ditulis Hafizh langsung (beda dengan `supabase/migrations/*.sql` yang domain Nevan).
- Harga dalam Rupiah per kg, harus masuk akal (bukan angka acak) — dicek manual terhadap harga pasar riil Indonesia, bukan ditebak.
- Seed harus bisa dijalankan berkali-kali tanpa menghasilkan row duplikat (DoD FG-7).
- Tabel `price_reference_data` (dari `supabase/migrations/20260716083135_initial_schema.sql`): `id uuid PK`, `category text NOT NULL`, `region text NOT NULL`, `avg_price numeric NOT NULL`, `min_price numeric NOT NULL`, `max_price numeric NOT NULL` — **tidak ada unique constraint** di luar `id`.
- RLS `price_reference_data`: public `SELECT`, tidak ada `INSERT`/`UPDATE`/`DELETE` policy untuk role `anon`/`authenticated` (lihat `docs/Sprint 2/sprint2_hasil_akhir.md`) — artinya seed **harus** dijalankan lewat koneksi yang bypass RLS (service role / `supabase db push`/`execute_sql` dengan akses admin), bukan lewat client app.

---

### Task 1: Tulis `supabase/seed.sql`

**Files:**
- Create: `supabase/seed.sql`

**Interfaces:**
- Produces: 18 baris di `price_reference_data` (6 kategori × 3 region), dikonsumsi `POST /price-recommendation` (FG-23, Sprint 4) lewat query `WHERE category = $1 AND region = $2`.

- [ ] **Step 1: Tulis dataset**

```sql
-- supabase/seed.sql
-- Seed data price_reference_data — FG-7, Sprint 3.
-- Re-runnable: DELETE semua baris lalu INSERT ulang, bukan ON CONFLICT,
-- karena tabel ini tidak punya unique constraint di (category, region).

DELETE FROM price_reference_data;

INSERT INTO price_reference_data (category, region, avg_price, min_price, max_price) VALUES
  ('Beras', 'Jawa Barat', 12000, 10500, 13500),
  ('Beras', 'Jawa Tengah', 11500, 10000, 13000),
  ('Beras', 'Jawa Timur', 11800, 10200, 13200),

  ('Cabai Merah', 'Jawa Barat', 38000, 28000, 55000),
  ('Cabai Merah', 'Jawa Tengah', 35000, 25000, 50000),
  ('Cabai Merah', 'Jawa Timur', 36000, 26000, 52000),

  ('Bawang Merah', 'Jawa Barat', 30000, 24000, 40000),
  ('Bawang Merah', 'Jawa Tengah', 28000, 22000, 38000),
  ('Bawang Merah', 'Jawa Timur', 29000, 23000, 39000),

  ('Tomat', 'Jawa Barat', 8500, 6000, 12000),
  ('Tomat', 'Jawa Tengah', 7500, 5500, 11000),
  ('Tomat', 'Jawa Timur', 8000, 5800, 11500),

  ('Jagung', 'Jawa Barat', 5500, 4500, 6500),
  ('Jagung', 'Jawa Tengah', 5000, 4200, 6000),
  ('Jagung', 'Jawa Timur', 5200, 4300, 6200),

  ('Kentang', 'Jawa Barat', 11000, 9000, 14000),
  ('Kentang', 'Jawa Tengah', 10000, 8200, 13000),
  ('Kentang', 'Jawa Timur', 10500, 8600, 13500);
```

Alasan pemilihan data:
- 6 kategori (Beras, Cabai Merah, Bawang Merah, Tomat, Jagung, Kentang) — komoditas pertanian umum yang diperdagangkan petani-buyer di Indonesia, memenuhi syarat DoD "5-8 kategori".
- 3 region Jawa (Jawa Barat, Jawa Tengah, Jawa Timur) — sentra produksi pertanian terbesar, representatif untuk MVP hackathon, memenuhi syarat DoD "2-3 region".
- Harga per kg dalam Rupiah, `min_price`/`max_price` merentang wajar di sekitar `avg_price` (Cabai Merah punya spread terlebar karena harganya paling volatil di pasar riil — cocok dengan sifat komoditas ini).

- [ ] **Step 2: Commit (dijalankan Hafizh sendiri)**

```bash
git add supabase/seed.sql
git commit -m "[FG-7] seed price_reference_data — 6 kategori x 3 region"
```

---

### Task 2: Apply seed ke project remote & verifikasi idempotency

**Files:** tidak ada file baru — task verifikasi.

**Interfaces:**
- Consumes: `supabase/seed.sql` (Task 1).

- [ ] **Step 1: Apply seed pertama kali**

Project ini tidak pakai local dev stack (langsung ke project `rwxnjxmzkcfoddnzjosi`), jadi jalankan isi `seed.sql` langsung ke remote:

```bash
supabase db push --include-seed --project-ref rwxnjxmzkcfoddnzjosi
```

Kalau flag itu tidak tersedia di versi CLI yang terpasang, jalankan manual lewat `psql` connection string dari `supabase status`/dashboard, atau lewat MCP `execute_sql` (`mcp__plugin_supabase_supabase__execute_sql`) dengan isi file `seed.sql` sebagai query — ini bypass RLS karena jalan sebagai service role/postgres, sesuai catatan di Global Constraints.

- [ ] **Step 2: Cek jumlah baris**

```sql
SELECT count(*) FROM price_reference_data;
```

Expected: `18`.

- [ ] **Step 3: Jalankan ulang seed (test idempotency, DoD FG-7)**

Ulangi Step 1 persis sama, lalu ulangi Step 2.

Expected: masih `18`, bukan `36` — membuktikan `DELETE`-then-`INSERT` bekerja, tidak ada duplikasi.

- [ ] **Step 4: Verifikasi data masuk akal**

```sql
SELECT category, region, avg_price, min_price, max_price
FROM price_reference_data
ORDER BY category, region;
```

Expected: 18 baris, `min_price < avg_price < max_price` di setiap baris, tidak ada nilai negatif/nol.

---

### Task 3: Verifikasi akses public read (regresi RLS)

**Files:** tidak ada file baru — task verifikasi.

**Interfaces:**
- Consumes: RLS policy `price_reference_data_select_public` (FG-3, Sprint 2, sudah live).

- [ ] **Step 1: Cek RLS masih public read**

```sql
SELECT policyname, cmd, roles FROM pg_policies WHERE tablename = 'price_reference_data';
```

Expected: minimal satu policy `cmd = 'SELECT'` dengan `roles` mencakup akses publik (bukan cuma `service_role`) — memastikan seed tidak butuh policy tambahan, sesuai catatan Nevan bahwa `price_reference_data` "public read" sudah siap sejak FG-3.

- [ ] **Step 2: Simulasi query sebagai anon (opsional tapi disarankan)**

```bash
curl -sS "https://rwxnjxmzkcfoddnzjosi.supabase.co/rest/v1/price_reference_data?select=category,region,avg_price" \
  -H "apikey: $SUPABASE_ANON_KEY"
```

Expected: HTTP 200, array berisi 18 objek — membuktikan data yang baru di-seed benar-benar bisa dibaca client app tanpa auth (`anon` role), bukan cuma lewat akses admin.

---

## Decisions Log

- **Jumlah kategori/region:** 6 kategori × 3 region = 18 baris (dalam rentang DoD 5-8 kategori × 2-3 region).
- **Strategi idempotency:** `DELETE FROM price_reference_data;` + `INSERT` massal — bukan `ON CONFLICT DO NOTHING`, karena tidak ada unique constraint di `(category, region)` dan menambah constraint itu di luar scope `seed.sql` (domain migration/Nevan).
- **Sumber angka harga:** estimasi harga pasar komoditas pertanian Indonesia per kg, bukan hasil riset harga real-time — cukup untuk kebutuhan demo hackathon (FG-23 cuma butuh angka yang "masuk akal", bukan akurat sampai ke sumber data resmi).

## Self-Check Coverage (FG-7 checklist asli → task di plan ini)

| Item checklist asli (`sprint3_hafizh_dev.md`) | Task di plan ini |
|---|---|
| Dataset 5-8 kategori × 2-3 region, harga masuk akal | Task 1 |
| Insert via seed script, bukan manual satu-satu | Task 1 |
| Bisa di-rerun tanpa duplikasi | Task 2 (Step 3) |
| Data siap dikonsumsi (kategori/region ada → tidak null saat dipakai FG-23) | Task 2 (Step 4), Task 3 |
