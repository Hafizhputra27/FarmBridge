import 'package:flutter/material.dart';
import '../data/recurring_order_repository.dart';

class RecurringOrderDetailScreen extends StatefulWidget {
  final String recurringOrderId;
  const RecurringOrderDetailScreen({super.key, required this.recurringOrderId});

  @override
  State<RecurringOrderDetailScreen> createState() =>
      _RecurringOrderDetailScreenState();
}

class _RecurringOrderDetailScreenState
    extends State<RecurringOrderDetailScreen> {
  final _repo = RecurringOrderRepository();
  Map<String, dynamic>? _order;
  bool _isLoading = true;
  bool _isUpdating = false;
  String? _error;

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
      final order = await _repo.getRecurringOrder(widget.recurringOrderId);
      setState(() {
        _order = order;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _confirmStatusChange(String newStatus, String title, String message) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ya'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isUpdating = true);
    try {
      await _repo.updateStatus(widget.recurringOrderId, newStatus);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detail Recurring Order')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Gagal memuat: $_error'))
              : _buildBody(),
    );
  }

  Widget _buildBody() {
    final order = _order!;
    final listing = order['listings'] as Map<String, dynamic>? ?? {};
    final farmerProfile = order['farmer_profiles'] as Map<String, dynamic>?;
    final buyerProfile = order['buyer_profiles'] as Map<String, dynamic>?;
    final status = order['status']?.toString() ?? 'active';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          listing['title']?.toString() ?? listing['category']?.toString() ?? '-',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text('Status: $status'),
        const SizedBox(height: 8),
        Text('Petani: ${farmerProfile?['nama'] ?? '-'}'),
        Text('Pembeli: ${buyerProfile?['nama_institusi'] ?? '-'}'),
        const SizedBox(height: 8),
        Text('Kuantitas: ${order['quantity']}'),
        Text('Harga terkunci: Rp${order['locked_price']}'),
        Text('Frekuensi: ${order['frequency']}'),
        Text('Order berikutnya: ${order['next_order_date']}'),
        const SizedBox(height: 24),
        if (status == 'active') ...[
          ElevatedButton(
            onPressed: _isUpdating
                ? null
                : () => _confirmStatusChange(
                      'paused',
                      'Jeda Recurring Order?',
                      'Siklus berikutnya tidak akan dibuat sampai diaktifkan lagi.',
                    ),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Jeda'),
          ),
          const SizedBox(height: 8),
        ],
        if (status == 'paused')
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: ElevatedButton(
              onPressed: _isUpdating
                  ? null
                  : () => _confirmStatusChange(
                        'active',
                        'Aktifkan Lagi?',
                        'Recurring order akan lanjut ke siklus berikutnya.',
                      ),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text('Aktifkan Lagi'),
            ),
          ),
        if (status != 'cancelled')
          OutlinedButton(
            onPressed: _isUpdating
                ? null
                : () => _confirmStatusChange(
                      'cancelled',
                      'Batalkan Recurring Order?',
                      'Tidak bisa diaktifkan lagi setelah dibatalkan.',
                    ),
            style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Batalkan'),
          ),
      ],
    );
  }
}
