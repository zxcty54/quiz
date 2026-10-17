# Content Proxy (Cloudflare Worker)

`content_proxy.js` ko Cloudflare Worker me chala kar `content_base`
repo private karne ke baad bhi app ko uski saari content surakshit
milegi.

## Bandobast (kram hi sahi hai — ulta mat karna)

1. Worker `content_proxy` banao, ye file ka code chikpao, Deploy.
2. Worker settings > Variables and Secrets me:
   - `APP_KEY` (Secret): app ke liye lambi random key.
   - `GITHUB_TOKEN` (Secret): GitHub fine-grained token, sirf
     `zxcty54/content_base`, permission Contents = Read-only.
3. Browser parakh: `https://<worker-address>/app_config.json?key=<APP_KEY>`
   JSON dikhe to proxy chal pada (repo abhi public hai).
4. App ki saari fetching is Worker address par ghumao (ye kadam
   Arena branch par hoga), APK bana kar parakh lo.
5. **Sabse aakhir me** GitHub par `content_base` ko Private karo.
   Isse pehle karne par purani sari fetching (jsDelivr/raw) band
   ho jayegi.

## Note

- Cache: sectional/revision 30 min, config 2 min, baaki 5 min
  (file ke upar `CACHE_RULES` me hai).
- Key badalni ho to: Cloudflare me `APP_KEY` badlo + app me nayi
  key — dono ek saath.
- Worker free plan ki had: 1 lakh request/roz; cache ki wajah se
  asal GitHub mang usse bahut kam rehti hai.
