# AI Mastery Worker — Bihar Special Fix (3 Edits)

**Problem:** `user_question_attempts` me Bihar Special (Revision Practice) ke attempts
ja rahe hain, lekin AI report me Bihar Special kabhi dikhta hi nahi.

**Root cause (Worker code me):**
1. Supabase se attempts uthate waqt `topic` aur `test_type` column select hi nahi hote —
   AI ko sirf raw question text milta hai, chapter/subject ka pata hi nahi chalta.
2. System prompt ki subject list me "Bihar Special" (aur Geography/Reasoning/English) hai hi nahi —
   Bihar ke sawal "History" me merge ho jate hain ya gayab.
3. 15-15 ke mixed batch me bina topic tag ke Bihar ke sawal ghul jate hain.

Cloudflare Worker me ye **3 jagah** badlo (find → replace):

---

## Edit 1 — Attempts uthate waqt topic bhi lao

**Find:**
```
`${supabaseUrl}/rest/v1/user_question_attempts?is_analyzed=eq.false&select=id,user_id,user_name,question_text,is_correct,time_taken_seconds,attempted_at&order=attempted_at.asc&limit=150`,
```

**Replace with:**
```
`${supabaseUrl}/rest/v1/user_question_attempts?is_analyzed=eq.false&select=id,user_id,user_name,topic,test_type,question_text,is_correct,time_taken_seconds,attempted_at&order=attempted_at.asc&limit=150`,
```

## Edit 2 — AI ko bhejte waqt topic tag jodo

**Find:**
```js
      const compactBatchData = batch.map(a => ({
        q: a.question_text ? (a.question_text.length > 400 ? a.question_text.substring(0, 400).trim() : a.question_text.trim()) : '',
        correct: a.is_correct,
        sec: a.time_taken_seconds || 0
      }));
```

**Replace with:**
```js
      const compactBatchData = batch.map(a => ({
        topic: a.topic || '',
        type: a.test_type || '',
        q: a.question_text ? (a.question_text.length > 400 ? a.question_text.substring(0, 400).trim() : a.question_text.trim()) : '',
        correct: a.is_correct,
        sec: a.time_taken_seconds || 0
      }));
```

## Edit 3 — Prompt ko Bihar Special sikhayo

System prompt me Rule 1 wali line ke **turant baad** ye naya rule jodo
(jo line hai: `1. STRICT SUBJECT INDEPENDENCE: ... strictly separate.` uske baad):

```
1B. SUBJECT IDENTIFICATION — the "topic" field of every attempt is GROUND TRUTH. Use it FIRST, question text second:
   - If topic contains "Bihar", OR the chapter is about Bihar (Magadha, Pataliputra, Patna, Bihar history/culture/geography/polity, Sufis, 1857 in Bihar, Bihar districts/tribes/art) => subject MUST be "Bihar Special". NEVER merge Bihar Special into History, Geography or Polity.
   - If topic is a mock/set title (e.g. "BSSC CGL Reasoning Sets Set 2"), extract subject from the title: Reasoning => "Reasoning", Aptitude/Maths => "Quantitative Aptitude", English => "English", GK/GS sets => decide subject from the question itself.
   - For revision chapters, topic IS the chapter name (e.g. "Percentage", "Optics", "Art, Culture, Crafts & Heritage of Bihar") — classify from it.
   - Valid subjects ONLY: "Physics", "Chemistry", "Biology", "Polity", "History", "Geography", "Economics", "Quantitative Aptitude", "Reasoning", "English", "Bihar Special", "Static GK", "Current Affairs".
   - Add a subject to subject_analysis only if it has at least 2 attempts in this batch OR already exists in the lifetime report.
   - In critical_traps_detailed, for Bihar chapters set subject "Bihar Special" and write the short theme in "topic" (e.g. topic "Art & Culture", subtopic "Heritage & Crafts"; topic "Magadha Empire", subtopic "Pataliputra").
```

Aur prompt ke JSON example me `subject_analysis` wala hissa isse badal do
(taaki AI har subject ke attempts bhi bataye — merge ki accuracy sahi hogi):

```json
  "subject_analysis": [
    { "subject": "Physics", "accuracy_pct": 68, "attempts": 12 },
    { "subject": "Chemistry", "accuracy_pct": 75, "attempts": 8 },
    { "subject": "Bihar Special", "accuracy_pct": 45, "attempts": 9 }
  ],
```

## Edit 4 (optional, accuracy sahi karne ke liye) — merge ka weight fix

Abhi naye batch ke saare 15 sawal har subject ke weight me gin liye jate hain. Ise badlo:

**Find:**
```js
              const newAttempts = compactBatchData.length;
```
**Replace with:**
```js
              const newAttempts = newSub.attempts || newSub.total_attempts || compactBatchData.length;
```

---

## Deploy ke baad test

1. Worker Save/Deploy karo. (Kuch aur badalne ki zarurat nahi — Secrets wahi rahenge.)
2. Manual trigger: `https://<worker-url>/sync-mastery` kholo (ya cron ka wait karo).
3. App me Profile kholo — Subject chips me **"Bihar Special 45%"** jaisi entry aur traps me
   Bihar wale topics dikhne chahiye.

## Note — purana report

Purani cumulative report me Bihar ke sawal pehle hi "History" me ghule hue hain, woh
apne aap alag nahi honge. Naye batches se Bihar Special alag banna shuru ho jayega.
Bilkul fresh baseline chahiye to Supabase SQL Editor me (apna user_id dalke):

```sql
-- Optional: sirf apne test user ke liye purani report saaf karo
delete from user_ai_insights where user_id = 'APNA_USER_ID';
-- Optional: purane attempts dobara analyze karwana hai to (AI tokens kharch honge)
update user_question_attempts set is_analyzed = false where user_id = 'APNA_USER_ID';
```

## ⚠️ Ek security note (alag se)

`/sync-mastery` aur `/debug-sync` bina kisi key ke koi bhi khol sakta hai —
poora AI sync trigger ho jayega aur error me stack trace bhi dikhta hai.
Ek `SYNC_KEY` secret bana ke in dono paths par check lagana behtar rahega.
