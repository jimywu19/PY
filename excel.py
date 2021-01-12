
# 对excel处理的两个python模块:

# pandas 相当于 python 中 excel：它使用表（也就是 dataframe)

# numpy 支持大量的维度数组与矩阵运算,此外也针对数组运算提供大量的数学函数库

import numpy as np
import pandas as pd

dir="d:\Lenovo\Desktop\decoded"
df = pd.DataFrame(pd.read_excel("d:\\Lenovo\\Desktop\\decoded\\20200803120000051.xlsx"))

print(df.head())