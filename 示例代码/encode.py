

x=input("Please input words:")

def encodes(s):
    return ' '.join([''.join(reversed(bin(ord(c)).replace('0b', '0'))) for c in s])

def decode(s):
 return ''.join([chr(i) for i in [int(b, 2) for b in s.split(' ')]])

n = encodes(x)
m = decode(encodes(x))

