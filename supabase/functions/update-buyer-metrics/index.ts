import { createClient } from "npm:@supabase/supabase-js@2";
import type { SupabaseClient } from "npm:@supabase/supabase-js@2";

interface BuyerMetricsResult {
  total_procurement: number;
  active_orders_count: number;
  fulfillment_rate: number;
  avg_monthly_volume: number | null;
}

async function updateBuyerMetrics(
  supabase: SupabaseClient,
  userId: string,
): Promise<BuyerMetricsResult> {
  // Resolve users.id -> buyer_profiles.id — buyer_metrics.buyer_id FK
  // mengacu ke buyer_profiles, BUKAN users, beda dari transactions/recurring_orders.
  const { data: profile, error: profileError } = await supabase
    .from("buyer_profiles")
    .select("id")
    .eq("user_id", userId)
    .single();
  if (profileError) throw profileError;
  const buyerProfileId = profile.id;

  const windowStart = new Date();
  windowStart.setDate(windowStart.getDate() - 90);
  const windowStartIso = windowStart.toISOString();

  const { data: transactions, error: txError } = await supabase
    .from("transactions")
    .select("status, total_amount, delivered_quantity, actual_delivery_date")
    .eq("buyer_id", userId)
    .gte("created_at", windowStartIso);
  if (txError) throw txError;

  const fulfilled = transactions.filter((t) => t.status === "fulfilled");
  const totalProcurement = fulfilled.reduce(
    (sum, t) => sum + Number(t.total_amount),
    0,
  );
  const fulfillmentRate = transactions.length === 0
    ? 0
    : (fulfilled.length / transactions.length) * 100;

  const monthlyTotals = new Map<string, number>();
  for (const t of fulfilled) {
    if (!t.actual_delivery_date) continue;
    const month = String(t.actual_delivery_date).slice(0, 7); // "YYYY-MM"
    monthlyTotals.set(
      month,
      (monthlyTotals.get(month) ?? 0) + Number(t.delivered_quantity ?? 0),
    );
  }
  const avgMonthlyVolume = monthlyTotals.size === 0
    ? null
    : Array.from(monthlyTotals.values()).reduce((a, b) => a + b, 0) /
      monthlyTotals.size;

  // active_orders_count: real-time, TIDAK pakai window 90 hari (beda dari 3 metrik lain).
  const { count: pendingCount, error: pendingError } = await supabase
    .from("transactions")
    .select("id", { count: "exact", head: true })
    .eq("buyer_id", userId)
    .eq("status", "pending");
  if (pendingError) throw pendingError;

  const { count: activeRecurringCount, error: recurringError } = await supabase
    .from("recurring_orders")
    .select("id", { count: "exact", head: true })
    .eq("buyer_id", userId)
    .eq("status", "active");
  if (recurringError) throw recurringError;

  const activeOrdersCount = (pendingCount ?? 0) + (activeRecurringCount ?? 0);

  const result: BuyerMetricsResult = {
    total_procurement: totalProcurement,
    active_orders_count: activeOrdersCount,
    fulfillment_rate: fulfillmentRate,
    avg_monthly_volume: avgMonthlyVolume,
  };

  // Tidak ada unique constraint di buyer_metrics.buyer_id — select dulu,
  // baru insert atau update, bukan .upsert(onConflict: ...).
  const { data: existing, error: existingError } = await supabase
    .from("buyer_metrics")
    .select("id")
    .eq("buyer_id", buyerProfileId)
    .maybeSingle();
  if (existingError) throw existingError;

  if (existing) {
    const { error: updateError } = await supabase
      .from("buyer_metrics")
      .update({ ...result, window_days: 90, updated_at: new Date().toISOString() })
      .eq("id", existing.id);
    if (updateError) throw updateError;
  } else {
    const { error: insertError } = await supabase
      .from("buyer_metrics")
      .insert({ ...result, buyer_id: buyerProfileId, window_days: 90 });
    if (insertError) throw insertError;
  }

  return result;
}

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  let payload: { user_id?: string };
  try {
    payload = await req.json();
  } catch {
    return new Response(
      JSON.stringify({ error: "invalid JSON body" }),
      { status: 400, headers: { "Content-Type": "application/json" } },
    );
  }

  if (!payload.user_id) {
    return new Response(
      JSON.stringify({ error: "user_id is required" }),
      { status: 400, headers: { "Content-Type": "application/json" } },
    );
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  const result = await updateBuyerMetrics(supabase, payload.user_id);

  return new Response(JSON.stringify(result), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
});
