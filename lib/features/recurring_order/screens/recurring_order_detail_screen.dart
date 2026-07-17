import 'package:flutter/material.dart';
import '../../../core/app_theme.dart';
import '../../../core/format.dart';
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
    final unit = listing['unit']?.toString() ?? 'kg';
    final lockedPrice = (order['locked_price'] as num?) ?? 0;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                listing['title']?.toString() ??
                    listing['category']?.toString() ??
                    '-',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const SizedBox(width: 12),
            _roStatusChip(status),
          ],
        ),
        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _infoRow(Icons.person_outline, 'Petani',
                    farmerProfile?['nama']?.toString() ?? '-'),
                _infoRow(Icons.storefront_outlined, 'Pembeli',
                    buyerProfile?['nama_institusi']?.toString() ?? '-'),
                _infoRow(Icons.scale_outlined, 'Kuantitas per siklus',
                    '${order['quantity']} $unit'),
                _infoRow(Icons.repeat, 'Frekuensi', _freqLabel(order['frequency'])),
                _infoRow(Icons.event_outlined, 'Order berikutnya',
                    order['next_order_date']?.toString() ?? '-',
                    isLast: true),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          color: AppTheme.sage,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Harga terkunci / $unit',
                    style: Theme.of(context).textTheme.titleMedium),
                Text(
                  formatRupiah(lockedPrice),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.brandGreen,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        if (status == 'active') ...[
          FilledButton(
            onPressed: _isUpdating
                ? null
                : () => _confirmStatusChange(
                      'paused',
                      'Jeda Recurring Order?',
                      'Siklus berikutnya tidak akan dibuat sampai diaktifkan lagi.',
                    ),
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFB26A00)),
            child: const Text('Jeda'),
          ),
          const SizedBox(height: 8),
        ],
        if (status == 'paused') ...[
          FilledButton(
            onPressed: _isUpdating
                ? null
                : () => _confirmStatusChange(
                      'active',
                      'Aktifkan Lagi?',
                      'Recurring order akan lanjut ke siklus berikutnya.',
                    ),
            child: const Text('Aktifkan Lagi'),
          ),
          const SizedBox(height: 8),
        ],
        if (status != 'cancelled')
          OutlinedButton(
            onPressed: _isUpdating
                ? null
                : () => _confirmStatusChange(
                      'cancelled',
                      'Batalkan Recurring Order?',
                      'Tidak bisa diaktifkan lagi setelah dibatalkan.',
                    ),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red.shade600,
              side: BorderSide(color: Colors.red.shade600),
            ),
            child: const Text('Batalkan'),
          ),
      ],
    );
  }

  String _freqLabel(dynamic f) => switch (f?.toString()) {
        'weekly' => 'Mingguan',
        'biweekly' => '2 Mingguan',
        'monthly' => 'Bulanan',
        _ => f?.toString() ?? '-',
      };

  Widget _roStatusChip(String status) {
    final (label, color) = switch (status) {
      'active' => ('Aktif', AppTheme.brandGreen),
      'paused' => ('Dijeda', const Color(0xFFB26A00)),
      'cancelled' => ('Dibatalkan', const Color(0xFFC62828)),
      _ => (status, Colors.grey.shade700),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontWeight: FontWeight.w700, fontSize: 13)),
    );
  }

  Widget _infoRow(IconData icon, String label, String value,
      {bool isLast = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade600),
          const SizedBox(width: 10),
          Text(label, style: TextStyle(color: Colors.grey.shade700)),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
