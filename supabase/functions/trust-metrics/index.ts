import { createClient } from "npm:@supabase/supabase-js@2";

Deno.serve(async (req) => {
  if (req.method !== "GET") {
    return new Response("Method not allowed", { status: 405 });
  }

  const farmerId = new URL(req.url).pathname.split("/").pop();
  if (!farmerId) {
    return new Response(
      JSON.stringify({ error: "farmer_id is required" }),
      { status: 400, headers: { "Content-Type": "application/json" } },
    );
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  // trust_metrics.farmer_id mengacu ke users.id (auth uid), bukan farmer_profiles.id —
  // cek eksistensi lewat farmer_profiles.user_id, bukan farmer_profiles.id.
  const { data: profile, error: profileError } = await supabase
    .from("farmer_profiles")
    .select("id")
    .eq("user_id", farmerId)
    .maybeSingle();
  if (profileError) throw profileError;
  if (!profile) {
    return new Response(
      JSON.stringify({ error: "farmer not found" }),
      { status: 404, headers: { "Content-Type": "application/json" } },
    );
  }

  const { data: metrics, error: metricsError } = await supabase
    .from("trust_metrics")
    .select("on_time_delivery_rate, rejection_rate, fulfillment_consistency, total_transactions, window_days")
    .eq("farmer_id", farmerId)
    .maybeSingle();
  if (metricsError) throw metricsError;

  const result = metrics ?? {
    on_time_delivery_rate: 0,
    rejection_rate: 0,
    fulfillment_consistency: 0,
    total_transactions: 0,
    window_days: 90,
  };

  return new Response(JSON.stringify(result), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
});
