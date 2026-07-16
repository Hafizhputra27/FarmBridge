> Direvisi 2026-07-14 — sinkron ulang dengan label JIRA (skema granular 13-sprint), menggantikan versi kompresi 6-sprint sebelumnya.

# Sprint 1: Foundation Kickoff — Task Plan untuk Fachri

## Peran di sprint ini
**Satu ticket: FG-57 (Flutter project init — gap-fill, subtask baru di bawah FG-11).** Sebelumnya ini tidak punya ticket JIRA sendiri sama sekali — cuma dikerjakan informal sebagai bagian tersembunyi dari FG-11 di plan lama. Sekarang sudah diformalkan: FG-57 murni scaffold project (flutter create, struktur folder, GoRouter skeleton, dependencies dasar), dikerjakan **paralel dari T+0, tanpa menunggu FG-9** (desain role picker, Alexander) maupun ticket manapun lain. FG-11 (build role picker flow sungguhan, UI + auth) baru jadi ticketmu di Sprint 3, setelah FG-9 dan FG-3 (Auth, Sprint 2) selesai.

**Kenapa dipisah jadi dua ticket**: scaffold project (struktur folder, dependencies, routing skeleton) tidak bergantung pada desain maupun backend apapun — kerjaan ini bisa dan seharusnya dimulai paling awal supaya tidak ada waktu terbuang menunggu. Role picker sungguhan (FG-11) baru make sense dikerjakan begitu ada frame Figma untuk diikuti dan Auth live untuk diuji.

## Task Checklist

### FG-57 — Flutter project init (gap-fill)
- [ ] `flutter create farmbridge`, struktur folder `lib/features/`, `lib/core/`, `lib/shared/`
- [ ] Install dependencies: `supabase_flutter`, `go_router`, riverpod (atau state management pilihan tim), `cached_network_image`, `image_picker` (dibutuhkan sendiri untuk FG-14, Sprint 4), `shared_preferences` (simpan role & nama lokal di device, pola PRD §13.1)
- [ ] Setup `GoRouter` dengan role-based redirect skeleton: `/buyer/*` dan `/farmer/*`, tolak akses ke route milik role lain — isi provider role-nya nanti begitu FG-11 (Sprint 3) jalan
- [ ] Landing page sementara (placeholder) untuk verifikasi project jalan
- [ ] Di `lib/main.dart`, panggil `Supabase.initialize()` — pakai project Supabase yang sudah di-share Nevan, walau schema masih dalam proses; tidak masalah kalau nanti perlu re-run setelah FG-2 selesai
- [ ] Struktur `routes` di `app_router.dart` disiapkan sebagai list yang di-spread dari file per-fitur (`...homeFeedRoutes`, dst) sejak awal — menghindari restrukturisasi besar saat Sprint 4-5 mulai nambah banyak route sekaligus

**Detail teknis — pola redirect GoRouter (skeleton, provider role diisi penuh di FG-11)**:
```dart
redirect: (context, state) {
  final role = ref.read(currentUserRoleProvider); // 'farmer' | 'buyer' | null
  final isBuyerRoute = state.matchedLocation.startsWith('/buyer');
  final isFarmerRoute = state.matchedLocation.startsWith('/farmer');
  if (role == null) return '/role-picker';
  if (isBuyerRoute && role != 'buyer') return '/farmer';
  if (isFarmerRoute && role != 'farmer') return '/buyer';
  return null; // no redirect
}
```

## Sambil menunggu Sprint 3 (opsional, tidak wajib)
- Baca ulang §15 PRD (pemetaan requirement → screen Figma) untuk ticket-ticketmu ke depan: FG-11 (Sprint 3), FG-13/FG-14 (Sprint 4), FG-15 (Sprint 5), FG-25/FG-26 (Sprint 6)
- **FG-14 (Sprint 4) punya open question yang belum terjawab**: PRD mencatat ada 3 varian "Create Listing" di Figma, belum jelas mana yang final. Ini belum mendesak sprint ini (FG-14 masih 3 sprint lagi), tapi kalau ada waktu longgar, mulai tanyakan ke Alexander/Hafizh dari sekarang — cukup jauh idle time di Sprint 2 nanti untuk menuntaskannya sebelum Sprint 4 benar-benar dimulai.

## Sync point dengan teammate
- **Tidak ada blocker masuk untuk FG-57** — bisa mulai dan selesai penuh sprint ini tanpa menunggu siapapun.
- **Tarik `hafizh_dev`** begitu Hafizh & Nevan kabari merge selesai (migration FG-2 + CI/CD + FCM) — `lib/main.dart`, `pubspec.yaml` mungkin berubah kalau ada env var tambahan dari mereka.

## File/folder yang kamu sentuh
```
lib/main.dart
lib/core/router/app_router.dart
pubspec.yaml
android/, ios/ (hasil generate flutter create)
```

## Potensi conflict & cara handle
- Kamu scaffold `lib/main.dart` & `pubspec.yaml` duluan, sementara Nevan (`Supabase.initialize()` config) dan Hafizh (FCM listener, FG-6) juga punya kepentingan di sana. Supaya tidak tabrakan: commit versi awalmu ke `fachri_dev`, dan begitu ada perubahan dari mereka yang perlu masuk, tarik lewat merge `hafizh_dev`, jangan minta mereka edit langsung branch-mu.

## Definition of Done
- [ ] `flutter run` jalan tanpa error di emulator Android, landing page placeholder tampil
- [ ] Struktur folder `lib/features/`, `lib/core/`, `lib/shared/` sudah ada dan konsisten dengan rencana fitur ke depan
- [ ] Dependencies inti (`supabase_flutter`, `go_router`, state management, `cached_network_image`, `image_picker`, `shared_preferences`) terpasang tanpa conflict versi
- [ ] `GoRouter` skeleton `/buyer/*` dan `/farmer/*` ada (redirect logic belum aktif penuh — provider role masih dummy, itu bagian FG-11 Sprint 3)
- [ ] `Supabase.initialize()` terpanggil tanpa error saat app start

## Referensi PRD
§7 (Tech Stack), §13.1 (role & nama tersimpan lokal), §15 (pemetaan requirement → screen, untuk prep ticket-ticket ke depan).
