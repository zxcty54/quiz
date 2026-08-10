import os

import json

import time

from datetime import datetime, timezone, timedelta

from groq import Groq



# ============================================================

# CONFIGURATION

# ============================================================



INPUT_FILE = "rawnews.json"

OUTPUT_FILE = "finalnews.json"



GROQ_KEY = os.environ.get("GROQ_API_KEY")

client = Groq(api_key=GROQ_KEY) if GROQ_KEY else None



# Strictly Using 70B Versatile Model

MODEL_NAME = "llama-3.3-70b-versatile"



IST = timezone(timedelta(hours=5, minutes=30))

TODAY_DATE = datetime.now(IST).strftime("%d %b %Y")



SYSTEM_PROMPT = """

You are an expert Current Affairs editor for competitive civil services exams (BPSC, SSC CGL, UPSC).

Your strict task is to analyze the provided article's TITLE and CONTENT, then FILTER, CATEGORIZE, and SUMMARIZE it.



CRITICAL INSTRUCTION ON CATEGORIZATION:

- IGNORE any pre-existing category or tags provided in the input.

- Re-analyze the full text independently and assign the 'category' key ONLY from the strict list of ALLOWED TOPICS below.



STRICT ALLOWED TOPICS (Assign 'category' strictly to one of these exact names):

1. National Polity, Judiciary & Governance

2. Govt Schemes, Policies & Social Welfare

3. National Economy, Union Budget & Banking

4. International Relations, Summits & Global Organizations

5. Science, Technology, Defense & Space

6. Agriculture, Environment, Climate & GI Tags

7. Infrastructure, Energy & Digital Projects

8. Awards, Appointments, Sports, Persons & Indexes

9. Bihar Special Affairs (strictly for Bihar state news)



REJECTION RULES (CRITICAL):

- If the news is about local crime, accidents, viral videos, entertainment, gossip, local domestic dispute, murder, or un-important political rhetoric, set "is_relevant": false.

- ONLY accept news that genuinely fits into one of the ALLOWED TOPICS above.



OUTPUT FORMAT REQUIREMENTS:

Output MUST be strictly valid JSON format with keys:

- "is_relevant": true or false

- "title": A crisp, factual headline in English

- "category": Exact name matched from ALLOWED TOPICS

- "bullets": Array of 2 to 3 exam-relevant factual bullet points

- "exam_tag": 

   - For National: "🎯 National Special / <Category Name>"

   - For Bihar: "🏛️ Bihar Special / <Topic Name>"

"""



def call_groq_versatile(user_prompt, max_retries=5):

    """Calls Groq llama-3.3-70b-versatile with backoff handling to prevent token expiry/limits"""

    if not client:

        print("❌ Groq Client is not initialized! Check GROQ_API_KEY.")

        return None



    for attempt in range(max_retries):

        try:

            response = client.chat.completions.create(

                model=MODEL_NAME,

                messages=[

                    {"role": "system", "content": SYSTEM_PROMPT},

                    {"role": "user", "content": user_prompt}

                ],

                response_format={"type": "json_object"},

                temperature=0.2

            )

            return json.loads(response.choices[0].message.content.strip())



        except Exception as e:

            err_msg = str(e).lower()

            if "429" in err_msg or "rate limit" in err_msg or "token" in err_msg:

                # Exponential backoff: 15s, 30s, 45s wait if token limit hits

                wait_time = (attempt + 1) * 15

                print(f"⚠️ Rate/Token limit hit for {MODEL_NAME}. Pausing for {wait_time}s to reset limit (Retry {attempt + 1}/{max_retries})...")

                time.sleep(wait_time)

            else:

                print(f"⚠️ Groq Error on attempt {attempt + 1}: {e}")

                time.sleep(5)

                

    return None





def summarize_article(item, is_bihar=False):

    title = item.get("title", "")

    content = item.get("content", "")



    news_type = "Bihar State News" if is_bihar else "National Current Affairs"

    user_prompt = (

        f"News Domain: {news_type}\n"

        f"Title: {title}\n"

        f"Content Body: {content}\n\n"

        "Analyze text, filter, assign strict category from syllabus, and output JSON:"

    )



    parsed = call_groq_versatile(user_prompt)



    if not parsed:

        print(f"❌ Skipping [{title[:30]}...] due to persistent API limits/failure.")

        return None



    if not parsed.get("is_relevant", True):

        print(f"  ⏭️ SKIPPED (Unnecessary News): {title[:50]}...")

        return None



    assigned_category = parsed.get("category") or ("Bihar Special Affairs" if is_bihar else "National Polity, Judiciary & Governance")

    default_prefix = "🏛️ Bihar Special" if is_bihar else "🎯 National Special"

    exam_tag = parsed.get("exam_tag") or f"{default_prefix} / {assigned_category}"



    return {

        "title": parsed.get("title", title),

        "category": assigned_category,

        "bullets": parsed.get("bullets", [content[:150] + "..."]),

        "exam_tag": exam_tag,

        "date": TODAY_DATE

    }





def process_all_news():

    if not os.path.exists(INPUT_FILE):

        print(f"❌ {INPUT_FILE} not found!")

        return



    with open(INPUT_FILE, "r", encoding="utf-8") as f:

        raw_data = json.load(f)



    national_raw = raw_data.get("national_raw_news", [])

    bihar_raw = raw_data.get("bihar_raw_news", [])



    print(f"🚀 Starting AI Summarization using ONLY [{MODEL_NAME}]...")

    print(f"📦 Raw Inputs -> National: {len(national_raw)} | Bihar: {len(bihar_raw)}")



    national_cards = []

    bihar_cards = []



    # Process National News

    print("\n🇮🇳 Processing National News...")

    nat_idx = 1

    for item in national_raw:

        print(f"[National {nat_idx}] Summarizing: {item.get('title', '')[:50]}...")

        card_data = summarize_article(item, is_bihar=False)

        

        if card_data:

            formatted_card = {

                "id": f"nat_{nat_idx:02d}",

                "title": card_data["title"],

                "category": card_data["category"],

                "bullets": card_data["bullets"],

                "exam_tag": card_data["exam_tag"],

                "date": card_data["date"]

            }

            national_cards.append(formatted_card)

            nat_idx += 1

            

        time.sleep(5)  # 5-second safe delay for Versatile 70B model



    # Process Bihar News

    print("\n🏛️ Processing Bihar News...")

    bih_idx = 1

    for item in bihar_raw:

        print(f"[Bihar {bih_idx}] Summarizing: {item.get('title', '')[:50]}...")

        card_data = summarize_article(item, is_bihar=True)



        if card_data:

            formatted_card = {

                "id": f"bih_{bih_idx:02d}",

                "title": card_data["title"],

                "category": card_data["category"],

                "bullets": card_data["bullets"],

                "exam_tag": card_data["exam_tag"],

                "date": card_data["date"]

            }

            bihar_cards.append(formatted_card)

            bih_idx += 1

            

        time.sleep(5)  # 5-second safe delay



    output_data = {

        "generated_at": datetime.now(IST).strftime("%Y-%m-%d %H:%M:%S"),

        "national_count": len(national_cards),

        "bihar_count": len(bihar_cards),

        "total_count": len(national_cards) + len(bihar_cards),

        "national_news": national_cards,

        "bihar_news": bihar_cards

    }



    with open(OUTPUT_FILE, "w", encoding="utf-8") as f:

        json.dump(output_data, f, ensure_ascii=False, indent=2)



    print("\n" + "=" * 80)

    print(f"💾 Successfully generated '{OUTPUT_FILE}' using {MODEL_NAME}!")

    print(f"📊 Accepted -> National: {len(national_cards)} | Bihar: {len(bihar_cards)}")

    print("=" * 80)





if __name__ == "__main__":

    process_all_news()
