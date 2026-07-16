import { createClient } from "npm:@supabase/supabase-js@2";

async function lockInventory(supabase, negotiationId, quantity, farmerId, buyerId, price, listingId) {
  const { data: list } = await supabase.from("listings").select("quantity_available").eq("id", listingId).single();
  if (!list) return { success: false, error: "Listing tidak ditemukan" };
  const currentQty = Number(list.quantity_available);
  if (currentQty < quantity) return { success: false, error: "Stok tidak mencukupi (first-accepted-wins)" };
  const { error: deductErr } = await supabase.from("listings").update({ quantity_available: currentQty - quantity }).eq("id", listingId);
  if (deductErr) return { success: false, error: "Gagal mengurangi stok" };
  const totalAmount = quantity * Number(price);
  const promised = new Date(); promised.setDate(promised.getDate() + 7);
  const { data: tx, error: txErr } = await supabase.from("transactions").insert({
    negotiation_id: negotiationId, farmer_id: farmerId, buyer_id: buyerId,
    status: "pending", agreed_quantity: quantity, total_amount: totalAmount,
    promised_delivery_date: promised.toISOString().slice(0, 10)
  }).select("id").single();
  if (txErr) { await supabase.from("listings").update({ quantity_available: currentQty }).eq("id", listingId); return { success: false, error: "Gagal buat transaksi" }; }
  return { success: true, transaction_id: tx.id };
}

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  const authHeader = req.headers.get("Authorization");
  if (!authHeader) {
    return new Response(JSON.stringify({ error: "Unauthorized" }), { status: 401, headers: { "Content-Type": "application/json" } });
  }

  const url = new URL(req.url);
  const pathParts = url.pathname.replace(/^\/functions\/v1\/buy-now\/?/, "").split("/").filter(Boolean);
  const listingId = pathParts[0];

  if (!listingId) {
    return new Response(JSON.stringify({ error: "listing_id wajib di URL" }), { status: 400, headers: { "Content-Type": "application/json" } });
  }

  let payload: { quantity?: number; note?: string; buyer_id?: string };
  try {
    payload = await req.json();
  } catch {
    return new Response(JSON.stringify({ error: "Invalid JSON body" }), { status: 400, headers: { "Content-Type": "application/json" } });
  }

  const { quantity, note, buyer_id } = payload;

  if (quantity == null || quantity <= 0) {
    return new Response(JSON.stringify({ error: "Quantity harus > 0" }), { status: 400, headers: { "Content-Type": "application/json" } });
  }

  if (!buyer_id) {
    return new Response(JSON.stringify({ error: "buyer_id wajib" }), { status: 400, headers: { "Content-Type": "application/json" } });
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

    // 1. Cek listing
    const { data: listing, error: listingErr } = await supabase.from("listings").select("*").eq("id", listingId).single();
    if (listingErr || !listing) {
      return new Response(JSON.stringify({ error: "Listing tidak ditemukan" }), { status: 404, headers: { "Content-Type": "application/json" } });
    }

    if (listing.status !== "active") {
      return new Response(JSON.stringify({ error: "Listing tidak aktif" }), { status: 400, headers: { "Content-Type": "application/json" } });
    }

    if (quantity > Number(listing.quantity_available)) {
      return new Response(JSON.stringify({ error: "Stok tidak cukup" }), { status: 400, headers: { "Content-Type": "application/json" } });
    }

    // 2. Buat negotiation dengan status ACCEPTED langsung (Buy Now — skip OPEN)
    const { data: negotiation, error: negErr } = await supabase.from("negotiations").insert({
      listing_id: listingId,
      buyer_id,
      farmer_id: listing.farmer_id,
      initial_price: listing.harga_per_unit,
      current_offer_price: listing.harga_per_unit,
      counter_count: 0,
      status: "accepted",
      expires_at: null,
      quantity,
    }).select("id").single();

    if (negErr) throw new Error("Gagal buat negotiation: " + negErr.message);

    // 3. Lock inventory + buat transaction (FG-35)
    const lockResult = await lockInventory(
      supabase, negotiation.id, quantity,
      listing.farmer_id, buyer_id,
      listing.harga_per_unit, listingId,
    );

    if (!lockResult.success) {
      // Rollback negotiation
      await supabase.from("negotiations").delete().eq("id", negotiation.id);
      return new Response(JSON.stringify({ error: lockResult.error }), { status: 409, headers: { "Content-Type": "application/json" } });
    }

    const totalAmount = quantity * Number(listing.harga_per_unit);

    return new Response(JSON.stringify({
      negotiation_id: negotiation.id,
      transaction_id: lockResult.transaction_id,
      status: "pending",
      total_amount: totalAmount,
    }), { status: 200, headers: { "Content-Type": "application/json" } });

  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), { status: 500, headers: { "Content-Type": "application/json" } });
  }
});
