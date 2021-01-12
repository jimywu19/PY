# import os,re


# x_path = r'F:\360极速浏览器下载'

# name = []
# with open('name.txt','wt') as f:
#     for root,dirs,files in os.walk(x_path):
#         for file in files:        
#             fname, extension = os.path.splitext(file)          
#             re.split(r'-',fname)
#             f.write(fname[l.start():l.end()])
#             f.write('\n')        
        
# f.close

import xlsxwriter

workbook = xlsxwriter.Workbook('demo.xlsx')
# workbook = xlsxwriter.workbook('demo.xlsx')
worksheet = workbook.add_worksheet()
worksheet.set_column('A:A',20)
bold = workbook.add_format({'bold':True})
worksheet.write('A1','Hello')
worksheet.write('A2','Word',bold)
workbook.close()



