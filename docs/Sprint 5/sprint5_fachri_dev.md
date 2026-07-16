> Direvisi 2026-07-14 — sinkron ulang dengan label JIRA (skema granular 13-sprint), menggantikan versi kompresi 6-sprint sebelumnya.

# Sprint 5: Home Feed, Metrics Endpoints & Negotiation Core — Task Plan untuk Fachri

## Peran di sprint ini
**Satu ticket: FG-15 (Buyer: Home Feed + Search & Filter).** Sprint yang lebih ringan setelah 2 ticket di Sprint 4 (FG-13, FG-14). Data listing untuk uji feed sudah tersedia dari FG-14 (Sprint 4, punyamu sendiri) — tidak perlu menunggu siapapun untuk mulai.

## Task Checklist

### FG-15 — Buyer: Home Feed + Search & Filter
- [ ] Home Feed: listing (foto, harga per unit, lokasi petani) dengan infinite scroll/pagination sederhana
- [ ] Search page terpisah dengan filter: kategori, region/lokasi petani, rentang harga — konsumsi endpoint dari FG-13 (Sprint 4)
- [ ] State hasil kosong yang jelas ("Tidak ada hasil"), bukan layar kosong tanpa penjelasan
- [ ] State feed kosong per kategori (belum ada listing sama sekali di kategori itu)
- [ ] Tap listing/nama farmer → siapkan navigasi ke Farmer Public Profile — **screen-nya sendiri baru dibangun Hafizh di FG-16 (Sprint 6)**, jadi cukup siapkan route/stub link sesuai nama yang sudah disepakati bersama di Sprint 4, sambungkan penuh begitu FG-16 selesai

## File/folder yang kamu sentuh
```
lib/features/listing/**  (home feed, search)
```

## Sync point dengan teammate
- **Koordinasi dengan Hafizh**: route navigasi ke profil farmer (`/farmer-profile/:id`) sudah disepakati di Sprint 4 — pastikan masih konsisten, karena screen tujuannya (FG-16) baru dibangun Hafizh sprint depan.

## Definition of Done
- [ ] Buyer bisa browse feed + search dengan berbagai kombinasi filter, state "Tidak ada hasil" muncul saat filter tidak menghasilkan apapun — **cara cek**: video demo scroll + search + screenshot state kosong
- [ ] Tap listing/nama farmer mengarah ke route yang benar (walau screen tujuan penuh baru ada Sprint 6)

## Referensi PRD
§3.1, §4.1, §9, §15.
