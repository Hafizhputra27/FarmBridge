import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/app_theme.dart';
import '../../../core/format.dart';
import '../../../core/widgets/main_shell.dart';
import '../../../core/widgets/metric_bar.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/widgets/logout_button.dart';
import '../providers/profile_metrics_provider.dart';
import '../widgets/profile_header.dart';

class BuyerProfileScreen extends ConsumerWidget {
  final String buyerId;
  const BuyerProfileScreen({super.key, required this.buyerId});

  Widget _header(WidgetRef ref) {
    final identity = ref.watch(buyerIdentityProvider(buyerId));
    return identity.maybeWhen(
      data: (id) => id == null
          ? const SizedBox.shrink()
          : ProfileHeader(
              name: id['nama_institusi']?.toString() ?? 'Pembeli',
            ),
      orElse: () => const SizedBox.shrink(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metrics = ref.watch(buyerMetricsProvider(buyerId));

    // Logout hanya di profil sendiri: buyerId (buyer_profiles.id) == milikku.
    final myUserId = ref.watch(authProvider).userId;
    final myBuyerId = myUserId == null
        ? null
        : ref.watch(myBuyerProfileIdProvider(myUserId)).valueOrNull;
    final isSelf = myBuyerId != null && myBuyerId == buyerId;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil Pembeli'),
        actions: [
          IconButton(
            icon: const Icon(Icons.autorenew),
            tooltip: 'Recurring Order Saya',
            onPressed: () => context.push('/recurring-orders'),
          ),
          if (isSelf) const LogoutButton(),
        ],
      ),
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
          final reliability = (data['fulfillment_rate'] as num?) ?? 0;
          final avgVolume = data['avg_monthly_volume'];

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _header(ref),
              // Ringkasan angka — dua kartu sejajar, gaya sama dengan kartu
              // TOTAL TRANSAKSI di profil petani.
              Row(
                children: [
                  Expanded(
                    child: _SummaryCard(
                      label: 'Total Pembelian',
                      value: formatRupiah(totalProcurement),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SummaryCard(
                      label: 'Pesanan Aktif',
                      value: '$activeOrders',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Trust bars — setara dengan profil petani.
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
                        icon: Icons.task_alt_outlined,
                        label: 'Reliability (Completion Rate)',
                        percent: reliability,
                        isLast: true,
                      ),
                      const Divider(height: 28),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Volume Rata-rata per Bulan',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.grey.shade600)),
                          Text(
                            avgVolume == null ? '-' : '$avgVolume',
                            style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.brandGreen),
                          ),
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

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  const _SummaryCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value,
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.brandGreen)),
            ),
          ],
        ),
      ),
    );
  }
}
