---
layout: post
title:  "云原生 01"
date:   2023-05-02 00:00:00 +0000
categories: cloud-native
---
# GitOps

[TOC]

GitOps 的核心思想是，通过 Git 以声明式的方式来定义环境和基础设施。

## 01 构建容器镜像

前提：安装 Docker Desktop

### 运行容器镜像

拉取镜像：
```bash
docker pull lyzhang1999/hello-world-flask:latest
```

查看镜像：
```bash
docker images
```
```
REPOSITORY                      TAG       IMAGE ID       CREATED        SIZE
lyzhang1999/hello-world-flask   latest    185eac234bc3   7 months ago   163MB
```

运行镜像：
```bash
docker run -d -p 8000:5000 lyzhang1999/hello-world-flask:latest 
```
```bash
curl http://localhost:8000
```

### 进入容器内部

查看运行中的容器：
```bash
docker ps
```
```
CONTAINER ID   IMAGE                                  COMMAND                  CREATED         STATUS         PORTS                    NAMES
7bcc2a8c1a8e   lyzhang1999/hello-world-flask:latest   "python3 -m flask ru…"   4 minutes ago   Up 4 minutes   0.0.0.0:8000->5000/tcp   blissful_chandrasekhar
```

进入容器内部:：
```bash
docker exec -it 7bcc2a8c1a8e bash
```

停止容器：
```bash
docker stop 7bcc2a8c1a8e
```
```bash
docker rm -f 7bcc2a8c1a8e
```

### 构建容器镜像

app.py
```python
from flask import Flask
import os
app = Flask(__name__)
app.run(debug=True)

@app.route('/')
def hello_world():
    return 'Hello, my first docker images! ' + os.getenv("HOSTNAME") + ''
```

requirements.txt
```
Flask==2.2.2
```

Dockerfile
```
# syntax=docker/dockerfile:1

FROM python:3.8-slim-buster

RUN apt-get update && apt-get install -y procps vim apache2-utils && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY requirements.txt requirements.txt
RUN pip3 install -r requirements.txt

COPY . .

CMD [ "python3", "-m" , "flask", "run", "--host=0.0.0.0"]
```

构建镜像：
```bash
docker build -t hello-world-flask .
```

查看镜像：
```bash
docker images
```
```
REPOSITORY                      TAG       IMAGE ID       CREATED         SIZE
hello-world-flask               latest    0ef4626bd411   5 seconds ago   163MB
```

运行镜像：
```bash
docker run -d -p 8000:5000 hello-world-flask
```
```
curl http://localhost:8000
Hello, my first docker images! 4f07773e527e
```

### 推送镜像

```bash
docker login
```

```bash
docker tag hello-world-flask liaozibo/hello-world-flask
```

```bash
docker push liaozibo/hello-world-flask
```

### 常用基础镜像

* [eclipse-temurin](https://hub.docker.com/_/eclipse-temurin)
* [ubuntu](https://hub.docker.com/_/ubuntu)
* [alpine](https://hub.docker.com/_/alpine)
* [busybox](https://hub.docker.com/_/busybox)

## 02 K8s 和 Kind

* 安装 [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl-windows/#install-kubectl-binary-with-curl-on-windows)
* 安装 [kind](https://kind.sigs.k8s.io/docs/user/quick-start/#installation) （全称 Kubernetes in Docker，单机测试 K8s 集群最佳方案）

### 创建 K8s 集群

config.yml（Manifest 清单文件）
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
kind create clusters --config config.yml
```

### 部署容器镜像到 K8s 集群

创建 Pod 工作负载

hello-flask.yml
* `kind`: 工作负载类型（在实际项目中，通常不会直接创建 Pod 类型的工作负载）
* `metadata.name`: 工作负载名称
* `containers`: 容器配置

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: hello-world-flask
spec:
  containers:
    - name: flask
      image: liaozibo/hello-world-flask:latest
      ports:
        - containerPort: 5000
```

```bash
kubectl apply -f hello-flask.yml
```

查看正在运行的 Pod：
```bash
kubectl get pods -w
```
```
NAME                READY   STATUS    RESTARTS   AGE
hello-world-flask   1/1     Running   0          10m
```

访问 Pod（端口转发，本地网络到集群网络）：
```bash
kubectl port-forward pod/hello-world-flask 8000:5000
```

```bash
curl http://localhost:8000
```
```
Hello, my first docker images! hello-world-flask
```

进入容器：
```bash
kubectl exec -it hello-world-flask -- bash
```

删除 Pod：
```bash
kubectl delete pod hello-world-flask
```


## 03 K8s 自愈和自动扩容

自愈：
* 节点尝试故障时，自动重启并恢复服务
* 自动故障转移（保证流量不会被转发到不健康的节点）

### 创建 Deployment 工作负载

创建 Deployment 工作负载（管理 Pod）

```bash
kubectl create deployment hello-world-flask --image liaozibo/hello-world-flask:latest --replicas=2
```

输出 Manifest
```bash
kubectl create deployment hello-world-flask --image liaozibo/hello-world-flask:latest --replicas=2 --dry-run=client -o yaml
```

创建 Service（相当于负载均衡器，将流量以加权负载均衡的方式转发到 Pod）
```bash
kubectl create service clusterip hello-world-flask --tcp=5000:5000
```

创建 Ingress（相当于集群的外网访问入口）
```bash
kubectl create ingress hello-world-flask --rule="/=hello-world-flask:5000"
```

部署 Ingress-Nginx
```bash
kubectl create -f https://cdn.jsdelivr.net/gh/liaozibo-dev/resource@main/ingress-nginx/ingress-nginx.yaml
```

### 访问 Deployment 工作负载

Kind 本地集群（暴露 80/443 端口）：
```bash
kind get clusters
```

```
kind
```

Pod：
```bash
kubectl get pods
```

```
NAME                                 READY   STATUS    RESTARTS   AGE
hello-world-flask-68bfc7dc45-49zcv   1/1     Running   0          31m
hello-world-flask-68bfc7dc45-s5l6t   1/1     Running   0          31m
```

Service：
```bash
kubectl get service
```

```
NAME                TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)    AGE
hello-world-flask   ClusterIP   10.96.134.76   <none>        5000/TCP   29m
kubernetes          ClusterIP   10.96.0.1      <none>        443/TCP    16h
```

Ingress：
```bash
kubectl get ingress
```

```
NAME                CLASS    HOSTS   ADDRESS     PORTS   AGE
hello-world-flask   <none>   *       localhost   80      27m
```

访问集群：

```bash
curl http://localhost
```

```
Hello, my first docker images! hello-world-flask-68bfc7dc45-s5l6t
Hello, my first docker images! hello-world-flask-68bfc7dc45-49zcv
```

```
kind(80:80) -> ingress(80:hello-world-flask-5000) -> service(5000:5000) -> Pod(5000)
```

### 自动自愈
K8s 会自动移除故障 Pod，重启服务后重新加入

```bash
kubectl exec -it hello-world-flask-68bfc7dc45-49zcv -- bash -c "killall python3"
```

### 自动扩容

创建 K8s Metric Server（提供监控指标）
```bash
kubectl apply -f https://cdn.jsdelivr.net/gh/liaozibo-dev/resource@main/metrics/metrics.yaml
```

等待 Metric 工作负载就绪
```bash
kubectl wait deployment -n kube-system metrics-server --for condition=Available=True --timeout=90s
```

```
deployment.apps/metrics-server condition met
```

创建自动扩容策略：
* CPU 阈值；50%
* 最小副本数：2
* 最大副本数：10

```bash
kubectl autoscale deployment hello-world-flask --cpu-percent=50 --min=2 --max=10
```

更新 Deployment

Linux:
```bash
kubectl patch deployment hello-world-flask --type='json' -p='[{"op": "add", "path": "/spec/template/spec/containers/0/resources", "value": {"requests": {"memory": "100Mi", "cpu": "100m"}}}]'
deployment.apps/hello-world-flask patched
```

Windows:
```bash
kubectl patch deployment hello-world-flask --type="json" -p="[{\"op\": \"add\", \"path\": \"/spec/template/spec/containers/0/resources\", \"value\": {\"requests\": {\"memory\": \"100Mi\", \"cpu\": \"100m\"}}}]"
deployment.apps/hello-world-flask patched
```

模拟并发：
* c: 50 并发
* n: 10000 次请求

```bash
kubectl exec -it hello-world-flask-6558d95457-4bcvf -- bash
```
```bash
ab -c 50 -n 10000 http://127.0.0.1:5000/
```

自动扩容和缩容：
```
NAME                                 READY   STATUS              RESTARTS   AGE
hello-world-flask-6558d95457-4bcvf   1/1     Running             0          2m54s
hello-world-flask-6558d95457-blqxm   0/1     ContainerCreating   0          1s
hello-world-flask-6558d95457-frfds   1/1     Running             0          3m7s
hello-world-flask-6558d95457-jzrd6   0/1     Pending             0          1s
```

* 资源文件 [resource](https://github.com/liaozibo-dev/resource/tree/main)
* GitHub 文件加速 [jsdelivr](https://www.jsdelivr.com/github)

## K8s 应用发布和回滚之 GitOps

### 手动发布

手动发布的三种方式：
* 更新镜像：`kubectl set image`
* 更新 Manifest：`kubectl apply -f`
* 编辑 Manifest：`kubectl edit deployment`

#### 更新镜像

查看之前部署的 Deployment：
```bash
kubectl get deployment
```
```
NAME                READY   UP-TO-DATE   AVAILABLE   AGE
hello-world-flask   2/2     2            2           3h49m
```

更新镜像版本：
```bash
kubectl set image deployment/hello-world-flask hello-world-flask=lyzhang1999/hello-world-flask:v1
```
```bash
kubectl get pods
```
```
NAME                                 READY   STATUS              RESTARTS   AGE
hello-world-flask-5467fbd748-68777   0/1     ContainerCreating   0          14s
hello-world-flask-6558d95457-7rck9   1/1     Running             0          136m
hello-world-flask-6558d95457-gm9gv   1/1     Running             0          136m
```

#### 更新 Manifest

```bash
kubectl apply -f hello-world-flask.yml
```

#### 编辑 Manifest

```bash

kubectl edit deployment hello-world-flask
```

### GitOps 发布工作流

GitOps：以 Git 版本控制为理念的 DevOps 实践。

将 Manifest 存储在 Git 仓库中，一旦修改并提交 Manifest，GitOps 工作流会自动对比差异并进行部署。

#### 搭建 FluxCD

安装 FluxCD （CD 持续部署，FluxCD 用于监听 Git 仓库变化）（实际生产中推荐使用 ArgoCD）
```
kubectl apply -f https://cdn.jsdelivr.net/gh/liaozibo-dev/resource@main/fluxcd/fluxcd.yaml
```

等待安装完成
```bash
kubectl wait --for=condition=available --timeout=300s --all deployments -n flux-system
```
```
deployment.apps/helm-controller condition met
deployment.apps/image-automation-controller condition met
deployment.apps/image-reflector-controller condition met
deployment.apps/kustomize-controller condition met
deployment.apps/notification-controller condition met
deployment.apps/source-controller condition met
```

deployment.yml
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: hello-world-flask
  name: hello-world-flask
spec:
  replicas: 2
  selector:
    matchLabels:
      app: hello-world-flask
  template:
    metadata:
      labels:
        app: hello-world-flask
    spec:
      containers:
      - image: liaozibo/hello-world-flask:latest
        name: hello-world-flask
```

将文件提交到 GitHub （public）仓库中
```bash
git init
git add .
git commit -m "add deployment"
git branch -M main
git remote add origin https://github.com/liaozibo-dev/fluxcd-demo.git
git push -u origin main
```

为 FluxCD 创建仓库连接信息 fluxcd-repo.yml

```yaml
apiVersion: source.toolkit.fluxcd.io/v1beta2
kind: GitRepository
metadata:
  name: hello-world-flask
spec:
  interval: 5s
  ref:
    branch: main
  url: https://github.com/liaozibo-dev/fluxcd-demo.git
```

将其部署到集群中：
```bash
kubectl apply -f fluxcd-repo.yml
```

检查配置状态：
```bash
kubectl get gitrepository
```
```
NAME                URL                                               AGE   READY   STATUS
hello-world-flask   https://github.com/liaozibo-dev/fluxcd-demo.git   18s   True    stored artifact for revision 'main/c04e6492afce39f4e891bbe97b40187a354b3b1a'
```

创建部署策略：fluxcd-kustomize.yml
```yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1beta2
kind: Kustomization
metadata:
  name: hello-world-flask
spec:
  interval: 5s
  path: ./
  prune: true
  sourceRef:
    kind: GitRepository
    name: hello-world-flask
  targetNamespace: default
```

```bash
kubectl apply -f fluxcd-kustomize.yml
```

```bash
kubectl get kustomization 
```
```
NAME                AGE   READY   STATUS
hello-world-flask   22s   True    Applied revision: main/c04e6492afce39f4e891bbe97b40187a354b3b1a
```

#### 自动发布

更新 deployment.yml 镜像版本（`lyzhang1999/hello-world-flask:v1`）

提交 deployment.yml
```bash
git add deployment.yml
git commit -m "update deployment" 
git push
```

验证自动发布：
```bash
kubectl describe kustomization hello-world-flask
```
```bash
kubectl get kustomization
```

```bash
curl http://localhost 
```

```
Hello, my v1 version docker images! hello-world-flask-67d6474f8f-xsncs
```

#### 自动回滚

回滚 deployment.yml

```bash
git log
```

```
commit f641e06dc00acfb2beac5f04bf52eb52711fae78 (HEAD -> main, origin/main)
Author: liaozibo <liaozibo@qq.com>
Date:   Tue May 2 20:36:13 2023 +0800

    update deployment

commit c04e6492afce39f4e891bbe97b40187a354b3b1a
Author: liaozibo <liaozibo@qq.com>
Date:   Tue May 2 20:27:43 2023 +0800

    add deployment
```

```bash
git reset --hard c04e6492afce39f4e891bbe97b40187a354b3b1a
git push -f
```

```bash
curl http://localhost
```

```
Hello, my first docker images! hello-world-flask-68bfc7dc45-j8p6q
```

## 参考

* 《云原生架构与 GitOps 实战》 入门篇：从零上手GitOps