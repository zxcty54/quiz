// ============================================================
// MockTester Content Proxy (Cloudflare Worker)
// Kaam: private content_base repo ki files app tak surakshit
// pahunchana. App seedha GitHub nahi, is Worker ko bulata hai.
//
// Zaruri Worker settings (Settings > Variables and Secrets):
//   GITHUB_TOKEN  (Secret)   GitHub fine-grained token,
//                            sirf content_base, Contents: Read-only
//   APP_KEY       (Secret)   App ke liye bani hui lambi key
//
// Abhi repo public hai, isiliye token ke bina bhi parakh sakte
// ho. Private karna SABSE AAKHIR ka kadam hai.
// ============================================================

const REPO = "zxcty54/content_base";
const BRANCH = "main";

// Kaunsi file kitni der cache rahe (second me). Pehla match jeetta hai.
const CACHE_RULES = [
  ["sectional_mock/", 1800],   // 30 min — sectional sets
  ["revision/", 1800],         // 30 min — revision chapters
  ["knowyourbihar/", 1800],    // 30 min
  ["app_config.json", 120],    // 2 min — payment/config: jald badalna chahiye
  ["sectional_data.json", 300],
  ["subject_mapping.json", 300],
];
const DEFAULT_TTL = 300;       // baaki news/json: 5 min

function ttlFor(path) {
  for (const [prefix, ttl] of CACHE_RULES) {
    if (path.startsWith(prefix)) return ttl;
  }
  return DEFAULT_TTL;
}

export default {
  async fetch(request, env, ctx) {
    if (request.method !== "GET") {
      return new Response("Method not allowed", { status: 405 });
    }

    const url = new URL(request.url);
    const path = decodeURIComponent(url.pathname.replace(/^\/+/, ""));
    if (!path || path.includes("..")) {
      return new Response("Not found", { status: 404 });
    }

    // App-key bandish (APP_KEY set ho tabhi lagu)
    if (env.APP_KEY) {
      const key = request.headers.get("X-App-Key") || url.searchParams.get("key") || "";
      if (key !== env.APP_KEY) {
        return new Response("Forbidden", { status: 403 });
      }
    }

    // ?t= type ke parameter cache ko nahi tode (app cache-clear ke liye bhejta hai)
    const cache = caches.default;
    const cacheKey = new Request(url.origin + url.pathname, { method: "GET" });
    const hit = await cache.match(cacheKey);
    if (hit) return hit;

    // GitHub se asali file lao (token hai to private bhi khulega)
    const encoded = path.split("/").map(encodeURIComponent).join("/");
    const upstream = `https://api.github.com/repos/${REPO}/contents/${encoded}?ref=${BRANCH}`;
    const headers = {
      "Accept": "application/vnd.github.raw",
      "User-Agent": "MockTester-content-proxy",
    };
    if (env.GITHUB_TOKEN) headers["Authorization"] = `Bearer ${env.GITHUB_TOKEN}`;

    const gh = await fetch(upstream, { headers });
    if (!gh.ok) {
      return new Response("Upstream error: " + gh.status, {
        status: gh.status === 404 ? 404 : 502,
      });
    }

    // GitHub ka header "download" type ka ata hai; json/txt ko sahi type do
    // taki browser me file dikhe bhi or app ke liye bhi saaf rahe
    const ext = path.split(".").pop().toLowerCase();
    const TEXT_TYPES = {
      json: "application/json; charset=utf-8",
      txt: "text/plain; charset=utf-8",
      md: "text/plain; charset=utf-8",
    };

    const res = new Response(gh.body, {
      status: 200,
      headers: {
        "Content-Type": TEXT_TYPES[ext] || gh.headers.get("Content-Type") || "application/octet-stream",
        "Cache-Control": `public, max-age=${ttlFor(path)}`,
        "X-Proxy-Cache": "MISS",
      },
    });
    ctx.waitUntil(cache.put(cacheKey, res.clone()));
    return res;
  },
};
