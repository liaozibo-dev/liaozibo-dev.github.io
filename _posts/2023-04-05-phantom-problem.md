---
layout: post
title:  "幻读与间隙锁"
date:   2023-04-05 00:00:00 +0000
categories: mysql
---

[TOC]

## 幻读

### 幻读定义

幻读指的是一个事务在前后两次查询同一范围的时候（执行同一条语句），后一次查询看到了前一次查询没有看到的（新插入的）行。
* 在可重复度隔离级别下，幻读在 “当前读” 下才会出现 `lock in share mode`, `for update`（普通的查询是快照读，是不会看到别的事务插入的数据的。）
* 幻读仅专指 “新插入的行”

### 解决幻读问题

如何解决幻读问题：
* 执行查询时，将扫描到的行都加上行锁（对于没有索引的查询，会进行全表扫描，需要将表中的所有行都加锁行锁）
* 执行查询时，将扫描到的行之间的间隙加锁上间隙锁

### 幻读导致的问题

如果不进行上面的两个操作，会出现问题：（由下面案例证明）
* 加锁语义被破坏
* 导致数据和日志在逻辑上不一致（binlog 是在事务提交时写入的）

```sql
DROP DATABASE IF EXISTS mysql45_20;
CREATE DATABASE mysql45_20;
USE mysql45_20;

CREATE TABLE `t` (
  `id` int(11) NOT NULL,
  `c` int(11) DEFAULT NULL,
  `d` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `c` (`c`)
) ENGINE=InnoDB;

INSERT INTO t VALUES
(0,0,0),(5,5,5),(10,10,10),
(15,15,15),(20,20,20),(25,25,25);
```

会话1：
```sql
-- T1 时刻
BEGIN;
SELECT * FROM t WHERE d = 5 FOR UPDATE; -- 假设不进行上面两个加锁操作，仅仅对 id = 5 加行锁
UPDATE t SET d = 100 WHERE d = 5; -- (5, 5, 100)

-- T3 时刻
COMMIT;
```

会话2：
```sql
-- T2 时刻
-- 如果 会话1 没有对扫描的行加行锁，则 会话2 可以更新成功，导致 会话1 再次查询时，会查出两条 d = 5 的记录，虽然由更新操作导致新查出的记录不属于幻读
UPDATE t SET d = 5 WHERE id = 0; -- (0, 0, 5)
UPDATE t SET c = 5 WHERE id = 0; -- (0, 5, 5)
```

会话3：
```sql
-- T2 时刻
-- 如果 会话1 对扫描到的行之间的间隙加间隙锁，则 会话3 可以插入成功，导致 会话1 再次执行查询时会出现幻读
INSERT INTO t VALUES (1, 1, 5); -- (1, 1, 5)
UPDATE t SET c = 5 WHERE id = 1; -- (1, 5, 5)
```

总结：
* 加锁语义被破坏：会话1 的 `SELECT FOR UPDATE` 表示对 d = 5 的行加锁，但最终 会话2 和 会话3 都能对 d = 5 的行执行更新操作
* 数据和日志在逻辑上不一致：由于 binlog 是在事务提交时才写入的，所以在使用 binlog 进行备份恢复或复制同步时，会导致 会话1 的 update 语句在最后执行，将 会话2 和 会话3 的数据都影响到，导致和主库数据不一致 

## 间隙锁

### 间隙锁冲突关系

间隙锁的冲突关系：
* 间隙锁与间隙锁之间不存在冲突关系
* 与间隙锁存在冲突关系的，是 “往这个间隙中插入一个记录” 这个操作

下面这两个会话不会冲突，都能加上间隙锁 `(5, 10)`

```sql
BEGIN;
SELECT * FROM t WHERE c = 7 LOCK IN SHARE MODE;
```

```sql
BEGIN;
SELECT * FROM t WHERE c = 7 FOR UPDATE;
```

### 间隙锁导致的死锁

间隙锁解决了幻读问题，但会导致语句锁住更大的范围，影响并发度。（下面两个会话会产生死锁）

会话1：
```sql
-- T1 时刻
BEGIN;
SELECT * FROM t WHERE id = 9 FOR UPDATE; -- 加上间隙锁 (5, 10)

-- T2 时刻
INSERT INTO t VALUES (9, 9, 9); -- 等待 会话2 释放间隙锁
```

会话2：
```sql
-- T1 时刻
BEGIN;
SELECT * FROM t WHERE id = 9 FOR UPDATE; -- 加上间隙锁 (5, 10)

-- T2 时刻
INSERT INTO t VALUES (9, 9, 9); -- 等待 会话1 释放间隙锁
-- 发现死锁：[40001][1213] Deadlock found when trying to get lock; try restarting transaction
```

死锁产生的原因分析：
* T1 时刻，因为间隙锁间不会产生冲突，所以两个会话都能加间隙锁成功
* T2 时间，会话1 插入时需要等待 会话2 释放间隙锁，会话2 插入时需要等待 会话1 插入间隙锁，两个会话都因互相等待对方持有锁而被阻塞，因此尝试死锁。

解决间隙锁导致加锁范围过大问题：如果业务不需要可重复度保证，可以将隔离级别设置为读已提交并将 binlog 格式设置为 raw
* 在读已提交隔离级别下，没有间隙锁
* 将 binlog 格式设置为 raw，解决数据和日志不一致问题


### 间隙锁导致加锁范围过大

另一个间隙锁导致加锁范围过大问题

会话1：
```sql
-- MySQL 加锁的基本单位是临键锁（Next-Key Lock），即由行锁和间隙锁组成的一个左开右闭区间 (N, M]
-- 由于是倒序查询，所以 MySQL 会从右往左进行扫描
-- 加锁范围：对 索引c 从右往左进行扫描，加锁范围是 (15, 20], (10, 15], 由于 索引c 不是唯一索引，所以扫描到行 id = 15 后，还有继续往左扫描，对 (5, 10] 加锁
-- 最终加锁范围：临键锁 (5, 10], (10, 15], (15, 20], 
BEGIN;
SELECT * FROM t WHERE c >= 15 AND c <= 20 ORDER BY c DESC FOR UPDATE;
```

会话2：
```sql
-- 被临键锁 (10, 15] 阻塞
INSERT INTO t VALUES (11, 11, 11);
```

会话3:
```sql
-- 被临键锁 (5, 10] 阻塞
INSERT INTO t VALUES (6, 6, 6);
```

## 参考

* 《MySQL 实战45讲》 20.幻读是什么，幻读有什么问题