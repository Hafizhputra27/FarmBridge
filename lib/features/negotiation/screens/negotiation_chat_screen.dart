import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/app_theme.dart';
import '../../../core/format.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/negotiation_repository.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/negotiation_actions.dart';

class NegotiationChatScreen extends ConsumerStatefulWidget {
  final String negotiationId;

  const NegotiationChatScreen({super.key, required this.negotiationId});

  @override
  ConsumerState<NegotiationChatScreen> createState() =>
      _NegotiationChatScreenState();
}

class _NegotiationChatScreenState extends ConsumerState<NegotiationChatScreen> {
  final _repo = NegotiationRepository();
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  Map<String, dynamic>? _negotiation;
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  String? _error;
  StreamSubscription? _subscription;
  num _initialQuantity = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
    _subscribeRealtime();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final negotiation =
          await _repo.getNegotiation(widget.negotiationId);
      final messages =
          await _repo.getMessages(widget.negotiationId);

      setState(() {
        _negotiation = negotiation;
        _messages = messages;
        _initialQuantity =
            negotiation['listings']?['quantity_available'] ?? 0;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _subscribeRealtime() {
    _subscription = _repo
        .subscribeMessages(widget.negotiationId)
        .listen((messages) {
      if (!mounted) return;
      final lastMsg = messages.isNotEmpty ? messages.last : null;
      if (lastMsg != null &&
          !_messages.any((m) => m['id'] == lastMsg['id'])) {
        setState(() {
          _messages.add(lastMsg);
          if (_negotiation != null &&
              lastMsg['action_type'] != 'message') {
            _negotiation!['status'] = lastMsg['action_type'] == 'accept'
                ? 'accepted'
                : lastMsg['action_type'] == 'decline'
                    ? 'declined'
                    : 'countered';
          }
        });
        _scrollToBottom();
      }
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final userId = ref.read(authProvider).userId;
    if (userId == null) return;

    _messageController.clear();

    try {
      await _repo.sendMessage(
        negotiationId: widget.negotiationId,
        senderId: userId,
        actionType: 'message',
        messageText: text,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengirim: $e')),
        );
      }
    }
  }

  Future<void> _onAccept() async {
    final userId = ref.read(authProvider).userId;
    if (userId == null) return;
    final offerPrice =
        (_negotiation?['current_offer_price'] as num?)?.toDouble();
    try {
      final result = await _repo.sendMessage(
        negotiationId: widget.negotiationId,
        senderId: userId,
        actionType: 'accept',
        offerPrice: offerPrice,
      );
      final transactionId = result['transaction_id']?.toString();
      if (transactionId != null && mounted) {
        // push, bukan go — sama seperti alur Buy Now (lihat
        // listing_detail_screen.dart), biar back button jalan normal.
        context.push('/transaksi/$transactionId');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal: $e')),
        );
      }
    }
  }

  Future<void> _onDecline() async {
    final userId = ref.read(authProvider).userId;
    if (userId == null) return;
    try {
      await _repo.sendMessage(
        negotiationId: widget.negotiationId,
        senderId: userId,
        actionType: 'decline',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal: $e')),
        );
      }
    }
  }

  Future<void> _onCounter(double offerPrice, String message) async {
    final userId = ref.read(authProvider).userId;
    if (userId == null) return;
    try {
      await _repo.sendMessage(
        negotiationId: widget.negotiationId,
        senderId: userId,
        actionType: 'counter',
        messageText: message.isNotEmpty ? message : null,
        offerPrice: offerPrice,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Negosiasi')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null || _negotiation == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Negosiasi')),
        body: Center(child: Text('Error: $_error')),
      );
    }

    final negotiation = _negotiation!;
    final listing = negotiation['listings'] as Map<String, dynamic>? ?? {};
    final farmerProfile =
        listing['farmer_profiles'] as Map<String, dynamic>? ?? {};
    final status = negotiation['status']?.toString() ?? 'open';
    final currentUserId = ref.read(authProvider).userId;
    final isBuyer = ref.read(authProvider).role == 'buyer';

    final counterpartName = isBuyer
        ? farmerProfile['nama']?.toString() ?? 'Farmer'
        : listing['title']?.toString() ?? 'Buyer';

    final counterpartId =
        isBuyer ? negotiation['farmer_id']?.toString() : negotiation['buyer_id']?.toString();

    final lastMessage = _messages.isNotEmpty ? _messages.last : null;
    // Penerima (pihak yang harus respon) = bukan pengirim aksi terakhir.
    // Tanpa pesan: pembeli adalah pembuat tawaran, jadi PETANI penerima —
    // sebelumnya `lastMessage == null` bikin keduanya dianggap penerima dan
    // pembeli kelihatan punya tombol Terima/Tolak miliknya sendiri
    // (edge fn tolak 403, tapi UI salah).
    final isReceiver = lastMessage == null
        ? currentUserId != negotiation['buyer_id']?.toString()
        : lastMessage['sender_id'] != currentUserId;

    final currentQuantity = listing['quantity_available'];
    final stockChanged =
        _initialQuantity != currentQuantity && currentQuantity != null;

    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: () async {
            if (counterpartId == null) return;
            if (isBuyer) {
              // Lawan bicara farmer: /farmer-profile/:id = users.id, cocok.
              context.push('/farmer-profile/$counterpartId');
              return;
            }
            // Saya farmer, lawan bicara buyer: /buyer-profile/:id expect
            // buyer_profiles.id, bukan users.id — resolve dulu.
            final buyerProfileId = await _repo.getBuyerProfileId(counterpartId);
            if (buyerProfileId != null && context.mounted) {
              context.push('/buyer-profile/$buyerProfileId');
            }
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(counterpartName,
                  style: const TextStyle(fontSize: 16)),
              Text(
                listing['title']?.toString() ?? '',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          _activeNegotiationCard(negotiation, listing, status),
          if (stockChanged)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.orange.shade50,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.warning_amber, size: 16,
                      color: Colors.orange.shade800),
                  const SizedBox(width: 6),
                  Text(
                    'Stok berubah: $_initialQuantity → $currentQuantity unit',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange.shade800,
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Text(
                      'Belum ada pesan',
                      style: TextStyle(color: Colors.grey.shade500),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    reverse: true,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[_messages.length - 1 - index];
                      final actionType =
                          msg['action_type']?.toString() ?? 'message';
                      final msgSenderId = msg['sender_id']?.toString();

                      return ChatBubble(
                        isMine: msgSenderId == currentUserId,
                        text: msg['message_text']?.toString(),
                        offerPrice: (msg['offer_price'] as num?)?.toDouble(),
                        recommendedPrice:
                            (negotiation['recommended_price'] as num?)
                                ?.toDouble(),
                        actionType: actionType,
                        createdAt:
                            DateTime.parse(msg['created_at'].toString()),
                      );
                    },
                  ),
          ),
          NegotiationActions(
            isReceiver: isReceiver,
            status: status,
            onAccept: _onAccept,
            onDecline: _onDecline,
            onCounter: _onCounter,
          ),
          if (status != 'accepted' && status != 'declined' && status != 'expired')
            Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        decoration: InputDecoration(
                          hintText: 'Ketik pesan...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade100,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    CircleAvatar(
                      backgroundColor: AppTheme.brandGreen,
                      child: IconButton(
                        icon: const Icon(Icons.send, color: Colors.white, size: 18),
                        onPressed: _sendMessage,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _activeNegotiationCard(
    Map<String, dynamic> negotiation,
    Map<String, dynamic> listing,
    String status,
  ) {
    final offerPrice = (negotiation['current_offer_price'] as num?) ??
        (negotiation['initial_price'] as num?) ??
        0;
    final quantity = negotiation['quantity'];
    final unit = listing['unit']?.toString() ?? 'kg';

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.brandGreen.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Negosiasi Aktif',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade700)),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _statusColor(status).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(_statusLabel(status),
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _statusColor(status))),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${formatRupiah(offerPrice)} / $unit',
            style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppTheme.brandGreen),
          ),
          if (quantity != null) ...[
            const SizedBox(height: 2),
            Text('Kuantitas: $quantity $unit',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
          ],
        ],
      ),
    );
  }

  Color _statusColor(String status) => switch (status) {
        'open' => Colors.green,
        'countered' => Colors.orange,
        'accepted' => Colors.blue,
        'declined' => Colors.red,
        'expired' => Colors.grey,
        _ => Colors.grey,
      };

  String _statusLabel(String status) => switch (status) {
        'open' => 'Terbuka',
        'countered' => 'Counter Offer',
        'accepted' => 'Diterima',
        'declined' => 'Ditolak',
        'expired' => 'Kedaluwarsa',
        _ => status,
      };
}
