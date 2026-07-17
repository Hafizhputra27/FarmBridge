import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/app_theme.dart';
import '../../../core/format.dart';
import '../data/transaction_repository.dart';

/// Daftar pesanan user (buyer: pembelian, farmer: order masuk). Filter
/// Aktif (pending/fulfilled) vs Riwayat (rejected/completed). Tap -> detail.
class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  final _repo = TransactionRepository();
  List<Map<String, dynamic>> _all = [];
  bool _isLoading = true;
  String? _error;
  bool _showActive = true;

  static const _activeStatuses = {'pending', 'fulfilled'};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final data = await _repo.getMyTransactions();
      if (!mounted) return;
      setState(() {
        _all = data;
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

  List<Map<String, dynamic>> get _filtered {
    return _all.where((t) {
      final s = t['status']?.toString() ?? '';
      final active = _activeStatuses.contains(s);
      return _showActive ? active : !active;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pesanan Saya')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              children: [
                _FilterChip(
                  label: 'Aktif',
                  selected: _showActive,
                  onTap: () => setState(() => _showActive = true),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Riwayat',
                  selected: !_showActive,
                  onTap: () => setState(() => _showActive = false),
                ),
              ],
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Gagal memuat: $_error', textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: _load, child: const Text('Coba Lagi')),
          ],
        ),
      );
    }
    final items = _filtered;
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.receipt_long_outlined,
                size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              _showActive ? 'Belum ada pesanan aktif' : 'Belum ada riwayat',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        itemCount: items.length,
        itemBuilder: (_, i) => _OrderCard(tx: items[i]),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? AppTheme.brandGreen : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppTheme.brandGreen : Colors.black.withValues(alpha: 0.12),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : AppTheme.ink,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final Map<String, dynamic> tx;
  const _OrderCard({required this.tx});

  @override
  Widget build(BuildContext context) {
    final neg = tx['negotiations'] as Map<String, dynamic>?;
    final rec = tx['recurring_orders'] as Map<String, dynamic>?;
    final listing = (neg?['listings'] ?? rec?['listings']) as Map<String, dynamic>?;
    final foto = listing?['foto_url']?.toString();
    final title = listing?['title']?.toString() ?? 'Pesanan';
    final unit = listing?['unit']?.toString() ?? 'kg';
    final status = tx['status']?.toString() ?? 'pending';
    final total = (tx['total_amount'] as num?) ?? 0;
    final qty = tx['agreed_quantity'];

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/transaksi/${tx['id']}'),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: foto != null
                    ? CachedNetworkImage(
                        imageUrl: foto,
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                        placeholder: (_, _) =>
                            Container(width: 60, height: 60, color: AppTheme.sage),
                        errorWidget: (_, _, _) => Container(
                            width: 60,
                            height: 60,
                            color: AppTheme.sage,
                            child: const Icon(Icons.eco, color: AppTheme.leaf)),
                      )
                    : Container(
                        width: 60,
                        height: 60,
                        color: AppTheme.sage,
                        child: const Icon(Icons.eco, color: AppTheme.leaf)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 14)),
                        ),
                        _OrderStatusChip(status: status),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('$qty $unit',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade600)),
                    const SizedBox(height: 4),
                    Text(formatRupiah(total),
                        style: const TextStyle(
                            color: AppTheme.brandGreen,
                            fontWeight: FontWeight.w800,
                            fontSize: 15)),
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

class _OrderStatusChip extends StatelessWidget {
  final String status;
  const _OrderStatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'pending' => ('Menunggu', const Color(0xFFB26A00)),
      'fulfilled' => ('Terkirim', AppTheme.brandGreen),
      'completed' => ('Selesai', AppTheme.brandGreen),
      'rejected' => ('Ditolak', const Color(0xFFC62828)),
      _ => (status, Colors.grey.shade700),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontWeight: FontWeight.w700, fontSize: 11)),
    );
  }
}
