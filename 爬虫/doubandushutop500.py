# *-* coding:'utf-8' *-*

import requests
import re
import json

def main(page):

    url = 'http://bang.dangdang.com/books/fivestars/01.00.00.00.00.00-recent30-0-0-1-' + str(page)
    html = request_dandan(url)
    items = parse_result(html)

    for item in items:
        save_to_file(item)

def request_dandan(url):
    try:
        req = requests.get(url)
        if req.status_code == '200':
            return req.text
    except requests.RequestException:
        return None

def parse_result(html):
    #pattern = re.compile('<li .*?"list_num red">(\d+).</div>.*?img src="(.*?)" alt=.*?title="(.*?)">.*?',re.S)
    pattern = re.compile('<li>.*?list_num.*?(\d+).</div>.*?<img src="(.*?)".*?class="name".*?title="(.*?)">.*?class="star">.*?class="tuijian">(.*?)</span>.*?class="publisher_info">.*?target="_blank">(.*?)</a>.*?class="biaosheng">.*?<span>(.*?)</span></div>.*?<p><span\sclass="price_n">&yen;(.*?)</span>.*?</li>',re.S)
    items = re.findall(pattern,html)
    print(type(items))
    for item in items:
        yield{
        'range': item[0],
        'image': item[1],
        'title': item[2]
        }

def save_to_file(item):
    with open('book.txt', 'at',encoding='utf-8') as f:
        f.write(json.dumps(item) + '\n')

if __name__ == "__main__":
    for i in range(1,21):
        main(i)







