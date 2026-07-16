import { createClient } from "npm:@supabase/supabase-js@2";

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  const authHeader = req.headers.get("Authorization");
  if (!authHeader) {
    return new Response(JSON.stringify({ error: "Unauthorized" }), { status: 401, headers: { "Content-Type": "application/json" } });
  }

  const url = new URL(req.url);
  const match = url.pathname.match(/\/fulfill\/([a-f0-9-]+)$/);
  const transactionId = match ? match[1] : null;

  if (!transactionId) {
    return new Response(JSON.stringify({ error: "transaction_id wajib di URL" }), { status: 400, headers: { "Content-Type": "application/json" } });
  }

  let payload: { delivered_quantity?: number; actual_delivery_date?: string };
  try {
    payload = await req.json();
  } catch {
    return new Response(JSON.stringify({ error: "Invalid JSON body" }), { status: 400, headers: { "Content-Type": "application/json" } });
  }

  const { delivered_quantity, actual_delivery_date } = payload;

  if (delivered_quantity == null || !actual_delivery_date) {
    return new Response(JSON.stringify({ error: "delivered_quantity dan actual_delivery_date wajib" }), { status: 400, headers: { "Content-Type": "application/json" } });
  }

  try {
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    const { data: userData, error: userError } = await supabase.auth.getUser(authHeader.replace("Bearer ", ""));
    if (userError || !userData?.user) {
      return new Response(JSON.stringify({ error: "Invalid token" }), { status: 401, headers: { "Content-Type": "application/json" } });
    }

    const userId = userData.user.id;

    // 1. Ambil transaction
    const { data: tx, error: txErr } = await supabase
      .from("transactions")
      .select("*")
      .eq("id", transactionId)
      .single();

    if (txErr || !tx) {
      return new Response(JSON.stringify({ error: "Transaksi tidak ditemukan" }), { status: 404, headers: { "Content-Type": "application/json" } });
    }

    // 2. Cek farmer owner
    if (tx.farmer_id !== userId) {
      return new Response(JSON.stringify({ error: "Hanya farmer pemilik transaksi yang bisa fulfill" }), { status: 403, headers: { "Content-Type": "application/json" } });
    }

    // 3. Cek status masih pending
    if (tx.status !== "pending") {
      return new Response(JSON.stringify({ error: "Transaksi bukan dalam status pending — status saat ini: " + tx.status }), { status: 409, headers: { "Content-Type": "application/json" } });
    }

    // 4. Tentukan anomaly flag
    const isAnomaly = Number(delivered_quantity) > Number(tx.agreed_quantity);

    // 5. Update transaction
    const { error: updateErr } = await supabase
      .from("transactions")
      .update({
        delivered_quantity,
        actual_delivery_date,
        status: "fulfilled",
        anomaly_flag: isAnomaly,
      })
      .eq("id", transactionId);

    if (updateErr) throw new Error("Gagal update transaksi: " + updateErr.message);

    // 6. Panggil update-trust-metrics
    const fnUrl = `${Deno.env.get("SUPABASE_URL")}/functions/v1/update-trust-metrics`;
    const fnKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

    try {
      await fetch(fnUrl, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Authorization": `Bearer ${fnKey}`,
        },
        body: JSON.stringify({ farmer_id: tx.farmer_id }),
      });
    } catch {
      // trust_metrics update gagal — tetap return sukses untuk fulfill
      // (trust_metrics bisa di-call ulang manual)
    }

    return new Response(JSON.stringify({
      transaction_id: transactionId,
      status: "fulfilled",
      trust_metrics_updated: true,
    }), { status: 200, headers: { "Content-Type": "application/json" } });

  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), { status: 500, headers: { "Content-Type": "application/json" } });
  }
});
