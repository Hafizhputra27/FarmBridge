import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../data/listing_repository.dart';

class BuyerHomeFeedScreen extends StatefulWidget {
  final String? category;

  const BuyerHomeFeedScreen({super.key, this.category});

  @override
  State<BuyerHomeFeedScreen> createState() => _BuyerHomeFeedScreenState();
}

class _BuyerHomeFeedScreenState extends State<BuyerHomeFeedScreen> {
  final _repo = ListingRepository();
  final _scrollController = ScrollController();

  List<Map<String, dynamic>> _listings = [];
  bool _isLoading = true;
  bool _hasMore = true;
  bool _isLoadingMore = false;
  String? _error;
  int _page = 0;
  static const _pageSize = 20;

  @override
  void initState() {
    super.initState();
    _loadListings();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (_hasMore && !_isLoadingMore) {
        _loadMore();
      }
    }
  }

  Future<void> _loadListings() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final data = await _repo.filterListings(category: widget.category);
      final batch = data.take(_pageSize).toList();
      setState(() {
        _listings = batch;
        _hasMore = data.length > _pageSize;
        _page = 0;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    setState(() => _isLoadingMore = true);
    _page++;

    try {
      final data = await _repo.filterListings(category: widget.category);
      final batch = data.skip(_page * _pageSize).take(_pageSize).toList();
      setState(() {
        _listings.addAll(batch);
        _hasMore = batch.length == _pageSize;
        _isLoadingMore = false;
      });
    } catch (e) {
      _page--;
      setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _onRefresh() async {
    _page = 0;
    await _loadListings();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('FarmBridge'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => context.push('/buyer/search'),
          ),
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
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Gagal memuat: $_error'),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadListings, child: const Text('Coba Lagi')),
          ],
        ),
      );
    }

    if (_listings.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              widget.category != null
                  ? 'Belum ada listing untuk kategori "${widget.category}"'
                  : 'Belum ada listing tersedia',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _onRefresh,
      child: GridView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.68,
        ),
        itemCount: _listings.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _listings.length) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
            );
          }
          return _ListingCard(listing: _listings[index]);
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
    final farmerProfile = (listing['farmer_profiles'] != null &&
            (listing['farmer_profiles'] is Map))
        ? listing['farmer_profiles'] as Map<String, dynamic>
        : null;

    final fotoUrl = listing['foto_url']?.toString();
    final title = listing['title']?.toString() ?? listing['category']?.toString() ?? '';
    final harga = listing['harga_per_unit']?.toString() ?? '0';
    final unit = listing['unit']?.toString() ?? 'kg';
    final lokasi = farmerProfile?['lokasi']?.toString() ?? '';
    final namaFarmer = farmerProfile?['nama']?.toString() ?? '';
    final farmerId = listing['farmer_id']?.toString() ?? '';

    return GestureDetector(
      onTap: () {
        if (farmerId.isNotEmpty) {
          context.push('/farmer-profile/$farmerId');
        }
      },
      child: Card(
        clipBehavior: Clip.antiAlias,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 3,
              child: fotoUrl != null
                  ? CachedNetworkImage(
                      imageUrl: fotoUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, _) => Container(color: Colors.grey.shade200),
                      errorWidget: (_, _, _) => Container(
                        color: Colors.grey.shade200,
                        child: const Icon(Icons.image_not_supported, color: Colors.grey),
                      ),
                    )
                  : Container(
                      color: Colors.grey.shade200,
                      child: const Icon(Icons.image, size: 48, color: Colors.grey),
                    ),
            ),
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    const Spacer(),
                    Text(
                      'Rp $harga/$unit',
                      style: TextStyle(
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (lokasi.isNotEmpty)
                      Row(
                        children: [
                          Icon(Icons.location_on, size: 12, color: Colors.grey.shade500),
                          const SizedBox(width: 2),
                          Expanded(
                            child: Text(
                              lokasi,
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    if (namaFarmer.isNotEmpty)
                      GestureDetector(
                        onTap: () {
                          if (farmerId.isNotEmpty) {
                            context.push('/farmer-profile/$farmerId');
                          }
                        },
                        child: Text(
                          namaFarmer,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.green.shade600,
                            fontStyle: FontStyle.italic,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
