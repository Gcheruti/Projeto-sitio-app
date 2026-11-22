// Edge Function: recebe {papeis, titulo, corpo} do banco e envia via FCM v1.
// Segredos (Supabase > Edge Functions > Secrets): FIREBASE_SERVICE_ACCOUNT, PUSH_SECRET.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const sa = JSON.parse(Deno.env.get("FIREBASE_SERVICE_ACCOUNT") ?? "{}");

function b64url(b: ArrayBuffer | string) {
  const bytes = typeof b === "string" ? new TextEncoder().encode(b) : new Uint8Array(b);
  let s = ""; bytes.forEach((x) => (s += String.fromCharCode(x)));
  return btoa(s).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

async function accessToken(): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const head = b64url(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const claim = b64url(JSON.stringify({
    iss: sa.client_email, scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token", iat: now, exp: now + 3600,
  }));
  const pem = String(sa.private_key).replace(/-----[^-]+-----/g, "").replace(/\s/g, "");
  const der = Uint8Array.from(atob(pem), (c) => c.charCodeAt(0));
  const key = await crypto.subtle.importKey("pkcs8", der,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" }, false, ["sign"]);
  const sig = await crypto.subtle.sign("RSASSA-PKCS1-v1_5", key, new TextEncoder().encode(`${head}.${claim}`));
  const jwt = `${head}.${claim}.${b64url(sig)}`;
  const r = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST", headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({ grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer", assertion: jwt }),
  });
  const j = await r.json();
  if (!j.access_token) throw new Error("oauth: " + JSON.stringify(j));
  return j.access_token;
}

Deno.serve(async (req) => {
  if (req.headers.get("x-push-secret") !== Deno.env.get("PUSH_SECRET")) {
    return new Response("forbidden", { status: 403 });
  }
  const { papeis, titulo, corpo } = await req.json();
  const db = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
  const { data } = await db.from("dispositivos_push").select("token").in("papel", papeis ?? []);
  const tokens = (data ?? []).map((d: { token: string }) => d.token);
  if (!tokens.length) return new Response("sem aparelhos");
  let at: string;
  try { at = await accessToken(); } catch (e) { return new Response(`ERRO TOKEN: ${String(e).slice(0, 400)}`); }
  let enviados = 0;
  let erro = "";
  for (const token of tokens) {
    const r = await fetch(`https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`, {
      method: "POST",
      headers: { Authorization: `Bearer ${at}`, "Content-Type": "application/json" },
      body: JSON.stringify({ message: { token, notification: { title: titulo, body: corpo },
        android: { priority: "HIGH", notification: { channel_id: "sitio_avisos" } } } }),
    });
    if (r.ok) enviados++;
    else { erro = `${r.status} ${await r.clone().text()}`; console.error(erro); }
    if (r.ok) { /* ok */ }
    else if (r.status === 404) await db.from("dispositivos_push").delete().eq("token", token);
  }
  return new Response(`enviados ${enviados}/${tokens.length}` + (erro ? ` | ERRO FCM: ${erro.slice(0, 400)}` : ""));
});
