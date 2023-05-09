# 6. 数据共享与持久化

- 数据卷（Data Volumes）
- 挂载主机目录 (Bind mounts)

## 数据卷

`数据卷`是一个可供一个或多个容器使用的特殊目录，它绕过`UFS`，可以提供很多有用的特性：

- 数据卷 可以在容器之间共享和重用
- 对 数据卷 的修改会立马生效
- 对 数据卷 的更新，不会影响镜像
- 数据卷 默认会一直存在，即使容器被删除

创建一个数据卷：

```
docker volume create my-vol
```

在主机里使用以下命令可以查看指定 数据卷 的信息

```shell
$ docker volume inspect my-vol
```

删除数据卷：

```
$ docker volume rm my-vol
```

## 挂载主机目录

挂载一个主机目录作为数据卷：使用 `--mount` 标记可以指定挂载一个本地主机的目录到容器中去。

```shell
$ docker run -d -P \
    --name web \
    # -v /src/webapp:/opt/webapp \
    --mount type=bind,source=/src/webapp,target=/opt/webapp \
    training/webapp \
    python app.py
```





# 7. Docker 的网络模式

## Bridge模式

随着 Docker 网络的完善，强烈建议大家将容器加入自定义的 Docker 网络来连接多个容器，而不是使用 --link 参数。

下面先创建一个新的 Docker 网络。

```shell
$ docker network create -d bridge my-net
```

`-d`参数指定 Docker 网络类型，有 `bridge overlay`。其中 overlay 网络类型用于 Swarm mode，在本小节中你可以忽略它。

运行一个容器并连接到新建的 my-net 网络

```shell
$ docker run -it --rm --name busybox1 --network my-net busybox sh
```

打开新的终端，再运行一个容器并加入到 my-net 网络

```shell
$ docker run -it --rm --name busybox2 --network my-net busybox sh
```

再打开一个新的终端查看容器信息

```shell
docker container ls
```







## Host 模式

## Container 模式

## None模式



# DOCKER 三架马车

# 8. Docker Compose

`Docker Compose`是`Docker`官方编排（Orchestration）项目之一

## 安装与卸载

```shell
$ docker-compose --version
docker-compose version 1.17.1, build 6d101fb
```

### 二进制安装

```shell
$ sudo curl -L https://github.com/docker/compose/releases/download/1.17.1/docker-compose-`uname -s`-`uname -m` > /usr/local/bin/docker-compose
$ sudo chmod +x /usr/local/bin/docker-compose
```

### PIP 安装

```shell
sudo pip install -U docker-compose
```

### 卸载

1.二进制

```shell
 sudo rm /usr/local/bin/docker-compose
```

2. pip

```shell
sudo pip uninstall docker-compose
```



## 使用

app.py

```python
import time
import redis
from flask import Flask

app = Flask(__name__)
cache = redis.Redis(host='redis', port=6379)

def get_hit_count():
    retries = 5
    while True:
        try:
            return cache.incr('hits')
        except redis.exceptions.ConnectionError as exc:
            if retries == 0:
                raise exc
            retries -= 1
            time.sleep(0.5)

@app.route('/')
def hello():
    count = get_hit_count()
    return 'Hello World! I have been seen {} times.\n'.format(count)

if __name__ == "__main__":
    app.run(host="0.0.0.0", debug=True)
```



Dockerfile

```docker
FROM python:3.6-alpine
ADD . /code
WORKDIR /code
RUN pip install redis flask
CMD ["python", "app.py"]
```

Dockerfile命令

### CMD 命令 交互式

### EXPOSE 指令用于指定容器将要监听的端口

### ENV 环境变量

### ADD 和 COPY

### ENTRYPOINT

`ENTRYPOINT`的最佳用处是设置镜像的主命令，允许将镜像当成命令本身来运行（用 CMD 提供默认选项）。

例如，下面的示例镜像提供了命令行工具 s3cmd:

```docker
ENTRYPOINT ["s3cmd"]
CMD ["--help"]
```

`ENTRYPOINT`的最佳用处是设置镜像的主命令，允许将镜像当成命令本身来运行（用 CMD 提供默认选项）。

例如，下面的示例镜像提供了命令行工具 s3cmd:

```docker
ENTRYPOINT ["s3cmd"]
CMD ["--help"]
```

### USER

如果某个服务不需要特权执行，建议使用 USER 指令切换到非 root 用户。先在 Dockerfile 中使用类似 RUN groupadd -r postgres && useradd -r -g postgres postgres 的指令创建用户和用户组。

### WORKDIR







docker-compose.yml

```yaml
version: '3'
services:
  web:    
  build: .    
  ports:    
  - "5000:5000"
  volumes:
       - .:/code
  redis:    
  image: "redis:alpine"
```



```shell
$ docker-compose up
```

### Compose 命令

docker-compose 命令的基本的使用格式是:

```shell
docker-compose [-f=<arg>...] [options] [COMMAND] [ARGS...]
```

命令选项：

- -f, --file FILE 指定使用的 Compose 模板文件，默认为 docker-compose.yml，可以多次指定。
- -p, --project-name NAME 指定项目名称，默认将使用所在目录名称作为项目名。
- --x-networking 使用 Docker 的可拔插网络后端特性
- --x-network-driver DRIVER 指定网络后端的驱动，默认为 bridge
- --verbose 输出更多调试信息。
- -v, --version 打印版本并退出。

```shell
 docker-compose run ubuntu ping docker.com
```

```shell
$ docker-compose run --no-deps web python manage.py shell
```



# 9. Docker Machine



## 安装

docker-machine -v



# 10. Docker Swarm

`docker machine`来充当集群的主机



# 13. Dockerfile 最佳实践





# 14. Kubernetes 初体验

# 15. 基本概念与组件

- Master：Master 节点是 Kubernetes 集群的控制节点，负责整个集群的管理和控制。Master 节点上包含以下组件：

- kube-apiserver：集群控制的入口，提供 HTTP REST 服务

- kube-controller-manager：Kubernetes 集群中所有资源对象的自动化控制中心

- kube-scheduler：负责 Pod 的调度

- Node：Node 节点是 Kubernetes 集群中的工作节点，Node 上的工作负载由 Master 节点分配，工作负载主要是运行容器应用。Node 节点上包含以下组件：

  - kubelet：负责 Pod 的创建、启动、监控、重启、销毁等工作，同时与 Master 节点协作，实现集群管理的基本功能。
  - kube-proxy：实现 Kubernetes Service 的通信和负载均衡
  - 运行容器化(Pod)应用

- Pod: Pod 是 Kubernetes 最基本的部署调度单元。每个 Pod 可以由一个或多个业务容器和一个根容器(Pause 容器)组成。一个 Pod 表示某个应用的一个实例

- ReplicaSet：是 Pod 副本的抽象，用于解决 Pod 的扩容和伸缩

- Deployment：Deployment 表示部署，在内部使用ReplicaSet 来实现。可以通过 Deployment 来生成相应的 ReplicaSet 完成 Pod 副本的创建

- Service：Service 是 Kubernetes 最重要的资源对象。Kubernetes 中的 Service 对象可以对应微服务架构中的微服务。Service 定义了服务的访问入口，服务的调用者通过这个地址访问 Service 后端的 Pod 副本实例。Service 通过 Label Selector 同后端的 Pod 副本建立关系，Deployment 保证后端Pod 副本的数量，也就是保证服务的伸缩性。

- ![k8s basic](https://www.k8stech.net/k8s-book/docs/images/k8s-basic.png)

  Kubernetes 主要由以下几个核心组件组成:

  - etcd 保存了整个集群的状态，就是一个数据库；
  - apiserver 提供了资源操作的唯一入口，并提供认证、授权、访问控制、API 注册和发现等机制；
  - controller manager 负责维护集群的状态，比如故障检测、自动扩展、滚动更新等；
  - scheduler 负责资源的调度，按照预定的调度策略将 Pod 调度到相应的机器上；
  - kubelet 负责维护容器的生命周期，同时也负责 Volume（CSI）和网络（CNI）的管理；
  - Container runtime 负责镜像管理以及 Pod 和容器的真正运行（CRI）；
  - kube-proxy 负责为 Service 提供 cluster 内部的服务发现和负载均衡；

  当然了除了上面的这些核心组件，还有一些推荐的插件：

  - kube-dns 负责为整个集群提供 DNS 服务
  - Ingress Controller 为服务提供外网入口
  - Heapster 提供资源监控
  - Dashboard 提供 GUI

## 组件通信



# 16. 用 kubeadm 搭建集群环境

## 架构

# 深入理解 POD

# 18. YAML 文件

```
{

   "apiVersion": "v1",

   "kind": "Pod",

   "metdata": {

​    "name": "kube100-site"

​    "labels": {

​     "app": "web"

​    }

   },

   "spec": {

​    "containers": [{

​       "name": "front-end",

​       "image": "nginx",

​       "ports": [{

​         "containerPort": 80

​       }]

​     },{

​       "name": "flaskapp-demo",

​       "image": "jcdemo/flaskapp",

​       "ports": [{

​         "containerPort": 5000

​       }]

​    }]

   }

} 
```



### 使用 YAML 创建 Pod



# 静态 Pod

---
```
apiVersion: apps/v1
kind: Deployment
metadata:
  name: kube100-site
spec:
  replicas: 2
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx
        ports:
        - containerPort: 80
```









































































































































































































