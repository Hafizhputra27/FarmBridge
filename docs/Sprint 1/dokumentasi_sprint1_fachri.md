# Sprint 1 — Dokumentasi Fachri (FG-57)

**Tanggal:** 16 Juli 2026  
**Status:** ✅ Selesai  
**Branch:** `fachri_dev`  
**Commit:** `3d36930`

---

## Ringkasan

FG-57 Flutter Project Scaffold — inisialisasi project Flutter FarmBridge dengan struktur folder, dependencies inti, GoRouter skeleton dengan role-based redirect, dan Supabase fallback. Dikerjakan paralel dari T+0 tanpa dependency ke ticket lain.

---

## Deliverables

| File | Aksi | Detail |
|---|---|---|
| `pubspec.yaml` | Edit | +6 dependency inti |
| `pubspec.lock` | Generated | 98 package terpasang |
| `lib/main.dart` | Rewrite total | ProviderScope, ConsumerWidget, MaterialApp.router, Supabase fallback |
| `lib/core/router/app_router.dart` | File baru | GoRouter skeleton + redirect + PlaceholderScreen |
| `lib/features/buyer/home/` | Folder baru | `.gitkeep` |
| `lib/features/farmer/home/` | Folder baru | `.gitkeep` |
| `lib/shared/widgets/` | Folder baru | `.gitkeep` |
| `test/widget_test.dart` | Edit | Uji `FarmBridgeApp` dengan ProviderScope |

---

## Dependencies Terpasang

| Package | Digunakan di Sprint |
|---|---|
| `supabase_flutter` | 1 (init), 3+ (auth/data) |
| `go_router` | 1 (skeleton), 3+ (routing) |
| `flutter_riverpod` | 1 (dummy), 3+ (state management) |
| `cached_network_image` | 4+ (FG-14 foto) |
| `image_picker` | 4 (FG-14 upload) |
| `shared_preferences` | 3 (FG-11 role + nama) |

---

## Verifikasi

| Item | Hasil |
|---|---|
| `flutter analyze` | 0 issues |
| `flutter test` | All tests passed |
| `flutter pub get` | Sukses, 98 package |

---

## Catatan

- **Supabase credential** masih placeholder (`xxxxxxxxxx`) — ganti setelah FG-2 Nevan selesai dan project URL/key dikonfirmasi
- **Provider `currentUserRoleProvider`** masih return `null` (dummy) — implementasi penuh di FG-11 Sprint 3
- **GoRouter redirect** skeleton sudah berfungsi, tapi role determination belum aktif — itu bagian FG-11
- **Tidak ada blocker** — FG-57 dikerjakan paralel penuh dari T+0 tanpa menunggu ticket lain

---

## Referensi

- PRD §7 (Tech Stack), §13.1 (role & nama lokal)
- `docs/Sprint 1/sprint1_fachri_dev.md`
- `docs/Sprint 1/projek_plan_fachri_sprint1.md`
