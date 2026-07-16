> Direvisi 2026-07-14 — sinkron ulang dengan label JIRA (skema granular 13-sprint), menggantikan versi kompresi 6-sprint sebelumnya.

# Sprint 4: Listing Management & Trust/Buyer Metrics Functions — Task Plan untuk Nevan

## Peran di sprint ini
**Satu ticket: FG-18 (Edge Function update trust_metrics).** Lebih ringan dari Sprint 1-2, breathing room setelah dua sprint fondasi berat. Formula trust_metrics (§2.3) tetap perlu dikerjakan hati-hati karena jadi sumber utama kepercayaan buyer terhadap farmer — hanya saja scope-nya sempit sprint ini.

**Kenapa cuma 1 ticket**: FG-18 sengaja dipisah dari FG-19 (buyer_metrics, Hafizh) supaya dua fungsi serupa tidak saling tunggu — kalian kerja paralel penuh tanpa dependency ke satu sama lain sprint ini.

## Catatan penting sebelum mulai
Trigger function ini **tidak akan pernah terpanggil oleh event nyata sprint ini** — perubahan status `transaction` ke `fulfilled`/`rejected` baru ada mulai Sprint 6-7. Testing-mu sprint ini adalah unit test terisolasi: insert/update manual row di `transactions` untuk mensimulasikan kondisi fulfilled/rejected, lalu verifikasi function menghasilkan angka yang benar.

## Task Checklist

### FG-18 — Edge Function update trust_metrics
- [ ] Formula `on_time_delivery_rate` = (fulfilled dengan `actual_delivery_date` ≤ `promised_delivery_date`) / (total fulfilled) × 100%, rolling 90 hari
- [ ] Formula `rejection_rate` = (rejected) / (total pernah pending untuk farmer tsb) × 100%, rolling 90 hari
- [ ] Formula `fulfillment_consistency` = (fulfilled dengan `delivered_quantity = agreed_quantity`, tanpa partial) / (total fulfilled) × 100%, rolling 90 hari
- [ ] Trigger dipanggil setelah `transaction` berubah status `fulfilled`/`rejected` (disambungkan sungguhan mulai Sprint 6-7 — cukup pastikan function-nya siap dipanggil sekarang)
- [ ] Simpan hasil ke tabel `trust_metrics` dengan `window_days=90`
- [ ] Data > 90 hari lalu tidak ikut mempengaruhi angka (rolling window benar)

**Test manual yang perlu kamu jalankan** (karena tidak ada trigger asli sprint ini):
```sql
-- simulasi 1: transaction fulfilled tepat waktu & kuantitas sesuai
insert into transactions (farmer_id, buyer_id, status, agreed_quantity, delivered_quantity, actual_delivery_date, promised_delivery_date)
values ('<dummy_farmer_id>', '<dummy_buyer_id>', 'fulfilled', 100, 100, '2026-01-10', '2026-01-12');
-- panggil function secara manual, cek trust_metrics.on_time_delivery_rate & fulfillment_consistency naik

-- simulasi 2: fulfilled tapi telat
-- actual_delivery_date > promised_delivery_date → transaksi ini TIDAK dihitung on-time

-- simulasi 3: rejected
-- rejection_rate farmer terkait ter-update pada perhitungan berikutnya
```

## File/folder yang kamu sentuh
```
supabase/functions/update-trust-metrics/**
```

## Sync point dengan teammate
- **Begitu FG-18 selesai**: kabari Hafizh — dia butuh function ini di Sprint 5 (FG-20, `GET /trust-metrics/:id`) sudah bisa dipanggil.
- Tidak ada dependency masuk untuk ticket ini.

## Waktu longgar — opsional
Kalau FG-18 selesai lebih cepat, ini waktu yang baik untuk mulai FG-22 (POST /negotiations + state machine, Sprint 5) lebih awal — ticket paling rawan salah di seluruh project. Baca ulang PRD §5.1 dan draft pseudocode state machine-nya sekarang. Opsional, jangan korbankan kualitas FG-18 demi ini.

## Definition of Done
- [ ] Formula 3 metrik terbukti benar lewat test manual di atas (before/after angka) — **cara cek**: jalankan 3 skenario simulasi, screenshot angka `trust_metrics` sebelum & sesudah
- [ ] Transaksi > 90 hari tidak mempengaruhi angka
- [ ] Function bisa dipanggil manual (invoke) tanpa error dari Supabase dashboard

## Referensi PRD
§2.3 (formula Trust Score), §9 (API spec), §12 (Data Integrity).
