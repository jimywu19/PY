#coding = 'UTF-8'

import os 
from shutil import copy

def get_names(file_path):

    file_path = os.path.abspath(file_path)  # 获取这个文件/文件夹的绝对路径

    dir_name = os.path.dirname(file_path)  # 获取所在目录

    dir_name = dir_name + os.sep  # 为拼接做准备

    filename = os.path.basename(file_path)

    name, extension = os.path.splitext(filename)  #: 分离文件名与扩展名结果为（filename，扩展名） 如果参数为一个路径则返回（路径，''）

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


def main():
    sourcedir = 'd:\\Lenovo\\Desktop\\coded'
    destdir = 'd:\\Lenovo\\Desktop\\decoded'
    #destdir = 'E:\\Program Files\\PremiumSoft\\Navicat Premium 12'
    bakdir = 'd:\\Lenovo\\Desktop\\bak'

    os.chdir(sourcedir)
    filenames = os.listdir(sourcedir)
    for filename in filenames:
        copy(filename,bakdir)
        newname = add_suffix(filename,'.txt')
        copy(newname,destdir)
        os.remove(newname)

    os.chdir(destdir)
    des_filenames = os.listdir(destdir)
    for des_filename in des_filenames:
        del_suffix(des_filename,'.txt')

if __name__ == '__main__':
    main()