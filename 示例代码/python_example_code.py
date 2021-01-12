###### robotparser：解析robots.txt的工具

from urllib import robotparser
parser = robotparser.RobotFileParser()
parser.set_url('https://www.taobao.com/robots.txt')
parser.read()
parser.can_fetch('Baiduspider', 'http://www.taobao.com/article')
True
parser.can_fetch('Baiduspider', 'http://www.taobao.com/product')
False


#取文件下载的URL链接中文件名
import requests
url = 'https://github.com/jackfrued/Python-100-Days/blob/master/Day01-15/14.txt'
filename = url[url.rfind('/') + 1: ]
print(filename)

##以对应的文件名保存url中的文件到本地，
resp = requests.get(url)
with open('/home/jimy' + filename, 'wb') as f:
    f.write(resp.content)
'''
dump       json-->file
load       file-->json
'''


########通过下面的字典避免重复抓取并控制抓取深度

def start_crawl(seed_url, match_pattern, *, max_depth=-1):
    """开始执行爬虫程序并对指定的数据进行持久化操作"""
    conn = pymysql.connect(host='localhost', port=3306,
                           database='crawler', user='root',
                           password='123456', charset='utf8')
    try:
        with conn.cursor() as cursor:
            url_list = [seed_url]
            # 通过下面的字典避免重复抓取并控制抓取深度
            visited_url_list = {seed_url: 0}
            while url_list:
                current_url = url_list.pop(0)
                depth = visited_url_list[current_url]
                if depth != max_depth:
                    # 尝试用utf-8/gbk/gb2312三种字符集进行页面解码
                    page_html = get_page_html(current_url, charsets=('utf-8', 'gbk', 'gb2312'))
                    links_list = get_matched_parts(page_html, match_pattern)
                    param_list = []
                    for link in links_list:
                        if link not in visited_url_list:
                            visited_url_list[link] = depth + 1
                            page_html = get_page_html(link, charsets=('utf-8', 'gbk', 'gb2312'))
                            headings = get_matched_parts(page_html, r'<h1>(.*)<span')
                            if headings:
                                param_list.append((headings[0], link))
                    cursor.executemany('insert into tb_result values (default, %s, %s)',
                                       param_list)
                    conn.commit()



######## mysql 存取
#example 1
# (本机，数据库名lilybbs, 表名 hunan_a)
import  MySQLdb
db=mysqldb.connect(host = 'localhost', user = "root", passwd="0101", db = "lilybbs", use_unicode = 1, charset = "utf8")
cursor = db.cursor()
写入
for i in range(20):
    cursor.execute("insert into hunan_a values (%s, %s, %s, %s, %s, %s, %s, %s)", (id[i], 'h', index[i], time1[i], size[i], hit[i], lz[i], title1[i]))

# example 2
import pymysql
from pymysql import Error

def start_crawl(seed_url, match_pattern, *, max_depth=-1):
    """开始执行爬虫程序并对指定的数据进行持久化操作"""
    conn = pymysql.connect(host='localhost', port=3306,
                           database='crawler', user='root',
                           password='123456', charset='utf8')
    try:
        with conn.cursor() as cursor:
            url_list = [seed_url]
            # 通过下面的字典避免重复抓取并控制抓取深度
            visited_url_list = {seed_url: 0}
            while url_list:
                current_url = url_list.pop(0)
                depth = visited_url_list[current_url]
                if depth != max_depth:
                    # 尝试用utf-8/gbk/gb2312三种字符集进行页面解码
                    page_html = get_page_html(current_url, charsets=('utf-8', 'gbk', 'gb2312'))
                    links_list = get_matched_parts(page_html, match_pattern)
                    param_list = []
                    for link in links_list:
                        if link not in visited_url_list:
                            visited_url_list[link] = depth + 1
                            page_html = get_page_html(link, charsets=('utf-8', 'gbk', 'gb2312'))
                            headings = get_matched_parts(page_html, r'<h1>(.*)<span')
                            if headings:
                                param_list.append((headings[0], link))
                    cursor.executemany('insert into tb_result values (default, %s, %s)',
                                       param_list)
                    conn.commit()
    except Error:
        pass
        # logging.error('SQL:', error)
    finally:
        conn.close()
#example 3
with con.cursor() as cursor:
       result = cursor.execute(
        'insert into tb_dept values (%s, %s, %s)',
        (no, name, loc)
    )
con.commit()
con.close()


######### 遍历windows目录
import os

# root = '%s%s%s' % ('..', os.path.sep, 'food')
# dir = 'c:/users/jimywu/documents/project/food'
dir = os.path.expandvars('%userprofile%\\document\\')
#for root,dirs,files in os.walk()
for  file_list in os.walk(dir):
    for name in file_list[2]:
        print('File: ' + name)


######## turtle 画画

import turtle

turtle.pensize(3)
turtle.pencolor('red')

for i in range(50,100,3):
    turtle.forward(i)
    turtle.right(60)
    
turtle.mainloop()


########### 日志
#### example 1
import logging

logging.basicConfig(format='%(asctime)s %(levelname)s/%(lineno)dL: %(message)s', filename='backup.log', level=logging.DEBUG)
logging.info(sys.argv)

### example 2
import os
import platform
import logging

if platform.platform().startswith('Windows'):
    logging_file = os.path.join(os.getenv('HOMEDRIVE'),
                                os.getenv('HOMEPATH'),
                                'test.log')
else:
    logging_file = os.path.join(os.getenv('HOME'),
                                'test.log')

print("Logging to", logging_file)

logging.basicConfig(
    level=logging.DEBUG,
    format='%(asctime)s : %(levelname)s : %(message)s',
    filename=logging_file,
    filemode='w',
)

logging.debug("Start of the program")
logging.info("Doing something")
logging.warning("Dying now")


####  正则匹配使用
import re

#example 1
string = "我爱北京天安门！"
pattern = re.compile('[\u4e00-\u9fa5]+')   #[\u4e00-\u9fa5]是匹配所有中文的正则 
pattern1 = re.compile('\d{6}')

result = pattern.findall(string)
result1 = re.findall(pattern, string)

#example 2
 m1 = re.match(r'^[0-9a-zA-Z_]{6,20}$', username)


#### 多线程的处理
## example 1
from functools import  partial
from multiprocessing.dummy import Pool as ThreadPool

partial = partial(portScan,port=port)
pool = ThreadPool(10)
pool.map(partial,rdp_hosts)
##example 2
import thread
for x in range(0,threads):
    thread.start_new_thread(synflood,(target,port))
    


#####参数检查
if len(sys.argv) != 4:
    print "用法: ./syn_flood.py [IP地址] [端口] [线程数]"
    print "举例: ../syn_flood.py  1.1.1.1 80 20"
    sys.exit()
####参数读取方法
target = str(sys.argv[1])
port= int(sys.argv[2])
threads = int(sys.argv[3])