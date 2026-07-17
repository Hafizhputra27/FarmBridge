# FG-45: E2E Testing — Realtime Chat Latency

**Sprint:** 10 | **Tanggal:** 2026-07-17 | **Tester:** Hafizh (backup semua role)

## Metodologi

Pengukuran latensi realtime **tidak** memakai 2 device fisik — pendekatan yang dipakai: script Node.js men-subscribe channel `postgres_changes` (event `INSERT`) pada tabel `negotiation_messages` lewat `@supabase/supabase-js`, lalu mengirim pesan lewat Edge Function `negotiations/:id/messages` dan mengukur delta waktu kirim vs waktu event realtime diterima di client. Ini mengukur komponen yang sama (server→client Supabase Realtime) yang dialami 2 device asli.

Negosiasi test: `negotiation_id=d4a86812-b3f2-4cab-bf75-8ca2c11d651d` (listing `10bae509...`, status `open`).

## Deviasi dari plan (dicatat transparan)

1. **Deno tidak terpasang** di environment ini. Plan menyediakan opsi fallback ("catat sebagai blocker kalau tidak boleh install tooling baru"). Node.js v22 sudah terpasang, jadi script ditulis ulang dalam plain JS (`realtime_latency_test.mjs`) memakai `@supabase/supabase-js` — logika identik dengan versi TypeScript di plan, tanpa menambah tooling sistem baru.
2. **Percobaan pertama (anon key polos, tanpa JWT) — semua 10 trial TIMEOUT.** Root cause: RLS `negotiation_messages_select_participant` mensyaratkan `auth.uid() = negotiations.buyer_id OR auth.uid() = negotiations.farmer_id` (dicek via `pg_policy`). Supabase Realtime menghormati RLS — dengan anon key tanpa sesi, `auth.uid()` bernilai NULL sehingga tidak ada baris yang lolos filter dan tidak ada event ter-broadcast ke client. **Ini bukan bug aplikasi** — desain RLS memang benar (mencegah pihak non-partisipan menguping chat), hanya metodologi awal skrip test yang salah (harus autentikasi sebagai partisipan). Diperbaiki dengan `createClient(url, anonKey, { accessToken: async () => JWT })` + `supabase.realtime.setAuth(JWT)` memakai JWT farmer.test (partisipan negosiasi test). Setelah fix, publication `supabase_realtime` juga dicek dan dikonfirmasi sudah mencakup `negotiation_messages` (bukan sumber masalah).

## Hasil (10 trial, terautentikasi sebagai farmer.test)

| Trial | Latensi |
|---|---|
| 1 | 835ms |
| 2 | 894ms |
| 3 | 496ms |
| 4 | 759ms |
| 5 | 494ms |
| 6 | 766ms |
| 7 | 955ms |
| 8 | 560ms |
| 9 | 849ms |
| 10 | 623ms |

**Rata-rata: 723ms** (10/10 trial berhasil, tidak ada timeout)

## Kesimpulan

**PASS** — rata-rata 723ms jauh di bawah target <2000ms. Latensi realtime Supabase untuk `negotiation_messages` konsisten di rentang 494-955ms tanpa outlier signifikan.
