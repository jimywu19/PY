import json
import requests

resp = requests.get('http://api.tianapi.com/guonei/?key=50478905e1e7488aefb8b6fcbc66d729&num=10')
data = resp.json()
#data = json.loads(resp.text)
for news in data['newslist']:
    title = news['title']
    url = news['url']
    print(title)
    print(url)
    print("\n")