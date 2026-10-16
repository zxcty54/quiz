# AI Mastery Worker — Bihar Special Fix (Prompt-Only)

**Design decision:** Koi topic / exam tag / subject tag NAHI bhejna hai.
AI khud sirf question text padh ke subject pehchanega.

**Problem:** AI report me Bihar Special kabhi dikhta hi nahi.

**Root cause:** Worker sirf question text bhejta hai (sahi hai), lekin system prompt ki
subject-soch me **"Bihar Special" naam ka subject hai hi nahi**. AI ke paas History,
Polity, Physics type ke purane dabbe hain — Bihar wala sawal ya to "History" me
zabardasti ghus jata hai, ya gayab ho jata hai. Isliye fix sirf prompt me hai:
AI ko sikhana hai ki Bihar ka sawal dikhe to use "Bihar Special" dabbe me dale.

App me kuch change NAHI hoga. Worker me sirf prompt ke 2 hisse badalne hain.

---

## Edit 1 — Rule 1 ke turant baad ye naya rule jodo

System prompt me jo line hai:

```
1. STRICT SUBJECT INDEPENDENCE: Never merge subjects into combined strings (e.g., do NOT output "History & Polity"). Keep "History", "Polity", "Physics", "Chemistry", "Biology", "Economics", "Quantitative Aptitude" strictly separate.
```

Uske **turant baad** ye jod do:

```
1B. SUBJECT CLASSIFICATION FROM QUESTION TEXT (no topic/subject tags are provided — YOU must infer the subject from the question itself):
   - The subject you infer MUST be one of ONLY these: "Physics", "Chemistry", "Biology", "Polity", "History", "Geography", "Economics", "Quantitative Aptitude", "Reasoning", "English", "Bihar Special", "Static GK", "Current Affairs".
   - BIHAR SPECIAL RULE (VERY IMPORTANT): Any question about the state of Bihar — its history (Magadha, Maurya & Pataliputra, Pala dynasty, Sher Shah, 1857 and the freedom movement in Bihar), geography (rivers, districts, soil, climate of Bihar), polity and governance of Bihar, Bihar economy, art and culture (Madhubani painting, folk songs, festivals of Bihar), society (castes, tribes, languages of Bihar), or famous personalities of Bihar — MUST be classified as subject "Bihar Special". NEVER put a Bihar question into History, Geography or Polity, even if it looks like general history or geography.
   - If a question mentions Bihar, Patna, or any Bihar district, place or person, prefer "Bihar Special" over the generic subject.
   - Keep topic names SHORT and CONSISTENT (2-4 words, e.g. "Bihar Art Culture", "Magadha Empire", "Ray Optics"), so the same topic is recognised again in future batches. For Bihar questions in critical_traps_detailed, always use subject "Bihar Special" with such short topic names.
   - Add a subject to subject_analysis only if it has at least 2 attempts in this batch OR it already exists in the lifetime report.
```

## Edit 2 — Prompt ke JSON example me Bihar Special jodo

Prompt me `subject_analysis` wala example isse badal do:

```json
  "subject_analysis": [
    { "subject": "Physics", "accuracy_pct": 68, "attempts": 12 },
    { "subject": "Chemistry", "accuracy_pct": 75, "attempts": 8 },
    { "subject": "Bihar Special", "accuracy_pct": 45, "attempts": 9 }
  ],
```

Aur `critical_traps_detailed` wale example me ek Bihar wala trap jod do
(taaki AI ko format samajh aaye):

```json
    {
      "subject": "Bihar Special",
      "topic": "Bihar Art Culture",
      "subtopic": "Madhubani Painting",
      "accuracy_pct": 25,
      "attempts": 4,
      "repeated_errors": 3
    }
```

---

## Deploy ke baad test

1. Worker Save/Deploy karo. (Secrets wahi rahenge, app me koi change nahi.)
2. Manual trigger: `https://<worker-url>/sync-mastery` kholo (ya cron ka wait karo).
3. App me Profile kholo — Subject chips me **"Bihar Special 45%"** jaisi entry
   aur Critical Traps me Bihar wale topics dikhne chahiye.

**Note:** Purani report me Bihar ke sawal pehle hi "History" me ghule hue hain,
woh apne aap alag nahi honge. Naye batches se Bihar Special alag banna shuru hoga.
Bilkul fresh baseline chahiye to (apna user_id dalke):

```sql
delete from user_ai_insights where user_id = 'APNA_USER_ID';
```

**Ek imandari wali baat:** Bina tag ke AI question text se 80-90% sawal sahi
pehchanega. Jo sawal Bihar se juda hai par usme Bihar/Patna ka naam nahi hai
(jaise koi generic art ya history ka sawal), woh kabhi-kabhi generic subject
me ja sakta hai — ye is design ki natural limit hai.
