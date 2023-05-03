---
layout: post
title:  "云原生 01 K8s 极简实战"
date:   2023-05-03 00:00:00 +0000
categories: cloud-native
---
# 云原生 01 K8s 极简实战

[TOC]

## 部署示例应用

### 示例应用

代码仓库：https://github.com/liaozibo-dev/kubernetes-example.git

应用业务架构：
* 前端：frontend
* 后端：backend
* K8s Manifest：deploy

K8s 部署架构：
```
            -- http://host/     --> frontend-service  -> frontend deployment
Ingress -
            -- http://host/api  --> backend-service   -> backend deployment(HPA) --> postgrep-service   -> postgrep deployment
```

### 创建 K8s 集群

删除之前的 kind 集群
```bash
kind delete cluster
```

kind 集群 config.yml
```yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
  extraPortMappings:
  - containerPort: 80
    hostPort: 80
    protocol: TCP
  - containerPort: 443
    hostPort: 443
    protocol: TCP
```

```bash
kind create cluster --config config.yml
```

部署 Ingress
```bash
kubectl apply -f https://cdn.jsdelivr.net/gh/liaozibo-dev/resource@main/ingress-nginx/ingress-nginx.yaml
```

部署 Metric，以便开启 HPA
```bash
kubectl apply -f https://cdn.jsdelivr.net/gh/liaozibo-dev/resource@main/metrics/metrics.yaml
```

### 部署示例应用

创建命名空间 example
```bash
kubectl create namespace example
```

创建 Postgres 数据库
```bash
kubectl apply -n example -f https://cdn.jsdelivr.net/gh/liaozibo-dev/kubernetes-example@main/deploy/database.yaml
```

创建前后端 Deployment 工作负载和 Service：
```bash
kubectl apply -n example -f https://cdn.jsdelivr.net/gh/liaozibo-dev/kubernetes-example@main/deploy/frontend.yaml
```

```bash
kubectl apply -n example -f https://cdn.jsdelivr.net/gh/liaozibo-dev/kubernetes-example@main/deploy/backend.yaml
```

创建 Ingress
```bash
kubectl apply -n example -f https://cdn.jsdelivr.net/gh/liaozibo-dev/kubernetes-example@main/deploy/ingress.yaml
```

创建 HPA

```bash
kubectl apply -n example -f https://cdn.jsdelivr.net/gh/liaozibo-dev/kubernetes-example@main/deploy/hpa.yaml
```

等待应用部署完成

```bash
kubectl get pods -n example
```

```
NAME                        READY   STATUS              RESTARTS   AGE
backend-5c4c868bc6-qxp5c    0/1     ContainerCreating   0          9m33s
frontend-6b48fbbc48-zzlh4   0/1     ContainerCreating   0          10m
postgres-7568bd77cf-pnnc9   0/1     ImagePullBackOff    0          12m
```

```bash
kubectl wait --for=condition=Ready pods --all -n example --timeout=300s
```

创建的资源总览
```bash
kubectl get all -n example
```

```
NAME                            READY   STATUS    RESTARTS      AGE
pod/backend-5c4c868bc6-7qmvx    1/1     Running   0             33m
pod/backend-5c4c868bc6-ksspg    1/1     Running   0             33m
pod/frontend-6b48fbbc48-vdxv6   1/1     Running   2 (11m ago)   33m
pod/frontend-6b48fbbc48-vh7st   1/1     Running   0             33m
pod/postgres-7568bd77cf-47wkm   1/1     Running   0             33m

NAME                       TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)    AGE
service/backend-service    ClusterIP   10.96.129.218   <none>        5000/TCP   33m
service/frontend-service   ClusterIP   10.96.30.56     <none>        3000/TCP   33m
service/pg-service         ClusterIP   10.96.96.184    <none>        5432/TCP   33m

NAME                       READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/backend    2/2     2            2           33m
deployment.apps/frontend   2/2     2            2           33m
deployment.apps/postgres   1/1     1            1           33m

NAME                                  DESIRED   CURRENT   READY   AGE
replicaset.apps/backend-5c4c868bc6    2         2         2       33m
replicaset.apps/frontend-6b48fbbc48   2         2         2       33m
replicaset.apps/postgres-7568bd77cf   1         1         1       33m

NAME                                           REFERENCE             TARGETS           MINPODS   MAXPODS   REPLICAS   AGE
horizontalpodautoscaler.autoscaling/backend    Deployment/backend    29%/50%, 1%/50%   2         10        2          33m
horizontalpodautoscaler.autoscaling/frontend   Deployment/frontend   0%/80%            2         2         2          33m
```

### 一键部署所有资源

`-f deploy` 指定了部署 deploy 目录下的所有 Manifest
```bash
git clone https://github.com/liaozibo-dev/kubernetes-example.git
cd kubernetes-example
kubectl apply -f deploy -n example
```

## 命名空间

使用命名空间隔离团队及应用环境。

系统级命名空间：
* default：默认命名空间
* kube-public：所有用户都可以读取的命名空间
* kube-system：K8s 系统级组件的命名空间
* kube-node-lease：集群扩展相关的命名空间

### 查看命名空间

查看命名空间：
```bash
kubectl get ns
```
```
NAME                 STATUS   AGE
default              Active   46m
example              Active   43m
ingress-nginx        Active   43m
kube-node-lease      Active   46m
kube-public          Active   46m
kube-system          Active   46m
local-path-storage   Active   46m
```

查看命名空间详情：
```bash
kubectl describe namespace example
```
```
Name:         example
Labels:       kubernetes.io/metadata.name=example
Annotations:  <none>
Status:       Active

No resource quota.

No LimitRange resource.
```

### 创建命名空间

通过命令行创建：
```bash
kubectl create namespace example
```

通过 Manifest 创建：（namespace.yml）
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: example
```
```bash
kubectl apply -f namespace.yml
```

### 删除命名空间

删除命名空间会删除该命名空间下的所有资源

```bash
kubectl delete namespace example
```

### 指定命名空间

在 Manifest 中指定：
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
  namespace: example   # 设置 namespace
  labels:
    app: frontend
spec:
```

在命令行中指定：（更常用）
```bash
kubectl apply -f deploy -n example
```

### 查看命名空间下的资源

```bash
kubectl get deployment -n example
```

```
NAME       READY   UP-TO-DATE   AVAILABLE   AGE
backend    2/2     2            2           63m
frontend   2/2     2            2           63m
postgres   1/1     1            1           64m
```

### 命名空间使用

命名空间作用：
* 环境管理：隔离不同环境（开发、测试、生产）。命名空间提供了一种软隔离的方式，实际中，建议使用不同集群对环境进行硬隔离。
* 隔离：隔离不同团队、产品线等
* 资源控制：可以在命名空间级别配置 CPU、内存等资源配额，避免资源恶心竞争导致业务不稳定的情况
* 权限控制：K8s 的 RBAC 可以对某个用户授权一个或多个命名空间
* 提高集群性能：提高资源搜索的性能

跨命名空间通信：
* 同一命名空间：可以直接通过 service-name 通信
* 不同命名空间：需要通过完整的 Service URL 进行通信 `<service-name>.<namespace-name>.svc.cluster.local`

命名空间规划：
* 小型组织：在同一集群下，通过命名空间隔离不同环境
* 大型组织：通过不同集群隔离环境，并且通过命名空间隔离不同团队（如果不同团队开发的是同一业务的不同微服务，可以将这些微服务在放在同一命名空间下）

## 工作负载

K8s 的工作负载包括：ReplicaSet、Deployment、StatefulSet、DaemonSet、Job、CronJob

### ReplicaSet

ReplicaSet：保持一定数量的 Pod 始终处于运行状态

关系图：
```
                - Pod
ReplicaSet -
                - Pod
```

创建 ReplicaSet 工作负载：ReplicaSet.yml
```yaml

apiVersion: apps/v1
kind: ReplicaSet
metadata:
  name: frontend
  labels:
    app: frontend
spec:
  replicas: 3   # 3 个副本数
  selector:
    matchLabels:
      app: frontend
  template:
    metadata:
      labels:
        app: frontend
    spec:
      containers:
      - name: frontend
        image: lyzhang1999/frontend:v1
```

```bash
kubectl apply -f ReplicaSet.yml
```

查看镜像版本：
```bashh
kubectl get pods --selector=app=frontend -o jsonpath='{.items[*].spec.containers[0].image}'
```

ReplicaSet 只负载维护 Pod 数量。
更新镜像版本并提交到 K8s 中，Pod 的镜像版本不会自动更新。只有删除 Pod，ReplicaSet 才会用新的镜像版本创建 Pod。

## Deployment

通常，无状态的业务应用都会使用 Deployment 部署。

Deployment 是 K8s 中最常用的工作负载
* 可以实现更新（不停机的滚动更新）、回滚、横向扩容
* 配置 HPA 可以实现自动扩缩容

关系图：
```
                - ReplicaSet - Pods
Deployment - 
                - ReplicaSet - Pods
```

查看示例应用中 backend 的工作负载详情：
```bash
kubectl describe deployment backend -n example
```

```
Name:                   backend
Namespace:              example
CreationTimestamp:      Wed, 03 May 2023 15:01:51 +0800
Labels:                 app=backend
Annotations:            deployment.kubernetes.io/revision: 1
Selector:               app=backend
Replicas:               10 desired | 10 updated | 10 total | 2 available | 8 unavailable
StrategyType:           RollingUpdate # 部署策略
MinReadySeconds:        0
RollingUpdateStrategy:  25% max unavailable, 25% max surge # 最大不可用数量、最大超出期望的 Pod 数量
Pod Template:
  Labels:  app=backend
  Containers:
   flask-backend:
    Image:      lyzhang1999/backend:latest
    Port:       5000/TCP
    Host Port:  0/TCP
    Limits:
      cpu:     256m
      memory:  256Mi
    Requests:
      cpu:      128m
      memory:   128Mi
    Liveness:   http-get http://:5000/healthy delay=0s timeout=1s period=10s #success=1 #failure=5
    Readiness:  http-get http://:5000/healthy delay=10s timeout=1s period=10s #success=1 #failure=5
    Startup:    http-get http://:5000/healthy delay=10s timeout=1s period=10s #success=1 #failure=5
    Environment:
      DATABASE_URI:       pg-service
      DATABASE_USERNAME:  postgres
      DATABASE_PASSWORD:  postgres
    Mounts:               <none>
  Volumes:                <none>
Conditions:
  Type           Status  Reason
  ----           ------  ------
  Progressing    True    NewReplicaSetAvailable
  Available      False   MinimumReplicasUnavailable
OldReplicaSets:  <none>
NewReplicaSet:   backend-5c4c868bc6 (10/10 replicas created) # 由 Deployment 管理的 ReplicaSet 名称
Events:
  Type    Reason             Age   From                   Message
  ----    ------             ----  ----                   -------
  Normal  ScalingReplicaSet  32s   deployment-controller  Scaled up replica set backend-5c4c868bc6 to 4 from 2
  Normal  ScalingReplicaSet  17s   deployment-controller  Scaled up replica set backend-5c4c868bc6 to 8 from 4
  Normal  ScalingReplicaSet  1s    deployment-controller  Scaled up replica set backend-5c4c868bc6 to 10 from 8
```

监控 ReplicaSet：
```bash
kubectl get replicaset --watch -n example
```

```
NAME                  DESIRED   CURRENT   READY   AGE
backend-5c4c868bc6    10        10        10      5h6m
frontend-6b48fbbc48   2         2         2       5h6m
postgres-7568bd77cf   1         1         1       5h6m
```

将最小 Pod 数量由 2 改成 3：
```
kubectl patch hpa backend -p "{\"spec\":{\"minReplicas\": 3}}" -n example
```

更新镜像版本，Deployment 会滚动更新 Pod
```bash
kubectl set image deployment/backend flask-backend=lyzhang1999/backend:v1 -n example
```

### StatefulSet

* StatefulSet 主要用于部署 “有状态” 的应用。
* 在实际的业务场景里，StatefulSet 经常用来部署中间件。
* StatefulSet 可以很好的支持中间件主从关系操作，以及可以配合持久化存储一起使用。

实际中，通常不需要自己写 StatefulSet Manifest，只要找到对于中间件的 Helm Chart 直接安装即可。

或者可以直接使用云厂商提供的高可用产品。

### DaemonSet

节点级的守护进程，集群中添加新节点时，它会在进行节点启动新的 Pod。它可以用于日志和监控组件，采集节点的日志或监控指标。

### Job/CronJob

相对于其他工作负载，如果 Pod 结束了，K8s 会不断重启 Pod。
而 Job/CronJob 主要用于执行一次性的批处理任务。

## 服务发现

K8s 原生的服务发现机制：Service


### 通过 IP 通信

获取后端服务的 IP 地址
```bash
kubectl get pods -n example --selector=app=backend -o wide
```
```
NAME                     READY   STATUS    RESTARTS   AGE   IP            NODE                 NOMINATED NODE   READINESS GATES
backend-5b9b8f78-4xt5k   1/1     Running   0          68m   10.244.0.38   kind-control-plane   <none>           <none>
backend-5b9b8f78-dxmj2   1/1     Running   0          69m   10.244.0.35   kind-control-plane   <none>           <none>
backend-5b9b8f78-mdw5k   1/1     Running   0          69m   10.244.0.33   kind-control-plane   <none>           <none>
```

进入前端服务的 Pod 并调用后端服务：
```bash
kubectl exec -n example -it frontend-6b48fbbc48-2xxdr -- sh
```
```bash
kubectl exec -it $(kubectl get pods --selector=app=frontend -n example -o jsonpath="{.items[0].metadata.name}") -n example -- sh
```

```
/frontend # wget -O - http://10.244.0.38:5000/healthy
Connecting to 10.244.0.38:5000 (10.244.0.38:5000)
writing to stdout
{"healthy":true}
```

### Service 服务发现

```
/frontend # wget -O - http://backend-service:5000/healthy
Connecting to backend-service:5000 (10.96.129.218:5000)
writing to stdout
{"healthy":true}
```

```bash
while true; do wget -q -O- http://backend-service:5000/host_name && sleep 1; done
```

Service 原理：
```
Service -> Endpoint(保存 pod ip 集合) -> Pods
```

backend Service Manifest：
```yaml
apiVersion: v1
kind: Service
metadata:
  name: backend-service # Service 域名
  labels:
    app: backend
spec:
  type: ClusterIP # Service 类型
  sessionAffinity: None # 保持会话
  selector:
    app: backend # 通过 Label 关联 Pod
  ports:
  - port: 5000 # Service 监听的端口
    targetPort: 5000 # 目标端口
```

> Service 完整域名：`{$service_name}.{$namespace}.svc.cluster.local` 或者 `{$service_name}.{$namespace}`

创建 Service 后，K8s 会自动创建 Endpoint：
```bash
kubectl get endpoints -n example
```
```
NAME               ENDPOINTS                                            AGE
backend-service    10.244.0.33:5000,10.244.0.35:5000,10.244.0.38:5000   6h43m
frontend-service   10.244.0.15:3000,10.244.0.17:3000                    6h43m
pg-service         10.244.0.18:5432                                     6h43m
```

### Service 类型

Service 类型：
* ClusterIP：（最常用）为 Service 创建一个 VIP，并提供集群内的访问能力
* NodePort：（不推荐）将 Service 暴露在节点的端口上，可以通过 节点IP+端口 的方式访问服务
* Loadbalancer：（不推荐）将 Service 和云厂商的负载均衡器关联起来，通过负载均衡器的外网 IP 进行访问
* ExternalName：将 Service 和另一个域名关联起来

ExternalName:在 default 命名空间下请求 `http://backend-serivce:5000`，会被转发到 example 命名空间下
```yaml

apiVersion: v1
kind: Service
metadata:
  name: backend-service
  namespace: default
spec:
  type: ExternalName
  externalName: backend-service.example.svc.cluster.local
```

### 通过 Service 访问外部服务

* Service 和 Endpoint 通过 metadata.name 关联
* Service 类型是 ClusterIP
* K8s 集群内通过 mysql-service.example.svc.cluster.local:3306 访问
```yaml
apiVersion: v1
kind: Service
metadata:
  name: mysql-service
  namespace: example
spec:
  ports:
    - port: 3306
      targetPort: 3306
---
apiVersion: v1
kind: Endpoints
metadata:
  name: mysql-service
  namespace: example
subsets:
  - addresses:
      - ip: 8.8.8.8
    ports:
      - port: 3306
        protocol: TCP
```

## 应用配置

不推荐直接将配置文件 COPY 到镜像中：
* 一般镜像表示的业务进程，只有源码改变时才会重新构建镜像
* 生效效率低，不支持热更新
* 安全性，敏感配置不应让开发直接接触

### Env

为 Deployment 配置环境变量

backend.yml
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
  ......
spec:
  replicas: 1
  ......
    spec:
      containers:
      - name: flask-backend
        image: lyzhang1999/backend:latest
        imagePullPolicy: Always
        ports:
        - containerPort: 5000
        env:
        - name: DATABASE_URI
          value: pg-service
        - name: DATABASE_USERNAME
          value: postgres
        - name: DATABASE_PASSWORD
          value: postgres
```

### ConfigMap

ConfigMap：能够在 Pod 启动时，将 ConfigMap 的内容以文件的方式挂载到容器里
```bash
kubectl get configmap pg-init-script -n example -o yaml
```
```yaml
apiVersion: v1
data:
  CreateDB.sql: |-
    CREATE TABLE text (
        id serial PRIMARY KEY,
        text VARCHAR ( 100 ) UNIQUE NOT NULL
    );
kind: ConfigMap
metadata:
  annotations:
    kubectl.kubernetes.io/last-applied-configuration: |
      {"apiVersion":"v1","data":{"CreateDB.sql":"CREATE TABLE text (\n    id serial PRIMARY KEY,\n    text VARCHAR ( 100 ) UNIQUE NOT NULL\n);"},"kind":"ConfigMap","metadata":{"annotations":{},"name":"pg-init-script","namespace":"example"}}
  creationTimestamp: "2023-05-03T07:01:42Z"
  name: pg-init-script
  namespace: example
  resourceVersion: "956"
  uid: 27451ea4-4c28-45e3-977b-c986fe71dfc6
```

在 deployment 中引用 ConfigMap：
```yaml

apiVersion: apps/v1
kind: Deployment
metadata:
  name: Postgres
  ......
spec:
  ......
  template:
    ......
    spec:
      containers:
        - name: Postgres
          image: Postgres
          volumeMounts:
            - name: sqlscript # 卷名称
              mountPath: /docker-entrypoint-initdb.d # 挂载路径
          ......
      volumes:
        - name: sqlscript # 卷名称
          configMap: # 以卷的方式使用 ConfigMap
            name: pg-init-script
```

其他：
* 环境变量引用 ConfigMap（`envFrom`）
* 从文件创建 ConfigMap（`kubectl create configmap --from-file`）
### Secret

Secret：将配置以加密文件的形式挂载到容器（Base64加密）

创建 Secret：
```yaml

apiVersion: v1
kind: Secret
metadata:
  name: pg-init-script
  namespace: example
type: Opaque
data:
  CreateDB.sql: |-
    Q1JFQVRFIFRBQkxFIHRleHQgKAogICAgaWQgc2VyaWFsIFBSSU1BUlkgS0VZLAogICAgdGV4dCBWQVJDSEFSICggMTAwICkgVU5JUVVFIE5PVCBOVUxMCik7
```

在 deployment 引用 secret 后，会实时挂载到容器中，并且文件内容是 Base64 解码后的
```
$ kubectl edit deployment postgres -n example
......
volumes:
  - secret:
      secretName: pg-init-script
    name: sqlscript
......
```

## 参考

* 《云原生架构与 GitOps 实战》 核心基础篇：K8s极简实战