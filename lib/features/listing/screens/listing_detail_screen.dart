import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/buy_now_repository.dart';
import '../data/listing_repository.dart';

class ListingDetailScreen extends ConsumerStatefulWidget {
  final String listingId;
  const ListingDetailScreen({super.key, required this.listingId});

  @override
  ConsumerState<ListingDetailScreen> createState() =>
      _ListingDetailScreenState();
}

class _ListingDetailScreenState extends ConsumerState<ListingDetailScreen> {
  final _listingRepo = ListingRepository();
  final _buyNowRepo = BuyNowRepository();
  Map<String, dynamic>? _listing;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final listing = await _listingRepo.getListingDetail(widget.listingId);
      setState(() {
        _listing = listing;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _openBuyNowSheet() async {
    final listing = _listing!;
    final available = (listing['quantity_available'] as num).toInt();
    final quantityController = TextEditingController(text: '1');
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
                    'Beli Sekarang',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text('Stok tersedia: $available'),
                  const SizedBox(height: 16),
                  TextField(
                    controller: quantityController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Kuantitas'),
                  ),
                  if (sheetError != null) ...[
                    const SizedBox(height: 8),
                    Text(sheetError!, style: const TextStyle(color: Colors.red)),
                  ],
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () async {
                      final qty = int.tryParse(quantityController.text);
                      if (qty == null || qty <= 0) {
                        setSheetState(
                          () => sheetError = 'Kuantitas harus lebih dari 0',
                        );
                        return;
                      }
                      if (qty > available) {
                        setSheetState(
                          () => sheetError = 'Kuantitas melebihi stok tersedia',
                        );
                        return;
                      }
                      final buyerId = ref.read(authProvider).userId;
                      if (buyerId == null) return;
                      try {
                        final transactionId = await _buyNowRepo.buyNow(
                          listingId: widget.listingId,
                          quantity: qty,
                          buyerId: buyerId,
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (mounted) context.go('/transaksi/$transactionId');
                      } catch (e) {
                        setSheetState(() => sheetError = e.toString());
                      }
                    },
                    child: const Text('Konfirmasi Beli'),
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
    return Scaffold(
      appBar: AppBar(title: const Text('Detail Listing')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Gagal memuat: $_error'))
              : _buildBody(),
    );
  }

  Widget _buildBody() {
    final listing = _listing!;
    final farmerProfile = listing['farmer_profiles'] as Map<String, dynamic>?;
    final available = (listing['quantity_available'] as num).toInt();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          listing['title']?.toString() ??
              listing['category']?.toString() ??
              '-',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text('Rp${listing['harga_per_unit']}/${listing['unit'] ?? 'kg'}'),
        Text('Stok tersedia: $available'),
        Text('Petani: ${farmerProfile?['nama'] ?? '-'}'),
        Text('Lokasi: ${farmerProfile?['lokasi'] ?? '-'}'),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: available > 0 ? _openBuyNowSheet : null,
          child: Text(available > 0 ? 'Beli Sekarang' : 'Stok Habis'),
        ),
      ],
    );
  }
}
