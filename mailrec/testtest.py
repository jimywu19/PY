list = [1,2,3,4,5]
lt = iter(list)

while True:
    if next(lt) == '2':
        n = next(lt)
        print(n)
    if not n:
        break

