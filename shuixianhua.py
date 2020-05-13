

for i in range(100,1000):
    low=i%10
    mid=i//10%10
    hig=i//100
    x=low**3+mid**3+hig**3

    if x==i:
        print (i)

