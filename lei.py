class student():
    def __init__ = name(self, name, age):
        self.name = name
        self.age = age

    def study(self, course_name):
        print('%S正在学习%S.' % (self.name, course_name))

    def watch_movie(self):
        if self.age < 18:
            print('%s只能看《熊出没》.' % self.name)
        else:
            print('%s正在看岛国爱情大电影.' % self.name)
            