# from PIL import Image, ImageDraw
# import imageio
# WIDTH, R = 126, 10
# frames = []
# for velocity in range(15):
#     y = sum(range(velocity+1))
#     frame = Image.new('L', (WIDTH, WIDTH))
#     draw  = ImageDraw.Draw(frame)
#     draw.ellipse((WIDTH/2-R, y, WIDTH/2+R, y+R*2), fill='white')
#     frames.append(frame)
# frames += reversed(frames[1:-1])
# imageio.mimsave('test.gif', frames, duration=0.03)


sourcedir = input("请输入待解密文件夹路径：")
if not sourcedir:
    sourcedir = 'd:\\Lenovo\\Desktop\\coded'
print(sourcedir)
sourcedir = '\\\\'.join(sourcedir.split('\\'))   
print(sourcedir)
 # transform the windows path to linux path