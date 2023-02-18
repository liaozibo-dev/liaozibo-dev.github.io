---
layout: post
title:  "Spring Cloud Gateway 微服务网关"
date:   2023-02-18 00:00:00 +0000
categories: microservice
---

## 知识点

Spring Cloud Gateway:
* 路由
* 谓词
* 过滤器
* 目标地址

路由：
* 静态路由配置
    * Java 代码
    * YAML 文件
* 动态路由配置
    * 使用 Spring Boot Actuator 临时修改路由
    * 使用 Nacos Config 实现动态路由持久化

谓词：
* 寻址谓词：
    * `path`
    * `method`
* 请求参数谓词：
    * `query`
    * `header`
    * `cookie`
* 时间谓词：
    * `before`
    * `after`
    * `between`
* 逻辑谓词：
    * `and`
    * `or`
    * `negate`

谓词工厂

过滤器：
* 全局过滤器
* 局部过滤器

## 微服务网关搭建

依赖：
```yaml
<!-- 微服务网关 -->
<dependency>
    <groupId>org.springframework.cloud</groupId>
    <artifactId>spring-cloud-starter-gateway</artifactId>
</dependency>
<!-- 服务发现 -->
<dependency>
    <groupId>org.springframework.cloud</groupId>
    <artifactId>spring-cloud-starter-openfeign</artifactId>
</dependency>
<dependency>
    <groupId>org.springframework.cloud</groupId>
    <artifactId>spring-cloud-starter-loadbalancer</artifactId>
</dependency>
<!-- Redis + Lua 网关层限流 -->
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-data-redis</artifactId>
</dependency>
```

`bootstrap.yml` 配置：
```yaml
spring:
  application:
    name: coupon-gateway
```

`application.yml` 配置：
```yaml
server:
  port: 8000
spring:
  redis:
    host: localhost
    port: 6379
  cloud:
    nacos:
      discovery:
        server-addr: localhost:8848
        heart-beat-interval: 5000
        heart-beat-timeout: 15000
        cluster-name: Cluster-A
        namespace: dev
        group: devGroup
        register-enable: true
    gateway:
      discovery:
        locator:
          enabled: true
          lower-case-service-id: true
      globalcors:
        cors-configurations:
          # 为所有请求路径设置的跨域访问
          '[/**]':
              allowed-origins: # 被信任的来源地址（与请求头 Origin 值比较）
                - "http:/localhost:10000"
              expose-headers: "*" # 允许暴露的 Response Headers
              allowed-methods: "*" # 允许的 Http Methods
              allow-credentials: true # 是否允许 cookies，默认 false
              allowed-headers: "*" # 允许的 Request Headers
              max-age: 1000 # 浏览器缓存时间
```

## 路由

路由配置：
```java
@Configuration
public class RouterConfig {
    @Bean
    public RouteLocator routers(RouteLocatorBuilder builder) {
        return builder.routes()
                .route(route -> route
                        .path("/gateway/coupon-customer/**")
                        .filters(f -> f.stripPrefix(1))
                        .uri("lb://coupon-customer-serv"))
                .route(route -> route
                        .order(1) // 数值越小，优先级越高
                        .path("/gateway/coupon-template/**")
                        .filters(f -> f.stripPrefix(1))
                        .uri("lb://coupon-template-serv"))
                .route(route -> route
                        .path("/gateway/coupon-calculator/**")
                        .filters(f -> f.stripPrefix(1))
                        .uri("lb://coupon-calculator-serv")
                )
                .build();
    }
}
```

## 谓词


## 过滤器

使用过滤器对请求和响应进行修改：
```java
route
    .path("/gateway/coupon-template/**")
    .filters(f -> f.stripPrefix(1)
        .removeRequestHeader("header")
        .addRequestHeader("header", "value")
        .removeRequestParameter("param")
        .addRequestParameter("param", "value")
        .removeResponseHeader("header")
    )
    .uri("lb://coupon-template-serv")
```

限流规则：
```java
/**
 * Redis + Lua 网关层限流规则
 * Lua 脚本：request_rate_limiter.lua (由 Spring Cloud Gateway 依赖提供)
 */
public class RedisRateLimiterConfig {
    private static final int DEFAULT_RATE = 10;
    private static final int DEFAULT_CAPACITY = 20;

    // 限流维度
    @Bean
    public KeyResolver remoteHostLimitKey() {
        return exchange -> Mono.just(
                exchange.getRequest()
                        .getRemoteAddress()
                        .getAddress()
                        .getHostAddress()
        );
    }

    // 限流规则
    @Bean("templateRateLimiter")
    public RedisRateLimiter templateRateLimiter() {
        // 令牌桶限流算法
        // rate, capacity
        return new RedisRateLimiter(DEFAULT_RATE, DEFAULT_CAPACITY);
    }

    @Bean("defaultRateLimiter")
    @Primary
    public RedisRateLimiter defaultRateLimiter() {
        return new RedisRateLimiter(DEFAULT_RATE, DEFAULT_CAPACITY);
    }
}
```

在过滤器中配置限流规则：
```java
@Autowired
private KeyResolver hostAddrKeyResolver;

@Autowired
private RedisRateLimiter defaultRateLimiter;

@Autowired
@Qualifier("templateRateLimiter")
private RedisRateLimiter templateRateLimiter;


route
    .path("/gateway/coupon-customer/**")
    .filters(f -> f.stripPrefix(1)
    .requestRateLimiter(limiter -> {
        limiter.setKeyResolver(hostAddrKeyResolver)
                .setRateLimiter(defaultRateLimiter)
                .setStatusCode(HttpStatus.BANDWIDTH_LIMIT_EXCEEDED); // 限流后返回的状态码
    }))
    .uri("lb://coupon-customer-serv")
```

## 参考

* https://spring.io/blog/2021/04/05/api-rate-limiting-with-spring-cloud-gateway
* Spring Cloud 微服务项目实战 - 极客时间