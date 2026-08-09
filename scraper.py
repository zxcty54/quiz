import requests
from bs4 import BeautifulSoup
import html

url = "https://pib.gov.in/PressReleasePage.aspx?PRID=2296883"

headers = {"User-Agent": "Mozilla/5.0"}
response = requests.get(url, headers=headers)

soup = BeautifulSoup(response.text, "html.parser")

# ✅ Title
title = soup.find("h2", id="Titleh2").get_text(strip=True)

# ✅ Date
date = soup.find("div", id="PrDateTime").get_text(strip=True)

# ✅ Hidden full content (BEST SOURCE)
hidden_content = soup.find("input", id="ltrDescriptionn")["value"]

# HTML decode
clean_content = html.unescape(hidden_content)

print("TITLE:", title)
print("DATE:", date)
print("CONTENT:\n", clean_content)
