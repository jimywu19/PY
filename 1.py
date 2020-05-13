import os

#root = '%s%s%s' % ('..', os.path.sep, 'food')
dir = 'c:/users/jimywu/documents/project/food'
for  file_list in os.walk(dir):
    for name in file_list[2]:
        print('File: ' + name)
