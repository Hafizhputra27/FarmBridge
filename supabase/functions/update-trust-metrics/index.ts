import { createClient } from "jsr:@supabase/supabase-js@2";

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  let payload: { farmer_id?: string };
  try {
    payload = await req.json();
  } catch {
    return new Response(
      JSON.stringify({ error: "Invalid JSON body" }),
      { status: 400, headers: { "Content-Type": "application/json" } },
    );
  }

  const { farmer_id } = payload;
  if (!farmer_id) {
    return new Response(
      JSON.stringify({ error: "farmer_id is required" }),
      { status: 400, headers: { "Content-Type": "application/json" } },
    );
  }

  try {
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    // --- 1. Ambil semua transaksi farmer dalam 90 hari terakhir ---
    const ninetyDaysAgo = new Date();
    ninetyDaysAgo.setDate(ninetyDaysAgo.getDate() - 90);

    const { data: transactions, error: txError } = await supabase
      .from("transactions")
      .select("*")
      .eq("farmer_id", farmer_id)
      .gte("created_at", ninetyDaysAgo.toISOString());

    if (txError) throw new Error(`Query transactions: ${txError.message}`);

    if (!transactions || transactions.length === 0) {
      // Tidak ada transaksi — reset metrik ke 0
      const { error: upsertError } = await supabase
        .from("trust_metrics")
        .upsert({
          farmer_id,
          on_time_delivery_rate: 0,
          rejection_rate: 0,
          fulfillment_consistency: 0,
          total_transactions: 0,
          window_days: 90,
          updated_at: new Date().toISOString(),
        });

      if (upsertError) throw new Error(`Upsert trust_metrics: ${upsertError.message}`);

      return new Response(
        JSON.stringify({
          farmer_id,
          on_time_delivery_rate: 0,
          rejection_rate: 0,
          fulfillment_consistency: 0,
          total_transactions: 0,
        }),
        { status: 200, headers: { "Content-Type": "application/json" } },
      );
    }

    // --- 2. Hitung 3 metrik ---
    const fulfilled = transactions.filter((t) => t.status === "fulfilled");
    const rejected = transactions.filter((t) => t.status === "rejected");
    const totalPending = transactions.length;

    const totalFulfilled = fulfilled.length;
    const onTime = fulfilled.filter(
      (t) => t.actual_delivery_date && t.promised_delivery_date &&
        new Date(t.actual_delivery_date) <= new Date(t.promised_delivery_date),
    ).length;
    const totalRejected = rejected.length;
    const konsisten = fulfilled.filter(
      (t) => t.delivered_quantity != null &&
        Number(t.delivered_quantity) === Number(t.agreed_quantity),
    ).length;

    const onTimeRate = totalFulfilled > 0
      ? Math.round((onTime / totalFulfilled) * 100 * 100) / 100
      : 0;
    const rejectRate = totalPending > 0
      ? Math.round((totalRejected / totalPending) * 100 * 100) / 100
      : 0;
    const consistency = totalFulfilled > 0
      ? Math.round((konsisten / totalFulfilled) * 100 * 100) / 100
      : 0;

    // --- 3. UPSERT ke trust_metrics ---
    const { error: upsertError } = await supabase
      .from("trust_metrics")
      .upsert({
        farmer_id,
        on_time_delivery_rate: onTimeRate,
        rejection_rate: rejectRate,
        fulfillment_consistency: consistency,
        total_transactions: totalPending,
        window_days: 90,
        updated_at: new Date().toISOString(),
      });

    if (upsertError) throw new Error(`Upsert trust_metrics: ${upsertError.message}`);

    return new Response(
      JSON.stringify({
        farmer_id,
        on_time_delivery_rate: onTimeRate,
        rejection_rate: rejectRate,
        fulfillment_consistency: consistency,
        total_transactions: totalPending,
      }),
      { status: 200, headers: { "Content-Type": "application/json" } },
    );
  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { "Content-Type": "application/json" } },
    );
  }
});
