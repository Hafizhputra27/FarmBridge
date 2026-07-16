# Sprint 10: Integration Testing — Task Plan untuk Hafizh

## Peran di sprint ini
**FG-44 (E2E negotiation→transaction→trust_metrics) dan FG-47 (E2E recurring order full cycle).**

## Task Checklist

### FG-44 — E2E test: negotiation → transaction → trust_metrics pipeline
- [ ] Skenario penuh: `negotiation` → counter → accept → `transaction` pending → fulfill → cek `trust_metrics` ter-update (§2.3)
- [ ] Skenario reject: `transaction` pending → reject → cek `rejection_rate` ter-update & `quantity_available` rollback
- [ ] Catat bug/gap integrasi sebagai ticket terpisah

### FG-47 — E2E test: recurring order full cycle (manual-trigger)
- [ ] Create recurring order → manual-trigger job pg_cron → cek `transaction` baru terbentuk
- [ ] Skenario skip: manual-trigger saat farmer belum konfirmasi/stok kurang → `recurring_orders` tetap `active`, `transaction` tidak terbentuk **(hasil ini juga jadi bukti baris 9 checklist edge case FG-48 milik Nevan — kabari dia)**
- [ ] Cancel di tengah siklus pending → transaksi pending tetap jalan

## File/folder yang kamu sentuh
```
docs/qa/e2e-negotiation-pipeline.md
docs/qa/e2e-recurring-order.md
```

## Sync point dengan teammate
- **Kabari Nevan** hasil skenario skip FG-47 untuk melengkapi baris 9 di FG-48.

## Definition of Done
- [ ] FG-44: pipeline accept→fulfill dan reject dua-duanya terverifikasi dengan bukti
- [ ] FG-47: 3 skenario (create→trigger sukses, skip, cancel-mid-cycle) terverifikasi dengan log

## Referensi PRD
§2.3, §5.1, §6, §9, §10.4, §10.5, §11.
