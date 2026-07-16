import 'package:supabase_flutter/supabase_flutter.dart';

class NegotiationRepository {
  final SupabaseClient _client;

  NegotiationRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  Future<List<Map<String, dynamic>>> getMyNegotiations({String? status}) {
    var filter = _client
        .from('negotiations')
        .select(
            '*, listings(title, foto_url, harga_per_unit, unit), farmer_profiles(nama), buyer_profiles(nama_institusi)');

    if (status != null && status.isNotEmpty) {
      filter = filter.eq('status', status);
    }
    return filter.order('updated_at', ascending: false);
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

  Future<void> sendMessage({
    required String negotiationId,
    required String senderId,
    required String actionType,
    String? messageText,
    double? offerPrice,
  }) {
    return _client.from('negotiation_messages').insert({
      'negotiation_id': negotiationId,
      'sender_id': senderId,
      'action_type': actionType,
      'message_text': messageText,
      'offer_price': offerPrice,
    });
  }
}
