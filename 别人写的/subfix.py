#
#coding = "utf-8"

import os

 

class PreffixAndSuffix:

 

    def __init__(self):

        pass

 

    @staticmethod

    def add_preffix(file_path, preffix):  # 为file_path添加preffix前缀 并返回文件名绝对路径

        dir_name, filename, extension = PreffixAndSuffix.get_names(file_path)

 

        new_name = dir_name + preffix + filename + extension

        os.rename(file_path, new_name)

        return new_name

 

    @staticmethod

    def del_preffix(file_path, preffix):        # 为file_path删除preffix前缀 并返回文件名绝对路径

        dir_name, filename, extension = PreffixAndSuffix.get_names(file_path)

 

        if filename.startswith(preffix):            # 判断文件名是否以preffix开头

            filename = filename.partition(preffix)[2]  # ('', preffix, 去掉前缀文件名)[2]

            new_name = dir_name + filename + extension

            os.rename(file_path, new_name)

            return new_name

        else:

            return file_path

 

    @staticmethod

    def add_suffix(file_path, suffix):  # 为file_path添加preffix后缀 并返回文件名绝对路径

        dir_name, filename, extension = PreffixAndSuffix.get_names(file_path)

 

        new_name = dir_name + filename + suffix + extension

        os.rename(file_path, new_name)

        return new_name

 

 

    @staticmethod

    def del_suffix(file_path, suffix):  # 为file_path删除preffix后缀 并返回文件名绝对路径

        dir_name, filename, extension = PreffixAndSuffix.get_names(file_path)

 

        if filename.endswith(suffix):  # 判断文件名是否以preffix开头

            filename = filename.rpartition(suffix)[0]  # (文件名, suffix, 扩展名)[0]

 

            new_name = dir_name + filename + extension

            os.rename(file_path, new_name)

            return new_name

        else:

            return file_path

 

    @staticmethod

    def get_names(file_path):

        file_path = os.path.abspath(file_path)  # 获取这个文件/文件夹的绝对路径

        dir_name = os.path.dirname(file_path)  # 获取所在目录

        dir_name = dir_name + os.sep  # 为拼接做准备

        filename, extension = os.path.splitext(file_path)  #: 分离文件名与扩展名结果为（filename，扩展名） 如果参数为一个路径则返回（路径，''）

        name = filename.rpartition(os.sep)[2]  # (文件目录名 ,目录分隔符, 文件名/目录名)

        names = (dir_name, name, extension)    #(文件所在目录名, 文件名, 文件扩展名)

        # print(names)

        return names
 

 

def change_name(file_path):

    pass

 

 

 

 

def main():

 

    y_or_n = {'Y': True, 'y': True, 'N': False, 'n': False, '': False}

    method = {'0': PreffixAndSuffix.add_preffix, '1': PreffixAndSuffix.add_suffix, '2': PreffixAndSuffix.del_preffix, '3': PreffixAndSuffix.del_suffix}

 

    #file_path = str(input('请输入要求改的文件路径：'))
    file_path = 'd:\Lenovo\Desktop\解密\subfix.py'
	

    #designated_suffix_or_preffix = str(input('请输入指定的文件名前缀或后缀：'))
    designated_suffix_or_preffix = '.txt'
	

 

    while True:

        #ecursive_modify = str(input('是否递归修改？((Y/N)默认为N)'))
        ecursive_modify = 'N'

        if ecursive_modify in y_or_n:

            isecursive_modify = y_or_n[ecursive_modify]

            break

 

    while True:

        #designated_suffix_modify = str(input('是否只修改特定后缀文件？((Y/N)默认为N)'))
        designated_suffix_modify = 'N'

        if designated_suffix_modify in y_or_n:

            isdesignated_suffix_modify = y_or_n[designated_suffix_modify]

            if isdesignated_suffix_modify:  # 只修改指定后缀的文件

                designated_suffix =  str(input('请输入指定的后缀(如：.txt、.jpg)'))

                break

            else:

                designated_suffix = ''

                break

 

    while True:

        tip = '''

        0：添加指定前缀

        1：添加指定后缀

        2：删除指定前缀

        3：删除指定后缀

        请输入： '''

        #change_method_num = input(tip)
        change_method_num = '1'

        if change_method_num in method:     # 判断是否在方法字典中

            change_method = method[change_method_num]   # 获取选择的方法入口地址。

            break

 

    print('文件名：', file_path)

    print('指定的前缀或后缀：', designated_suffix_or_preffix)

    print('是否递归修改：', isecursive_modify)

    print('是否只修改特定后缀文件：', isdesignated_suffix_modify)

    print('指定修改的后缀：', designated_suffix)

    print('选择方法：',method[change_method_num])

 

 

    if not isecursive_modify:   # 如果不递归修改

        print('当前执行目录：', file_path)

        os.chdir(file_path)

        for file in os.listdir(file_path):  # 遍历当前目录下所有文件

            abs_path = file_path + os.sep + file    # 拼接文件的绝对路径

            if os.path.isfile(abs_path):    # 如果是文件

                if abs_path.endswith(designated_suffix):    # 判断是否为指定后缀。

                    new_name = change_method(abs_path, designated_suffix_or_preffix) # 调用方法字典中的选择的方法

                    print('已成功改名：', new_name)

        print('-' * 80)

 

    else:

        for root, dirs, files in os.walk(file_path):    # 递归遍历 file_path

            print('当前执行目录：', root)

            os.chdir(root)

            print(files)    # 当前目录下所有文件

 

            for file in files:  # 遍历所有文件

                abs_path = root + os.sep + file  # 拼接绝对地址

                if abs_path.endswith(designated_suffix): # 判断是否为指定后缀

                    new_name = change_method(abs_path, designated_suffix_or_preffix)    # 调用方法字典中的选择的方法

                    print('已成功改名：', new_name)

            print('-' * 80)

 

 

 

if __name__ == '__main__':

    main()