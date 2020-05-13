# -*- coding: utf-8 -*-

import sys
import json
import requests
from urllib.request import  quote

# Api
url = 'http://api.map.baidu.com/geocoder/v2/'
# 输出类型
output = 'json'
# 密钥
ak = 'ejxfGfepWQOUT2toG8GeGPN0rATxhBds'
# 为防止乱码，先进行编码
address = quote(sys.argv[1])
uri = url + '?' + 'address=' + address  + '&output=' + output + '&ak=' + ak 
# 请求第一次获得经纬度
req = requests.get(uri)

# 返回为json,进行解析
temp = json.loads(req.text)
temp = req.json()

# 获得经纬度
lat = temp['result']['location']['lat']
lng = temp['result']['location']['lng']

# 请求第二次用经纬度去获得位置信息
url_reback = 'http://api.map.baidu.com/geocoder/v2/?location=' + str(lat) + ',' + str(lng) + '&output=' + output + '&pois=1&ak=' + ak
req_reback = requests.get(url_reback)
data = json.loads(req_reback.text)

print("省：\t", data['result']['addressComponent']['province'])
print("市：\t", data['result']['addressComponent']['city']) 
print("区：\t", data['result']['addressComponent']['district'])
print("街：\t", data['result']['addressComponent']['street'])
print("地址：\t", data['result']['formatted_address'])

