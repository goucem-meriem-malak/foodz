// Uploads a dish photo to Supabase Storage for admins and the owner.
//
// The app sends the image bytes with the user's Firebase ID token. The function
// checks the token, then checks in Firestore (with the service account) that the
// caller is a verified, unblocked admin or owner. Only then does it store the
// photo, using the Supabase service key that Supabase injects into this
// function. The storage bucket has no public write access at all, so nobody can
// upload without going through this check. Photos are public to read.
import { createRemoteJWKSet, importPKCS8, jwtVerify, SignJWT } from "npm:jose@5.9.6";

type Json = Record<string, unknown>;

const sa = JSON.parse(Deno.env.get("FIREBASE_SERVICE_ACCOUNT") ?? "{}") as Json;
const PROJECT = String(sa.project_id ?? "");
const FS = `https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/(default)/documents`;
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const BUCKET = "dishes";
const MAX_BYTES = 1_500_000;
const EXT: Record<string, string> = { "image/jpeg": "jpg", "image/png": "png", "image/webp": "webp" };
const JWKS = createRemoteJWKSet(
  new URL("https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com"),
);

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const reply = (status: number, body: Json) =>
  new Response(JSON.stringify(body), { status, headers: { ...CORS, "Content-Type": "application/json" } });

let cached: { token: string; exp: number } | null = null;
async function accessToken(): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  if (cached && cached.exp - 60 > now) return cached.token;
  const key = await importPKCS8(String(sa.private_key), "RS256");
  const assertion = await new SignJWT({ scope: "https://www.googleapis.com/auth/datastore" })
    .setProtectedHeader({ alg: "RS256", typ: "JWT" })
    .setIssuer(String(sa.client_email))
    .setSubject(String(sa.client_email))
    .setAudience("https://oauth2.googleapis.com/token")
    .setIssuedAt()
    .setExpirationTime("1h")
    .sign(key);
  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({ grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer", assertion }),
  });
  if (!res.ok) throw new Error(`token exchange failed: ${res.status}`);
  const data = await res.json();
  cached = { token: data.access_token, exp: now + Number(data.expires_in ?? 3600) };
  return cached.token;
}

async function userProfile(uid: string): Promise<{ role: string; blocked: boolean } | null> {
  const res = await fetch(`${FS}/users/${uid}`, { headers: { Authorization: `Bearer ${await accessToken()}` } });
  if (res.status === 404) return null;
  if (!res.ok) throw new Error(`firestore get: ${res.status}`);
  const fields = ((await res.json()) as Json).fields as Record<string, Json> | undefined;
  return {
    role: String(fields?.role?.stringValue ?? ""),
    blocked: fields?.blocked?.booleanValue === true,
  };
}

/** The first bytes must match the declared type, so a renamed file is refused. */
function looksLike(type: string, b: Uint8Array): boolean {
  if (type === "image/jpeg") return b[0] === 0xff && b[1] === 0xd8 && b[2] === 0xff;
  if (type === "image/png") return b[0] === 0x89 && b[1] === 0x50 && b[2] === 0x4e && b[3] === 0x47;
  if (type === "image/webp") {
    const tag = (from: number) => String.fromCharCode(...b.slice(from, from + 4));
    return tag(0) === "RIFF" && tag(8) === "WEBP";
  }
  return false;
}

const storageHeaders = { apikey: SERVICE_KEY, Authorization: `Bearer ${SERVICE_KEY}` };

const put = (name: string, type: string, bytes: Uint8Array) =>
  fetch(`${SUPABASE_URL}/storage/v1/object/${BUCKET}/${name}`, {
    method: "POST",
    headers: { ...storageHeaders, "Content-Type": type, "x-upsert": "false" },
    body: bytes,
  });

async function createBucket() {
  await fetch(`${SUPABASE_URL}/storage/v1/bucket`, {
    method: "POST",
    headers: { ...storageHeaders, "Content-Type": "application/json" },
    body: JSON.stringify({
      id: BUCKET,
      name: BUCKET,
      public: true,
      file_size_limit: MAX_BYTES,
      allowed_mime_types: Object.keys(EXT),
    }),
  });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: CORS });
  if (req.method !== "POST") return reply(405, { error: "method" });
  try {
    const bearer = (req.headers.get("Authorization") ?? "").replace(/^Bearer /, "");
    if (!bearer) return reply(401, { error: "sign in first" });

    let uid: string;
    let verifiedEmail: boolean;
    try {
      const { payload } = await jwtVerify(bearer, JWKS, {
        issuer: `https://securetoken.google.com/${PROJECT}`,
        audience: PROJECT,
      });
      uid = String(payload.sub);
      verifiedEmail = payload.email_verified === true;
    } catch {
      return reply(401, { error: "bad token" });
    }

    const profile = await userProfile(uid);
    if (!verifiedEmail || !profile || profile.blocked || !["admin", "owner"].includes(profile.role)) {
      return reply(403, { error: "not allowed" });
    }

    const type = (req.headers.get("Content-Type") ?? "").split(";")[0].trim();
    const ext = EXT[type];
    if (!ext) return reply(415, { error: "only jpeg, png or webp" });

    const bytes = new Uint8Array(await req.arrayBuffer());
    if (bytes.length === 0 || bytes.length > MAX_BYTES) return reply(413, { error: "too big" });
    if (!looksLike(type, bytes)) return reply(415, { error: "not an image" });

    const name = `${crypto.randomUUID()}.${ext}`;
    let res = await put(name, type, bytes);
    if (!res.ok) {
      await createBucket(); // first upload ever: the bucket does not exist yet
      res = await put(name, type, bytes);
    }
    if (!res.ok) return reply(502, { error: "storage" });
    return reply(200, { url: `${SUPABASE_URL}/storage/v1/object/public/${BUCKET}/${name}` });
  } catch (e) {
    console.error(e);
    return reply(500, { error: "server" });
  }
});
