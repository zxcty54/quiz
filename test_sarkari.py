import os
import re
from urllib.parse import quote
import requests
from bs4 import BeautifulSoup

# Secret se API Key uthayega, ya fallback key use karega
SCRAPINGANT_API_KEY = os.environ.get("SCRAPINGANT_API_KEY", "f2dac73c566b4f60b9ca989beedeb5de")

TARGET_URL = "https://www.sarkariresult.com/latestjob/"

# Correct ScrapingAnt V2 Endpoint
encoded_target_url = quote(TARGET_URL)
api_endpoint = f"https://api.scrapingant.com/v2/general?url={encoded_target_url}&x-api-key={SCRAPINGANT_API_KEY}&browser=true"

OTHER_STATES_REJECT = [
    "aiims", "cuttack", "odisha", "orissa", "khordha", "balipatna", "oav ", 
    "uttar pradesh", " up ", "uppsc", "madhya pradesh", "mppsc", 
    "rajasthan", "rpsc", "haryana", "hpsc", "maharashtra", "mpsc", 
    "jharkhand", "jpsc", "west bengal", "wbpsc", "punjab", "gujarat", 
    "kerala", "karnataka", "tamil nadu", "andhra", " ap ", "ap mahesh", "mahesh bank",
    "telangana", "tspsc", "assam", "chhattisgarh", "delhi", "dsssb"
]

def clean_html_text(text):
    if not text:
        return ""
    return BeautifulSoup(text, "html.parser").get_text().strip()

def is_hard_rejected(text):
    text_lower = f" {text.lower()} "
    return any(keyword in text_lower for keyword in OTHER_STATES_REJECT)

def test_sarkari_scrapingant():
    print("🔄 Fetching SarkariResult via ScrapingAnt API...")
    try:
        response = requests.get(api_endpoint, timeout=35)
        
        if response.status_code == 200:
            print("✅ Successfully Bypassed Cloudflare! Status 200 OK\n")
            soup = BeautifulSoup(response.text, 'html.parser')
            
            post_div = soup.find('div', id='post') or soup.find('body')
            links = post_div.find_all('a', href=True) if post_div else soup.find_all('a', href=True)
            
            valid_jobs = []
            for link in links:
                title = clean_html_text(link.text)
                url = link['href'].strip()
                
                if len(title) > 8 and "sarkariresult.com" in url:
                    if is_hard_rejected(title):
                        continue
                    valid_jobs.append({"title": title, "url": url})
            
            print(f"🎉 Total Valid Bihar & Central Jobs Found: {len(valid_jobs)}\n")
            print("--- TOP 10 EXTRACTED JOBS ---")
            for idx, job in enumerate(valid_jobs[:10], 1):
                print(f"{idx}. {job['title']}")
                print(f"   URL: {job['url']}\n")
        else:
            print(f"❌ ScrapingAnt Error Code: {response.status_code}")
            print(f"Response: {response.text[:200]}")

    except Exception as e:
        print(f"🚨 Request Error: {e}")

if __name__ == "__main__":
    test_sarkari_scrapingant()
