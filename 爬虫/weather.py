# *-* coding:'utf-8' *-*

import requests
import re
from bs4 import BeautifulSoup
import smtplib
from email.mime.text import MIMEText
from email.header import Header
import itchat

def main():

    root_url = "http://www.yw.gov.cn/11330782002609848G/bmxxgk/12330782471773341E/06/qxyb/"
    index_url = root_url
    MAIL_TO = "wujy@zjbdos.com"
    oldlink = ""
    messageToSomeOne = "凝凝"

    html = request_html_page(index_url)
    link = parse_result(html)

    
    if link == oldlink:
        pass
    else:
        oldlink = link
        weather_link = root_url + link
        weather_html = request_weather(weather_link)
        weather_content = parse_result1(weather_html)

        #send_mail(weather_content,MAIL_TO)
        itchat.auto_login(hotReload=True)
        #itchat.login()
        userinfo = itchat.search_friends(messageToSomeOne)
        userid = userinfo[0]["UserName"]

        itchat.send(weather_content,toUserName=userid)

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
    

def parse_result(html):
    '''
    取最新天气播报的实际url地址
    '''

    soup = BeautifulSoup(html,'lxml')
    link = soup.find("a",string=re.compile("天气预报"))
    #link = link.attrs['href']
    link = link.get("href")
    return link

def parse_result1(html):
    '''
    取天气预报内容
    '''

    soup = BeautifulSoup(html,'lxml')
    weather = soup.find(class_="artm-text").text
    #print(weather)
    return weather

def parse_jinsanEng(html):
    soup = BeautifulSoup(html,'lxml')
    words = soup.find('div',class_="fl dailyEtext")
    e_words = words.find('a',).string
    c_words = words.find('h5').string


def save_to_file(item):
    with open('book.txt', 'at',encoding='utf-8') as f:
        f.write(json.dumps(item) + '\n')

'''
def send_mail(messages,mail_address):
    
    sender = 'yiwu_weather@yw.gov.cn'
    receivers = mail_address
    
    mail_host = "smtp.163.com"
    mail_user = 'fqy471@163.com'
    mail_pass = '123456ab'

    message = MIMEText(messages)
    message['From'] = Header("天气播报员"，"utf-8")
    message['To'] = Header("测试"，'utf-8')
    Header()

    subject = "天气预报"
    message['Subject'] = Header(subject,'utf-8')

    try:
        smtpObj = smtplib.SMTP()
        smtpObj.connect(mail_host,25)
        smtpObj.login(mail_user,mail_pass)
        smtpObj.sendmail(sender,receivers,message.as_string())
    except smtplib.SMTPException:
        print("Error:无法发送邮件")

'''




if __name__ == "__main__":
    
    main()
