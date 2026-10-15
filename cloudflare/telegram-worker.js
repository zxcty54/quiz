// MockTester Telegram Worker — Cloudflare me ye code paste karo.
// Secrets (Settings → Variables and Secrets → Add → Type: Secret):
//   BOT_TOKEN  = BotFather wala naya token
//   CHAT_ID    = bot ki chat id
//   APP_KEY    = app ki pehchan key (mocktester-nitesh2026)
// Token is file me KABHI mat likho — sirf Secrets me rahega.

export default {
  async fetch(request, env) {
    if (request.method !== "POST") {
      return new Response("Sirf POST chalega", { status: 405 });
    }
    if (request.headers.get("X-App-Key") !== env.APP_KEY) {
      return new Response("Mana hai", { status: 401 });
    }

    let data;
    try {
      data = await request.json();
    } catch {
      return new Response("JSON galat hai", { status: 400 });
    }

    const text = (data.text || "").toString().slice(0, 4000).trim();
    if (!text) return new Response("text khaali hai", { status: 400 });

    const parseMode = (data.parse_mode || "HTML").toString();
    const replyMarkup = data.reply_markup || undefined;
    const photo = (data.photo || "").toString().trim();

    // Photo hai to sendPhoto (text caption ban jayega), warna sendMessage
    const endpoint = photo ? "sendPhoto" : "sendMessage";
    const payload = photo
      ? {
          chat_id: env.CHAT_ID,
          photo: photo,
          caption: text.slice(0, 1024),
          parse_mode: parseMode,
          reply_markup: replyMarkup,
        }
      : {
          chat_id: env.CHAT_ID,
          text: text,
          parse_mode: parseMode,
          reply_markup: replyMarkup,
        };

    const res = await fetch(
      `https://api.telegram.org/bot${env.BOT_TOKEN}/${endpoint}`,
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(payload),
      }
    );

    const out = await res.text();
    return new Response(out, {
      status: res.status,
      headers: { "Content-Type": "application/json" },
    });
  },
};
