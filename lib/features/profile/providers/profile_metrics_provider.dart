import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final trustMetricsProvider =
    FutureProvider.family<Map<String, dynamic>?, String>((ref, farmerId) async {
  try {
    final res = await Supabase.instance.client.functions
        .invoke('trust-metrics/$farmerId', method: HttpMethod.get);
    return res.data as Map<String, dynamic>;
  } on FunctionException catch (e) {
    if (e.status == 404) return null;
    rethrow;
  }
});

final buyerMetricsProvider =
    FutureProvider.family<Map<String, dynamic>?, String>((ref, buyerId) async {
  try {
    final res = await Supabase.instance.client.functions
        .invoke('buyer-metrics/$buyerId', method: HttpMethod.get);
    return res.data as Map<String, dynamic>;
  } on FunctionException catch (e) {
    if (e.status == 404) return null;
    rethrow;
  }
});

// Identitas untuk header profil (avatar/nama/lokasi/bio/verified). Query
// langsung ke tabel profil (RLS izinkan baca publik). farmerId = users.id,
// buyerId = buyer_profiles.id (lihat komentar route di main_shell.dart).
final farmerIdentityProvider =
    FutureProvider.family<Map<String, dynamic>?, String>((ref, farmerUserId) async {
  return await Supabase.instance.client
      .from('farmer_profiles')
      .select('nama, lokasi, bio, verified')
      .eq('user_id', farmerUserId)
      .maybeSingle();
});

final buyerIdentityProvider =
    FutureProvider.family<Map<String, dynamic>?, String>((ref, buyerProfileId) async {
  return await Supabase.instance.client
      .from('buyer_profiles')
      .select('nama_institusi')
      .eq('id', buyerProfileId)
      .maybeSingle();
});
