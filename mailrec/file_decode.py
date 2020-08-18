#coding = 'UTF-8'
# from configfile.py import *


import os
from os.path import join,dirname,basename,abspath,splitext,isdir,isfile
from shutil import copy

def get_names(file_path):
    file_path = abspath(file_path)  # 获取这个文件/文件夹的绝对路径
    dir_name = dirname(file_path)  # 获取所在目录
    dir_name = dir_name + os.sep  # 为拼接做准备
    filename = basename(file_path)
    name, extension = splitext(filename)  #: 分离文件名与扩展名结果为（filename，扩展名） 如果参数为一个路径则返回（路径，''）
    #name = filename.rpartition(os.sep)[2]  # (文件目录名 ,目录分隔符, 文件名/目录名)
    names = (dir_name, name, extension)    #(文件所在目录名, 文件名, 文件扩展名)
    # print(names)
    return names

def add_suffix(file_path, suffix):  # 为file_path添加preffix后缀 并返回文件名绝对路径
    dir_name, filename, extension = get_names(file_path)
    if extension != suffix:
        new_name = dir_name + filename + extension + suffix
        os.rename(file_path, new_name)
        return new_name
    else:
        return file_path

def del_suffix(file_path, suffix):  # 为file_path删除preffix后缀 并返回文件名绝对路径
    dir_name, filename, extension = get_names(file_path)
    if extension == suffix:  # 判断文件名是否以suffix结尾                
        new_name = dir_name + filename
        os.rename(file_path, new_name)
        return new_name
    else:
        return file_path

def decodefile(file,de_dir):

    if not isdir(de_dir):
        os.mkdir(de_dir)
    mydirname = dirname(file)
    os.chdir(mydirname)
    newname = add_suffix(file,".txt")
    copy(newname,de_dir)
    base_newname = basename(newname)
    os.remove(newname)

    os.chdir(de_dir)
    de_newname = join(de_dir,base_newname)
    de_file = del_suffix(de_newname,".txt")
    return de_file

def decodedir(dir,de_dir):

    de_files = []
    for file in os.listdir(dir):
        fullpathfile = os.path.join(dir,file)
        de_file = decodefile(fullpathfile,de_dir)
        de_files.append(de_file)
    return de_files





