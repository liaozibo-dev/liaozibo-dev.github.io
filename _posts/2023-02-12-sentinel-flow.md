---
layout: post
title:  "Sentinel 流量整形"
date:   2023-02-12 01:00:00 +0000
categories: microservice
---

# Sentinel 流量整形

[TOC]

## 服务容错

高可用手段：
* 集群：避免单点故障
* 服务容错：避免服务雪崩

服务容错手段：
* 降级熔断：降级（异常或超时时走降级逻辑），熔断（异常或超时次数超过阈值时直接走降级逻辑，不再发起远程调用）
* 流量整形

## 流量整形（流控）

Sentinel 流控模式：
* 直接模式
* 关联模式
* 链路模式

Sentinel 流控效果：
* 快速失败
* 预热模式
* 排队等待

## Sentinel 控制台

https://sentinelguard.io/

启动 Sentinel 控制台：`sentinel-start.cmd`
```
start java -jar -Dcsp.sentinel.dashboard.server=127.0.0.1:8090 -Dserver.port=8090 sentinel-dashboard-1.8.6.jar
```

* Sentinel 控制台地址：http://127.0.0.1:8090
* Sentinel API 地址：http://127.0.0.1:8719
* Sentinel 用户名密码：sentinel/sentinel

## 依赖

```xml
<dependency>
    <groupId>com.alibaba.cloud</groupId>
    <artifactId>spring-cloud-starter-alibaba-sentinel</artifactId>
</dependency>
```

## 配置

```yaml
spring:
  cloud:
    sentinel:
      transport:
        port: 8719
        dashboard: 127.0.0.1:8090
```

## 标记资源

```java
@RestController
@RequestMapping("/hello")
public class HelloController {
    @GetMapping
    @SentinelResource("hello")
    public String hello() {
        return "Hello World";
    }

    @GetMapping("/{name}")
    @SentinelResource(value = "hello-somebody", blockHandler = "helloBlocker")
    public String hello(@PathVariable String name) {
        return "Hello " + name;
    }

    /**
     * 降级逻辑
     * */
    public String helloBlocker(String name, BlockException e) {
        return "Hello " + e.getMessage();
    }
}
```

调用接口，触发信息上报

## 流控模式

流控模式：
* 直接流控：当前资源请求量大于阈值，对当前资源进行限流
* 关联流控：关联资源请求量大于阈值，对当前资源进行限流
* 链路流控：链路上某 API 请求量大于阈值，对当前资源进行限流

### 直接流控

![img.png](/static/imgs/sentinel-flow/sentinel-direct.png)

### 关联流控

对优先级低的资源进行限流

![img_1.png](/static/imgs/sentinel-flow/sentinel-relation.png)

### 链路流控

当 `/api/edit -> hello` 这条链路的请求量大于阈值时，对该链路进行限流

![img_2.png](/static/imgs/sentinel-flow/sentinel-link.png)

### 针对调用源进行限流

使用 OpenFeign 拦截器，添加特殊的请求头标识

```java
@Configuration
public class SentinelInterceptor implements RequestInterceptor {
    @Override
    public void apply(RequestTemplate request) {
        request.header("SentinelSource", "coupon-customer-serv");
    }
}
```

使用 Sentinel 解析器解析请求头：
```java
@Component
public class SentinelOrignParser implements RequestOriginParser {
    @Override
    public String parseOrigin(HttpServletRequest request) {
        return request.getHeader("SentinelSource");
    }
}
```

配置流控规则

![img_3.png](/static/imgs/sentinel-flow/sentinel-rule.png)


## 流控效果

Sentinel 流控效果：
* 快速失败
* 预热模式：适合缓存预热场景 `起始阈值 = 单机阈值 / 冷加载因子` （冷加载因子默认是 3） 
* 排队等待：将超过阈值的请求放到队列，并设置排队超时时间

预热模式：
* 单机阈值：10
* 预热时间：5
* 起始阈值：3 `10 / 3 = 3`
![img_4.png](/static/imgs/sentinel-flow/sentinel-hot.png)

排队等待：
* 排队超时：500ms

![img_5.png](/static/imgs/sentinel-flow/sentinel-queue.png)