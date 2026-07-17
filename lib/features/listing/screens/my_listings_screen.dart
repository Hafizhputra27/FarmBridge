import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/listing_repository.dart';

class MyListingsScreen extends ConsumerStatefulWidget {
  const MyListingsScreen({super.key});

  @override
  ConsumerState<MyListingsScreen> createState() => _MyListingsScreenState();
}

class _MyListingsScreenState extends ConsumerState<MyListingsScreen> {
  final _repo = ListingRepository();
  List<Map<String, dynamic>> _listings = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final userId = ref.read(authProvider).userId;
    if (userId == null) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final data = await _repo.getMyListings(userId);
      setState(() {
        _listings = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _confirmArchive(String listingId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Arsipkan Listing?'),
        content: const Text(
          'Listing tidak akan muncul lagi di pencarian buyer. '
          'Kalau masih ada recurring order aktif yang terikat, aksi ini akan ditolak.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Arsipkan'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _repo.update(listingId, {'status': 'archived'});
      await _load();
    } on PostgrestException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengarsipkan: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(authProvider.select((s) => s.userId));

    return Scaffold(
      appBar: AppBar(title: const Text('Listing Saya')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/farmer/listings/create'),
        child: const Icon(Icons.add),
      ),
      body: userId == null
          ? const Center(child: Text('Silakan login terlebih dahulu'))
          : _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Text('Error: $_error'));
    }
    if (_listings.isEmpty) {
      return const Center(
        child: Text(
          'Belum ada listing.\nTambah listing pertama Anda.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey, fontSize: 16),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _listings.length,
        itemBuilder: (context, index) {
          final item = _listings[index];
          final isArchived = item['status'] == 'archived';
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.all(12),
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: item['foto_url'] != null
                    ? Image.network(
                        item['foto_url'],
                        width: 64,
                        height: 64,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          width: 64,
                          height: 64,
                          color: Colors.grey.shade200,
                          child: const Icon(Icons.image, color: Colors.grey),
                        ),
                      )
                    : Container(
                        width: 64,
                        height: 64,
                        color: Colors.grey.shade200,
                        child: const Icon(Icons.image, color: Colors.grey),
                      ),
              ),
              title: Text(
                item['title'] ?? item['category'] ?? 'No Title',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                isArchived
                    ? 'Diarsipkan'
                    : 'Rp ${item['harga_per_unit']}/${item['unit'] ?? 'kg'} · ${item['quantity_available']} tersedia',
              ),
              trailing: isArchived
                  ? null
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () {
                            context.push(
                              '/farmer/listings/${item['id']}/edit',
                              extra: item,
                            );
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.archive_outlined),
                          onPressed: () => _confirmArchive(item['id']),
                        ),
                      ],
                    ),
            ),
          );
        },
      ),
    );
  }
}
