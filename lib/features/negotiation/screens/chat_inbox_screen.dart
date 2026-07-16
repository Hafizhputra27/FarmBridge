import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../data/negotiation_repository.dart';

class ChatInboxScreen extends StatefulWidget {
  const ChatInboxScreen({super.key});

  @override
  State<ChatInboxScreen> createState() => _ChatInboxScreenState();
}

class _ChatInboxScreenState extends State<ChatInboxScreen> {
  final _repo = NegotiationRepository();
  List<Map<String, dynamic>> _negotiations = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadInbox();
  }

  Future<void> _loadInbox() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final data = await _repo.getMyNegotiations();
      setState(() {
        _negotiations = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Percakapan')),
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
            ElevatedButton(onPressed: _loadInbox, child: const Text('Coba Lagi')),
          ],
        ),
      );
    }

    if (_negotiations.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'Belum ada percakapan',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadInbox,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _negotiations.length,
        itemBuilder: (context, index) {
          final item = _negotiations[index];
          return _InboxItem(
            negotiation: item,
            onTap: () => context.push('/negotiations/${item['id']}'),
          );
        },
      ),
    );
  }
}

class _InboxItem extends StatelessWidget {
  final Map<String, dynamic> negotiation;
  final VoidCallback onTap;

  const _InboxItem({required this.negotiation, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final listing = negotiation['listings'] as Map<String, dynamic>? ?? {};
    final farmerProfile = negotiation['farmer_profiles'] as Map<String, dynamic>? ?? {};
    final buyerProfile = negotiation['buyer_profiles'] as Map<String, dynamic>? ?? {};
    final status = negotiation['status']?.toString() ?? 'open';
    final fotoUrl = listing['foto_url']?.toString();

    final counterpartName = farmerProfile['nama']?.toString().isNotEmpty == true
        ? farmerProfile['nama'].toString()
        : buyerProfile['nama_institusi']?.toString() ?? '';

    final listingTitle = listing['title']?.toString() ?? '';
    final harga = listing['harga_per_unit']?.toString() ?? '0';
    final unit = listing['unit']?.toString() ?? 'kg';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: fotoUrl != null
                    ? CachedNetworkImage(
                        imageUrl: fotoUrl,
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                        placeholder: (_, _) =>
                            Container(width: 56, height: 56, color: Colors.grey.shade200),
                        errorWidget: (_, _, _) =>
                            Container(width: 56, height: 56, color: Colors.grey.shade200,
                                child: const Icon(Icons.image, color: Colors.grey)),
                      )
                    : Container(
                        width: 56, height: 56, color: Colors.grey.shade200,
                        child: const Icon(Icons.image, color: Colors.grey),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            counterpartName,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: _chipColor(status),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _statusLabel(status),
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                                color: _statusTextColor(status)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(listingTitle,
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Text(
                      'Rp $harga/$unit',
                      style: TextStyle(
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _chipColor(String status) => switch (status) {
        'open' => Colors.green.shade100,
        'countered' => Colors.orange.shade100,
        'accepted' => Colors.blue.shade100,
        'declined' => Colors.red.shade100,
        'expired' => Colors.grey.shade200,
        _ => Colors.grey.shade100,
      };

  Color _statusTextColor(String status) => switch (status) {
        'open' => Colors.green.shade800,
        'countered' => Colors.orange.shade800,
        'accepted' => Colors.blue.shade800,
        'declined' => Colors.red.shade800,
        'expired' => Colors.grey.shade700,
        _ => Colors.grey.shade700,
      };

  String _statusLabel(String status) => switch (status) {
        'open' => 'Terbuka',
        'countered' => 'Counter',
        'accepted' => 'Diterima',
        'declined' => 'Ditolak',
        'expired' => 'Expired',
        _ => status,
      };
}
