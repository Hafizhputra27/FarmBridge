import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/format.dart';
import '../../auth/providers/auth_provider.dart';
import '../../recurring_order/data/recurring_order_repository.dart';
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
  bool _isFulfilling = false;
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

  Future<void> _openFulfillSheet() async {
    final tx = _tx!;
    final quantityController = TextEditingController(
      text: tx['agreed_quantity'].toString(),
    );
    DateTime selectedDate = DateTime.now();
    String? sheetError;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Tandai Terkirim',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: quantityController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Kuantitas terkirim',
                    ),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Tanggal kirim'),
                    subtitle: Text(
                      '${selectedDate.year}-'
                      '${selectedDate.month.toString().padLeft(2, '0')}-'
                      '${selectedDate.day.toString().padLeft(2, '0')}',
                    ),
                    trailing: const Icon(Icons.calendar_today, size: 18),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setSheetState(() => selectedDate = picked);
                      }
                    },
                  ),
                  if (sheetError != null) ...[
                    const SizedBox(height: 8),
                    Text(sheetError!, style: const TextStyle(color: Colors.red)),
                  ],
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      final qty = int.tryParse(quantityController.text);
                      if (qty == null || qty <= 0) {
                        setSheetState(
                          () => sheetError = 'Kuantitas harus lebih dari 0',
                        );
                        return;
                      }
                      Navigator.pop(ctx);
                      _confirmFulfill(qty, selectedDate);
                    },
                    child: const Text('Lanjutkan'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _confirmFulfill(int deliveredQuantity, DateTime deliveryDate) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tandai Terkirim?'),
        content: const Text(
          'Data tidak bisa diubah setelah disimpan. Trust score petani '
          'akan diperbarui otomatis berdasarkan kuantitas & tanggal ini.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ya, Tandai Terkirim'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isFulfilling = true);
    try {
      await _repo.fulfill(
        widget.transactionId,
        deliveredQuantity: deliveredQuantity,
        actualDeliveryDate: deliveryDate,
      );
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menandai terkirim: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isFulfilling = false);
    }
  }

  Future<void> _openRecurringOrderSheet() async {
    final tx = _tx!;
    final negotiation = tx['negotiations'] as Map<String, dynamic>?;
    final listingId = negotiation?['listing_id']?.toString();
    if (listingId == null) return;

    final agreedQuantity = (tx['agreed_quantity'] as num).toInt();
    final totalAmount = (tx['total_amount'] as num).toDouble();
    final unitPrice = totalAmount / agreedQuantity;

    final quantityController =
        TextEditingController(text: agreedQuantity.toString());
    String frequency = 'weekly';
    String? sheetError;
    bool isSubmitting = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Jadikan Recurring Order',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: quantityController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Kuantitas per siklus'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: frequency,
                    decoration: const InputDecoration(labelText: 'Frekuensi'),
                    items: const [
                      DropdownMenuItem(value: 'weekly', child: Text('Mingguan')),
                      DropdownMenuItem(value: 'biweekly', child: Text('2 Mingguan')),
                      DropdownMenuItem(value: 'monthly', child: Text('Bulanan')),
                    ],
                    onChanged: (v) {
                      if (v != null) setSheetState(() => frequency = v);
                    },
                  ),
                  if (sheetError != null) ...[
                    const SizedBox(height: 8),
                    Text(sheetError!, style: const TextStyle(color: Colors.red)),
                  ],
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: isSubmitting
                        ? null
                        : () async {
                            final qty = int.tryParse(quantityController.text);
                            if (qty == null || qty <= 0) {
                              setSheetState(
                                () => sheetError = 'Kuantitas harus lebih dari 0',
                              );
                              return;
                            }
                            setSheetState(() => isSubmitting = true);
                            try {
                              final id = await RecurringOrderRepository().create(
                                buyerId: tx['buyer_id'].toString(),
                                farmerId: tx['farmer_id'].toString(),
                                listingId: listingId,
                                quantity: qty,
                                frequency: frequency,
                                lockedPrice: unitPrice,
                              );
                              if (ctx.mounted) Navigator.pop(ctx);
                              if (mounted) context.push('/recurring-orders/$id');
                            } catch (e) {
                              setSheetState(() {
                                isSubmitting = false;
                                sheetError = e.toString();
                              });
                            }
                          },
                    child: isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Buat Recurring Order'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
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
    final total = (tx['total_amount'] as num?) ?? 0;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                listing?['title']?.toString() ??
                    listing?['category']?.toString() ??
                    '-',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const SizedBox(width: 12),
            _StatusChip(status: status),
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
                _infoRow(Icons.scale_outlined, 'Jumlah',
                    '${tx['agreed_quantity']} ${listing?['unit'] ?? 'kg'}'),
                _infoRow(Icons.calendar_today_outlined, 'Estimasi kirim',
                    tx['promised_delivery_date']?.toString() ?? '-',
                    isLast: true),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          color: const Color(0xFFEFF6F0),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total',
                    style: Theme.of(context).textTheme.titleMedium),
                Text(
                  formatRupiah(total),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1B5E32),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        if (role == 'buyer' && status == 'pending')
          FilledButton(
            onPressed: _isRejecting ? null : _confirmReject,
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade600),
            child: _isRejecting
                ? const _BtnSpinner()
                : const Text('Tolak Transaksi'),
          ),
        if (role == 'buyer' && status == 'fulfilled')
          FilledButton(
            onPressed: _openRecurringOrderSheet,
            child: const Text('Jadikan Recurring Order'),
          ),
        if (role == 'farmer' && status == 'pending')
          FilledButton(
            onPressed: _isFulfilling ? null : _openFulfillSheet,
            child: _isFulfilling
                ? const _BtnSpinner()
                : const Text('Tandai Terkirim'),
          ),
      ],
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

class _BtnSpinner extends StatelessWidget {
  const _BtnSpinner();
  @override
  Widget build(BuildContext context) => const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
      );
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'pending' => ('Menunggu', const Color(0xFFB26A00)),
      'fulfilled' => ('Terkirim', const Color(0xFF1B5E32)),
      'rejected' => ('Ditolak', const Color(0xFFC62828)),
      _ => (status, Colors.grey.shade700),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13),
      ),
    );
  }
}
