> Direvisi 2026-07-14 — sinkron ulang dengan label JIRA (skema granular 13-sprint), menggantikan versi kompresi 6-sprint sebelumnya.

# Sprint 6: Profile UI, Chat & Buy Now — Task Plan untuk Hafizh

## Peran di sprint ini
**Satu ticket: FG-16 (Buyer & Farmer Public Profile UI).** Dependency-nya (FG-20, Sprint 5, kamu sendiri) sudah selesai — tidak ada lagi yang perlu ditunggu untuk mulai.

## Catatan penting sebelum mulai
Trust Score & Buyer Metrics belum akan punya data "fulfilled" asli sampai FG-32 (fulfill, Sprint 7) berjalan — walau FG-29 (Buy Now, sprint ini, Nevan) sudah mulai membentuk `transaction PENDING`. Artinya:
- State yang **natural untuk ditest end-to-end sprint ini justru state kosong** ("Belum ada riwayat transaksi", field 0/null) — itu memang kondisi asli semua akun di titik ini.
- State "ada data" cuma bisa divalidasi lewat **insert manual dummy** ke `trust_metrics`/`buyer_metrics` langsung di Supabase Studio, bukan lewat trigger sungguhan.

## Task Checklist

### FG-16 — Buyer & Farmer Public Profile UI
- [ ] Farmer Public Profile: `on_time_delivery_rate`, `rejection_rate`, `fulfillment_consistency`, `total_transactions` — **3 angka terpisah**, bukan skor tunggal (§2.3)
- [ ] State **"Belum ada riwayat transaksi"** untuk farmer baru — bukan `0%` (§10.1 AC, ini state yang paling sering muncul sprint ini)
- [ ] Buyer Public Profile: `total_procurement`, `active_orders_count`, `fulfillment_rate`, `avg_monthly_volume`
- [ ] Label UI `fulfillment_rate` pakai **"Reliability"/"Completion Rate"** — BUKAN "Payment Rate" (PRD eksplisit melarang label ini, tidak ada tracking pembayaran sungguhan)
- [ ] Konsumsi endpoint dari FG-20 (Sprint 5), bukan hitung ulang di client
- [ ] Entry point dari feed (FG-15, Fachri, Sprint 5) ke profil farmer — route sudah disepakati sejak Sprint 4, tinggal sambungkan

## File/folder yang kamu sentuh
```
lib/features/profile/**
```

## Sync point dengan teammate
- Tidak ada dependency masuk yang belum selesai — FG-20 (Sprint 5) sudah siap.
- Pastikan route entry point dari FG-15 (Fachri, Sprint 5) masih konsisten dengan yang disepakati di Sprint 4.

## Definition of Done
- [ ] Farmer baru (belum ada transaksi) menampilkan "Belum ada riwayat transaksi", bukan 0% — **cara cek**: buka profil akun farmer dummy, screenshot state-nya
- [ ] Label UI buyer metrics terkonfirmasi bukan "Payment Rate" — **cara cek**: screenshot UI, cocokkan teks label
- [ ] State "ada data" tervalidasi lewat insert manual di Supabase Studio, tampil benar di UI

## Referensi PRD
§2.3, §2.4, §9, §10.1, §12 (Data Integrity).
