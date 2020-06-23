# -*- coding: utf-8 -*-

# Define here the models for your scraped items
#
# See documentation in:
# https://docs.scrapy.org/en/latest/topics/items.html

import scrapy


class MaoyanreyingItem(scrapy.Item):
    # define the fields for your item here like:
    # name = scrapy.Field()
    # pass
    index = scrapy.Field()
    title = scrapy.Field()
    star = scrapy.Field()
    releasetime = scrapy.Field()
    score = scrapy.Field()
