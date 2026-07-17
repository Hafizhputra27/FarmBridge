import { createClient } from "npm:@supabase/supabase-js@2";
import { FREQUENCY_DAYS } from "../_shared/frequency.ts";

function parsePath(path: string): { id?: string } {
  const parts = path.replace(/^\/recurring-orders\/?/, "").split("/").filter(Boolean);
  return { id: parts[0] };
}

const VALID_STATUSES = ["active", "paused", "cancelled"];

// --- POST /recurring-orders ---
async function handleCreate(supabase: ReturnType<typeof createClient>, body: Record<string, unknown>) {
  const { buyer_id, farmer_id, listing_id, quantity, frequency, locked_price } = body;

  if (!buyer_id || !farmer_id || !listing_id || quantity == null || !frequency || locked_price == null) {
    return new Response(JSON.stringify({ error: "buyer_id, farmer_id, listing_id, quantity, frequency, locked_price wajib" }), { status: 400, headers: { "Content-Type": "application/json" } });
  }
  if (!(frequency as string in FREQUENCY_DAYS)) {
    return new Response(JSON.stringify({ error: `frequency harus salah satu: ${Object.keys(FREQUENCY_DAYS).join(", ")}` }), { status: 400, headers: { "Content-Type": "application/json" } });
  }
  if (Number(quantity) <= 0) {
    return new Response(JSON.stringify({ error: "quantity harus > 0" }), { status: 400, headers: { "Content-Type": "application/json" } });
  }
  if (Number(locked_price) <= 0) {
    return new Response(JSON.stringify({ error: "locked_price harus > 0" }), { status: 400, headers: { "Content-Type": "application/json" } });
  }

  const { data: listing, error: listingErr } = await supabase.from("listings").select("status").eq("id", listing_id as string).single();
  if (listingErr || !listing) return new Response(JSON.stringify({ error: "Listing tidak ditemukan" }), { status: 404, headers: { "Content-Type": "application/json" } });
  if (listing.status !== "active") return new Response(JSON.stringify({ error: "listing_id sudah tidak berstatus active" }), { status: 400, headers: { "Content-Type": "application/json" } });

  const nextOrderDate = new Date();
  nextOrderDate.setDate(nextOrderDate.getDate() + FREQUENCY_DAYS[frequency as string]);

  const { data: order, error: insertErr } = await supabase.from("recurring_orders").insert({
    buyer_id, farmer_id, listing_id, quantity, frequency, locked_price,
    next_order_date: nextOrderDate.toISOString().slice(0, 10),
    status: "active",
  }).select("id, next_order_date").single();

  if (insertErr) throw new Error("Gagal membuat recurring order: " + insertErr.message);

  return new Response(JSON.stringify({ recurring_order_id: order.id, next_order_date: order.next_order_date }), { status: 200, headers: { "Content-Type": "application/json" } });
}

// --- PATCH /recurring-orders/:id ---
async function handlePatch(supabase: ReturnType<typeof createClient>, id: string, body: Record<string, unknown>) {
  const { status } = body;
  if (!status || !VALID_STATUSES.includes(status as string)) {
    return new Response(JSON.stringify({ error: `status harus salah satu: ${VALID_STATUSES.join(", ")}` }), { status: 400, headers: { "Content-Type": "application/json" } });
  }

  const { data: order, error: getErr } = await supabase.from("recurring_orders").select("status").eq("id", id).single();
  if (getErr || !order) return new Response(JSON.stringify({ error: "Recurring order tidak ditemukan" }), { status: 404, headers: { "Content-Type": "application/json" } });

  if (order.status === "cancelled") {
    return new Response(JSON.stringify({ error: "Recurring order sudah cancelled, transisi status tidak valid" }), { status: 409, headers: { "Content-Type": "application/json" } });
  }

  const { error: updateErr } = await supabase.from("recurring_orders").update({ status }).eq("id", id);
  if (updateErr) throw new Error("Gagal update status: " + updateErr.message);

  return new Response(JSON.stringify({ recurring_order_id: id, status }), { status: 200, headers: { "Content-Type": "application/json" } });
}

// --- ROUTER ---
Deno.serve(async (req: Request) => {
  const supabase = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);

  const url = new URL(req.url);
  const pathname = url.pathname.replace(/^\/functions\/v1\/recurring-orders/, "/recurring-orders");
  const { id } = parsePath(pathname);

  try {
    if (!id && req.method === "POST") {
      const body = await req.json();
      return await handleCreate(supabase, body);
    }
    if (id && req.method === "PATCH") {
      const body = await req.json();
      return await handlePatch(supabase, id, body);
    }
    return new Response(JSON.stringify({ error: "Route not found" }), { status: 404, headers: { "Content-Type": "application/json" } });
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), { status: 500, headers: { "Content-Type": "application/json" } });
  }
});
