from os.path import abspath
import sys
import time
import re
import os


time1 = time.time()
# print("初始时间为：",time1)

import os.path
from pdfminer.pdfparser import  PDFParser, PDFDocument
from pdfminer.pdfinterp import PDFResourceManager, PDFPageInterpreter
from pdfminer.converter import PDFPageAggregator
from pdfminer.layout import LTTextBoxHorizontal,LAParams
from pdfminer.pdfinterp import PDFTextExtractionNotAllowed

ROOT_DIR='D:\\Lenovo\\Documents\\py'
EIP = list()


# text_path = r'words-words.pdf'
#text_path = r'IP置换交付单-罗滨20200103E1.pdf'

def getIp(text):
    '''解析字段中的IP地址'''
    text
    result = re.findall(r"\b(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\b", text)
    if result: 
        return result


def parse(file):
    '''解析PDF文本，并保存到TXT文件中'''
    fp = open(file,'rb')
    #用文件对象创建一个PDF文档分析器
    parser = PDFParser(fp)
    #创建一个PDF文档
    doc = PDFDocument()
    #连接分析器，与文档对象
    parser.set_document(doc)
    doc.set_parser(parser)
    #提供初始化密码，如果没有密码，就创建一个空的字符串
    doc.initialize()
    #检测文档是否提供txt转换，不提供就忽略
    if not doc.is_extractable:
        raise PDFTextExtractionNotAllowed
    else:
        #创建PDF，资源管理器，来共享资源
        rsrcmgr = PDFResourceManager()
        #创建一个PDF设备对象
        laparams = LAParams()
        device = PDFPageAggregator(rsrcmgr,laparams=laparams)
        #创建一个PDF解释其对象
        interpreter = PDFPageInterpreter(rsrcmgr,device)
        #循环遍历列表，每次处理一个page内容
        # doc.get_pages() 获取page列表
        for page in doc.get_pages():
            try :
                interpreter.process_page(page)
            
                #接受该页面的LTPage对象
                layout = device.get_result()
                # 这里layout是一个LTPage对象 里面存放着 这个page解析出的各种对象
                # 一般包括LTTextBox, LTFigure, LTImage, LTTextBoxHorizontal 等等
                # 想要获取文本就获得对象的text属性，
                for x in layout:
                    if(isinstance(x,LTTextBoxHorizontal)):
                        results = x.get_text().replace(" ","")
                        ipAddress = getIp(results)
                        if ipAddress:
                            EIP.extend(ipAddress)
            except:
                continue

        with open('2.txt','a') as f:
            for line in EIP:
                f.write(line+"\n")


if __name__ == '__main__':
    parse("20义数云平台资源交付单--何旭1008_427309286238969.pdf")
    # for root,dirs,files in os.walk(ROOT_DIR):
    #     for filename in files:
    #         if filename.endswith('.pdf'):
    #             absname = os.path.join(root,filename)
    #             parse(absname)
    time2 = time.time()
    print("总共消耗时间为:",time2-time1)
