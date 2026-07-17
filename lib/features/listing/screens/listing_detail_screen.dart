import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/app_theme.dart';
import '../../../core/format.dart';
import '../../auth/providers/auth_provider.dart';
import '../../negotiation/data/negotiation_repository.dart';
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
  final _negoRepo = NegotiationRepository();
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

  Future<void> _openActionSheet() async {
    final listing = _listing!;
    final unit = listing['unit']?.toString() ?? 'kg';
    final price = (listing['harga_per_unit'] as num?) ?? 0;
    final available = (listing['quantity_available'] as num).toInt();

    await showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const Text(
                  'Pilih Aksi',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  'Beli langsung atau ajukan negosiasi harga ke petani.',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 12),
                if (available > 0) ...[
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _openBuyNowSheet();
                    },
                    icon: const Icon(Icons.flash_on, size: 18),
                    label: const Text('Beli Sekarang'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _openNegotiateSheet();
                    },
                    icon: const Icon(Icons.handshake_outlined, size: 18),
                    label: const Text('Negosiasi Harga'),
                  ),
                ] else
                  Text(
                    'Stok habis — tidak bisa membeli atau menawar saat ini.',
                    style: TextStyle(color: Colors.grey.shade600),
                    textAlign: TextAlign.center,
                  ),
                const SizedBox(height: 4),
                if (available > 0)
                  Text(
                    'Harga ${formatRupiah(price)}/$unit · Stok $available $unit',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openNegotiateSheet() async {
    final listing = _listing!;
    final available = (listing['quantity_available'] as num).toInt();
    final price = (listing['harga_per_unit'] as num?) ?? 0;
    final unit = listing['unit']?.toString() ?? 'kg';

    final quantityController = TextEditingController(text: '1');
    final offerController =
        TextEditingController(text: price.toStringAsFixed(0));
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
                    'Negosiasi Harga',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Harga patokan: ${formatRupiah(price)}/$unit · Stok $available $unit',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: quantityController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Kuantitas ($unit)',
                      errorText: null,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: offerController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Harga tawaran per $unit (Rp)',
                      prefixText: 'Rp ',
                    ),
                  ),
                  if (sheetError != null) ...[
                    const SizedBox(height: 8),
                    Text(sheetError!, style: const TextStyle(color: Colors.red)),
                  ],
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: isSubmitting
                        ? null
                        : () async {
                            final qty = int.tryParse(quantityController.text);
                            final offer =
                                double.tryParse(offerController.text);
                            if (qty == null || qty <= 0) {
                              setSheetState(
                                () => sheetError = 'Kuantitas harus lebih dari 0',
                              );
                              return;
                            }
                            if (qty > available) {
                              setSheetState(
                                () => sheetError = 'Kuantitas melebihi stok',
                              );
                              return;
                            }
                            if (offer == null || offer <= 0) {
                              setSheetState(
                                () => sheetError =
                                    'Harga tawaran harus lebih dari 0',
                              );
                              return;
                            }
                            final buyerId = ref.read(authProvider).userId;
                            if (buyerId == null) return;
                            setSheetState(() => isSubmitting = true);
                            try {
                              final negId = await _negoRepo.createNegotiation(
                                listingId: widget.listingId,
                                buyerId: buyerId,
                                initialPrice: offer,
                                quantity: qty,
                              );
                              if (ctx.mounted) Navigator.pop(ctx);
                              // Tidak perlu kirim pesan counter awal —
                              // negotiations.current_offer_price sudah diisi
                              // initial_price oleh handleCreate, dan edge fn
                              // menolak counter dari pembuat (lastSender
                              // default buyer_id, sender==lastSender -> 403).
                              if (mounted) context.push('/negosiasi/$negId');
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
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Kirim Tawaran'),
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
    final role = ref.watch(currentUserRoleProvider);
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
              if (role == 'buyer')
                FilledButton.icon(
                  onPressed: available > 0 ? _openActionSheet : null,
                  icon: const Icon(Icons.shopping_basket_outlined),
                  label: Text(available > 0 ? 'Beli / Negosiasi' : 'Stok Habis'),
                )
              else
                Card(
                  color: AppTheme.sage,
                  child: const Padding(
                    padding: EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: AppTheme.brandGreen),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Mode petani — fitur beli hanya untuk pembeli.',
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
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
