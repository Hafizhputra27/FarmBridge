# Sprint 8: Fulfillment UI, Recurring — Task Plan untuk Fachri

## Peran di sprint ini
**Satu ticket: FG-34 (Fulfillment Form UI + modal konfirmasi).**

## Task Checklist

### FG-34 — Fulfillment Form UI + modal konfirmasi
- [ ] Form fulfillment: input `delivered_quantity`, `actual_delivery_date`, sesuai frame Figma "Fulfillment Form [161:1155]"
- [ ] Modal konfirmasi "Anda yakin?" sebelum submit final, sesuai frame "Confirm Delivery [135:1746]" — aksi tidak bisa dibatalkan setelah tersimpan
- [ ] Setelah submit, status transaction berubah `fulfilled` real-time
- [ ] Diakses dari Transaction Detail screen (dibangun sendiri di FG-30, Sprint 7) sisi farmer, lewat tombol "Tandai Terkirim"

## File/folder yang kamu sentuh
```
lib/features/transaction/**
```

## Sync point dengan teammate
- **Tunggu Nevan** FG-32 (Sprint 7) untuk endpoint fulfill asli.

## Definition of Done
- [ ] Farmer buka transaksi pending miliknya, tekan "Tandai Terkirim", isi form, muncul modal konfirmasi
- [ ] Modal dikonfirmasi → status berubah `fulfilled` tanpa refresh manual
- [ ] Modal dibatalkan → data belum tersimpan, form tetap bisa diedit

## Referensi PRD
§4.1, §15.
