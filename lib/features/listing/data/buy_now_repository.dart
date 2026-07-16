import 'package:supabase_flutter/supabase_flutter.dart';

class BuyNowRepository {
  final SupabaseClient _client;

  BuyNowRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  Future<String> buyNow({
    required String listingId,
    required int quantity,
    required String buyerId,
  }) async {
    try {
      final res = await _client.functions.invoke(
        'buy-now/$listingId',
        method: HttpMethod.post,
        body: {'quantity': quantity, 'buyer_id': buyerId},
      );
      final data = res.data as Map<String, dynamic>;
      return data['transaction_id'] as String;
    } on FunctionException catch (e) {
      final details = e.details;
      final message = (details is Map && details['error'] != null)
          ? details['error'].toString()
          : 'Gagal membeli (${e.status})';
      throw Exception(message);
    }
  }
}
