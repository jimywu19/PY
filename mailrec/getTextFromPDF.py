from os.path import abspath, dirname, join
import re
import os
import json

from pdfminer.pdfparser import  PDFParser, PDFDocument
from pdfminer.pdfinterp import PDFResourceManager, PDFPageInterpreter, PDFTextExtractionNotAllowed
from pdfminer.converter import PDFPageAggregator
from pdfminer.layout import LTTextBoxHorizontal,LAParams

base_path = abspath(dirname(__file__))

def getIp(text):
    '''解析字段中的IP地址'''
    
    ipaddress = re.findall(r"\b(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\b", text)
    if ipaddress: 
        return ipaddress

def parse(file,savefile):
    '''解析PDF文本，并保存到TXT文件中'''
    EIPs = []
    result = dict()
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
        p=0
        for page in doc.get_pages():
            interpreter.process_page(page)
            layout = device.get_result()
            elts=[]
            m = 0
            mindeltaheight = 1000
            """
            breakdown lines into string (w/o \n) calculate new coordinates
            """
            for element in layout:
                if isinstance(element, LTTextBoxHorizontal):
                    x0 = element.x0
                    y0 = element.y0
                    x1 = element.x1
                    y1 = element.y1
                    print(element.get_text())
                    lines = element.get_text().splitlines()
                    lenlines = len(lines)
                    j = 0
                    deltaheight = (y1-y0)/lenlines
                    if mindeltaheight > deltaheight:
                        mindeltaheight = deltaheight
                    for line in lines:
                        x0j = x0
                        y0j = y1 - (1+j)*deltaheight
                        x1j = x1
                        y1j = y1 - j*deltaheight
                        j += 1
                        elts.append({"x1":x1j,"y1":y1j,"x0":x0j,"y0":y0j,"txt":line})
                    if m < element.y1:
                        m = element.y1
            n = len(elts)
            """
            tune strings coordinate to get them aligned in the same "line" if not too far apart 
            (less than 1/2 the min line height of the page)
            """
            for i in range(1,n):
                for j in range(i+1,n):
                    if abs(elts[i-1]["y0"]-elts[j-1]["y0"])<(mindeltaheight/2):
                        elts[j-1]["y0"] = elts[i-1]["y0"]
                    if abs(elts[i-1]["y1"]-elts[j-1]["y1"])<(mindeltaheight/2):
                        elts[j-1]["y1"] = elts[i-1]["y1"]
                    
            selts = sorted(elts, key=lambda item: (round((2*m-item['y0']-item['y1'])/2,0),round(item['x0'],0)))   
            
            # for elt in selts:
            #    print(f"({p})({elt['x0']:0.0f},{elt['y0']:0.0f},{elt['x1']:0.0f},{elt['y1']:0.0f}){elt['txt']}")
            # if not callback(p,selts,context):
            #     return
               
            p +=1
            elt_len = len(selts)
            
            for x in range(elt_len):
                if selts[x]['txt'] == '联系人：':
                    result['联系人'] = selts[x+1]['txt']
                elif selts[x]['txt'] == '业务开通日期：':
                    result['开通日期'] = selts[x+1]['txt']
                else:
                    # ipAddress = getIp(selts[x]['txt'].replace(" ",""))
                    ipAddress = getIp(selts[x]['txt'])
                    if ipAddress:
                        EIPs.extend(ipAddress)
                    result['eip'] = EIPs
        
    fp.close
    os.chdir(base_path)
    with open(savefile,'a') as f:
        json.dump(result, f, ensure_ascii=False)


def parsedir(dir,outfile):
    for root,dirs,files in os.walk(dir):
        for filename in files:
            if filename.endswith('.pdf'):
                absname = os.path.join(root,filename)
                parse(absname,outfile)
                os.remove(absname)

if __name__ == '__main__':

    ##  Constants
    

    # ROOT_DIR = join(base_path,'mail') 
    text_path = r'义数云平台资源交付单-蔡春江20200728G1.pdf'
    #text_path = r'20义数云平台资源交付单--何旭1008_427309286238969.pdf'
    outfile = '2.json'

    parse(text_path,outfile)
    # for root,dirs,files in os.walk(ROOT_DIR):
    #     for filename in files:
    #         if filename.endswith('.pdf'):
    #             absname = os.path.join(root,filename)
    #             parse(absname,outfile)
    #             os.remove(absname)

