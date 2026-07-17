// supabase/functions/_shared/price-recommendation.ts
import type { SupabaseClient } from "npm:@supabase/supabase-js@2";

export interface PriceRecommendationParams {
  category: string;
  region: string;
  quantity?: number;
}

export interface PriceRecommendationResult {
  recommended_price: number | null;
  avg_price: number | null;
  min_price: number | null;
  max_price: number | null;
  message?: string;
}

export async function getRecommendedPrice(
  supabase: SupabaseClient,
  { category, region }: PriceRecommendationParams,
): Promise<PriceRecommendationResult> {
  const { data, error } = await supabase
    .from("price_reference_data")
    .select("avg_price, min_price, max_price")
    .eq("category", category)
    .eq("region", region)
    .maybeSingle();

  if (error) throw error;

  if (!data) {
    return {
      recommended_price: null,
      avg_price: null,
      min_price: null,
      max_price: null,
      message: "Data referensi belum tersedia untuk kategori ini",
    };
  }

  return {
    recommended_price: data.avg_price,
    avg_price: data.avg_price,
    min_price: data.min_price,
    max_price: data.max_price,
  };
}
