import 'package:supabase_flutter/supabase_flutter.dart';

class NegotiationRepository {
  final SupabaseClient _client;

  NegotiationRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  Future<List<Map<String, dynamic>>> getMyNegotiations({String? status}) async {
    // negotiations.farmer_id/buyer_id -> users(id), BUKAN langsung ke
    // farmer_profiles/buyer_profiles — tidak ada FK buat PostgREST embed
    // otomatis (dicek langsung ke pg_constraint). Join manual di sini,
    // bukan migration baru (butuh koordinasi Nevan, ini bisa selesai
    // tanpa itu).
    var filter = _client
        .from('negotiations')
        .select('*, listings(title, foto_url, harga_per_unit, unit)');

    if (status != null && status.isNotEmpty) {
      filter = filter.eq('status', status);
    }
    // negotiations tidak punya kolom updated_at (dicek langsung ke skema
    // remote) — urut created_at, bukan error tiap ChatInboxScreen dibuka.
    final negotiations =
        await filter.order('created_at', ascending: false);

    final farmerIds =
        negotiations.map((n) => n['farmer_id'] as String).toSet().toList();
    final buyerIds =
        negotiations.map((n) => n['buyer_id'] as String).toSet().toList();

    final farmerProfiles = farmerIds.isEmpty
        ? <Map<String, dynamic>>[]
        : await _client
            .from('farmer_profiles')
            .select('user_id, nama')
            .inFilter('user_id', farmerIds);
    final buyerProfiles = buyerIds.isEmpty
        ? <Map<String, dynamic>>[]
        : await _client
            .from('buyer_profiles')
            .select('user_id, nama_institusi')
            .inFilter('user_id', buyerIds);

    final farmerByUserId = {
      for (final f in farmerProfiles) f['user_id'] as String: f,
    };
    final buyerByUserId = {
      for (final b in buyerProfiles) b['user_id'] as String: b,
    };

    return negotiations
        .map((n) => {
              ...n,
              'farmer_profiles': farmerByUserId[n['farmer_id']],
              'buyer_profiles': buyerByUserId[n['buyer_id']],
            })
        .toList();
  }

  // POST /negotiations — handleCreate pakai service-role key di edge
  // function jadi buyer_id dipercaya dari body. Balas negotiation_id +
  // rekomendasi harga untuk ditampilkan di sheet/bubble.
  Future<String> createNegotiation({
    required String listingId,
    required String buyerId,
    required double initialPrice,
    required int quantity,
  }) async {
    try {
      final res = await _client.functions.invoke(
        'negotiations',
        method: HttpMethod.post,
        body: {
          'listing_id': listingId,
          'buyer_id': buyerId,
          'initial_price': initialPrice,
          'quantity': quantity,
        },
      );
      final data = res.data as Map<String, dynamic>;
      return data['negotiation_id'] as String;
    } on FunctionException catch (e) {
      final details = e.details;
      final message = (details is Map && details['error'] != null)
          ? details['error'].toString()
          : 'Gagal membuat negosiasi (${e.status})';
      throw Exception(message);
    }
  }

  /// negotiations.buyer_id = users.id, tapi /buyer-profile/:id (route)
  /// expect buyer_profiles.id — resolve dulu sebelum navigasi ke sana.
  Future<String?> getBuyerProfileId(String userId) async {
    final row = await _client
        .from('buyer_profiles')
        .select('id')
        .eq('user_id', userId)
        .maybeSingle();
    return row?['id'] as String?;
  }

  Future<Map<String, dynamic>> getNegotiation(String id) {
    return _client
        .from('negotiations')
        .select('*, listings(*, farmer_profiles(nama, lokasi))')
        .eq('id', id)
        .single();
  }

  Future<List<Map<String, dynamic>>> getMessages(String negotiationId) {
    return _client
        .from('negotiation_messages')
        .select('*')
        .eq('negotiation_id', negotiationId)
        .order('created_at', ascending: true);
  }

  Stream<List<Map<String, dynamic>>> subscribeMessages(
    String negotiationId,
  ) {
    return _client
        .from('negotiation_messages')
        .stream(primaryKey: ['id'])
        .eq('negotiation_id', negotiationId)
        .order('created_at');
  }

  Future<Map<String, dynamic>> sendMessage({
    required String negotiationId,
    required String senderId,
    required String actionType,
    String? messageText,
    double? offerPrice,
  }) async {
    try {
      final res = await _client.functions.invoke(
        'negotiations/$negotiationId/messages',
        method: HttpMethod.post,
        body: {
          'sender_id': senderId,
          'action_type': actionType,
          'message_text': ?messageText,
          'offer_price': ?offerPrice,
        },
      );
      return res.data as Map<String, dynamic>;
    } on FunctionException catch (e) {
      final details = e.details;
      final message = (details is Map && details['error'] != null)
          ? details['error'].toString()
          : 'Gagal mengirim (${e.status})';
      throw Exception(message);
    }
  }
}
