import 'package:supabase_flutter/supabase_flutter.dart';

class RecurringOrderRepository {
  final SupabaseClient _client;

  RecurringOrderRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  Future<String> create({
    required String buyerId,
    required String farmerId,
    required String listingId,
    required int quantity,
    required String frequency,
    required double lockedPrice,
  }) async {
    final res = await _client.functions.invoke(
      'recurring-orders',
      method: HttpMethod.post,
      body: {
        'buyer_id': buyerId,
        'farmer_id': farmerId,
        'listing_id': listingId,
        'quantity': quantity,
        'frequency': frequency,
        'locked_price': lockedPrice,
      },
    );
    final data = res.data as Map<String, dynamic>?;
    if (data != null && data['error'] != null) {
      throw Exception(data['error']);
    }
    return data!['recurring_order_id'] as String;
  }

  Future<void> updateStatus(String id, String status) async {
    final res = await _client.functions.invoke(
      'recurring-orders/$id',
      method: HttpMethod.patch,
      body: {'status': status},
    );
    final data = res.data as Map<String, dynamic>?;
    if (data != null && data['error'] != null) {
      throw Exception(data['error']);
    }
  }

  // recurring_orders.buyer_id/farmer_id -> users(id), tidak ada FK
  // langsung ke buyer_profiles/farmer_profiles — pola sama seperti
  // NegotiationRepository.getMyNegotiations().
  Future<List<Map<String, dynamic>>> getMyRecurringOrders(String userId) async {
    final orders = await _client
        .from('recurring_orders')
        .select('*, listings(title, category, harga_per_unit, unit, foto_url)')
        .or('buyer_id.eq.$userId,farmer_id.eq.$userId')
        .order('created_at', ascending: false);

    final farmerIds =
        orders.map((o) => o['farmer_id'] as String).toSet().toList();
    final buyerIds =
        orders.map((o) => o['buyer_id'] as String).toSet().toList();

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

    return orders
        .map((o) => {
              ...o,
              'farmer_profiles': farmerByUserId[o['farmer_id']],
              'buyer_profiles': buyerByUserId[o['buyer_id']],
            })
        .toList();
  }

  Future<Map<String, dynamic>> getRecurringOrder(String id) async {
    final order = await _client
        .from('recurring_orders')
        .select('*, listings(title, category, harga_per_unit, unit, foto_url)')
        .eq('id', id)
        .single();

    final farmerProfile = await _client
        .from('farmer_profiles')
        .select('nama, lokasi')
        .eq('user_id', order['farmer_id'])
        .maybeSingle();
    final buyerProfile = await _client
        .from('buyer_profiles')
        .select('nama_institusi')
        .eq('user_id', order['buyer_id'])
        .maybeSingle();

    return {
      ...order,
      'farmer_profiles': farmerProfile,
      'buyer_profiles': buyerProfile,
    };
  }
}
