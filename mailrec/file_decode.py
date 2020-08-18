#coding = 'UTF-8'

import os
from os.path import join,dirname,basename,abspath,splitext,expandvars
from shutil import move

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

def decodefile(full_path_filename):

    des_path = expandvars("%TMP%")
    a_path = dirname(full_path_filename)

    os.chdir(a_path)
    tmp_fullpath_file = add_suffix(full_path_filename,".txt") #加后缀
    tmp_file = basename(tmp_fullpath_file)

    move(tmp_fullpath_file,des_path)                        #拷出
    
    des_tmp_fullpath_file = join(des_path,tmp_file)
    move(des_tmp_fullpath_file,a_path)                #拷回

    de_file = del_suffix(tmp_fullpath_file,".txt")  #删后缀
    return de_file

def decodedir(dir):

    de_files = []
    for file in os.listdir(dir):
        fullpathfile = os.path.join(dir,file)
        de_file = decodefile(fullpathfile)
        de_files.append(de_file)
    return de_files