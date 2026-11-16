// Sends push notifications for an order, so staff and clients are alerted even
// when the app is closed. Runs on Supabase Edge Functions (free tier).
//
// Flow: the app updates the order in Firestore, then calls this function with
// { orderId } and the user's Firebase ID token. The function:
//   1. verifies the token,
//   2. reads the order and the caller's profile with a service account,
//   3. allows the call only for the order's client or a staff member,
//   4. decides who to notify from the order's REAL status (never from the request),
//   5. sends each status only once (pushLog document), then calls FCM.
// The service account lives only in the Supabase secret FIREBASE_SERVICE_ACCOUNT.
import { createRemoteJWKSet, importPKCS8, jwtVerify, SignJWT } from "npm:jose@5.9.6";

type Json = Record<string, unknown>;
type Lang = "ar" | "fr" | "en";

const sa = JSON.parse(Deno.env.get("FIREBASE_SERVICE_ACCOUNT") ?? "{}") as Json;
const PROJECT = String(sa.project_id ?? "");
const FS = `https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/(default)/documents`;
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

// ---------- Google access token (cached) ----------
let cached: { token: string; exp: number } | null = null;
async function accessToken(): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  if (cached && cached.exp - 60 > now) return cached.token;
  const key = await importPKCS8(String(sa.private_key), "RS256");
  const assertion = await new SignJWT({
    scope: "https://www.googleapis.com/auth/datastore https://www.googleapis.com/auth/firebase.messaging",
  })
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
const authHeader = async () => ({ Authorization: `Bearer ${await accessToken()}` });

// ---------- Firestore REST helpers ----------
function decode(v: Json): unknown {
  if ("stringValue" in v) return v.stringValue;
  if ("integerValue" in v) return Number(v.integerValue);
  if ("doubleValue" in v) return v.doubleValue;
  if ("booleanValue" in v) return v.booleanValue;
  if ("timestampValue" in v) return v.timestampValue;
  if ("mapValue" in v) return decodeFields((v.mapValue as Json).fields as Json | undefined);
  if ("arrayValue" in v) return (((v.arrayValue as Json).values ?? []) as Json[]).map(decode);
  return null;
}
function decodeFields(fields: Json | undefined): Json {
  const out: Json = {};
  for (const [k, v] of Object.entries(fields ?? {})) out[k] = decode(v as Json);
  return out;
}
const lastSegment = (name: string) => decodeURIComponent(name.split("/").pop() ?? "");

async function getDoc(path: string): Promise<Json | null> {
  const res = await fetch(`${FS}/${path}`, { headers: await authHeader() });
  if (res.status === 404) return null;
  if (!res.ok) throw new Error(`firestore get ${path}: ${res.status}`);
  return decodeFields(((await res.json()) as Json).fields as Json | undefined);
}

async function usersWithRoles(roles: string[]): Promise<{ uid: string; locale: Lang }[]> {
  const res = await fetch(`${FS}:runQuery`, {
    method: "POST",
    headers: { ...(await authHeader()), "Content-Type": "application/json" },
    body: JSON.stringify({
      structuredQuery: {
        from: [{ collectionId: "users" }],
        where: {
          fieldFilter: {
            field: { fieldPath: "role" },
            op: "IN",
            value: { arrayValue: { values: roles.map((r) => ({ stringValue: r })) } },
          },
        },
        limit: 50,
      },
    }),
  });
  if (!res.ok) throw new Error(`firestore query: ${res.status}`);
  const rows = (await res.json()) as Json[];
  return rows
    .filter((r) => r.document)
    .map((r) => {
      const doc = r.document as Json;
      const f = decodeFields(doc.fields as Json | undefined);
      return { uid: lastSegment(String(doc.name)), locale: toLang(f.locale) };
    });
}

async function deviceTokens(uid: string): Promise<string[]> {
  const res = await fetch(`${FS}/users/${uid}/devices?pageSize=20`, { headers: await authHeader() });
  if (!res.ok) return [];
  const body = (await res.json()) as Json;
  return ((body.documents ?? []) as Json[]).map((d) => lastSegment(String(d.name)));
}

async function deleteDevice(uid: string, token: string) {
  await fetch(`${FS}/users/${uid}/devices/${encodeURIComponent(token)}`, {
    method: "DELETE",
    headers: await authHeader(),
  });
}

/** True if this (order, status) was not announced yet. Atomic: create fails with 409 when it exists. */
async function claimOnce(key: string): Promise<boolean> {
  const res = await fetch(`${FS}/pushLog?documentId=${encodeURIComponent(key)}`, {
    method: "POST",
    headers: { ...(await authHeader()), "Content-Type": "application/json" },
    body: JSON.stringify({ fields: { createdAt: { timestampValue: new Date().toISOString() } } }),
  });
  if (res.status === 409) return false;
  if (!res.ok) throw new Error(`pushLog: ${res.status}`);
  return true;
}

// ---------- Messages ----------
const toLang = (v: unknown): Lang => (v === "ar" || v === "fr" || v === "en" ? v : "fr");

type Kind = "new" | "confirmed" | "rejected" | "toCook" | "incoming" | "eta" | "ready" | "onTheWay" | "delivered" | "cancelled";
type Who = "admins" | "chefs" | "couriers" | "client";

const TEXT: Record<Kind, Record<Lang, (c: string, n?: number) => [string, string]>> = {
  new: {
    en: (c) => ["New order", `Order #${c} is waiting for your call.`],
    fr: (c) => ["Nouvelle commande", `Commande #${c} à confirmer par téléphone.`],
    ar: (c) => ["طلب جديد", `الطلب #${c} في انتظار اتصالك لتأكيده.`],
  },
  confirmed: {
    en: (c) => ["Order confirmed", `We confirmed order #${c}. The kitchen is on it.`],
    fr: (c) => ["Commande confirmée", `Nous avons confirmé la commande #${c}. La cuisine s'en occupe.`],
    ar: (c) => ["تم تأكيد الطلب", `تم تأكيد طلبك #${c} والمطبخ يعمل عليه.`],
  },
  rejected: {
    en: (c) => ["Order not accepted", `Order #${c} was not accepted. Open the app for details.`],
    fr: (c) => ["Commande refusée", `La commande #${c} n'a pas été acceptée. Ouvrez l'application.`],
    ar: (c) => ["لم يُقبل الطلب", `لم يتم قبول الطلب #${c}. افتح التطبيق للتفاصيل.`],
  },
  toCook: {
    en: (c) => ["Order to prepare", `Order #${c} is confirmed. Open the kitchen screen.`],
    fr: (c) => ["Commande à préparer", `La commande #${c} est confirmée. Ouvrez l'écran cuisine.`],
    ar: (c) => ["طلب للتحضير", `تم تأكيد الطلب #${c}. افتح شاشة المطبخ.`],
  },
  incoming: {
    en: (c) => ["Delivery coming up", `Order #${c} is confirmed. Get ready.`],
    fr: (c) => ["Livraison à venir", `La commande #${c} est confirmée. Préparez-vous.`],
    ar: (c) => ["توصيل قادم", `تم تأكيد الطلب #${c}. استعد.`],
  },
  eta: {
    en: (c, n) => [`Ready in about ${n} min`, `Order #${c} will be ready in about ${n} minutes.`],
    fr: (c, n) => [`Prête dans environ ${n} min`, `La commande #${c} sera prête dans environ ${n} minutes.`],
    ar: (c, n) => [`جاهز بعد حوالي ${n} دقيقة`, `سيكون الطلب #${c} جاهزًا بعد حوالي ${n} دقيقة.`],
  },
  ready: {
    en: (c) => ["Ready for pickup", `Order #${c} is ready. Claim it now.`],
    fr: (c) => ["Prête à récupérer", `La commande #${c} est prête. Prenez-la en charge.`],
    ar: (c) => ["جاهز للاستلام", `الطلب #${c} جاهز. تولَّ توصيله الآن.`],
  },
  onTheWay: {
    en: (c) => ["On its way", `Your order #${c} is out for delivery.`],
    fr: (c) => ["En route", `Votre commande #${c} est en cours de livraison.`],
    ar: (c) => ["في الطريق", `طلبك #${c} في طريقه إليك.`],
  },
  delivered: {
    en: (c) => ["Delivered", `Order #${c} was delivered. Enjoy your meal!`],
    fr: (c) => ["Livrée", `La commande #${c} a été livrée. Bon appétit !`],
    ar: (c) => ["تم التوصيل", `تم توصيل الطلب #${c}. بالهناء والشفاء!`],
  },
  cancelled: {
    en: (c) => ["Order cancelled", `Order #${c} was cancelled.`],
    fr: (c) => ["Commande annulée", `La commande #${c} a été annulée.`],
    ar: (c) => ["تم إلغاء الطلب", `تم إلغاء الطلب #${c}.`],
  },
};

/** Who hears about each status. Derived from the stored order, not from the request. */
function plan(order: Json): { who: Who; kind: Kind }[] {
  switch (order.status) {
    case "placed": return [{ who: "admins", kind: "new" }];
    case "confirmed":
      return [{ who: "client", kind: "confirmed" }, { who: "chefs", kind: "toCook" }, { who: "couriers", kind: "incoming" }];
    case "rejected": return [{ who: "client", kind: "rejected" }];
    case "preparing": return [{ who: "couriers", kind: "eta" }];
    case "ready": return [{ who: "couriers", kind: "ready" }];
    case "out_for_delivery": return [{ who: "client", kind: "onTheWay" }];
    case "delivered": return [{ who: "client", kind: "delivered" }];
    case "cancelled": {
      const list: { who: Who; kind: Kind }[] = [{ who: "client", kind: "cancelled" }, { who: "admins", kind: "cancelled" }];
      if (order.confirmedAt) list.push({ who: "chefs", kind: "cancelled" }, { who: "couriers", kind: "cancelled" });
      return list;
    }
    default: return [];
  }
}

// ---------- FCM ----------
/** Returns false when the token is dead and should be removed. */
async function sendPush(token: string, title: string, body: string, data: Record<string, string>): Promise<boolean> {
  const res = await fetch(`https://fcm.googleapis.com/v1/projects/${PROJECT}/messages:send`, {
    method: "POST",
    headers: { ...(await authHeader()), "Content-Type": "application/json" },
    body: JSON.stringify({
      message: {
        token,
        notification: { title, body },
        data,
        android: { priority: "HIGH", ttl: "3600s" },
        webpush: { headers: { Urgency: "high", TTL: "3600" }, fcm_options: { link: "/" } },
      },
    }),
  });
  if (res.ok) return true;
  const err = (await res.json().catch(() => ({}))) as Json;
  const status = String(((err.error ?? {}) as Json).status ?? "");
  return !(status === "NOT_FOUND" || status === "UNREGISTERED" || status === "INVALID_ARGUMENT");
}

// ---------- Handler ----------
Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: CORS });
  if (req.method !== "POST") return reply(405, { error: "method" });
  if (!PROJECT) return reply(500, { error: "service account not configured" });

  // 1. Who is calling?
  const bearer = (req.headers.get("authorization") ?? "").replace(/^Bearer\s+/i, "");
  let callerUid: string;
  try {
    const { payload } = await jwtVerify(bearer, JWKS, {
      issuer: `https://securetoken.google.com/${PROJECT}`,
      audience: PROJECT,
    });
    callerUid = String(payload.sub);
  } catch {
    return reply(401, { error: "invalid token" });
  }

  // 2. Which order?
  const input = (await req.json().catch(() => ({}))) as Json;
  const orderId = String(input.orderId ?? "");
  if (!/^[A-Za-z0-9]{10,40}$/.test(orderId)) return reply(400, { error: "orderId" });

  try {
    const [order, caller] = await Promise.all([getDoc(`orders/${orderId}`), getDoc(`users/${callerUid}`)]);
    if (!order || !caller) return reply(404, { error: "not found" });

    // 3. Only the order's client or staff may trigger it.
    const staff = ["admin", "owner", "chef", "delivery"].includes(String(caller.role));
    if (caller.blocked === true || !(staff || order.clientUid === callerUid)) return reply(403, { error: "forbidden" });

    // 4. Once per status.
    const status = String(order.status);
    if (!(await claimOnce(`${orderId}_${status}`))) return reply(200, { sent: 0, duplicate: true });

    // 5. Build recipients and send.
    const code = String(order.code ?? "");
    const prep = Number(order.prepMinutes ?? 0);
    const roleOf: Record<Exclude<Who, "client">, string[]> = {
      admins: ["admin", "owner"], chefs: ["chef"], couriers: ["delivery"],
    };
    let sent = 0;
    for (const step of plan(order)) {
      const people = step.who === "client"
        ? await (async () => {
            const c = await getDoc(`users/${String(order.clientUid)}`);
            return c ? [{ uid: String(order.clientUid), locale: toLang(c.locale) }] : [];
          })()
        : await usersWithRoles(roleOf[step.who]);
      for (const person of people) {
        const [title, body] = TEXT[step.kind][person.locale](code, prep);
        for (const token of await deviceTokens(person.uid)) {
          const alive = await sendPush(token, title, body, { orderId, status, kind: step.kind });
          if (alive) sent++;
          else await deleteDevice(person.uid, token);
        }
      }
    }
    return reply(200, { sent });
  } catch (e) {
    console.error("notify-order failed:", (e as Error).message);
    return reply(500, { error: "internal" });
  }
});
