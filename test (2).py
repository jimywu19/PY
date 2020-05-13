
import requests

#取文件下载的URL链接中文件名
url = 'https://github.com/jackfrued/Python-100-Days/blob/master/Day01-15/14.txt'
filename = url[url.rfind('/') + :1]
print(filename)

##以对应的文件名保存url中的文件到本地，
resp = requests.get(url)
with open('/home/jimy' + filename, 'wb') as f:
    f.write(resp.content)
'''
dump       json-->file
load       file-->json
'''



import pygame
pygame.examples.aliens