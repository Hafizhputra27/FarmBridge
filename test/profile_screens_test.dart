import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:farmbridge/features/profile/providers/profile_metrics_provider.dart';
import 'package:farmbridge/features/profile/screens/farmer_profile_screen.dart';
import 'package:farmbridge/features/profile/screens/buyer_profile_screen.dart';

void main() {
  testWidgets('FarmerProfileScreen shows 3 metrics when data exists',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          trustMetricsProvider('farmer-1').overrideWith((ref) async => {
                'on_time_delivery_rate': 75,
                'rejection_rate': 20,
                'fulfillment_consistency': 75,
                'total_transactions': 5,
                'window_days': 90,
              }),
        ],
        child: const MaterialApp(
          home: FarmerProfileScreen(farmerId: 'farmer-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Pengiriman Tepat Waktu'), findsOneWidget);
    expect(find.text('75%'), findsWidgets);
    expect(find.text('Tingkat Penolakan'), findsOneWidget);
    expect(find.text('Konsistensi Pemenuhan'), findsOneWidget);
    expect(find.text('TOTAL TRANSAKSI'), findsOneWidget);
    expect(find.text('Belum ada riwayat transaksi'), findsNothing);
  });

  testWidgets('FarmerProfileScreen shows empty state when total_transactions is 0',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          trustMetricsProvider('farmer-2').overrideWith((ref) async => {
                'on_time_delivery_rate': 0,
                'rejection_rate': 0,
                'fulfillment_consistency': 0,
                'total_transactions': 0,
                'window_days': 90,
              }),
        ],
        child: const MaterialApp(
          home: FarmerProfileScreen(farmerId: 'farmer-2'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Belum ada riwayat transaksi'), findsOneWidget);
    expect(find.text('Pengiriman Tepat Waktu'), findsNothing);
  });

  testWidgets('FarmerProfileScreen shows not-found state on 404 (null)',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          trustMetricsProvider('farmer-missing')
              .overrideWith((ref) async => null),
        ],
        child: const MaterialApp(
          home: FarmerProfileScreen(farmerId: 'farmer-missing'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Profil tidak ditemukan'), findsOneWidget);
  });

  testWidgets('BuyerProfileScreen shows 4 metrics with Reliability label, not Payment Rate',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          buyerMetricsProvider('buyer-1').overrideWith((ref) async => {
                'total_procurement': 1200000,
                'active_orders_count': 2,
                'fulfillment_rate': 100,
                'avg_monthly_volume': 100,
                'window_days': 90,
              }),
        ],
        child: const MaterialApp(
          home: BuyerProfileScreen(buyerId: 'buyer-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Total Pembelian'), findsOneWidget);
    expect(find.text('Pesanan Aktif'), findsOneWidget);
    expect(find.text('Reliability (Completion Rate)'), findsOneWidget);
    expect(find.text('Volume Rata-rata per Bulan'), findsOneWidget);
    expect(find.textContaining('Payment Rate'), findsNothing);
    expect(find.text('Belum ada riwayat transaksi'), findsNothing);
  });

  testWidgets('BuyerProfileScreen shows empty state when no procurement/orders',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          buyerMetricsProvider('buyer-2').overrideWith((ref) async => {
                'total_procurement': 0,
                'active_orders_count': 0,
                'fulfillment_rate': 0,
                'avg_monthly_volume': null,
                'window_days': 90,
              }),
        ],
        child: const MaterialApp(
          home: BuyerProfileScreen(buyerId: 'buyer-2'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Belum ada riwayat transaksi'), findsOneWidget);
    expect(find.text('Total Pembelian'), findsNothing);
  });
}
