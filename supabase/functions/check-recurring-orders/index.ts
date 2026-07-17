import { createClient } from "npm:@supabase/supabase-js@2";
import { sendPush } from "../_shared/fcm.ts";
import { FREQUENCY_DAYS } from "../_shared/frequency.ts";
import { lockInventoryForRecurringCycle } from "../_shared/inventory-locking.ts";

async function triggerDueCycles(supabase: ReturnType<typeof createClient>) {
  const todayStr = new Date().toISOString().slice(0, 10);

  const { data: dueOrders, error: dueErr } = await supabase
    .from("recurring_orders")
    .select("id, listing_id, farmer_id, buyer_id, quantity, locked_price, frequency, listings(title, category)")
    .eq("status", "active")
    .eq("next_order_date", todayStr);

  if (dueErr) throw new Error("Gagal query recurring_orders (trigger): " + dueErr.message);

  let created = 0;
  let skipped = 0;

  for (const order of dueOrders ?? []) {
    const lockResult = await lockInventoryForRecurringCycle(supabase, order);

    const nextDate = new Date();
    nextDate.setDate(nextDate.getDate() + (FREQUENCY_DAYS[order.frequency as string] ?? 30));
    await supabase
      .from("recurring_orders")
      .update({ next_order_date: nextDate.toISOString().slice(0, 10) })
      .eq("id", order.id);

    const listing = order.listings as { title: string | null; category: string | null } | null;
    const listingLabel = listing?.title ?? listing?.category ?? "listing Anda";

    const { data: users } = await supabase
      .from("users")
      .select("id, device_token")
      .in("id", [order.buyer_id, order.farmer_id]);

    if (lockResult.success) {
      created++;
      for (const user of users ?? []) {
        if (!user.device_token) continue;
        try {
          await sendPush({
            deviceToken: user.device_token,
            title: "Recurring order dibuat",
            body: `Siklus baru untuk ${listingLabel} sudah dibuat, menunggu fulfillment`,
            deepLink: lockResult.transaction_id ? `/transaksi/${lockResult.transaction_id}` : undefined,
          });
        } catch {
          // push gagal tidak boleh hentikan siklus lain
        }
      }
    } else {
      skipped++;
      for (const user of users ?? []) {
        if (!user.device_token) continue;
        try {
          await sendPush({
            deviceToken: user.device_token,
            title: "Siklus recurring order dilewati",
            body: `Siklus untuk ${listingLabel} dilewati: ${lockResult.error}`,
          });
        } catch {
          // push gagal tidak boleh hentikan siklus lain
        }
      }
    }
  }

  return { due_today: dueOrders?.length ?? 0, created, skipped };
}

Deno.serve(async (req: Request) => {
  const supabase = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);

  try {
    const tomorrow = new Date();
    tomorrow.setDate(tomorrow.getDate() + 1);
    const tomorrowStr = tomorrow.toISOString().slice(0, 10);

    const { data: dueOrders, error: dueErr } = await supabase
      .from("recurring_orders")
      .select("id, buyer_id, farmer_id, listings(title, category)")
      .eq("status", "active")
      .eq("next_order_date", tomorrowStr);

    if (dueErr) throw new Error("Gagal query recurring_orders: " + dueErr.message);

    let notified = 0;
    for (const order of dueOrders ?? []) {
      const listing = order.listings as { title: string | null; category: string | null } | null;
      const listingLabel = listing?.title ?? listing?.category ?? "listing Anda";

      const { data: users } = await supabase
        .from("users")
        .select("id, device_token")
        .in("id", [order.buyer_id, order.farmer_id]);

      for (const user of users ?? []) {
        if (!user.device_token) continue;
        try {
          await sendPush({
            deviceToken: user.device_token,
            title: "Recurring order besok",
            body: `Recurring order untuk ${listingLabel} jatuh tempo besok`,
            deepLink: "/percakapan",
          });
          notified++;
        } catch {
          // satu push gagal tidak boleh hentikan yang lain
        }
      }
    }

    const cycleResult = await triggerDueCycles(supabase);

    await supabase.from("cron_execution_log").insert({
      job_name: "check-recurring-orders",
      status: "success",
      message: `Reminder H-1: ${dueOrders?.length ?? 0} order, ${notified} notifikasi. ` +
        `Trigger hari-H: ${cycleResult.due_today} due, ${cycleResult.created} dibuat, ${cycleResult.skipped} di-skip.`,
    });

    return new Response(JSON.stringify({
      due_orders: dueOrders?.length ?? 0,
      notified,
      ...cycleResult,
    }), { status: 200, headers: { "Content-Type": "application/json" } });
  } catch (error) {
    await supabase.from("cron_execution_log").insert({
      job_name: "check-recurring-orders",
      status: "error",
      message: error.message,
    });
    return new Response(JSON.stringify({ error: error.message }), { status: 500, headers: { "Content-Type": "application/json" } });
  }
});
