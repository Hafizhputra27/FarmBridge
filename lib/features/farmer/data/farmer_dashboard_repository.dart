import 'package:supabase_flutter/supabase_flutter.dart';

// Queries langsung (RLS participant-scope aman di sisi server) — tidak
// butuh edge function baru. ponytail: kalau dashboard butuh agregat berat
// (growth %, dll), pindah ke edge function trust-metrics-style.
class FarmerDashboardRepository {
  final SupabaseClient _client;
  FarmerDashboardRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  Future<({int txCount, num revenue, int activeListings})> todaySummary(
      String farmerId) async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day).toUtc();

    final txRes = await _client
        .from('transactions')
        .select('total_amount')
        .eq('farmer_id', farmerId)
        .gte('created_at', startOfDay.toIso8601String());
    final revenue = txRes.fold<num>(
        0, (sum, t) => sum + ((t['total_amount'] as num?) ?? 0));

    final listingRes = await _client
        .from('listings')
        .select('id')
        .eq('farmer_id', farmerId)
        .eq('status', 'active');

    return (
      txCount: txRes.length,
      revenue: revenue,
      activeListings: listingRes.length,
    );
  }

  Future<List<Map<String, dynamic>>> recentNegotiations(
      String farmerId) async {
    // RLS sudah scope ke participant, tapi kita filter eksplisit farmer_id
    // biar dashboard petani hanya tampil negosiasi miliknya (RLS juga akan
    // ikut filter, jadi ini dobel-aman, bukan dobel-kerja signifikan).
    final negs = await _client
        .from('negotiations')
        .select(
            'id, status, current_offer_price, quantity, created_at, listings(title, foto_url, unit)')
        .eq('farmer_id', farmerId)
        .order('created_at', ascending: false)
        .limit(5);
    return List<Map<String, dynamic>>.from(negs);
  }
}
