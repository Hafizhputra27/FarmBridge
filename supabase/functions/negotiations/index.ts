import { createClient } from "npm:@supabase/supabase-js@2";
import { getRecommendedPrice } from "../_shared/price-recommendation.ts";
import { lockInventoryOnAcceptWithQuantity } from "../_shared/inventory-locking.ts";

function parsePath(path: string): { action: string; negotiationId?: string } {
  const parts = path.replace(/^\/negotiations\/?/, "").split("/").filter(Boolean);
  if (parts.length === 0) return { action: "list" };
  if (parts.length === 1) return { action: "detail", negotiationId: parts[0] };
  if (parts[1] === "messages") return { action: "messages", negotiationId: parts[0] };
  return { action: "unknown" };
}

async function getUserId(req: Request, supabase: ReturnType<typeof createClient>): Promise<string | Response> {
  const authHeader = req.headers.get("Authorization");
  if (!authHeader) {
    return new Response(JSON.stringify({ error: "Unauthorized" }), { status: 401, headers: { "Content-Type": "application/json" } });
  }
  const { data, error } = await supabase.auth.getUser(authHeader.replace("Bearer ", ""));
  if (error || !data?.user) {
    return new Response(JSON.stringify({ error: "Invalid token" }), { status: 401, headers: { "Content-Type": "application/json" } });
  }
  return data.user.id;
}

// --- POST /negotiations ---
async function handleCreate(supabase: ReturnType<typeof createClient>, body: Record<string, unknown>) {
  const { listing_id, buyer_id, initial_price, quantity } = body;

  if (!listing_id || !buyer_id || initial_price == null || quantity == null) {
    return new Response(JSON.stringify({ error: "listing_id, buyer_id, initial_price, quantity wajib" }), { status: 400, headers: { "Content-Type": "application/json" } });
  }
  if (Number(initial_price) <= 0) {
    return new Response(JSON.stringify({ error: "Harga harus > 0" }), { status: 400, headers: { "Content-Type": "application/json" } });
  }
  if (Number(quantity) <= 0) {
    return new Response(JSON.stringify({ error: "Quantity harus > 0" }), { status: 400, headers: { "Content-Type": "application/json" } });
  }

  const { data: listing, error: listingErr } = await supabase.from("listings").select("*").eq("id", listing_id as string).single();
  if (listingErr || !listing) return new Response(JSON.stringify({ error: "Listing tidak ditemukan" }), { status: 404, headers: { "Content-Type": "application/json" } });
  if (listing.status !== "active") return new Response(JSON.stringify({ error: "Listing tidak aktif" }), { status: 400, headers: { "Content-Type": "application/json" } });
  if (Number(quantity) > Number(listing.quantity_available)) return new Response(JSON.stringify({ error: "Stok tidak cukup" }), { status: 400, headers: { "Content-Type": "application/json" } });

  const priceResult = await getRecommendedPrice(supabase, { category: listing.category, region: listing.region, quantity: Number(quantity) });

  const expiresAt = new Date();
  expiresAt.setHours(expiresAt.getHours() + 6);

  const { data: negotiation, error: negErr } = await supabase.from("negotiations").insert({
    listing_id: listing.id, buyer_id, farmer_id: listing.farmer_id,
    initial_price, current_offer_price: initial_price,
    recommended_price: priceResult.recommended_price,
    expires_at: expiresAt.toISOString(), status: "open", quantity,
  }).select("id, status, expires_at").single();

  if (negErr) throw new Error("Gagal membuat negosiasi: " + negErr.message);

  return new Response(JSON.stringify({ negotiation_id: negotiation.id, recommended_price: priceResult.recommended_price, avg_price: priceResult.avg_price, min_price: priceResult.min_price, max_price: priceResult.max_price, status: negotiation.status, expires_at: negotiation.expires_at }), { status: 200, headers: { "Content-Type": "application/json" } });
}

// --- POST /negotiations/:id/messages ---
async function handleMessages(supabase: ReturnType<typeof createClient>, negotiationId: string, body: Record<string, unknown>) {
  const { sender_id, message_text, offer_price, action_type } = body;
  if (!sender_id || !action_type) return new Response(JSON.stringify({ error: "sender_id dan action_type wajib" }), { status: 400, headers: { "Content-Type": "application/json" } });

  const validActions = ["counter", "accept", "decline", "message"];
  if (!validActions.includes(action_type as string)) return new Response(JSON.stringify({ error: `action_type harus salah satu: ${validActions.join(", ")}` }), { status: 400, headers: { "Content-Type": "application/json" } });
  if (["counter", "accept"].includes(action_type as string) && offer_price == null) return new Response(JSON.stringify({ error: "offer_price wajib untuk counter/accept" }), { status: 400, headers: { "Content-Type": "application/json" } });

  const { data: neg, error: negErr } = await supabase.from("negotiations").select("*").eq("id", negotiationId).single();
  if (negErr || !neg) return new Response(JSON.stringify({ error: "Negosiasi tidak ditemukan" }), { status: 404, headers: { "Content-Type": "application/json" } });
  if (["accepted", "declined", "expired"].includes(neg.status)) return new Response(JSON.stringify({ error: "Negosiasi sudah selesai — status: " + neg.status }), { status: 409, headers: { "Content-Type": "application/json" } });

  // Validasi "pihak penerima"
  if (["counter", "accept", "decline"].includes(action_type as string)) {
    const { data: lastMsg } = await supabase.from("negotiation_messages").select("sender_id").eq("negotiation_id", negotiationId).order("created_at", { ascending: false }).limit(1).maybeSingle();
    const lastSender = lastMsg?.sender_id ?? neg.buyer_id;
    if (sender_id === lastSender) return new Response(JSON.stringify({ error: "Hanya pihak penerima yang bisa melakukan aksi ini" }), { status: 403, headers: { "Content-Type": "application/json" } });
  }

  const { data: msg, error: msgErr } = await supabase.from("negotiation_messages").insert({ negotiation_id: negotiationId, sender_id, action_type, message_text: (message_text as string) ?? null, offer_price: offer_price != null ? Number(offer_price) : null }).select("id").single();
  if (msgErr) throw new Error("Gagal insert message: " + msgErr.message);

  let newStatus = neg.status;
  let transactionId: string | undefined;

  if (action_type === "accept") {
    const qty = Number(neg.quantity) || 0;
    const lockResult = await lockInventoryOnAcceptWithQuantity(supabase, negotiationId, qty);
    if (!lockResult.success) return new Response(JSON.stringify({ error: lockResult.error }), { status: 409, headers: { "Content-Type": "application/json" } });
    transactionId = lockResult.transaction_id;
    newStatus = "accepted";
  } else if (action_type === "decline") {
    newStatus = "declined";
  } else if (action_type === "counter") {
    newStatus = "countered";
  }

  const updateData: Record<string, unknown> = { status: newStatus };
  if (action_type === "counter" && offer_price != null) { updateData.current_offer_price = Number(offer_price); updateData.counter_count = (neg.counter_count ?? 0) + 1; }
  await supabase.from("negotiations").update(updateData).eq("id", negotiationId);

  return new Response(JSON.stringify({ message_id: msg.id, negotiation_status: newStatus, transaction_id: transactionId ?? null }), { status: 200, headers: { "Content-Type": "application/json" } });
}

// --- GET /negotiations/:id ---
async function handleDetail(supabase: ReturnType<typeof createClient>, negotiationId: string, userId: string) {
  const { data: neg, error: negErr } = await supabase.from("negotiations").select("*, listings(*), farmer_profile:farmer_profiles!negotiations_farmer_id_fkey(*), buyer_profile:buyer_profiles!negotiations_buyer_id_fkey(*)").eq("id", negotiationId).single();
  if (negErr || !neg) return new Response(JSON.stringify({ error: "Negosiasi tidak ditemukan" }), { status: 404, headers: { "Content-Type": "application/json" } });
  if (neg.buyer_id !== userId && neg.farmer_id !== userId) return new Response(JSON.stringify({ error: "Anda bukan peserta negosiasi ini" }), { status: 403, headers: { "Content-Type": "application/json" } });

  const { data: messages } = await supabase.from("negotiation_messages").select("*").eq("negotiation_id", negotiationId).order("created_at", { ascending: true });

  return new Response(JSON.stringify({ negotiation: neg, messages: messages || [] }), { status: 200, headers: { "Content-Type": "application/json" } });
}

// --- GET /negotiations ---
async function handleList(supabase: ReturnType<typeof createClient>, userId: string, url: URL) {
  const statusFilter = url.searchParams.get("status");
  let query = supabase.from("negotiations").select("*, listings(title, category, harga_per_unit, foto_url)").or(`buyer_id.eq.${userId},farmer_id.eq.${userId}`);
  if (statusFilter) query = query.in("status", statusFilter.split(",").map((s) => s.trim()));
  const { data: negotiations } = await query.order("updated_at", { ascending: false });
  return new Response(JSON.stringify(negotiations || []), { status: 200, headers: { "Content-Type": "application/json" } });
}

// --- ROUTER ---
Deno.serve(async (req: Request) => {
  const supabase = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);

  const url = new URL(req.url);
  const pathname = url.pathname.replace(/^\/functions\/v1\/negotiations/, "/negotiations");
  const { action, negotiationId } = parsePath(pathname);

  try {
    if (action === "list") {
      if (req.method !== "GET") return new Response("Method not allowed", { status: 405 });
      const userId = await getUserId(req, supabase);
      if (typeof userId !== "string") return userId;
      return await handleList(supabase, userId, url);
    }

    if (action === "detail") {
      if (req.method !== "GET") return new Response("Method not allowed", { status: 405 });
      const userId = await getUserId(req, supabase);
      if (typeof userId !== "string") return userId;
      return await handleDetail(supabase, negotiationId!, userId);
    }

    if (action === "messages") {
      if (req.method !== "POST") return new Response("Method not allowed", { status: 405 });
      const body = await req.json();
      return await handleMessages(supabase, negotiationId!, body);
    }

    // No negotiation ID → create
    if (pathname === "/negotiations" || pathname === "/negotiations/") {
      if (req.method !== "POST") return new Response("Method not allowed", { status: 405 });
      const body = await req.json();
      return await handleCreate(supabase, body);
    }

    return new Response(JSON.stringify({ error: "Route not found" }), { status: 404, headers: { "Content-Type": "application/json" } });
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), { status: 500, headers: { "Content-Type": "application/json" } });
  }
});
