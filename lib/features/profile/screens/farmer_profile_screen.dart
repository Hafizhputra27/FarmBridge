import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/app_theme.dart';
import '../../../core/widgets/metric_bar.dart';
import '../providers/profile_metrics_provider.dart';
import '../widgets/profile_header.dart';

class FarmerProfileScreen extends ConsumerWidget {
  final String farmerId;
  const FarmerProfileScreen({super.key, required this.farmerId});

  Widget _header(WidgetRef ref) {
    final identity = ref.watch(farmerIdentityProvider(farmerId));
    return identity.maybeWhen(
      data: (id) => id == null
          ? const SizedBox.shrink()
          : ProfileHeader(
              name: id['nama']?.toString() ?? 'Petani',
              location: id['lokasi']?.toString(),
              bio: id['bio']?.toString(),
              verified: id['verified'] == true,
            ),
      orElse: () => const SizedBox.shrink(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metrics = ref.watch(trustMetricsProvider(farmerId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil Petani'),
        actions: [
          IconButton(
            icon: const Icon(Icons.autorenew),
            tooltip: 'Recurring Order Saya',
            onPressed: () => context.push('/recurring-orders'),
          ),
        ],
      ),
      body: metrics.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Gagal memuat profil: $e')),
        data: (data) {
          if (data == null) {
            return const Center(child: Text('Profil tidak ditemukan'));
          }
          final totalTransactions = data['total_transactions'] as int? ?? 0;
          if (totalTransactions == 0) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _header(ref),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'Belum ada riwayat transaksi',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            );
          }
          num pct(dynamic v) => (v as num?) ?? 0;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _header(ref),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.shield_outlined,
                              size: 20, color: AppTheme.brandGreen),
                          const SizedBox(width: 8),
                          Text('Trust Score',
                              style: Theme.of(context).textTheme.titleMedium),
                        ],
                      ),
                      const SizedBox(height: 18),
                      MetricBar(
                        icon: Icons.local_shipping_outlined,
                        label: 'Pengiriman Tepat Waktu',
                        percent: pct(data['on_time_delivery_rate']),
                      ),
                      MetricBar(
                        icon: Icons.cancel_outlined,
                        label: 'Tingkat Penolakan',
                        percent: pct(data['rejection_rate']),
                      ),
                      MetricBar(
                        icon: Icons.verified_outlined,
                        label: 'Konsistensi Pemenuhan',
                        percent: pct(data['fulfillment_consistency']),
                        isLast: true,
                      ),
                      const Divider(height: 28),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('TOTAL TRANSAKSI',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.grey.shade600)),
                          Text('$totalTransactions',
                              style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.brandGreen)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Berdasarkan ${data['window_days']} hari terakhir',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          );
        },
      ),
    );
  }
}

