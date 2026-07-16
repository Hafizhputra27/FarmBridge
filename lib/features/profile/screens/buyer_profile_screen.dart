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
