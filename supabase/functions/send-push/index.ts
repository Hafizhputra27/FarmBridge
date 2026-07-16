import { sendPush } from "../_shared/fcm.ts";

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  let payload: {
    device_token?: string;
    title?: string;
    body?: string;
    deep_link?: string;
  };

  try {
    payload = await req.json();
  } catch {
    return new Response(
      JSON.stringify({ ok: false, error: "invalid JSON body" }),
      { status: 400, headers: { "Content-Type": "application/json" } },
    );
  }

  const { device_token, title, body, deep_link } = payload;
  if (!device_token || !title || !body) {
    return new Response(
      JSON.stringify({
        ok: false,
        error: "device_token, title, body are required",
      }),
      { status: 400, headers: { "Content-Type": "application/json" } },
    );
  }

  const result = await sendPush({
    deviceToken: device_token,
    title,
    body,
    deepLink: deep_link,
  });

  return new Response(JSON.stringify(result), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
});
