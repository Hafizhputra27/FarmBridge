import { createClient } from "npm:@supabase/supabase-js@2";
import { sendPush } from "../_shared/fcm.ts";

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

    await supabase.from("cron_execution_log").insert({
      job_name: "check-recurring-orders",
      status: "success",
      message: `${dueOrders?.length ?? 0} recurring order jatuh tempo besok, ${notified} notifikasi terkirim`,
    });

    return new Response(JSON.stringify({ due_orders: dueOrders?.length ?? 0, notified }), { status: 200, headers: { "Content-Type": "application/json" } });
  } catch (error) {
    await supabase.from("cron_execution_log").insert({
      job_name: "check-recurring-orders",
      status: "error",
      message: error.message,
    });
    return new Response(JSON.stringify({ error: error.message }), { status: 500, headers: { "Content-Type": "application/json" } });
  }
});
