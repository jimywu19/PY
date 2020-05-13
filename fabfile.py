import fabric


'''
hosts = []
for i in range(2,16):
    host = "192.168.75." + str(i)
    hosts.append(host)
'''

def getcpu(c):
    ''' 取cpu核数'''
    result = c.run("grep -i processor /proc/cpuinfo |wc -l")
    return result.stdout.strip()
def getmem(c):
    ''' 取内存大小'''
    mem_result = c.run("free -h|grep -i mem|awk '{print $2}'")
    return mem_result.stdout.strip()
def getdisk(c):
    '''取第二磁盘vdb大小'''
    disk_result = c.run("fdisk -l|grep -w vdb|awk '{print $3}'")
    return disk_result.stdout.strip()



def myconnect():
    hosts = ['192.168.75.2', '192.168.75.3', '192.168.75.4', '192.168.75.5', '192.168.75.6', '192.168.75.7', '192.168.75.8', '192.168.75.9', '192.168.75.10', '192.168.75.11', '192.168.75.12', '192.168.75.13', '192.168.75.14', '192.168.75.15']
    #hosts = ['192.168.75.2']
    for host in hosts:
        conn = fabric.Connection(host,user='root',connect_kwargs={"password":"admin@123"})
        print("{}:  cpu {}核  mem {}  disk {}G".format(host,getcpu(conn),getmem(conn),getdisk(conn)))


if __name__ == '__main__':
    myconnect()