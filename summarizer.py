import os
import json
import time
from datetime import datetime
from groq import Groq

# -------------------------------------------------------------
# API Client Setup
# -------------------------------------------------------------
GROQ_KEY = os.environ.get("GROQ_API_KEY")
client = Groq(api_key=GROQ_KEY) if GROQ_KEY else None
MODELS = ["llama-3.1-8b-instant", "llama-3.3-70b-versatile"]

def call_groq_safe(prompt, system_role="You are a JSON generator assistant."):
    time.sleep(1)
    for model_name in MODELS:
        try:
            response = client.chat.completions.create(
                model=model_name,
                messages=[
                    {"role": "system", "content": system_role},
                    {"role": "user", "content": prompt}
                ],
                temperature=0.01,
                response_format={"type": "json_object"},
                max_tokens=3000,
                timeout=45,
            )
            print(f"⚡ Groq LLM Success using [{model_name}]!")
            return response.choices[0].message.content
        except Exception as e:
            print(f"⚠️ Model [{model_name}] skipped ({e}). Trying next...")
            time.sleep(1)
    return ""

def generate_clean_summary(raw_news_list, target_date_str, is_national=False):
    raw_text = "\n".join(raw_news_list)[:6500]

    if not raw_text.strip():
        print(f"⚠️ No raw news text found for {'National' if is_national else 'Bihar'}.")
        return None

    scope_name = "India National" if is_national else "Bihar State"
    tag_name = "🎯 National Special / India Affairs" if is_national else "🎯 BPSC Special / Bihar Current Affairs"

    prompt = f"""
    You are a Senior News Summarizer & Editor.
    Below is raw news text scraped for yesterday ({target_date_str}) at {scope_name} Level:
    
    {raw_text}
    
    STRICT ALLOWED CATEGORIES (Pick ONLY from these 5 exact names):
    1. "Govt Schemes & Policies"
    2. "Infrastructure, Economy & Reports"
    3. "Science, Defense & Environment"
    4. "International Affairs & Summits"
    5. "Appointments, Awards & Sports"

    STRICT REJECTION & DISCARD RULES:
    1. REJECT routine administrative instructions, local politics, crime, and accidents.
    2. REJECT Education, Schools, University, Vacancies, Exam Notices, Admit Cards, and Results.
    3. ACCEPT ALL important Government schemes, MoUs, infrastructure projects, environment updates, and national/state reports.

    CRITICAL BULLET POINT RULES (PURE NEWS EXPLANATION ONLY):
    - Write ALL 3 Bullets in **Hinglish** (Hindi written in Roman English script).
    - Focus STRICTLY on explaining WHAT happened in the news (Facts, Figures, Details).
    - STRICTLY FORBIDDEN: Do NOT write "importance", "strategic significance", "exam value", or filler opinions.
    - Bullet 1 (What Happened): Core event, decision, Ministry/Department, or location.
    - Bullet 2 (Numbers & Facts): Specific budget outlay, target date, numerical figures, MoU amount, or rank.
    - Bullet 3 (Further News Detail): Additional factual details about how the scheme/event works or implementation steps.
    - Do NOT use Markdown asterisks (**).

    JSON SCHEMA OUTPUT:
    {{
      "news_cards": [
        {{
          "id": "news_01",
          "title": "Clean Detailed Hinglish Headline with Specific Fact",
          "category": "Select EXACT matching category",
          "bullets": [
            "Bullet 1: Pure news fact / decision in Hinglish",
            "Bullet 2: Exact numerical data / budget / details in Hinglish",
            "Bullet 3: Further news explanation / implementation details in Hinglish"
          ],
          "exam_tag": "{tag_name}",
          "date": "{target_date_str}"
        }}
      ]
    }}
    """
    return call_groq_safe(prompt, system_role="Senior News Editor")

def append_to_master_history(news_cards, yesterday_key, is_national=False):
    master_file = "all_national_news_history.json" if is_national else "all_bihar_news_history.json"
    
    master_data = {}
    if os.path.exists(master_file):
        try:
            with open(master_file, "r", encoding="utf-8") as f:
                master_data = json.load(f)
        except Exception as e:
            print(f"⚠️ Master History file read error ({master_file}): {e}")
            
    master_data[yesterday_key] = news_cards
    
    if len(master_data) > 60:
        oldest_key = sorted(master_data.keys())[0]
        del master_data[oldest_key]

    with open(master_file, "w", encoding="utf-8") as f:
        json.dump(master_data, f, ensure_ascii=False, indent=2)
    print(f"✅ Appended under key '{yesterday_key}' into '{master_file}'!")

# -------------------------------------------------------------
# MAIN SUMMARIZER PIPELINE
# -------------------------------------------------------------
def run_summarizer():
    if not GROQ_KEY:
        print("❌ Error: GROQ_API_KEY environment variable not found!")
        exit(1)

    if not os.path.exists("rawnews.json"):
        print("❌ Error: 'rawnews.json' does not exist. Run 'scraper.py' first!")
        exit(1)

    with open("rawnews.json", "r", encoding="utf-8") as f:
        raw_data = json.load(f)

    date_str = raw_data.get("target_date_str", datetime.now().strftime("%d %b %Y"))
    key_str = raw_data.get("target_key_str", datetime.now().strftime("%Y-%m-%d"))

    print(f"🤖 Processing AI Summaries for Date: {date_str}\n")

    # === A. PROCESS BIHAR NEWS ===
    print("📍 --- AI PROCESSING: BIHAR NEWS ---")
    bihar_raw_list = raw_data.get("bihar_raw_news", [])
    if bihar_raw_list:
        ai_bihar = generate_clean_summary(bihar_raw_list, date_str, is_national=False)
        if ai_bihar:
            try:
                parsed_bihar = json.loads(ai_bihar.strip())
                with open("bihar_news.json", "w", encoding="utf-8") as f:
                    json.dump(parsed_bihar, f, ensure_ascii=False, indent=2)
                print("✅ bihar_news.json successfully updated!")
                if "news_cards" in parsed_bihar and len(parsed_bihar["news_cards"]) > 0:
                    append_to_master_history(parsed_bihar["news_cards"], key_str, is_national=False)
            except Exception as e:
                print(f"❌ Bihar JSON Error: {e}")

    print("\n------------------------------------\n")

    # === B. PROCESS NATIONAL NEWS ===
    print("🇮🇳 --- AI PROCESSING: NATIONAL NEWS ---")
    national_raw_list = raw_data.get("national_raw_news", [])
    if national_raw_list:
        ai_national = generate_clean_summary(national_raw_list, date_str, is_national=True)
        if ai_national:
            try:
                parsed_national = json.loads(ai_national.strip())
                with open("national_news.json", "w", encoding="utf-8") as f:
                    json.dump(parsed_national, f, ensure_ascii=False, indent=2)
                print("✅ national_news.json successfully updated!")
                if "news_cards" in parsed_national and len(parsed_national["news_cards"]) > 0:
                    append_to_master_history(parsed_national["news_cards"], key_str, is_national=True)
        except Exception as e:
            print(f"❌ National JSON Error: {e}")

    print("\n🚀 Step 2 Done: Summaries generated & saved successfully.")

if __name__ == "__main__":
    run_summarizer()
