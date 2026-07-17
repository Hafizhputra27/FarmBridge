import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/app_theme.dart';
import '../../../core/format.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/farmer_dashboard_repository.dart';

class FarmerDashboardScreen extends ConsumerStatefulWidget {
  const FarmerDashboardScreen({super.key});

  @override
  ConsumerState<FarmerDashboardScreen> createState() =>
      _FarmerDashboardScreenState();
}

class _FarmerDashboardScreenState extends ConsumerState<FarmerDashboardScreen> {
  final _repo = FarmerDashboardRepository();
  int _txCount = 0;
  num _revenue = 0;
  int _activeListings = 0;
  List<Map<String, dynamic>> _negos = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final userId = ref.read(authProvider).userId;
    if (userId == null) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final s = await _repo.todaySummary(userId);
      final negs = await _repo.recentNegotiations(userId);
      if (!mounted) return;
      setState(() {
        _txCount = s.txCount;
        _revenue = s.revenue;
        _activeListings = s.activeListings;
        _negos = negs;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.eco, color: AppTheme.leaf, size: 22),
            const SizedBox(width: 6),
            Text('FarmBridge',
                style: TextStyle(
                    color: AppTheme.brandGreen,
                    fontWeight: FontWeight.w800,
                    fontSize: 20)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Pesanan Masuk',
            icon: const Icon(Icons.receipt_long_outlined),
            onPressed: () => context.push('/pesanan'),
          ),
          IconButton(
            tooltip: 'Listing Saya',
            icon: const Icon(Icons.list_alt),
            onPressed: () => context.push('/farmer/listings'),
          ),
          IconButton(
            tooltip: 'Recurring Order',
            icon: const Icon(Icons.autorenew),
            onPressed: () => context.push('/recurring-orders'),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorState(message: _error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    children: [
                      const _SectionTitle('Ringkasan Hari Ini'),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _StatCard(
                              icon: Icons.local_shipping_outlined,
                              label: 'Transaksi',
                              value: '$_txCount',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _StatCard(
                              icon: Icons.payments_outlined,
                              label: 'Pendapatan',
                              value: formatRupiah(_revenue),
                              emphasize: true,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _StatCard(
                              icon: Icons.inventory_2_outlined,
                              label: 'Listing Aktif',
                              value: '$_activeListings',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const _SectionTitle('Negosiasi Terbaru'),
                          TextButton(
                            onPressed: () => context.push('/percakapan'),
                            child: const Text('Lihat semua'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (_negos.isEmpty)
                        _EmptyNegotiations()
                      else
                        ..._negos.map((n) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _NegotiationTile(n: n),
                            )),
                    ],
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/farmer/listings/create'),
        icon: const Icon(Icons.add),
        label: const Text('Listing Baru'),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.ink));
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool emphasize;
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: AppTheme.leaf),
            const SizedBox(height: 10),
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 11, color: Colors.grey.shade600)),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value,
                  style: TextStyle(
                      fontSize: emphasize ? 16 : 18,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.brandGreen)),
            ),
          ],
        ),
      ),
    );
  }
}

class _NegotiationTile extends StatelessWidget {
  final Map<String, dynamic> n;
  const _NegotiationTile({required this.n});

  @override
  Widget build(BuildContext context) {
    final listing = n['listings'] as Map<String, dynamic>? ?? {};
    final status = n['status']?.toString() ?? 'open';
    final offer = (n['current_offer_price'] as num?) ?? 0;
    final fotoUrl = listing['foto_url']?.toString();
    final title = listing['title']?.toString() ?? 'Listing';

    return Card(
      child: InkWell(
        onTap: () => context.push('/negosiasi/${n['id']}'),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: fotoUrl != null
                    ? CachedNetworkImage(
                        imageUrl: fotoUrl,
                        width: 44,
                        height: 44,
                        fit: BoxFit.cover,
                        placeholder: (_, _) =>
                            Container(width: 44, height: 44, color: AppTheme.sage),
                        errorWidget: (_, _, _) => Container(
                            width: 44,
                            height: 44,
                            color: AppTheme.sage,
                            child: const Icon(Icons.image,
                                size: 20, color: Colors.grey)),
                      )
                    : Container(
                        width: 44,
                        height: 44,
                        color: AppTheme.sage,
                        child: const Icon(Icons.eco,
                            size: 20, color: AppTheme.leaf),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(formatRupiah(offer),
                        style: const TextStyle(
                            color: AppTheme.brandGreen,
                            fontWeight: FontWeight.w700,
                            fontSize: 13)),
                  ],
                ),
              ),
              _StatusChip(status: status),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'open' => ('Terbuka', const Color(0xFF2E7D46)),
      'countered' => ('Counter', const Color(0xFFB26A00)),
      'accepted' => ('Diterima', const Color(0xFF1B5E32)),
      'declined' => ('Ditolak', const Color(0xFFC62828)),
      'expired' => ('Kedaluwarsa', Colors.grey),
      _ => (status, Colors.grey),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

class _EmptyNegotiations extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(Icons.chat_bubble_outline,
                size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            const Text('Belum ada negosiasi masuk',
                style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text('Gagal memuat: $message', textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Coba Lagi')),
          ],
        ),
      ),
    );
  }
}
