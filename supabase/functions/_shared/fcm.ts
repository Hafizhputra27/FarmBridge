import { GoogleAuth } from "npm:google-auth-library@9";

const FIREBASE_PROJECT_ID = Deno.env.get("FIREBASE_PROJECT_ID")!;
const FIREBASE_SERVICE_ACCOUNT = JSON.parse(
  Deno.env.get("FIREBASE_SERVICE_ACCOUNT_JSON")!,
);

async function getAccessToken(): Promise<string> {
  const auth = new GoogleAuth({
    credentials: FIREBASE_SERVICE_ACCOUNT,
    scopes: ["https://www.googleapis.com/auth/firebase.messaging"],
  });
  const client = await auth.getClient();
  const token = await client.getAccessToken();
  if (!token.token) throw new Error("Failed to obtain FCM access token");
  return token.token;
}

export interface SendPushParams {
  deviceToken: string;
  title: string;
  body: string;
  deepLink?: string;
}

export interface SendPushResult {
  ok: boolean;
  error?: string;
}

export async function sendPush(
  { deviceToken, title, body, deepLink }: SendPushParams,
): Promise<SendPushResult> {
  if (!deviceToken) {
    return { ok: false, error: "missing device_token" };
  }

  const accessToken = await getAccessToken();

  const res = await fetch(
    `https://fcm.googleapis.com/v1/projects/${FIREBASE_PROJECT_ID}/messages:send`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        message: {
          token: deviceToken,
          notification: { title, body },
          data: deepLink ? { deep_link: deepLink } : undefined,
        },
      }),
    },
  );

  if (!res.ok) {
    const errText = await res.text();
    // Token invalid/expired atau request salah tidak boleh crash pemanggil.
    return { ok: false, error: `FCM ${res.status}: ${errText}` };
  }

  return { ok: true };
}
