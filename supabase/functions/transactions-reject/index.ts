import { createClient } from "npm:@supabase/supabase-js@2";
import { releaseInventoryOnReject } from "../_shared/inventory-locking.ts";

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  const authHeader = req.headers.get("Authorization");
  if (!authHeader) {
    return new Response(JSON.stringify({ error: "Unauthorized" }), {
      status: 401,
      headers: { "Content-Type": "application/json" },
    });
  }

  // Ambil segmen terakhir non-kosong dari path, bukan regex prefix-strip
  // (`/functions/v1/transactions-reject/`) — regex prefix-strip terbukti
  // rapuh di buy-now (Nevan), diduga req.url runtime tidak selalu
  // menyertakan prefix penuh itu. Pola ini konsisten dengan
  // trust-metrics/buyer-metrics yang sudah terbukti jalan.
  const url = new URL(req.url);
  const transactionId = url.pathname.split("/").filter(Boolean).pop();

  if (!transactionId) {
    return new Response(
      JSON.stringify({ error: "transaction_id wajib di URL" }),
      { status: 400, headers: { "Content-Type": "application/json" } },
    );
  }

  let payload: { reason?: string };
  try {
    payload = await req.json();
  } catch {
    payload = {};
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  const { data: userData, error: userError } = await supabase.auth.getUser(
    authHeader.replace("Bearer ", ""),
  );
  if (userError || !userData?.user) {
    return new Response(JSON.stringify({ error: "Invalid token" }), {
      status: 401,
      headers: { "Content-Type": "application/json" },
    });
  }

  const { data: tx, error: txError } = await supabase
    .from("transactions")
    .select("id, status, buyer_id, farmer_id")
    .eq("id", transactionId)
    .single();

  if (txError || !tx) {
    return new Response(JSON.stringify({ error: "Transaction tidak ditemukan" }), {
      status: 404,
      headers: { "Content-Type": "application/json" },
    });
  }

  if (tx.buyer_id !== userData.user.id) {
    return new Response(
      JSON.stringify({ error: "Hanya buyer terkait yang bisa reject" }),
      { status: 403, headers: { "Content-Type": "application/json" } },
    );
  }

  if (tx.status !== "pending") {
    return new Response(
      JSON.stringify({ error: "Transaction sudah bukan pending, tidak bisa direject" }),
      { status: 400, headers: { "Content-Type": "application/json" } },
    );
  }

  const releaseResult = await releaseInventoryOnReject(supabase, transactionId);
  if (!releaseResult.success) {
    return new Response(JSON.stringify({ error: releaseResult.error }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }

  const { error: updateError } = await supabase
    .from("transactions")
    .update({ status: "rejected" })
    .eq("id", transactionId);

  if (updateError) {
    return new Response(JSON.stringify({ error: updateError.message }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }

  // Update rejection_rate (+ metrik lain) farmer — reuse function Nevan
  // yang sudah ada, bukan hitung ulang logicnya di sini. Best-effort:
  // kegagalan di sini tidak boleh bikin reject sendiri gagal (rollback
  // stok & status sudah sukses duluan).
  try {
    await fetch(`${Deno.env.get("SUPABASE_URL")}/functions/v1/update-trust-metrics`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ farmer_id: tx.farmer_id }),
    });
  } catch (e) {
    console.error("update-trust-metrics gagal (non-fatal):", e);
  }

  return new Response(
    JSON.stringify({
      transaction_id: transactionId,
      status: "rejected",
      reason: payload.reason ?? null,
    }),
    { status: 200, headers: { "Content-Type": "application/json" } },
  );
});
