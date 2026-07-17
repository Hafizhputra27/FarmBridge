import 'package:supabase_flutter/supabase_flutter.dart';

class TransactionRepository {
  final SupabaseClient _client;

  TransactionRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  // transactions.buyer_id/farmer_id -> users(id), TIDAK ada FK langsung ke
  // buyer_profiles/farmer_profiles (dicek pg_constraint, pola sama seperti
  // negotiations Sprint 6). Data farmer didapat lewat chain FK yang valid
  // (negotiations -> listings -> farmer_profiles), data buyer manual lookup.
  // Daftar transaksi milik user (RLS scope ke buyer/farmer). Listing didapat
  // via negotiations->listings, atau recurring_orders->listings untuk order
  // recurring (negotiation_id null).
  Future<List<Map<String, dynamic>>> getMyTransactions() async {
    return await _client
        .from('transactions')
        .select(
            '*, negotiations(listings(title, foto_url, unit)), recurring_orders(listings(title, foto_url, unit))')
        .order('created_at', ascending: false);
  }

  Future<Map<String, dynamic>> getTransaction(String id) async {
    final tx = await _client
        .from('transactions')
        .select(
            '*, negotiations(listing_id, listings(*, farmer_profiles(nama, lokasi)))')
        .eq('id', id)
        .single();

    final buyerProfile = await _client
        .from('buyer_profiles')
        .select('nama_institusi')
        .eq('user_id', tx['buyer_id'])
        .maybeSingle();

    return {...tx, 'buyer_profiles': buyerProfile};
  }

  Future<void> reject(String transactionId, {String? reason}) async {
    final res = await _client.functions.invoke(
      'transactions-reject/$transactionId',
      method: HttpMethod.post,
      body: {'reason': reason},
    );
    final data = res.data as Map<String, dynamic>?;
    if (data != null && data['error'] != null) {
      throw Exception(data['error']);
    }
  }

  Future<void> fulfill(
    String transactionId, {
    required int deliveredQuantity,
    required DateTime actualDeliveryDate,
  }) async {
    final dateStr = '${actualDeliveryDate.year}-'
        '${actualDeliveryDate.month.toString().padLeft(2, '0')}-'
        '${actualDeliveryDate.day.toString().padLeft(2, '0')}';
    final res = await _client.functions.invoke(
      'transactions-fulfill/fulfill/$transactionId',
      method: HttpMethod.post,
      body: {
        'delivered_quantity': deliveredQuantity,
        'actual_delivery_date': dateStr,
      },
    );
    final data = res.data as Map<String, dynamic>?;
    if (data != null && data['error'] != null) {
      throw Exception(data['error']);
    }
  }
}
