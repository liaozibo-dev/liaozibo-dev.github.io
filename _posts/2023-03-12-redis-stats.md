---
layout: post
title:  "Redis 集合统计"
date:   2023-03-12 00:00:00 +0000
categories: redis
---

[TOC]

## 基础知识

Redis 五种基础数据类型：
* String
* List
* Set
* Sorted Set
* Hash

常用高级数据类型：
* Bitmap
* HyperLogLog

Set 操作：
* 并集
* 交集
* 差集

![图片来源：https://livebook.manning.com/book/get-programming-with-scala/chapter-35/v-7/11](/static/imgs/redis-stats/set.png)

对集合进行统计的场景：
* 统计每日新增用户数和留存用户数 -> Set
* 统计评论列表最新评论 -> Sorted Set
* 统计一个月内连续签到的用户/用户数 -> Bitmap
* 统计页面独立访客（Unique Visitor, UV） -> Set（精确）/ HyperLogLog（不精确）

集合类型常见的四种统计模式：
* 聚合统计：对多个集合进行聚合统计（比如，对 Set 进行并集、交集、差集计算）
* 排序统计：对集合进行排序（Sorted Set）
* 二值状态统计：取值只有 0 和 1 两种状态（Bitmap）
* 基数统计：统计不重复的元素个数（Set、HyperLogLog）

> todo: Redis 大 Key 问题

## 聚合统计

场景：统计每日新增用户数和留存用户数据

用 Set 记录登录过的用户id：
```
user:id [uid...]
```

用另一个 Set 记录每日登录用户id：
```
user:id:20230312 [uid...]
```

计算每日新增用户（差集）：
```
SDIFFSTORE user:new user:id user:id:20230312
```

计算每日留存用户（交集）：
```
SINTERSTORE user:rem user:id:20230311 user:id:20230312
```

更新登录过的用户id（并集）：
```
SUNIONSTORE user:id user:id user:id:20230312
```

Tips：
* 可以将每日统计数据落库持久化，而 Redis 只用来做集合统计运算
* 在数据量比较大的情况下，可以在从库或客户端进行集合运算，避免阻塞主库
* 对集合设置过期时间，过期自动删除

## 排序统计

场景：商品的最新评论列表

使用 Sorted Set，用一个递增的数值作为排序的权重，则获取最新评论的命令为：
```
ZRANGEBYSCORE comments N-9 N
```

为什么不用 List 类型：
```
在获取第二页数据时，如果此时有新的评论插到列表头部，就会导致所有数据都向后偏移，导致分页错误
```

## 二值状态统计

场景：统计用户每月签到情况

记录用户（3000） 3 月 12 日签到：
```bash
# 将第 12 位设置成 1
SETBIT uid:sign:3000:202303 12 1
```

检查用户（3000） 3 月 12 日是否签到：
```
# 获取第 12 位的值
GETBIT uid:sign:3000:202303 12
```

统计用户 3 月签到次数：
```
BITCOUNT uid:sign:3000:202303
```

场景：统计 1 亿用户 10 天连续签到的用户总数

记录每天用户签到情况：
```bash
# 第一天签到情况，offset 表示用户id
SETBIT uid:sign:202303 3000 1
```

计算连续 10 天签到的用户总数：
```bash
# 与运算 OP: operation
BITOP AND uid:sign uid:sign:202303 uid:sign:202304 ...

BITCOUNT uid:sign
```

Tips：
* 使用过期时间或者主动删除计算数据，以节省内存开销

## 基数统计

场景：网页 UV

使用 Set 进行精确统计（但对于大量数据来说太耗内存）：
```bash
SADD uv:page1 <uid>

# 获取总数
SCARD uv:page1
```

使用 HyperLogLog 进行不精确统计（标准误算率：0.81%）：
```bash
PFADD uv:page1 <uid...>

# 获取统计结果
PFCOUNT uv:page1
```

## 参考

* 《Redis 核心技术与实战》