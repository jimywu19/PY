#!/usr/bin/env python
# conding="utf-8"

import requests
from bs4 import BeautifulSoup

url = "https://cl.fc55.ga/thread0806.php?fid=7"
content = requests.get(url)
print(content.text)
'''
soup = BeautifulSoup(content.text)
polist = soup.findAll('class = "tal"')
print(polist[0].contents[0])
'''