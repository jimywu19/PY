#coding : 'UTF-8'

import os
import json

filedir = "d:\\Lenovo\\Desktop\\api"
categories = 'flavors'

os.chdir(filedir)
for sourcefile in os.listdir(filedir):
    sourcefilename, ext = os.path.splitext(sourcefile)
    desfile = sourcefilename + '-convert' + ext
    with open(sourcefile, 'rt') as f1:
        arr = json.load(f1)
        with open(desfile, 'wt') as f2: 
            for c in arr[categories]:
                f2.write(str(c['id']) + '\t' + str(c['vcpus']) + '\t' + str(c['ram']/1024) + '\t' + str(c['name'])+ '\n')
                