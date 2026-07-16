import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../data/listing_repository.dart';

class SearchFilterScreen extends StatefulWidget {
  const SearchFilterScreen({super.key});

  @override
  State<SearchFilterScreen> createState() => _SearchFilterScreenState();
}

class _SearchFilterScreenState extends State<SearchFilterScreen> {
  final _repo = ListingRepository();

  final _categories = ['Semua', 'Beras', 'Cabai Merah', 'Bawang Merah', 'Tomat', 'Jagung', 'Kentang'];
  final _regions = ['Semua', 'Jawa Barat', 'Jawa Tengah', 'Jawa Timur'];

  String _selectedCategory = 'Semua';
  String _selectedRegion = 'Semua';
  RangeValues _priceRange = const RangeValues(0, 100000);

  List<Map<String, dynamic>> _results = [];
  bool _isLoading = false;

  Future<void> _applyFilter() async {
    setState(() => _isLoading = true);

    try {
      final data = await _repo.filterListings(
        category: _selectedCategory == 'Semua' ? null : _selectedCategory,
        region: _selectedRegion == 'Semua' ? null : _selectedRegion,
        minPrice: _priceRange.start > 0 ? _priceRange.start : null,
        maxPrice: _priceRange.end < 100000 ? _priceRange.end : null,
      );
      setState(() {
        _results = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Cari Listing'),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _selectedCategory = 'Semua';
                _selectedRegion = 'Semua';
                _priceRange = const RangeValues(0, 100000);
                _results = [];
              });
            },
            child: const Text('Reset'),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              boxShadow: [
                BoxShadow(color: Colors.black12, blurRadius: 4, offset: const Offset(0, 2)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Kategori', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: _categories.map((cat) {
                    return ChoiceChip(
                      label: Text(cat, style: const TextStyle(fontSize: 12)),
                      selected: _selectedCategory == cat,
                      onSelected: (selected) {
                        setState(() => _selectedCategory = selected ? cat : 'Semua');
                      },
                      selectedColor: Colors.green.shade100,
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                const Text('Region', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: _regions.map((reg) {
                    return ChoiceChip(
                      label: Text(reg, style: const TextStyle(fontSize: 12)),
                      selected: _selectedRegion == reg,
                      onSelected: (selected) {
                        setState(() => _selectedRegion = selected ? reg : 'Semua');
                      },
                      selectedColor: Colors.green.shade100,
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                const Text('Rentang Harga', style: TextStyle(fontWeight: FontWeight.w600)),
                Row(
                  children: [
                    Text('Rp ${_priceRange.start.toInt()}'),
                    Expanded(
                      child: RangeSlider(
                        values: _priceRange,
                        min: 0,
                        max: 100000,
                        divisions: 20,
                        labels: RangeLabels(
                          'Rp ${_priceRange.start.toInt()}',
                          'Rp ${_priceRange.end.toInt()}',
                        ),
                        onChanged: (values) {
                          setState(() => _priceRange = values);
                        },
                      ),
                    ),
                    Text('Rp ${_priceRange.end.toInt()}'),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _applyFilter,
                    icon: const Icon(Icons.search, size: 18),
                    label: const Text('Terapkan Filter'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _results.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.search_off, size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 16),
                            Text(
                              'Tidak ada hasil',
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Coba ubah filter atau reset',
                              style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                            ),
                          ],
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.all(12),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 0.68,
                        ),
                        itemCount: _results.length,
                        itemBuilder: (context, index) {
                          return _ResultCard(listing: _results[index]);
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final Map<String, dynamic> listing;

  const _ResultCard({required this.listing});

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
    final farmerId = listing['farmer_id']?.toString() ?? '';
    final namaFarmer = farmerProfile?['nama']?.toString() ?? '';

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
                    Text(title, maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const Spacer(),
                    Text('Rp $harga/$unit',
                      style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold, fontSize: 13)),
                    if (namaFarmer.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(namaFarmer,
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                        overflow: TextOverflow.ellipsis),
                    ],
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
