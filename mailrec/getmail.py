
# from genericpath import exists
# from imaplib import IMAP4
from justmencrypt import decrypt
from file_decode import decodedir
from getTextFromPDF import parsedir
from os.path import isfile,dirname,abspath,exists, join
import os
import re  


# -*- coding: utf-8 -*-
import poplib,email,telnetlib
import datetime,time,sys,traceback
from email.parser import Parser
from email.header import decode_header
from email.utils import parseaddr

class down_email():

    def __init__(self,user,password,eamil_server):
        # 输入邮件地址, 口令和POP3服务器地址:
        self.user = user
        # 此处密码是授权码,用于登录第三方邮件客户端
        self.password = password
        self.pop3_server = eamil_server

    # 获得msg的编码
    def guess_charset(self,msg):
        charset = msg.get_charset()
        if charset is None:
            content_type = msg.get('Content-Type', '').lower()
            pos = content_type.find('charset=')
            if pos >= 0:
                charset = content_type[pos + 8:].strip()
        return charset

    #获取邮件内容
    def get_content(self,msg):
        content=''
        content_type = msg.get_content_type()
        # print('content_type:',content_type)
        if content_type == 'text/plain': # or content_type == 'text/html'
            content = msg.get_payload(decode=True)
            charset = self.guess_charset(msg)
            if charset:
                content = content.decode(charset)
        return content
    

    # 字符编码转换
    # @staticmethod
    def decode_str(self,str_in):
        value, charset = decode_header(str_in)[0]
        if charset:
            value = value.decode(charset)
        return value

    # 解析邮件,获取附件
    def get_att(self,msg_in,savedir):
        attachment_files = []
        for part in msg_in.walk():
            # 获取附件名称类型
            file_name = part.get_param("name")  # 如果是附件，这里就会取出附件的文件名
            # file_name = part.get_filename() #获取file_name的第2中方法
            # contType = part.get_content_type()
            if file_name:
                h = email.header.Header(file_name)
                # 对附件名称进行解码
                dh = email.header.decode_header(h)
                filename = dh[0][0]
                if dh[0][1]:
                    # 将附件名称可读化
                    filename = self.decode_str(str(filename, dh[0][1]))
                    # print(filename)
                    # filename = filename.encode("utf-8")
                # 下载附件
                data = part.get_payload(decode=True)
                # 在指定目录下创建文件，注意二进制文件需要用wb模式打开
                att_path = os.path.join(base_path,savedir)
                if not exists(att_path):
                    os.mkdir(att_path)
                att_filename = os.path.join(att_path,filename)
                att_file = open(att_filename, 'wb')
                att_file.write(data)  # 保存附件
                att_file.close()
                attachment_files.append(filename)

        return attachment_files

    def run_ing(self,savedir):
        
        global mark_time
        # 连接到POP3服务器,有些邮箱服务器需要ssl加密，可以使用poplib.POP3_SSL
        try:
            telnetlib.Telnet(self.pop3_server, 995)
            self.server = poplib.POP3_SSL(self.pop3_server, 995, timeout=10)
        except:
            time.sleep(5)
            self.server = poplib.POP3(self.pop3_server, 110, timeout=10)
        # 身份认证:
        self.server.user(self.user)
        self.server.pass_(self.password)

        # list()返回所有邮件的编号:
        resp, mails, octets = self.server.list()
        # 可以查看返回的列表类似[b'1 82923', b'2 2184', ...]

        index = len(mails)
        mark = 1
        for i in range(index, 0, -1):# 倒序遍历邮件
            print(i)
        # for i in range(1, index + 1):# 顺序遍历邮件
            resp, lines, octets = self.server.retr(i)
            # lines存储了邮件的原始文本的每一行,
            # 邮件的原始文本:
            if re.findall(b'\xb7',lines[2]):
                continue
            msg_content = b'\r\n'.join(lines).decode('utf-8')
            # 解析邮件:
            msg = Parser().parsestr(msg_content)
            #获取邮件的发件人，收件人， 抄送人,主题
            # hdr, addr = parseaddr(msg.get('From'))
            # From = self.decode_str(hdr)
            # hdr, addr = parseaddr(msg.get('To'))
            # To = self.decode_str(hdr)
            # Cc=parseaddr(msg.get_all('Cc'))[1]# 抄送人
            Subject = self.decode_str(msg.get('Subject'))
            
            # print('from:%s,to:%s,Cc:%s,subject:%s'%(From,To,Cc,Subject))
            # 获取邮件时间,格式化收件时间         
            date1 = time.strptime(msg.get("Date")[0:25], '%a, %d %b %Y %H:%M:%S')
            date2 = time.mktime(date1)
            # 最新邮件时间保存
            if mark :                
                mark_time.append(date2)
                mark = 0                        
                        
            if date2 <= mark_time[0]:
                break # 倒叙用break
                # continue # 顺叙用continue
            else:
                # 获取附件
                if re.findall('交付单', Subject):
                    self.get_att(msg,savedir)

        self.server.quit()

if __name__ == '__main__':

    MAIL_USER = "wujy@zjbdos.com"
    MAIL_PASS = "AIDKHKDLKIJPIPLP"
    imap_server = "imap.exmail.qq.com"

    base_path = abspath(dirname(__file__))
    mark_time_filename = os.path.join(base_path,'marktime.txt')
    savedir = 'mail' #附件保存的相对目录
    mailpath = join(base_path,savedir)
    datafile = '5.txt'

    #开始收取邮件
    mark_time = []
    str_daytime = int(time.time())    
    # n = int(input("请输入解密码:"))
    n=int(202)

    if  isfile(mark_time_filename):
        f = open(mark_time_filename, 'r+')
        mark_time.append(float(f.readline()))
        f.close        
    else :
        mark_time.append(str_daytime) 
    
    try:
        email_class=down_email(user=MAIL_USER,password=decrypt(n,MAIL_PASS),eamil_server=imap_server)
        email_class.run_ing(savedir)
        with open(mark_time_filename,'w') as f:
            f.write(str(mark_time[1]))
            f.close
    except Exception as e:
        import traceback
        ex_msg = '{exception}'.format(exception=traceback.format_exc())
        print(ex_msg)
        # traceback.print_exc()

    #解密收到的邮件
    decodedir(mailpath)

    #解析pdf文件
    parsedir(mailpath,datafile)


    