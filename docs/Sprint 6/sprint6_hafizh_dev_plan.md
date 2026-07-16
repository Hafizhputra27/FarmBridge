# Sprint 6 (Hafizh) — FG-16 Buyer & Farmer Public Profile UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

> **Catatan eksekusi:** Sesuai `docs/CLAUDE.md`, Claude tidak menjalankan operasi git yang mengubah state repo. Commit/push tetap dijalankan Hafizh sendiri di terminal.

**Goal:** Farmer Public Profile screen (3 angka trust metrics terpisah) dan Buyer Public Profile screen (4 angka buyer metrics), keduanya konsumsi endpoint FG-20 (Sprint 5), dengan state kosong "Belum ada riwayat transaksi" untuk data nol.

**Konteks penting:** Ini UI Flutter pertama Hafizh di project ini — `lib/features/profile/` belum ada, `buyer/home`/`farmer/home` masih placeholder kosong (`.gitkeep`). Tidak ada pola repository/service layer yang sudah ada untuk manggil Edge Function dari Flutter — konvensi yang dipakai `auth_provider.dart` adalah panggil `Supabase.instance.client` langsung di provider, tanpa layer abstraksi tambahan. Diikuti di sini juga (YAGNI, konsisten dengan codebase).

**Entry point belum ada:** FG-15 (Fachri, home feed yang nge-link ke `/farmer-profile/:id`) belum dibangun (cek `fachri_dev` branch — belum ada commit FG-14/FG-15). Jadi testing sprint ini pakai **navigasi URL langsung** di Chrome web target (`flutter run -d chrome`, GoRouter mendukung deep-link URL), bukan lewat tap UI dari feed — sesuai catatan `sprint6_hafizh_dev.md` yang memang bilang state kosong itu paling natural buat ditest sprint ini.

## Bug prasyarat yang harus difix dulu

`lib/core/router/app_router.dart` — `isBuyerRoute`/`isFarmerRoute` pakai `matchedLocation.startsWith('/buyer')` / `startsWith('/farmer')`. Route baru `/farmer-profile/:id` akan **salah kecocokan** dengan `startsWith('/farmer')` (prefix string, bukan segment) → buyer yang buka profil farmer bakal ke-redirect balik ke `/buyer` oleh guard yang salah sasaran. Fix: cocokkan exact atau dengan trailing slash, bukan raw prefix.

## Konvensi route (sudah disepakati dengan Fachri di Sprint 4)

`/farmer-profile/:id` — dipakai FG-15 (Fachri) nanti. `/buyer-profile/:id` — belum ada ticket lain yang butuh sprint ini, dibuat simetris (bukan kesepakatan formal, keputusan Hafizh sendiri karena tidak ada yang menunggu).

---

### Task 0: Fix redirect guard di `app_router.dart`

- [x] **Step 1: Perbaiki prefix match jadi exact-or-slash**

```dart
// lib/core/router/app_router.dart — di dalam redirect callback
final isBuyerRoute = state.matchedLocation == '/buyer' ||
    state.matchedLocation.startsWith('/buyer/');
final isFarmerRoute = state.matchedLocation == '/farmer' ||
    state.matchedLocation.startsWith('/farmer/');
```

- [x] **Step 2: Tambah dua route baru** (top-level, sejajar `buyerRoutes`/`farmerRoutes`, BUKAN di dalam salah satunya — supaya tidak kena role-gate `isBuyerRoute`/`isFarmerRoute` sama sekali, karena kedua profil harus bisa diakses lintas role)

```dart
// di dalam routes: [...] pada routerProvider, sejajar ShellRoute
GoRoute(
  path: '/farmer-profile/:id',
  builder: (context, state) =>
      FarmerProfileScreen(farmerId: state.pathParameters['id']!),
),
GoRoute(
  path: '/buyer-profile/:id',
  builder: (context, state) =>
      BuyerProfileScreen(buyerId: state.pathParameters['id']!),
),
```

---

### Task 1: Provider — panggil `trust-metrics`/`buyer-metrics`

**Files:** Create `lib/features/profile/providers/profile_metrics_provider.dart`

- [x] **Step 1: Tulis provider**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final trustMetricsProvider =
    FutureProvider.family<Map<String, dynamic>?, String>((ref, farmerId) async {
  try {
    final res = await Supabase.instance.client.functions
        .invoke('trust-metrics/$farmerId', method: HttpMethod.get);
    return res.data as Map<String, dynamic>;
  } on FunctionException catch (e) {
    if (e.status == 404) return null;
    rethrow;
  }
});

final buyerMetricsProvider =
    FutureProvider.family<Map<String, dynamic>?, String>((ref, buyerId) async {
  try {
    final res = await Supabase.instance.client.functions
        .invoke('buyer-metrics/$buyerId', method: HttpMethod.get);
    return res.data as Map<String, dynamic>;
  } on FunctionException catch (e) {
    if (e.status == 404) return null;
    rethrow;
  }
});
```

`null` = profile tidak ditemukan (404 dari FG-20) → screen tampilkan pesan "profil tidak ditemukan". Data dengan angka 0/null di dalamnya (bukan `null` keseluruhan) = profile ada tapi belum ada transaksi → state "Belum ada riwayat transaksi".

- [ ] **Step 2: Commit**

---

### Task 2: Farmer Public Profile screen

**Files:** Create `lib/features/profile/screens/farmer_profile_screen.dart`

- [x] **Step 1: Tulis screen** — 3 angka terpisah (`on_time_delivery_rate`, `rejection_rate`, `fulfillment_consistency`) + `total_transactions`, state kosong kalau `total_transactions == 0`.

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/profile_metrics_provider.dart';

class FarmerProfileScreen extends ConsumerWidget {
  final String farmerId;
  const FarmerProfileScreen({super.key, required this.farmerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metrics = ref.watch(trustMetricsProvider(farmerId));

    return Scaffold(
      appBar: AppBar(title: const Text('Profil Petani')),
      body: metrics.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Gagal memuat profil: $e')),
        data: (data) {
          if (data == null) {
            return const Center(child: Text('Profil tidak ditemukan'));
          }
          final totalTransactions = data['total_transactions'] as int? ?? 0;
          if (totalTransactions == 0) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Belum ada riwayat transaksi',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _MetricCard(
                label: 'Tingkat Pengiriman Tepat Waktu',
                value: '${data['on_time_delivery_rate']}%',
              ),
              _MetricCard(
                label: 'Tingkat Penolakan',
                value: '${data['rejection_rate']}%',
              ),
              _MetricCard(
                label: 'Konsistensi Pemenuhan Pesanan',
                value: '${data['fulfillment_consistency']}%',
              ),
              _MetricCard(
                label: 'Total Transaksi',
                value: '$totalTransactions',
              ),
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Berdasarkan ${data['window_days']} hari terakhir',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  const _MetricCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        title: Text(label),
        trailing: Text(
          value,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Commit**

---

### Task 3: Buyer Public Profile screen

**Files:** Create `lib/features/profile/screens/buyer_profile_screen.dart`

- [x] **Step 1: Tulis screen** — pola sama Task 2, tapi 4 metrik buyer + label `fulfillment_rate` **wajib** "Reliability" atau "Completion Rate" (bukan "Payment Rate", PRD eksplisit melarang). State kosong kalau `total_procurement == 0 && active_orders_count == 0` (buyer tidak punya field `total_transactions`, jadi dua field ini dipakai sebagai proxy "belum pernah transaksi").

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/profile_metrics_provider.dart';

class BuyerProfileScreen extends ConsumerWidget {
  final String buyerId;
  const BuyerProfileScreen({super.key, required this.buyerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metrics = ref.watch(buyerMetricsProvider(buyerId));

    return Scaffold(
      appBar: AppBar(title: const Text('Profil Pembeli')),
      body: metrics.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Gagal memuat profil: $e')),
        data: (data) {
          if (data == null) {
            return const Center(child: Text('Profil tidak ditemukan'));
          }
          final totalProcurement =
              (data['total_procurement'] as num?)?.toDouble() ?? 0;
          final activeOrders = data['active_orders_count'] as int? ?? 0;
          if (totalProcurement == 0 && activeOrders == 0) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Belum ada riwayat transaksi',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          final avgVolume = data['avg_monthly_volume'];
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _MetricCard(
                label: 'Total Pembelian',
                value: 'Rp${totalProcurement.toStringAsFixed(0)}',
              ),
              _MetricCard(
                label: 'Pesanan Aktif',
                value: '$activeOrders',
              ),
              _MetricCard(
                label: 'Reliability (Completion Rate)',
                value: '${data['fulfillment_rate']}%',
              ),
              _MetricCard(
                label: 'Volume Rata-rata per Bulan',
                value: avgVolume == null ? '-' : '$avgVolume',
              ),
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Berdasarkan ${data['window_days']} hari terakhir',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  const _MetricCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        title: Text(label),
        trailing: Text(
          value,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Commit**

---

### Task 4: Testing

- [x] **Step 1:** `flutter analyze` — 0 issue di `lib/` (`flutter analyze lib/` khusus, karena `flutter analyze` tanpa target ikut nge-scan `build/ios/SourcePackages/**` punya dependency `firebase_messaging` yang sudah error duluan, tidak terkait kode kita)
- [x] **Step 2 (revisi dari rencana awal):** rencana semula `flutter run -d chrome` + navigasi URL manual + `screencapture` — **tidak bisa dijalankan**, sandbox eksekusi Claude di sesi ini tidak (dan `screencapture`: `could not create image from display`, `System Events`: `not allowed to send keystrokes`). Selain itu route baru butuh session `role` ada dulu (redirect guard `role == null → /role-picker`), jadi navigasi URL langsung ke fresh browser tidak akan sampai ke screen tujuan tanpa login dulu.
  
  **Diganti widget test** (`test/profile_screens_test.dart`) — 5 test, pakai Riverpod provider override (`trustMetricsProvider`/`buyerMetricsProvider`) dengan data **persis sama** dengan response asli yang sudah diverifikasi via curl di Sprint 5 (bukan data karangan), assert lewat `find.text(...)` bukan lewat mata:
  - Farmer, data ada (shape sama dgn hasil curl `trust-metrics/1666543a...`) → 4 label + angka muncul, empty-state text TIDAK muncul
  - Farmer, `total_transactions: 0` → "Belum ada riwayat transaksi" muncul, label metrik tidak
  - Farmer, `null` (404) → "Profil tidak ditemukan" muncul
  - Buyer, data ada → 4 label termasuk **"Reliability (Completion Rate)"**, assert eksplisit `find.textContaining('Payment Rate')` → `findsNothing`
  - Buyer, `total_procurement`/`active_orders_count` keduanya 0 → empty-state
  
  **Hasil:** `flutter test` → `6 passed` (5 baru + 1 test lama `widget_test.dart`, tidak ada regresi).
- [ ] **Step 3 (baru — pengganti screenshot):** **Verifikasi visual manual oleh Hafizh sendiri** — jalankan `flutter run -d chrome` atau device fisik, login/onboarding dulu (role bebas), lalu di address bar atau lewat `context.push()` sementara buka `/farmer-profile/1666543a-bd53-4b22-80c7-3a5186afb2c5` dan `/buyer-profile/84a10df5-3b65-486a-af2c-d6f8f3abd07b` — pastikan layout & warna enak dilihat (widget test cuma jamin teks/logic benar, bukan estetika)
- [ ] **Step 4: Commit**

---

## Decisions Log

- **Tanpa repository/service layer terpisah**: konsisten dengan `auth_provider.dart`, panggil `Supabase.instance.client` langsung di `FutureProvider.family` — YAGNI, tidak ada consumer lain yang butuh abstraksi ini.
- **Route `/buyer-profile/:id` dibuat simetris** meski tidak ada kesepakatan formal dengan Fachri (beda dari `/farmer-profile/:id` yang sudah disepakati Sprint 4) — tidak ada ticket lain yang butuh sprint ini, aman dibuat sendiri.
- **Fix bug redirect guard** (`startsWith('/farmer')` → exact-or-slash) — prasyarat wajib, tanpa ini `/farmer-profile/:id` rusak untuk buyer yang mengakses.
- **State kosong buyer pakai proxy `total_procurement == 0 && active_orders_count == 0`** (bukan field khusus, buyer tidak punya `total_transactions`) — konsisten dengan semangat DoD walau ticket teks fokus ke farmer.
- **Testing tanpa entry point asli**: FG-15 (Fachri) belum ada, rencana awal pakai deep-link URL langsung di Chrome — direalisasikan ulang jadi widget test (lihat Task 4) karena sandbox eksekusi tidak punya akses display/screen recording.
- **Widget test, bukan screenshot manual**: sandbox tidak bisa `screencapture` (`could not create image from display`) atau UI-automation klik (`System Events` ditolak). Widget test pakai Riverpod override lebih deterministik untuk cek teks/logic (termasuk assert negatif "Payment Rate" TIDAK muncul — sesuatu yang gampang kelewat kalau cuma lihat sekilas dari screenshot), tapi tidak menggantikan cek estetika visual — itu perlu dilakukan manual oleh Hafizh (Task 4 Step 3).

## Self-Check Coverage (`sprint6_hafizh_dev.md` checklist asli → task di plan ini)

| Item checklist asli | Task di plan ini |
|---|---|
| Farmer Public Profile: 3 angka terpisah | Task 2 |
| State "Belum ada riwayat transaksi" untuk farmer baru | Task 2 (guard `total_transactions == 0`) |
| Buyer Public Profile: 4 angka | Task 3 |
| Label `fulfillment_rate` "Reliability"/"Completion Rate", bukan "Payment Rate" | Task 3 |
| Konsumsi endpoint FG-20, bukan hitung ulang di client | Task 1 |
| Entry point dari feed (FG-15) | *Belum bisa disambungkan — FG-15 belum ada, route sudah siap di sisi Hafizh, tinggal Fachri sambungkan* |
| Formula/logic terbukti benar lewat test otomatis | `test/profile_screens_test.dart`, 5 test — `flutter test` hijau |
