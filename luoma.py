from bs4 import BeautifulSoup
import requests

HEADERS = {
    'user-agent': "Mozilla/5.0 (iPhone; CPU iPhone OS 11_0 like Mac OS X) AppleWebKit/604.1.38 (KHTML, like Gecko) Version/11.0 Mobile/15A372 Safari/604.1",
}

def req_luoma(url):
    try:
        req = requests.get(url,headers=HEADERS)
        if req.status_code == 200:
            return req.content
    except requests.RequestException:
        return None

def main():
    baseUrl = "https://www.yooread.net/5/4513/"
    start = '177969'
    end = '177996'
     
    for i in range(177969,177997):
        url =baseUrl + str(i) + ".html"
        html = req_luoma(url)
        soup = BeautifulSoup(html,"lxml")
        story = soup.find(class_="read-content").findall('p').read_content

if __name__ == "__main__":
    main()

# //*[@id="TextContent"]/p
# //*[@id="TextContent"]/p

