---
layout: post
title:  "使用 GitHub Pages 和 Jekyll 搭建博客"
date:   2023-01-15 00:00:00 +0000
categories: jekyll
---

# 使用 GitHub Pages 和 Jekyll 搭建博客

本文以我自己的 GitHub 用户名 `liaozibo-dev` 为例，介绍使用 GitHub Pages 和 Jekyll 搭建博客的流程

[TOC]

## 创建 GitHub Pages

在 Gibhub 在新建一个公开的空代码仓库，仓库名称为 `liaozibo-dev`

将代码拉取到本地，并进去代码目录：
```bash
git clone https://github.com/liaozibo-dev/liaozibo-dev.git
```


使用 Docker 生成 Jekyll 文件：
```bash
docker run --name jekyll --rm -it -w /usr/src/app -v %cd%:/usr/src/app ruby:2.7.4 bash
```

```bash
gem sources --add https://gems.ruby-china.com/ --remove https://rubygems.org/
gem install jekyll -v 3.9.2
jekyll new --skip-bundle .
```

编辑 `Gemfile`：
```Gemfile
# 注释 jekyll 依赖
# gem "jekyll", "~> 3.9.2"

# 添加 github-pages 依赖
gem "github-pages", "~> 227", group: :jekyll_plugins
```

更新依赖：
```bash
bundle config mirror.https://rubygems.org https://gems.ruby-china.com
bundle update
```


编辑配置 `_config.yml`：
```
baseurl: "/liaozibo-dev"
url: "https://liaozibo-dev.github.io"
```

> 在 [Dependency Versions][dependency-versions] 可以查看 GitHub Pages 使用的依赖版本

推送文件到远程仓库：

```
git branch -M main
git push -u origin main
```

配置 Github Pags：`Settings -> Pages`
 * Souces 选择：Deploy from a branch
 * Branch 选择：main \| root 

在 Actions 可以查看部署流程，等待部署完成，访问：https://liaozibo-dev.github.io/liaozibo-dev

## 配置域名

配置域名：`Settings -> Pages`
* Custom domain：`liaozibo.com`
* 勾选 `Enforce HTTPS`

到域名提供商，配置 DNS 解析

添加解析 `liaozibo.com` 的 A 记录：
```
# IPv4
185.199.108.153
185.199.109.153
185.199.110.153
185.199.111.153
```

添加解析到 `liaozibo.com` 的 AAAA 记录：
``` 
# IPv6
2606:50c0:8000::153
2606:50c0:8001::153
2606:50c0:8002::153
2606:50c0:8003::153
```

添加解析到 `wwww.liaozibo.com` 的 CNAME 记录：
```
liaozibo-dev.github.io.
```

等待域名解析生效，可以用 dig 工具测试：
```bash
docker run --rm -it  nicolaka/netshoot
```

```bash
dig liaozibo.com
dig www.liaozibo.com
```

访问：https://liaozibo.com

## 看不到新增的博客

将博客推送到 GitHub 没有看到新增博客。

在 `Actions -> Jobs -> Build -> Build with Jekyll` 中查看 Jekyll 构建日志

发现构建时因为时间文件跳过了该博客

```
Skipping: _posts/2023-01-15-github-pages-jekyll.md has a future date
```

直接将时间调整到过去即可，比如 `2023-01-15 00:00:00`

## 参考

* [Ruby China][ruby-china]
* [Create site with Jekyll - GitHub Docs][creating-a-github-pages-site-with-jekyll]
* [Manage a custom domain - GitHub Docs][managing-a-custom-domain-for-your-github-pages-site]
* [Quick Start - Jekyll][jekyll-quick-start]
* [Ruby - Docker Hub][ruby]


[dependency-versions]: https://pages.github.com/versions/
[creating-a-github-pages-site-with-jekyll]: https://docs.github.com/en/pages/setting-up-a-github-pages-site-with-jekyll/creating-a-github-pages-site-with-jekyll
[managing-a-custom-domain-for-your-github-pages-site]: https://docs.github.com/en/pages/configuring-a-custom-domain-for-your-github-pages-site/managing-a-custom-domain-for-your-github-pages-site
[ruby-china]: https://gems.ruby-china.com/
[jekyll-quick-start]: https://jekyllrb.com/docs/
[ruby]: https://hub.docker.com/_/ruby