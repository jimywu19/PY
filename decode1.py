#coding = 'UTF-8'

import os 
from shutil import copy
from mailrec.file_decode import decodedir
import sys




def main():
    #sourcedir = 'd:\\Lenovo\\Desktop\\coded'
    sourcedir = input("请输入待解密文件夹路径：")
    sourcedir = '\\\\'.join(sourcedir.split('\\'))  # transform the windows path to linux path
    if not sourcedir:
        sourcedir = 'd:\Lenovo\Desktop\coded'

    # sourcedir = 'F:\\360极速浏览器下载\\k8s'
    destdir = 'd:\\Lenovo\\Desktop\\decoded'
    bakdir = 'd:\\Lenovo\\Desktop\\bak'

    # os.chdir(sourcedir)
    # filenames = os.listdir(sourcedir)
    # for filename in filenames:
    #     #copy(filename,bakdir)
    #     newname = add_suffix(filename,'.txt')
    #     copy(newname,destdir)
    #     os.remove(newname)

    # os.chdir(destdir)
    # des_filenames = os.listdir(destdir)
    # for des_filename in des_filenames:
    #     del_suffix(des_filename,'.txt')
    decodedir(sourcedir)

if __name__ == '__main__':
    main()