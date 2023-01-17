---
layout: post
title:  "Arthas 内存编译命令报错"
date:   2023-01-17 00:00:00 +0000
categories: java
---

内存编译命令报错，尝试重启电脑无效：
```
[arthas@4712]$ mc -c 38af3868 UserController.java -d UserController.class
Memory compiler error, exception message: Can not load JavaCompiler from javax.tools.ToolProvider#getSystemJavaCompiler(), please confirm the application running in JDK not JRE., please check $HOME/logs/arthas/arthas.log for more details.
```

发现启动时，日志打印的 `JAVA_HOME` 不是 JDK
```
C:\Users\liaoz\arthas>java -jar arthas-boot.jar
[INFO] JAVA_HOME: D:\Java\jre1.8.0_341
[INFO] arthas-boot version: 3.6.7
```

查看环境变量设置，没有问题：
```
C:\Users\liaoz\arthas>echo %JAVA_HOME%
D:\Java\jdk1.8.0_341
```

查看 Arthas 源码，发现该值是从系统属性读取的：
```java
// com/taobao/arthas/boot/Bootstrap.java:315
String javaHome = System.getProperty("java.home");
if (javaHome != null) {
    AnsiLog.info("JAVA_HOME: " + javaHome);
}
```

在 Arthas 查看系统属性：
```
[arthas@4712]$ sysprop  java.home
 KEY                     VALUE
-----------------------------------------------------------------------------------------------------------------------
 java.home               D:\Java\jre1.8.0_341
```

将该值改为 JDK：
```
[arthas@4712]$ sysprop java.home 'D:\Java\jdk1.8.0_341'
```

重新编译成功：
```
[arthas@4712]$ mc -c 38af3868 UserController.java
Memory compiler output:
C:\Users\liaoz\arthas\com\example\demo\arthas\user\UserController.class
Affect(row-cnt:1) cost in 6942 ms.
[arthas@4712]$ retransform -c 38af3868 'com\example\demo\arthas\user\UserController.class'
retransform success, size: 1, classes:
com.example.demo.arthas.user.UserController
```