#雨果网新闻爬取

import requests
from bs4 import BeautifulSoup
import xlwt
import time


HEADER = {
    'user-agent': 'Mozilla/5.0 (Windows NT 10.0; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/63.0.3239.132 Safari/537.36'
} 

def request_douban(url):
    try:
        response = requests.get(url,headers=HEADER)
        if response.status_code == 200:
            return response.text
    except requests.RequestException:
        return None


book=xlwt.Workbook(encoding='utf-8',style_compression=0)

sheet=book.add_sheet('雨果新闻',cell_overwrite_ok=True)
sheet.write(0,0,'标题')
sheet.write(0,1,'图片')
sheet.write(0,2,'简介')
sheet.write(0,3,'链接')
sheet.write(0,4,'标签')
sheet.write(0,5,'发布时间')


def time_to_stamp(time):
    result = re.match(r'')

n = 1

def save_to_excel(soup):
    list = soup.find(class_='article_box',attrs={"data-tag" :"latest"}).find_all('div',class_='article')

    for item in list:
        if  item.find(class_="hint"):
            continue
        item_title = item.find(class_='tit').string
        item_desc = item.find(class_='desc').string
        item_img = "http:" + item.find('img').get('src')
        item_link = item.find(class_='info_box').find('a').get('href')
        item_tag = item.find(class_='tag')
        if item_tag :
            item_tag = item_title.string
        else :
            item_tag = ""
        item_time = item.find(class_='user_time').string

        # item_name = item.find(class_='title').string
        # item_img = item.find('a').find('img').get('src')
        # item_index = item.find(class_='').string
        # item_score = item.find(class_='rating_num').string
        # item_author = item.find('p').text
        # item_intr = item.find(class_='inq')
        # if item_intr :
        #     item_intr = item_intr.string
        # else:
        #     item_intr = ""

        # print('爬取电影：' + item_index + ' | ' + item_name +' | ' + item_img +' | ' + item_score +' | ' + item_author +' | ' + item_intr )
        print('爬取新闻：' + item_title + ' | ' + item_desc   )
        
        global n

        sheet.write(n, 0, item_title)
        sheet.write(n, 1, item_img)
        sheet.write(n, 2, item_desc)
        sheet.write(n, 3, item_link)
        sheet.write(n, 4, item_tag)
        sheet.write(n, 5, item_time)

        n = n + 1

def main():
    url = 'https://www.cifnews.com/'
    html = request_douban(url)
    soup = BeautifulSoup(html, 'lxml')
    save_to_excel(soup)

if __name__ == "__main__":
    # for i in range(0, 10):
    main()

book.save(u'雨果新闻.xls')