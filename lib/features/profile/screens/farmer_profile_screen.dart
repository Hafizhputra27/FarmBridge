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
