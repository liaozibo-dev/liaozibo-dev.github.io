---
layout: post
title:  "Spring Cache Redis 源码分析"
date:   2023-04-06 00:00:00 +0000
categories: spring
---

![spring-cache-redis.png](/static/imgs/spring-cache-redis/spring-cache-redis.png)

## 缓存 AOP 配置

AOP 配置：`org.springframework.cache.annotation.ProxyCachingConfiguration`
```java
@Configuration(proxyBeanMethods = false)
@Role(BeanDefinition.ROLE_INFRASTRUCTURE)
public class ProxyCachingConfiguration extends AbstractCachingConfiguration {

	@Bean(name = CacheManagementConfigUtils.CACHE_ADVISOR_BEAN_NAME)
	@Role(BeanDefinition.ROLE_INFRASTRUCTURE)
	public BeanFactoryCacheOperationSourceAdvisor cacheAdvisor(CacheOperationSource cacheOperationSource, CacheInterceptor cacheInterceptor) {
		BeanFactoryCacheOperationSourceAdvisor advisor = new BeanFactoryCacheOperationSourceAdvisor(); // 其中定义了切点
		advisor.setCacheOperationSource(cacheOperationSource); // 保存缓存注解实例的对象
		advisor.setAdvice(cacheInterceptor); // 缓存拦截器
		return advisor;
	}

	@Bean
	@Role(BeanDefinition.ROLE_INFRASTRUCTURE)
	public CacheOperationSource cacheOperationSource() {
		return new AnnotationCacheOperationSource(); // 保存缓存注解实例的对象
	}

	@Bean
	@Role(BeanDefinition.ROLE_INFRASTRUCTURE)
	public CacheInterceptor cacheInterceptor(CacheOperationSource cacheOperationSource) {
		CacheInterceptor interceptor = new CacheInterceptor(); // 缓存拦截器
		interceptor.configure(this.errorHandler, this.keyGenerator, this.cacheResolver, this.cacheManager);
		interceptor.setCacheOperationSource(cacheOperationSource);
		return interceptor;
	}

}
```

缓存拦截器：对使用缓存注解的方法进行拦截，并织入缓存功能
`org.springframework.cache.interceptor.CacheInterceptor`
```java
public class CacheInterceptor extends CacheAspectSupport implements MethodInterceptor, Serializable {

	@Override
	public Object invoke(final MethodInvocation invocation) throws Throwable {
        CacheOperationInvoker aopAllianceInvoker = () -> {return invocation.proceed();};
		Method method = invocation.getMethod();
		Object target = invocation.getThis();
        return execute(aopAllianceInvoker, target, method, invocation.getArguments()); // 调用父类 CacheAspectSupport 的方法
	}

}
```

缓存切面辅助类：定义缓存切面逻辑
`org.springframework.cache.interceptor.CacheAspectSupport`
```java
public abstract class CacheAspectSupport extends AbstractCacheInvoker
		implements BeanFactoryAware, InitializingBean, SmartInitializingSingleton {
    protected Object execute(CacheOperationInvoker invoker, Object target, Method method, Object[] args) {
        CacheOperationSource cacheOperationSource = getCacheOperationSource(); // 保存所有缓存注解实例的对象
        Collection<CacheOperation> operations = cacheOperationSource.getCacheOperations(method, targetClass); // 获取方法上的缓存注解集合
        return execute(invoker, method, new CacheOperationContexts(operations, method, args, target, targetClass)); // new CacheOperationContexts() 对每个缓存注解创建缓存注解上下文集合 
    }

    private Object execute(final CacheOperationInvoker invoker, Method method, CacheOperationContexts contexts) {
        // Process any early evictions
        processCacheEvicts(contexts.get(CacheEvictOperation.class), true, CacheOperationExpressionEvaluator.NO_RESULT);

        // Check if we have a cached item matching the conditions
        // 从缓存注解上下文集合中获取 Cacheable 缓存注解上下文集合，并尝试从缓存中取数据
        Cache.ValueWrapper cacheHit = findCachedItem(contexts.get(CacheableOperation.class));

        // Collect puts from any @Cacheable miss, if no cached item is found
        List<CachePutRequest> cachePutRequests = new ArrayList<>();
        if (cacheHit == null) {
            collectPutRequests(contexts.get(CacheableOperation.class),
                    CacheOperationExpressionEvaluator.NO_RESULT, cachePutRequests);
        }

        Object cacheValue;
        Object returnValue;

        if (cacheHit != null && !hasCachePut(contexts)) {
            // If there are no put requests, just use the cache hit
            cacheValue = cacheHit.get();
            returnValue = wrapCacheValue(method, cacheValue);
        }
        else {
            // Invoke the method if we don't have a cache hit
            returnValue = invokeOperation(invoker);
            cacheValue = unwrapReturnValue(returnValue);
        }

        // Collect any explicit @CachePuts
        collectPutRequests(contexts.get(CachePutOperation.class), cacheValue, cachePutRequests);

        // Process any collected put requests, either from @CachePut or a @Cacheable miss
        for (CachePutRequest cachePutRequest : cachePutRequests) {
            cachePutRequest.apply(cacheValue);
        }

        // Process any late evictions
        processCacheEvicts(contexts.get(CacheEvictOperation.class), false, cacheValue);

        return returnValue;
    }

    private Cache.ValueWrapper findCachedItem(Collection<CacheOperationContext> contexts) {
        Object result = CacheOperationExpressionEvaluator.NO_RESULT;
        // 遍历所有缓存注解上下文，尝试从中定义的缓存去数据
        for (CacheOperationContext context : contexts) {
            if (isConditionPassing(context, result)) {
                Object key = generateKey(context, result);
                Cache.ValueWrapper cached = findInCaches(context, key);
                if (cached != null) {
                    return cached;
                }
            }
        }
        return null;
    }

    private Cache.ValueWrapper findInCaches(CacheOperationContext context, Object key) {
        // 遍历由缓存注解上下文中获取 cacheNames 定义的缓存实例，并尝试从缓存实例中获取数据
        for (Cache cache : context.getCaches()) {
            Cache.ValueWrapper wrapper = doGet(cache, key);
            if (wrapper != null) {
                return wrapper;
            }
        }
        return null;
    }

    protected Cache.ValueWrapper doGet(Cache cache, Object key) {
        return cache.get(key);
    }
}
```

## 缓存注解上下文

缓存注解上下文集合：
```java
public abstract class CacheAspectSupport {
    // CacheAspectSupport 内部类
    private class CacheOperationContexts {

        private final MultiValueMap<Class<? extends CacheOperation>, CacheOperationContext> contexts;

        private final boolean sync;

        public CacheOperationContexts(Collection<? extends CacheOperation> operations, Method method, Object[] args, Object target, Class<?> targetClass) {
            this.contexts = new LinkedMultiValueMap<>(operations.size());
            for (CacheOperation op : operations) {
                this.contexts.add(op.getClass(), getOperationContext(op, method, args, target, targetClass));
            }
            this.sync = determineSyncFlag(method);
        }
    }

    protected CacheOperationContext getOperationContext(CacheOperation operation, Method method, Object[] args, Object target, Class<?> targetClass) {
        CacheOperationMetadata metadata = getCacheOperationMetadata(operation, method, targetClass);
        return new CacheOperationContext(metadata, args, target);
    }
    
}
```

缓存注解上下文：
```java
public abstract class CacheAspectSupport {
    // CacheAspectSupport 内部类
    protected class CacheOperationContext implements CacheOperationInvocationContext<CacheOperation> {

        private final CacheOperationMetadata metadata;

        private final Object[] args;

        private final Object target;

        private final Collection<? extends Cache> caches;

        private final Collection<String> cacheNames;

        @Nullable
        private Boolean conditionPassing;

        public CacheOperationContext(CacheOperationMetadata metadata, Object[] args, Object target) {
            this.metadata = metadata;
            this.args = extractArgs(metadata.method, args);
            this.target = target;
            this.caches = CacheAspectSupport.this.getCaches(this, metadata.cacheResolver); // 调用缓存解析器，解析该上下文的缓存实例
            this.cacheNames = createCacheNames(this.caches);
        }
    }

    protected Collection<? extends Cache> getCaches(CacheOperationInvocationContext<CacheOperation> context, CacheResolver cacheResolver) {
        Collection<? extends Cache> caches = cacheResolver.resolveCaches(context); // 调用缓存解析器，解析该上下文的缓存实例
        return caches;
    }
    
}
```

## 缓存实例解析器

缓存实例解析器接口：从被拦截的方法的缓存注解上下文解析出缓存实例
```java
public interface CacheResolver {

	Collection<? extends Cache> resolveCaches(CacheOperationInvocationContext<?> context);

}
```

抽象缓存实例解析器：从缓存管理器中获取缓存实例
```java
public abstract class AbstractCacheResolver implements CacheResolver, InitializingBean {

	private CacheManager cacheManager;
    
	@Override
	public Collection<? extends Cache> resolveCaches(CacheOperationInvocationContext<?> context) {
		Collection<String> cacheNames = getCacheNames(context); // 从缓存注解上下文中获取缓存实例名称
		Collection<Cache> result = new ArrayList<>(cacheNames.size());
		for (String cacheName : cacheNames) {
			Cache cache = getCacheManager().getCache(cacheName); // 根据缓存名称从缓存管理器中获取缓存实例
			result.add(cache);
		}
		return result;
	}

	protected abstract Collection<String> getCacheNames(CacheOperationInvocationContext<?> context);

}
```

简单缓存实例解析器：从缓存注解上下文中的 cacheNames 属性获取缓存实例名称
```java
public class SimpleCacheResolver extends AbstractCacheResolver {

	public SimpleCacheResolver(CacheManager cacheManager) {
		super(cacheManager);
	}

	@Override
	protected Collection<String> getCacheNames(CacheOperationInvocationContext<?> context) {
		return context.getOperation().getCacheNames();
	}

}
```