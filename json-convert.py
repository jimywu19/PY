import json
import os
import sys

filedir = "C:/Users/jimywu/Desktop/apis"
source_file = 'ecs'
des_file = source_file + '-convert'
cate = 'apis'

os.path.
os.chdir(filedir)

with open(source_file, 'rt') as f1:
    arr = json.load(f1)
    with open(des_file,'wt') as f2:
        for c in arr[cate]:
            f2.write(c['serviceName'] + '   ')
            f2.write(c['method'] + '   ')
            f2.write(c['sourceUri'] + '\n')

sys.stdin
            
