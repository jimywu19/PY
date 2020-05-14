from bs4 import BeautifulSoup
import requests

HEADERS = {
    'user-agent': "Mozilla/5.0 (iPhone; CPU iPhone OS 11_0 like Mac OS X) AppleWebKit/604.1.38 (KHTML, like Gecko) Version/11.0 Mobile/15A372 Safari/604.1",
}

def req_luoma(url):
    try:
        req = requests.get(url,headers=HEADERS)
        req.encoding = 'utf-8'
        if req.status_code == 200:
            return req.text
    except requests.RequestException:
        return None

def save_story(text):
    with open("d:\luoma_story.txt",'a+',encoding='utf-8') as f:
        num = len(text)
        i=0
        while i < num:
            f.write('\t')
            f.write(text[i].get_text())
            f.write("\n")
            i+=1
     

def main(i):
    baseUrl = "https://www.yooread.net/5/4513/"
    url =baseUrl + str(i) + ".html"
    html = req_luoma(url)
    soup = BeautifulSoup(html,"lxml")
    story = soup.find(class_="read-content")
    story = story.find_all('p')
    save_story(story)

    # story = story.read_content
    # print(story)

if __name__ == "__main__":
    start = 177969
    end = 177996

    for i in range(start,end+1): 
        main(i)


# //*[@id="TextContent"]/p
# //*[@id="TextContent"]/p

