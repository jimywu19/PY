import requests
from bs4 import BeautifulSoup

url = "https://www.baidu.com"
req = requests.get(url)
req.incoding="utf-8"
resp = req.text
resp2 =req.content

print(resp)
print(type(resp))

print(resp2)
print(type(resp2))