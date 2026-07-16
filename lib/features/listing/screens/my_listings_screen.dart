import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/listing_repository.dart';

class MyListingsScreen extends ConsumerWidget {
  const MyListingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(authProvider.select((s) => s.userId));
    final repo = ListingRepository();

    return Scaffold(
      appBar: AppBar(title: const Text('Listing Saya')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/farmer/listings/create'),
        child: const Icon(Icons.add),
      ),
      body: userId == null
          ? const Center(child: Text('Silakan login terlebih dahulu'))
          : FutureBuilder<List<Map<String, dynamic>>>(
              future: repo.getMyListings(userId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final listings = snapshot.data ?? [];

                if (listings.isEmpty) {
                  return const Center(
                    child: Text(
                      'Belum ada listing.\nTambah listing pertama Anda.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: listings.length,
                  itemBuilder: (context, index) {
                    final item = listings[index];
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
                          'Rp ${item['harga_per_unit']}/${item['unit'] ?? 'kg'} · ${item['quantity_available']} tersedia',
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () {
                            context.push(
                              '/farmer/listings/${item['id']}/edit',
                              extra: item,
                            );
                          },
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
