from bs4 import BeautifulSoup
import requests
from time import sleep

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

def save_story(title,text):
    with open("d:\luoma_story.txt",'a+',encoding='utf-8') as f:
        if title:
            f.write('\n\t\t\t\t' + title +'\n\n')
        num = len(text)
        i=0
        while i < num:
            f.write('    '+ text[i].get_text() + "\n")
            i+=1

def main():
    baseUrl = "https://www.yooread.net/5/4513/"
    url =baseUrl + "177969.html"
    change = 1
    while True:
        sleep(2)        
        html = req_luoma(url)
        soup = BeautifulSoup(html,"lxml")
        if change == 1 :
            title = soup.find('h1').string
        else :
            title = ''
        # story = soup.get_text()
        story = soup.find(class_="read-content").find_all('p')
        page = soup.find(class_='mlfy_page').find_all('a')[3]
        page_string = page.string
        if page_string != '返回列表':
            next_i = page.get('href')
            url = baseUrl + '../..' + next_i         
            if page_string == '下一页':
                change = 0
            else :
                change = 1
            save_story(title,story)
        else :
            break

if __name__ == "__main__":
    main()
    # start = 177969
    # end = 177996

    # for i in range(start,end+1): 
    #     main(i)
    #     sleep(5)



