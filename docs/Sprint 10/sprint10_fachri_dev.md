# Sprint 10: Integration Testing — Task Plan untuk Fachri

## Peran di sprint ini
**Satu ticket: FG-45 (E2E test: realtime chat sync <2 detik).**

## Task Checklist

### FG-45 — E2E test: realtime chat sync <2 detik
- [ ] Kirim pesan dari akun buyer, ukur waktu sampai muncul di akun farmer (device berbeda), dan sebaliknya
- [ ] Test di kondisi jaringan wajar (wifi venue kalau memungkinkan, bukan cuma localhost)
- [ ] 10 kali percobaan, rata-rata harus < 2 detik
- [ ] Lag > 2 detik → catat sebagai bug ticket terpisah dengan kemungkinan penyebab

## File/folder yang kamu sentuh
```
docs/qa/e2e-realtime-latency.md
```

## Definition of Done
- [ ] Data pengukuran 10 percobaan, rata-rata < 2 detik, atau bug ticket dibuat kalau tidak

## Referensi PRD
§12.
