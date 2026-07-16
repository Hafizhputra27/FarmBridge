# Project Plan: FG-57 — Flutter Project Init

> Dibuat 16 Juli 2026 · Fachri · Sprint 1 Foundation Kickoff

---

## Ringkasan

| | |
|---|---|
| **Ticket** | FG-57 (subtask FG-11) |
| **PIC** | Fachri |
| **Sprint** | 1 — Foundation Kickoff |
| **Waktu estimasi** | 15-20 menit |
| **Dependency** | Tidak ada (paralel dari T+0) |
| **Branch target** | `fachri_dev` |

---

## Task Breakdown

```
FG-57 Flutter Project Init
│
├── T1: Buat struktur folder           (1 mnt)
│   ├── lib/core/router/
│   ├── lib/features/buyer/home/
│   ├── lib/features/farmer/home/
│   └── lib/shared/widgets/
│
├── T2: Tambah dependencies            (3 mnt)
│   ├── Edit pubspec.yaml (+6 package)
│   └── flutter pub get
│
├── T3: Buat app_router.dart           (5 mnt)
│   ├── Provider role dummy
│   ├── GoRouter dengan redirect
│   ├── ShellRoute buyer + farmer
│   └── PlaceholderScreen widget
│
├── T4: Rewrite main.dart              (5 mnt)
│   ├── Supabase.initialize() + fallback
│   ├── ProviderScope + ConsumerWidget
│   └── MaterialApp.router
│
└── T5: Verifikasi                     (3 mnt)
    ├── flutter run
    ├── flutter analyze
    └── Commit ke fachri_dev
```

---

## Deliverables

| File | Aksi | Output |
|---|---|---|
| `pubspec.yaml` | Edit | +6 dependency di `dependencies:` |
| `lib/main.dart` | Rewrite total | ~30 baris (hapus 122 baris counter app) |
| `lib/core/router/app_router.dart` | File baru | ~70 baris (GoRouter + redirect + placeholder) |
| `lib/features/buyer/home/` | Folder baru | `.gitkeep` |
| `lib/features/farmer/home/` | Folder baru | `.gitkeep` |
| `lib/shared/widgets/` | Folder baru | `.gitkeep` |

---

## Spesifikasi Teknis per Deliverable

### T2 — `pubspec.yaml`

Tambahkan setelah `cupertino_icons`:

```yaml
  supabase_flutter: ^2.8.4
  go_router: ^14.8.1
  flutter_riverpod: ^2.6.1
  cached_network_image: ^3.4.1
  image_picker: ^1.1.2
  shared_preferences: ^2.3.5
```

| Package | Dipakai di Sprint | Alasan |
|---|---|---|
| `supabase_flutter` | 1 (init), 3+ (auth/data) | Backend client |
| `go_router` | 1 (skeleton), 3+ (routing) | Role-based navigation |
| `flutter_riverpod` | 1 (dummy), 3+ (state) | State management, dipakai redirect snippet |
| `cached_network_image` | 4+ (FG-14 foto) | Placeholder requirement |
| `image_picker` | 4 (FG-14 upload) | Requirement FG-14 |
| `shared_preferences` | 3 (FG-11 role+nama) | Simpan role & nama lokal (PRD §13.1) |

### T3 — `lib/core/router/app_router.dart`

3 komponen:

| Komponen | Detail |
|---|---|
| `currentUserRoleProvider` | `Provider<String?>` return `null` (dummy untuk FG-11) |
| `routerProvider` | `GoRouter` dengan `redirect:` role-based + `routes:` berisi `/role-picker` + `ShellRoute` spread buyer/farmer |
| `buyerRoutes` + `farmerRoutes` | Dua list `RouteBase` terpisah, di-spread pakai `...` ke `ShellRoute` |
| `PlaceholderScreen` | Widget scaffold sederhana menerima `title`, dipakai di semua route sementara |

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final currentUserRoleProvider = Provider<String?>((ref) {
  // TODO FG-11: baca role dari SharedPreferences, bukan hardcode null
  return null;
});

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/role-picker',
    redirect: (context, state) {
      final role = ref.read(currentUserRoleProvider);
      final isBuyerRoute = state.matchedLocation.startsWith('/buyer');
      final isFarmerRoute = state.matchedLocation.startsWith('/farmer');
      if (role == null) return '/role-picker';
      if (isBuyerRoute && role != 'buyer') return '/farmer';
      if (isFarmerRoute && role != 'farmer') return '/buyer';
      return null;
    },
    routes: [
      GoRoute(
        path: '/role-picker',
        builder: (context, state) => const PlaceholderScreen(title: 'Role Picker'),
      ),
      ShellRoute(
        builder: (context, state, child) => child,
        routes: [
          ...buyerRoutes,
          ...farmerRoutes,
        ],
      ),
    ],
  );
});

final buyerRoutes = <RouteBase>[
  GoRoute(
    path: '/buyer',
    builder: (context, state) => const PlaceholderScreen(title: 'Buyer Home'),
  ),
];

final farmerRoutes = <RouteBase>[
  GoRoute(
    path: '/farmer',
    builder: (context, state) => const PlaceholderScreen(title: 'Farmer Home'),
  ),
];

class PlaceholderScreen extends StatelessWidget {
  final String title;
  const PlaceholderScreen({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(child: Text('$title — placeholder')),
    );
  }
}
```

### T4 — `lib/main.dart`

3 bagian kunci:

| Bagian | Detail | Kenapa |
|---|---|---|
| `Supabase.initialize()` dalam `try-catch` | App tidak crash jika credential belum ada | FG-2 belum tentu selesai |
| `ProviderScope(child: FarmBridgeApp())` | Root Riverpod | Semua provider (termasuk router) bisa diakses |
| `MaterialApp.router(routerConfig: router)` | Ganti `MaterialApp` biasa | GoRouter butuh `.router` constructor |

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/router/app_router.dart';

bool _supabaseReady = false;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Supabase.initialize(
      url: 'https://xxxxxxxxxx.supabase.co', // TODO: ganti dengan URL project
      anonKey: 'xxxxxxxxxx',                 // TODO: ganti dengan anon key
    );
    _supabaseReady = true;
  } catch (e) {
    debugPrint('Supabase init skipped: $e');
  }

  runApp(const ProviderScope(child: FarmBridgeApp()));
}

class FarmBridgeApp extends ConsumerWidget {
  const FarmBridgeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'FarmBridge',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      routerConfig: router,
    );
  }
}
```

---

## Acceptance Criteria (Definition of Done)

```
[x] flutter run jalan tanpa error di emulator Android (diverifikasi via Chrome web)
[x] Landing page placeholder tampil ("Role Picker — placeholder")
[x] flutter analyze 0 errors, 0 warnings
[x] Struktur folder lib/features/, lib/core/, lib/shared/ ada
[x] Semua 6 dependency terpasang, flutter pub get sukses
[x] GoRouter skeleton /buyer, /farmer, /role-picker terdefinisi
[x] Supabase.initialize() terpanggil (dengan fallback jika credential kosong)
[x] Commit ke fachri_dev
```

---

## Risiko & Mitigasi

| Risiko | Prob. | Dampak | Mitigasi |
|---|---|---|---|
| `Supabase.initialize()` crash karena credential kosong | Tinggi | App tidak bisa dijalankan | `try-catch` + flag `_supabaseReady` |
| Versi package conflict dengan SDK `^3.12.2` | Rendah | `pub get` gagal | Turunkan versi package atau kendurkan `environment.sdk` |
| Folder kosong tidak ter-track Git | Rendah | Tim bingung struktur tidak muncul | Tambah `.gitkeep` |
| Merge conflict saat tarik `hafizh_dev` nanti | Sedang | `main.dart` perlu resolve manual | Fachri commit duluan, resolve saat pull -- ringan |

---

## Urutan Eksekusi

```
T1 ──► T2 ──► T3 ──► T4 ──► T5
 │       │      │      │      │
 │       │      │      │      └── flutter run + analyze + commit
 │       │      │      └── Rewrite main.dart
 │       │      └── Buat app_router.dart
 │       └── Edit pubspec.yaml + flutter pub get
 └── mkdir 5 folder
```

Semua task berurutan tapi independen terhadap orang lain. Fachri bisa jalan dari T1 ke T5 tanpa interupsi, **15-20 menit selesai.**
