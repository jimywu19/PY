# *-* coding:'utf-8' *-*

import requests
import re
from bs4 import BeautifulSoup
import itchat

def main():

    root_url = "http://news.iciba.com/index.php?mod=dailysentence"
    index_url = root_url
    oldlink = ""
    messageToSomeOne = "凝凝"

    html = request_html_page(index_url)
    link = parse_jinsanEng(html)

    
    itchat.auto_login(hotReload=True)
    #itchat.login()
    userinfo = itchat.search_friends(messageToSomeOne)
    userid = userinfo[0]["UserName"]
    itchat.send(link,toUserName=userid)

def request_html_page(url):
    '''
    
    取url对应的页面源码
    '''

    HEADERS = {
    'accept-encoding': 'gzip, deflate, br',
    'accept-language': 'zh-CN,zh;q=0.9',
    'pragma': 'no-cache',
    'cache-control': 'no-cache',
    'upgrade-insecure-requests': '1',
    'user-agent': "Mozilla/5.0 (iPhone; CPU iPhone OS 11_0 like Mac OS X) AppleWebKit/604.1.38 (KHTML, like Gecko) Version/11.0 Mobile/15A372 Safari/604.1",
}
    try:
        req = requests.get(url,headers=HEADERS)
        req.encoding = 'utf-8'
        if req.status_code == 200:
            return req.text
    except requests.RequestException:
        return None
    
def parse_jinsanEng(html):
    soup = BeautifulSoup(html,'lxml')
    words = soup.find('div',class_="fl dailyEtext")
    e_words = words.find('a',).string
    c_words = words.find_all('h5')
    c_words = c_words[1].string
    return (e_words+'\n'+ c_words)


if __name__ == "__main__":
    
    main()
