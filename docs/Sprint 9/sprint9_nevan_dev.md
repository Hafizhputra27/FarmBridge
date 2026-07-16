# Sprint 9: Recurring Order UI — Task Plan untuk Nevan

## Peran di sprint ini
**Satu ticket kecil: FG-60 (bagian backend) — guard cegah archive listing yang masih terikat recurring order aktif.** Ini menutup edge case §11 ke-8 (dari 9 total) yang sebelumnya tidak punya owner sama sekali. Ringan, tapi wajib supaya tabel edge case §11 benar-benar lengkap saat QA (FG-48, Sprint 10). Bagian UI-nya (pesan error) dikerjakan Fachri di ticket yang sama.

**Kenapa ini kamu**: kamu pemilik migration & seluruh logic integritas data listing/recurring (FG-2, FG-35, FG-22). Guard ini murni aturan data — paling aman ditegakkan di backend, bukan cuma dicegah di UI.

## Task Checklist

### FG-60 (backend) — Guard archive listing dgn recurring aktif
- [ ] Sebelum listing boleh di-archive/`status='archived'` atau dihapus, cek `recurring_orders` terkait `listing_id` dengan `status='active'`
- [ ] Kalau ada minimal 1 recurring aktif → tolak operasi (kembalikan error jelas, mis. `409` dengan pesan "Listing masih terikat N recurring order aktif")
- [ ] Kalau tidak ada → izinkan archive/delete seperti biasa
- [ ] Enforce di level backend (Edge Function / RLS / trigger, bukan hanya validasi client) supaya tidak bisa di-bypass
- [ ] Sediakan info jumlah/daftar recurring aktif ke Fachri untuk pesan UI-nya

## File/folder yang kamu sentuh
```
supabase/functions/archive-listing/**   (atau guard di endpoint update listing existing)
supabase/migrations/*.sql               (jika pilih enforce lewat trigger/policy)
```

## Sync point dengan teammate
- **Kabari Fachri** bentuk error response FG-60 (kode + field jumlah recurring aktif) supaya dia tinggal render pesannya di UI.
- **Butuh FG-37 (Hafizh, Sprint 8)** sudah ada supaya ada `recurring_orders` berstatus active untuk diuji.

## Potensi conflict & cara handle
- Kalau enforce lewat migration/trigger, ini menyentuh `supabase/migrations/` — tetap kamu satu-satunya penulis migration (Aturan Playbook #5), jadi aman.

## Definition of Done
- [ ] Archive listing yang punya recurring aktif → ditolak dengan error jelas — **cara cek**: buat recurring active untuk sebuah listing, coba archive listing itu, pastikan gagal + pesannya benar
- [ ] Archive listing tanpa recurring aktif → berhasil normal
- [ ] Ditambahkan ke checklist verifikasi edge case §11 (FG-48, Sprint 10)

## Referensi PRD
§11 (edge case: "Farmer menghapus/mengarsipkan listing yang sedang terikat recurring_orders aktif"), §6.
