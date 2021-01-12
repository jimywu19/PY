class student():
    def __init__(self, name1, age1):
        self.name = name1
        self.age = age1

    def study(self, course_name):
        print('%s正在学习%s.' % (self.name, course_name))

    def watch_movie(self):
        if self.age < 18:
            print('%s只能看《熊出没》.' % self.name)
        else:
            print('%s正在看岛国爱情大电影.' % self.name)

stu1 = student("小明","23")
stu1.study("math")

            