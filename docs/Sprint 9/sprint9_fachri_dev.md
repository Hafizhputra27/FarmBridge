# Sprint 9: Recurring Order UI — Task Plan untuk Fachri

## Peran di sprint ini
**FG-39 (My Recurring Orders + Detail UI) + bagian UI FG-60 (pesan error guard archive listing).** Bagian backend FG-60 dikerjakan Nevan (lihat `sprint9_nevan_dev.md`); kamu tinggal render pesan errornya di UI.

## Task Checklist

### FG-39 — My Recurring Orders + Detail UI
- [ ] List My Recurring Orders: status (Active/Paused/Cancelled), listing terkait, `next_order_date`, sesuai frame Figma "My Recurring Orders [217:347]"
- [ ] Detail screen per status dengan aksi Pause/Cancel/Resume + modal konfirmasi
- [ ] Cancel → tombol Resume tidak lagi tersedia (§6, tidak pernah kembali `active`)
- [ ] Entry point dari CTA FG-40 (Hafizh) dan dari menu tersendiri

### FG-60 (UI) — pesan error guard archive listing
- [ ] Saat farmer coba archive/hapus listing yang punya recurring aktif, tangkap error dari backend Nevan (FG-60) dan tampilkan pesan jelas: "Selesaikan/pause recurring order terkait dulu sebelum archive listing ini"
- [ ] Idealnya arahkan farmer ke daftar recurring order terkait listing tsb
- [ ] Konfirmasi ke Nevan bentuk error response (kode + jumlah recurring aktif) sebelum wiring

## Catatan gap yang masih terbuka (bukan tanggung jawabmu)
UI konfirmasi kesiapan farmer di H-1 (opsi konfirmasi/reschedule/pause, PRD §4.1) belum punya ticket sama sekali. Kalau sprint ini selesai cepat, ini kandidat kuat diangkat jadi ticket baru sebelum masuk QA (Sprint 10+).

## File/folder yang kamu sentuh
```
lib/features/recurring-order/**
lib/features/listing/**        (pesan error archive — FG-60 UI)
```

## Sync point dengan teammate
- **Tunggu Hafizh** FG-37 (Sprint 8) untuk data asli.
- **Koordinasi dengan Nevan** (FG-60) — sepakati bentuk error response guard archive sebelum wiring pesannya.

## Definition of Done
- [ ] Buyer dengan beberapa recurring order → semua tampil dengan status masing-masing
- [ ] Cancel → status berubah, tombol Resume tidak lagi tersedia
- [ ] Archive listing dgn recurring aktif → muncul pesan error jelas (FG-60 UI), tidak silent fail

## Referensi PRD
§4.1, §6, §15.
