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
