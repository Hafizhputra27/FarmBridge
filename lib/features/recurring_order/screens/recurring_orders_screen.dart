import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/recurring_order_repository.dart';

class RecurringOrdersScreen extends ConsumerStatefulWidget {
  const RecurringOrdersScreen({super.key});

  @override
  ConsumerState<RecurringOrdersScreen> createState() =>
      _RecurringOrdersScreenState();
}

class _RecurringOrdersScreenState
    extends ConsumerState<RecurringOrdersScreen> {
  final _repo = RecurringOrderRepository();
  List<Map<String, dynamic>> _orders = [];
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
      final data = await _repo.getMyRecurringOrders(userId);
      setState(() {
        _orders = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recurring Order Saya')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Gagal memuat: $_error'),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _load, child: const Text('Coba Lagi')),
          ],
        ),
      );
    }
    if (_orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.autorenew, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'Belum ada recurring order',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
            ),
          ],
        ),
      );
    }

    final currentUserId = ref.read(authProvider).userId;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _orders.length,
        itemBuilder: (context, index) {
          final item = _orders[index];
          return _RecurringOrderItem(
            order: item,
            currentUserId: currentUserId,
            onTap: () => context.push('/recurring-orders/${item['id']}'),
          );
        },
      ),
    );
  }
}

class _RecurringOrderItem extends StatelessWidget {
  final Map<String, dynamic> order;
  final String? currentUserId;
  final VoidCallback onTap;

  const _RecurringOrderItem({
    required this.order,
    required this.currentUserId,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final listing = order['listings'] as Map<String, dynamic>? ?? {};
    final farmerProfile = order['farmer_profiles'] as Map<String, dynamic>?;
    final buyerProfile = order['buyer_profiles'] as Map<String, dynamic>?;
    final status = order['status']?.toString() ?? 'active';
    final fotoUrl = listing['foto_url']?.toString();

    // Tampilkan pihak LAIN, bukan diri sendiri — kalau user saat ini
    // adalah farmer di order ini, tampilkan nama buyer, dan sebaliknya.
    final isCurrentUserFarmer = order['farmer_id'] == currentUserId;
    final buyerName = buyerProfile?['nama_institusi']?.toString() ?? '';
    final farmerName = farmerProfile?['nama']?.toString() ?? '';
    final counterpartName = isCurrentUserFarmer ? buyerName : farmerName;

    final listingTitle =
        listing['title']?.toString() ?? listing['category']?.toString() ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: fotoUrl != null
                    ? CachedNetworkImage(
                        imageUrl: fotoUrl,
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                        placeholder: (_, _) => Container(
                            width: 56, height: 56, color: Colors.grey.shade200),
                        errorWidget: (_, _, _) => Container(
                            width: 56,
                            height: 56,
                            color: Colors.grey.shade200,
                            child: const Icon(Icons.image, color: Colors.grey)),
                      )
                    : Container(
                        width: 56,
                        height: 56,
                        color: Colors.grey.shade200,
                        child: const Icon(Icons.image, color: Colors.grey),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            counterpartName,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 14),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: _chipColor(status),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _statusLabel(status),
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: _statusTextColor(status)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(listingTitle,
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Text(
                      'Next order: ${order['next_order_date']}',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _chipColor(String status) => switch (status) {
        'active' => Colors.green.shade100,
        'paused' => Colors.orange.shade100,
        'cancelled' => Colors.red.shade100,
        _ => Colors.grey.shade100,
      };

  Color _statusTextColor(String status) => switch (status) {
        'active' => Colors.green.shade800,
        'paused' => Colors.orange.shade800,
        'cancelled' => Colors.red.shade800,
        _ => Colors.grey.shade700,
      };

  String _statusLabel(String status) => switch (status) {
        'active' => 'Aktif',
        'paused' => 'Dijeda',
        'cancelled' => 'Dibatalkan',
        _ => status,
      };
}
