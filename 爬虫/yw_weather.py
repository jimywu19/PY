# /html/body/div/div[2]/div/div[2]/div/div[1]/div[1]/ul/li[1]/a

# /html/body/div[1]/div[2]/div/div/div[2]/div[1]/div[5]/p[3]
# /html/body/div[1]/div[2]/div/div/div[2]/div[1]/div[5]



#coding='utf-8'
from lxml import etree
import re
import requests

HEADERS = {
    'accept-encoding': 'gzip, deflate, br',
    'accept-language': 'zh-CN,zh;q=0.9',
    'pragma': 'no-cache',
    'cache-control': 'no-cache',
    'upgrade-insecure-requests': '1',
    'user-agent': "Mozilla/5.0 (iPhone; CPU iPhone OS 11_0 like Mac OS X) AppleWebKit/604.1.38 (KHTML, like Gecko) Version/11.0 Mobile/15A372 Safari/604.1",
}

url = 'http://www.yw.gov.cn/11330782002609848G/bmxxgk/12330782471773341E/index.html'
req = requests.get(url,headers=HEADERS)

html = etree.HTML(req.text)
print(html)
html1 = etree.tostring(html)
html_data = html.xpath('/html/body/div[1]/div[2]/div/div/div[2]/div[1]/div[5]').string


for i in html_data:
    print(i.text)
    '''
print(req.text)