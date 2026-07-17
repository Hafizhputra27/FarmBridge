import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/format.dart';
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
                        // push, bukan go — biar ada back button otomatis
                        // (go mereset stack, user kena "keluar app" kalau
                        // tekan back dari Transaction Detail, tidak ada
                        // history buat di-pop).
                        if (mounted) context.push('/transaksi/$transactionId');
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
    final unit = listing['unit']?.toString() ?? 'kg';
    final price = (listing['harga_per_unit'] as num?) ?? 0;
    final fotoUrl = listing['foto_url']?.toString();

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        AspectRatio(
          aspectRatio: 16 / 10,
          child: fotoUrl != null
              ? CachedNetworkImage(
                  imageUrl: fotoUrl,
                  fit: BoxFit.cover,
                  placeholder: (_, _) => Container(color: Colors.grey.shade200),
                  errorWidget: (_, _, _) => Container(
                    color: Colors.grey.shade200,
                    child: const Icon(Icons.image_not_supported,
                        color: Colors.grey, size: 48),
                  ),
                )
              : Container(
                  color: Colors.grey.shade200,
                  child: const Icon(Icons.image, size: 64, color: Colors.grey),
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                listing['title']?.toString() ??
                    listing['category']?.toString() ??
                    '-',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    formatRupiah(price),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1B5E32),
                    ),
                  ),
                  Text('/$unit',
                      style: TextStyle(color: Colors.grey.shade600)),
                ],
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _infoRow(Icons.inventory_2_outlined, 'Stok tersedia',
                          '$available $unit'),
                      _infoRow(Icons.person_outline, 'Petani',
                          farmerProfile?['nama']?.toString() ?? '-'),
                      _infoRow(Icons.location_on_outlined, 'Lokasi',
                          farmerProfile?['lokasi']?.toString() ?? '-',
                          isLast: true),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: available > 0 ? _openBuyNowSheet : null,
                child: Text(available > 0 ? 'Beli Sekarang' : 'Stok Habis'),
              ),
            ],
          ),
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
