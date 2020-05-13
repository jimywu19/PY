
import json
import re

patten = re.compile('[\u4e00-\u9fa5]+')   #[\u4e00-\u9fa5]是匹配所有中文的正则 
patten1 = re.compile('\d{6}')
with open('f:\\new2.json', 'r',encoding='utf-8') as f:
    content = json.load(f)
    servers = content['returnObj']['servers']
    serv_len = len(servers)
    i = 0
    serv_name = set()
    serv_host = set()

    host_count = dict()
    with open('f:\\hostid2.txt','wt') as f2:
        while i < (serv_len-1):
            username = patten.findall(servers[i]['name'])
            serv_create_date = patten1.search(servers[i]['name'])
            if serv_create_date :
                serv_create_date = serv_create_date.group(0)
                year =  '20' + serv_create_date[:2]
                month = serv_create_date[2:4]
                date = serv_create_date[4:]
                
                print(username,year,month,date)

            hostname = servers[i]['hostId']
            
            serv_name.update(username)
            serv_host.add(hostname)
            i += 1
    # print(serv_name)
    # print(serv_host)
    # print(host_count)
