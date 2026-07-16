import type { SupabaseClient } from "npm:@supabase/supabase-js@2";

export interface LockInventoryResult {
  success: boolean;
  transaction_id?: string;
  error?: string;
}

export async function lockInventoryOnAccept(
  supabase: SupabaseClient,
  negotiationId: string,
): Promise<LockInventoryResult> {
  const { data: neg, error: negErr } = await supabase
    .from("negotiations")
    .select("listing_id, farmer_id, buyer_id, current_offer_price")
    .eq("id", negotiationId)
    .single();

  if (negErr || !neg) {
    return { success: false, error: "Negotiation tidak ditemukan" };
  }

  const quantityRequested = 0; // will be passed from caller
  // Note: caller must pass quantity — see overload below
  return { success: false, error: "Use lockInventoryOnAcceptWithQuantity" };
}

export async function lockInventoryOnAcceptWithQuantity(
  supabase: SupabaseClient,
  negotiationId: string,
  quantity: number,
): Promise<LockInventoryResult> {
  // 1. Ambil data negotiation
  const { data: neg, error: negErr } = await supabase
    .from("negotiations")
    .select("listing_id, farmer_id, buyer_id, current_offer_price")
    .eq("id", negotiationId)
    .single();

  if (negErr || !neg) {
    return { success: false, error: "Negotiation tidak ditemukan" };
  }

  // 2. Atomic: kurangi quantity_available (first-accepted-wins)
  const { data: listings, error: updateErr } = await supabase
    .from("listings")
    .select("quantity_available, harga_per_unit")
    .eq("id", neg.listing_id)
    .single();

  if (updateErr || !listings) {
    return { success: false, error: "Listing tidak ditemukan" };
  }

  const currentQty = Number(listings.quantity_available);
  if (currentQty < quantity) {
    return { success: false, error: "Stok tidak mencukupi — transaksi lain mungkin sudah mengambil (first-accepted-wins)" };
  }

  const { error: deductErr } = await supabase
    .from("listings")
    .update({ quantity_available: currentQty - quantity })
    .eq("id", neg.listing_id)
    .eq("quantity_available", currentQty); // optimistic concurrency guard

  if (deductErr) {
    return { success: false, error: "Gagal mengurangi stok: " + deductErr.message };
  }

  // 3. Buat transaction PENDING
  const totalAmount = quantity * Number(neg.current_offer_price);
  // Konvensi sama dengan buy-now/index.ts:11 — H+7 dari tanggal accept.
  const promised = new Date();
  promised.setDate(promised.getDate() + 7);
  const { data: tx, error: txErr } = await supabase
    .from("transactions")
    .insert({
      negotiation_id: negotiationId,
      farmer_id: neg.farmer_id,
      buyer_id: neg.buyer_id,
      status: "pending",
      agreed_quantity: quantity,
      total_amount: totalAmount,
      promised_delivery_date: promised.toISOString().slice(0, 10),
    })
    .select("id")
    .single();

  if (txErr) {
    // Rollback: kembalikan stok
    await supabase
      .from("listings")
      .update({ quantity_available: currentQty })
      .eq("id", neg.listing_id);
    return { success: false, error: "Gagal membuat transaksi: " + txErr.message };
  }

  return { success: true, transaction_id: tx.id };
}

export async function releaseInventoryOnReject(
  supabase: SupabaseClient,
  transactionId: string,
): Promise<{ success: boolean; error?: string }> {
  const { data: tx, error: txErr } = await supabase
    .from("transactions")
    .select("agreed_quantity, negotiation_id")
    .eq("id", transactionId)
    .single();

  if (txErr || !tx) {
    return { success: false, error: "Transaction tidak ditemukan" };
  }

  const { data: neg, error: negErr } = await supabase
    .from("negotiations")
    .select("listing_id")
    .eq("id", tx.negotiation_id)
    .single();

  if (negErr || !neg) {
    return { success: false, error: "Negotiation tidak ditemukan" };
  }

  const { data: listing } = await supabase
    .from("listings")
    .select("quantity_available")
    .eq("id", neg.listing_id)
    .single();

  const newQty = Number(listing.quantity_available) + Number(tx.agreed_quantity);

  const { error: updateErr } = await supabase
    .from("listings")
    .update({ quantity_available: newQty })
    .eq("id", neg.listing_id);

  if (updateErr) {
    return { success: false, error: "Gagal rollback stok: " + updateErr.message };
  }

  return { success: true };
}
