import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/app_theme.dart';
import '../../../core/format.dart';
import '../data/listing_repository.dart';

class BuyerHomeFeedScreen extends StatefulWidget {
  const BuyerHomeFeedScreen({super.key});

  @override
  State<BuyerHomeFeedScreen> createState() => _BuyerHomeFeedScreenState();
}

class _BuyerHomeFeedScreenState extends State<BuyerHomeFeedScreen> {
  final _repo = ListingRepository();

  List<Map<String, dynamic>> _all = [];
  List<String> _categories = [];
  String? _selectedCategory; // null = Semua
  bool _isLoading = true;
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
      final data = await _repo.filterListings();
      final cats = <String>{
        for (final l in data)
          if ((l['category']?.toString() ?? '').isNotEmpty)
            l['category'].toString(),
      }.toList()
        ..sort();
      setState(() {
        _all = data;
        _categories = cats;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _visible => _selectedCategory == null
      ? _all
      : _all.where((l) => l['category'] == _selectedCategory).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
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
            icon: const Icon(Icons.chat_bubble_outline),
            onPressed: () => context.push('/percakapan'),
          ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => context.push('/buyer/search'),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _ErrorState(message: _error!, onRetry: _load);
    }

    return Column(
      children: [
        if (_categories.isNotEmpty) _categoryChips(),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: _visible.isEmpty
                ? _EmptyState(category: _selectedCategory)
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: _visible.length,
                    itemBuilder: (_, i) => Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: _ListingCard(listing: _visible[i]),
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _categoryChips() {
    final chips = <String?>[null, ..._categories];
    return SizedBox(
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: chips.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final cat = chips[i];
          final selected = cat == _selectedCategory;
          return GestureDetector(
            onTap: () => setState(() => _selectedCategory = cat),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? AppTheme.brandGreen : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: selected
                        ? AppTheme.brandGreen
                        : Colors.black.withValues(alpha: 0.12)),
              ),
              child: Text(
                cat ?? 'Semua',
                style: TextStyle(
                  color: selected ? Colors.white : AppTheme.ink,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ListingCard extends StatelessWidget {
  final Map<String, dynamic> listing;
  const _ListingCard({required this.listing});

  @override
  Widget build(BuildContext context) {
    final farmer = listing['farmer_profiles'] is Map
        ? listing['farmer_profiles'] as Map<String, dynamic>
        : null;
    final fotoUrl = listing['foto_url']?.toString();
    final title = listing['title']?.toString() ??
        listing['category']?.toString() ??
        '';
    final price = (listing['harga_per_unit'] as num?) ?? 0;
    final unit = listing['unit']?.toString() ?? 'kg';
    final qty = (listing['quantity_available'] as num?)?.toInt() ?? 0;
    final lokasi = farmer?['lokasi']?.toString() ?? '';
    final nama = farmer?['nama']?.toString() ?? 'Petani';
    final verified = farmer?['verified'] == true;
    final farmerId = listing['farmer_id']?.toString() ?? '';
    final listingId = listing['id']?.toString() ?? '';

    return Card(
      child: InkWell(
        onTap: () {
          if (listingId.isNotEmpty) context.push('/listing/$listingId');
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: fotoUrl != null
                      ? CachedNetworkImage(
                          imageUrl: fotoUrl,
                          fit: BoxFit.cover,
                          placeholder: (_, _) =>
                              Container(color: Colors.grey.shade200),
                          errorWidget: (_, _, _) => Container(
                            color: Colors.grey.shade200,
                            child: const Icon(Icons.image_not_supported,
                                color: Colors.grey),
                          ),
                        )
                      : Container(
                          color: Colors.grey.shade200,
                          child: const Icon(Icons.image,
                              size: 48, color: Colors.grey),
                        ),
                ),
                if (verified)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.verified,
                              size: 14, color: AppTheme.leaf),
                          const SizedBox(width: 4),
                          Text('VERIFIED',
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.brandGreen)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () {
                      if (farmerId.isNotEmpty) {
                        context.push('/farmer-profile/$farmerId');
                      }
                    },
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 11,
                          backgroundColor: AppTheme.sage,
                          child: const Icon(Icons.person,
                              size: 14, color: AppTheme.leaf),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(nama,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade700)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(formatRupiah(price),
                              style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.brandGreen)),
                          Text('/$unit',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade500)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined,
                          size: 15, color: Colors.grey.shade500),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          lokasi.isEmpty ? '-' : lokasi,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.sage,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text('$qty $unit tersedia',
                            style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.brandGreen)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String? category;
  const _EmptyState({this.category});

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SizedBox(height: 120),
        Icon(Icons.storefront_outlined, size: 64, color: Colors.grey.shade400),
        const SizedBox(height: 16),
        Text(
          category != null
              ? 'Belum ada listing untuk "$category"'
              : 'Belum ada listing tersedia',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
        ),
      ],
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
