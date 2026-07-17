import 'package:supabase_flutter/supabase_flutter.dart';

class ListingRepository {
  final SupabaseClient _client;

  ListingRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  Future<List<Map<String, dynamic>>> filterListings({
    String? category,
    String? region,
    double? minPrice,
    double? maxPrice,
  }) async {
    var query = _client
        .from('listings')
        .select('*, farmer_profiles(nama, lokasi, verified)')
        .eq('status', 'active');

    if (category != null && category.isNotEmpty) {
      query = query.eq('category', category);
    }
    if (region != null && region.isNotEmpty) {
      query = query.eq('region', region);
    }
    if (minPrice != null) {
      query = query.gte('harga_per_unit', minPrice);
    }
    if (maxPrice != null) {
      query = query.lte('harga_per_unit', maxPrice);
    }

    return query.order('created_at', ascending: false);
  }

  Future<Map<String, dynamic>> getListingDetail(String id) {
    return _client
        .from('listings')
        .select('*, farmer_profiles(nama, lokasi, verified)')
        .eq('id', id)
        .single();
  }

  Future<List<Map<String, dynamic>>> getMyListings(String farmerId) {
    return _client
        .from('listings')
        .select()
        .eq('farmer_id', farmerId)
        .order('created_at', ascending: false);
  }

  Future<void> create(Map<String, dynamic> data) {
    return _client.from('listings').insert(data);
  }

  Future<void> update(String id, Map<String, dynamic> data) {
    return _client.from('listings').update(data).eq('id', id);
  }

  Future<List<Map<String, dynamic>>> getDistinctCategories() {
    return _client
        .from('price_reference_data')
        .select('category')
        .limit(50);
  }
}
