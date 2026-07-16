import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/transaction_repository.dart';

class TransactionDetailScreen extends ConsumerStatefulWidget {
  final String transactionId;
  const TransactionDetailScreen({super.key, required this.transactionId});

  @override
  ConsumerState<TransactionDetailScreen> createState() =>
      _TransactionDetailScreenState();
}

class _TransactionDetailScreenState
    extends ConsumerState<TransactionDetailScreen> {
  final _repo = TransactionRepository();
  Map<String, dynamic>? _tx;
  bool _isLoading = true;
  bool _isRejecting = false;
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
      final tx = await _repo.getTransaction(widget.transactionId);
      setState(() {
        _tx = tx;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _confirmReject() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tolak Transaksi?'),
        content: const Text('Stok akan dikembalikan ke listing.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Tolak'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isRejecting = true);
    try {
      await _repo.reject(widget.transactionId);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menolak: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isRejecting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(currentUserRoleProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Detail Transaksi')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Gagal memuat: $_error'))
              : _buildBody(role),
    );
  }

  Widget _buildBody(String? role) {
    final tx = _tx!;
    final negotiation = tx['negotiations'] as Map<String, dynamic>?;
    final listing = negotiation?['listings'] as Map<String, dynamic>?;
    final farmerProfile =
        listing?['farmer_profiles'] as Map<String, dynamic>?;
    final buyerProfile = tx['buyer_profiles'] as Map<String, dynamic>?;
    final status = tx['status']?.toString() ?? 'pending';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          listing?['title']?.toString() ??
              listing?['category']?.toString() ??
              '-',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text('Status: $status'),
        const SizedBox(height: 8),
        Text('Petani: ${farmerProfile?['nama'] ?? '-'}'),
        Text('Pembeli: ${buyerProfile?['nama_institusi'] ?? '-'}'),
        const SizedBox(height: 8),
        Text('Jumlah: ${tx['agreed_quantity']}'),
        Text('Total: Rp${tx['total_amount']}'),
        Text('Estimasi kirim: ${tx['promised_delivery_date'] ?? '-'}'),
        const SizedBox(height: 24),
        if (role == 'buyer' && status == 'pending')
          ElevatedButton(
            onPressed: _isRejecting ? null : _confirmReject,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: _isRejecting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Tolak Transaksi'),
          ),
        if (role == 'farmer')
          ElevatedButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Fitur "Tandai Terkirim" tersedia Sprint 8'),
                ),
              );
            },
            child: const Text('Tandai Terkirim'),
          ),
      ],
    );
  }
}
