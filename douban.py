import requests
from bs4 import BeautifulSoup
import re

# def requestUrl()
# for n in range(501):
#     if n%5 = 0:
#         i = n
# url = "https://movie.douban.com/top250?start=i&filter="
# return url

def reqest_douban(url):
    HEADERS={
        'User-Agent':' Mozilla/5.0 (Windows NT 6.1; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/71.0.3578.98 Safari/537.36'
    }
    try :
        response = requests.get(url,headers=HEADERS)
        if response.status_code == 200:
            return response.text
    except requests.RequestException:
        return None

def parase_content(html):
    soup = BeautifulSoup(html, 'lxml')
    items = soup.find(class_='grid_view').findall('li')

    for item in items:
        name = item.find(class_='title').string
        rate = item.find(class_='rating_num').string
        img = item.find('a').find('img').get('src')
        index = item.find(class_='').string
        description = item.find(class_='inq').string
        auth = item.find('p').text
    return index,name,rate,auth,img,description

def main(i):
    url = "https://movie.douban.com/top250?start=" + str(i*25) + "&filter="
    html = reqest_douban(url)
    moves = parase_content(html)
    for name,rate,index,des in moves:
        print(index + name + rate + des )

if __name__ == "__main__":
    for i in range(0,11):
        main(i)


