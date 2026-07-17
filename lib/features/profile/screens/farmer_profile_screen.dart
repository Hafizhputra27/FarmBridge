import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/app_theme.dart';
import '../../../core/format.dart';
import '../../../core/widgets/metric_bar.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/widgets/logout_button.dart';
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

  Widget _activeListings(BuildContext context, WidgetRef ref) {
    final listings = ref.watch(farmerListingsProvider(farmerId));
    return listings.maybeWhen(
      data: (items) {
        if (items.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            Text('Listing Aktif',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            SizedBox(
              height: 196,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (_, i) =>
                    _MiniListingCard(item: items[i]),
              ),
            ),
          ],
        );
      },
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
          if (farmerId == ref.watch(authProvider).userId) const LogoutButton(),
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
                _activeListings(context, ref),
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
              _activeListings(context, ref),
            ],
          );
        },
      ),
    );
  }
}

class _MiniListingCard extends StatelessWidget {
  final Map<String, dynamic> item;
  const _MiniListingCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final foto = item['foto_url']?.toString();
    final title = item['title']?.toString() ??
        item['category']?.toString() ??
        '-';
    final price = (item['harga_per_unit'] as num?) ?? 0;
    final unit = item['unit']?.toString() ?? 'kg';

    return GestureDetector(
      onTap: () => context.push('/listing/${item['id']}'),
      child: SizedBox(
        width: 150,
        child: Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AspectRatio(
                aspectRatio: 3 / 2,
                child: foto != null
                    ? CachedNetworkImage(
                        imageUrl: foto,
                        fit: BoxFit.cover,
                        placeholder: (_, _) =>
                            Container(color: AppTheme.sage),
                        errorWidget: (_, _, _) => Container(
                            color: AppTheme.sage,
                            child: const Icon(Icons.eco,
                                color: AppTheme.leaf)),
                      )
                    : Container(
                        color: AppTheme.sage,
                        child: const Icon(Icons.eco, color: AppTheme.leaf)),
              ),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 4),
                    Text('${formatRupiah(price)}/$unit',
                        style: const TextStyle(
                            color: AppTheme.brandGreen,
                            fontWeight: FontWeight.w700,
                            fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

