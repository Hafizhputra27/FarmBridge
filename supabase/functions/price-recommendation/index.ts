import { createClient } from "npm:@supabase/supabase-js@2";
import { getRecommendedPrice } from "../_shared/price-recommendation.ts";

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  let payload: { category?: string; region?: string; quantity?: number };
  try {
    payload = await req.json();
  } catch {
    return new Response(
      JSON.stringify({ error: "invalid JSON body" }),
      { status: 400, headers: { "Content-Type": "application/json" } },
    );
  }

  const { category, region, quantity } = payload;
  if (!category || !region) {
    return new Response(
      JSON.stringify({ error: "category and region are required" }),
      { status: 400, headers: { "Content-Type": "application/json" } },
    );
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  const result = await getRecommendedPrice(supabase, { category, region, quantity });

  return new Response(JSON.stringify(result), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
});
