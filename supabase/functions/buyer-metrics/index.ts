import { createClient } from "npm:@supabase/supabase-js@2";

Deno.serve(async (req) => {
  if (req.method !== "GET") {
    return new Response("Method not allowed", { status: 405 });
  }

  const buyerId = new URL(req.url).pathname.split("/").pop();
  if (!buyerId) {
    return new Response(
      JSON.stringify({ error: "buyer_id is required" }),
      { status: 400, headers: { "Content-Type": "application/json" } },
    );
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  const { data: profile, error: profileError } = await supabase
    .from("buyer_profiles")
    .select("id")
    .eq("id", buyerId)
    .maybeSingle();
  if (profileError) throw profileError;
  if (!profile) {
    return new Response(
      JSON.stringify({ error: "buyer not found" }),
      { status: 404, headers: { "Content-Type": "application/json" } },
    );
  }

  const { data: metrics, error: metricsError } = await supabase
    .from("buyer_metrics")
    .select("total_procurement, active_orders_count, fulfillment_rate, avg_monthly_volume, window_days")
    .eq("buyer_id", buyerId)
    .maybeSingle();
  if (metricsError) throw metricsError;

  const result = metrics ?? {
    total_procurement: 0,
    active_orders_count: 0,
    fulfillment_rate: 0,
    avg_monthly_volume: null,
    window_days: 90,
  };

  return new Response(JSON.stringify(result), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
});
