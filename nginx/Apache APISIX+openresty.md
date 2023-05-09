# APISIX云原生网关-APISIX安装



# 1.安装依赖

```
yum install -y curl git gcc glibc gcc-c++ openssl-devel pcre-devel yum-utils unzip
```



# 2.Centos中安装OpenResty、Openssl

```shell
#centos
参考文档：https://openresty.org/cn/linux-packages.html

wget https://openresty.org/package/centos/openresty.repo

mv openresty.repo /etc/yum.repos.d/

yum install -y openresty  openresty-openssl111-devel 安装软件包

yum install -y openresty-resty 安装命令行工具 resty
```



# 3.Centos中安装Nginx

```shell
vim /etc/yum.repos.d/nginx.repo
[nginx-stable]
name=nginx stable repo
baseurl=http://nginx.org/packages/centos/$releasever/$basearch/
gpgcheck=1
enabled=1
gpgkey=https://nginx.org/keys/nginx_signing.key
module_hotfixes=true

[nginx-mainline]
name=nginx mainline repo
baseurl=http://nginx.org/packages/mainline/centos/$releasever/$basearch/
gpgcheck=1
enabled=0
gpgkey=https://nginx.org/keys/nginx_signing.key
module_hotfixes=true

yum install nginx -y
```



# 4.安装 ETCD



```shell
#etcd是用来干嘛的
etcd是一个高可用的分布式键值存储系统，它可以用来存储APISIX的配置信息，包括路由信息、服务信息等。APISIX通过etcd来存储和管理配置，从而实现了配置的高可用和可扩展。

APISIX将配置数据以键值对的形式存储在etcd中，并通过etcd的Watcher机制来监听配置的变化，当配置发生变化时，APISIX能够及时地感知到这种变化，并对其进行相应的处理。

总之，etcd在APISIX中起到了配置管理和数据存储的重要作用，是APISIX提供高可用和高可靠的API网关服务的关键组成部分。
所以我们要安装etcd
```



```
#下载二进制
wget https://github.com/etcd-io/etcd/releases/download/v3.4.18/etcd-v3.4.18-linux-amd64.tar.gz
tar xf etcd-v3.4.13-linux-amd64.tar.gz
cd etcd-v3.4.13-linux-amd64
cp etcd* /usr/local/bin
mkdir -p ./{conf,data,log}
```



```shell
/usr/local/etcd/conf/etcd.conf
#[Member]
#ETCD_CORS=""
ETCD_DATA_DIR="/usr/local/etcd/data"
#ETCD_WAL_DIR=""
ETCD_LISTEN_PEER_URLS="http://192.168.4.60:2380"
ETCD_LISTEN_CLIENT_URLS="http://192.168.4.60:2379"
#ETCD_MAX_SNAPSHOTS="5"
#ETCD_MAX_WALS="5"
ETCD_NAME="node1"
#ETCD_SNAPSHOT_COUNT="100000"
#ETCD_HEARTBEAT_INTERVAL="100"
#ETCD_ELECTION_TIMEOUT="1000"
#ETCD_QUOTA_BACKEND_BYTES="0"
#ETCD_MAX_REQUEST_BYTES="1572864"
#ETCD_GRPC_KEEPALIVE_MIN_TIME="5s"
#ETCD_GRPC_KEEPALIVE_INTERVAL="2h0m0s"
#ETCD_GRPC_KEEPALIVE_TIMEOUT="20s"


#[Clustering]
ETCD_INITIAL_ADVERTISE_PEER_URLS="http://192.168.4.60:2380"
ETCD_ADVERTISE_CLIENT_URLS="http://192.168.4.60:2379"
#ETCD_DISCOVERY=""
#ETCD_DISCOVERY_FALLBACK="proxy"
#ETCD_DISCOVERY_PROXY=""
#ETCD_DISCOVERY_SRV=""
ETCD_INITIAL_CLUSTER="node1=http://192.168.4.60:2380"
#ETCD_INITIAL_CLUSTER_TOKEN="etcd-cluster"
#ETCD_INITIAL_CLUSTER_STATE="new"
#ETCD_STRICT_RECONFIG_CHECK="true"
#ETCD_ENABLE_V2="true"
#
#[Proxy]
#ETCD_PROXY="off"
#ETCD_PROXY_FAILURE_WAIT="5000"
#ETCD_PROXY_REFRESH_INTERVAL="30000"
#ETCD_PROXY_DIAL_TIMEOUT="1000"
#ETCD_PROXY_WRITE_TIMEOUT="5000"
#ETCD_PROXY_READ_TIMEOUT="0"
#
#[Security]
#ETCD_CERT_FILE=""
#ETCD_KEY_FILE=""
#ETCD_CLIENT_CERT_AUTH="false"
#ETCD_TRUSTED_CA_FILE=""
#ETCD_AUTO_TLS="false"
#ETCD_PEER_CERT_FILE=""
#ETCD_PEER_KEY_FILE=""
#ETCD_PEER_CLIENT_CERT_AUTH="false"
#ETCD_PEER_TRUSTED_CA_FILE=""
#ETCD_PEER_AUTO_TLS="false"
#
#[Logging]
#ETCD_DEBUG="false"
#ETCD_LOG_PACKAGE_LEVELS=""
#ETCD_LOG_OUTPUT="default"
#
#[Unsafe]
#ETCD_FORCE_NEW_CLUSTER="false"
#
#[Version]
#ETCD_VERSION="false"
#ETCD_AUTO_COMPACTION_RETENTION="0"
#
#[Profiling]
#ETCD_ENABLE_PPROF="false"
#ETCD_METRICS="basic"
#
#[Auth]
#ETCD_AUTH_TOKEN="simple"
```



## 4.1配置日志

```
/etc/rsyslog.d/etcd.conf

if $programname == 'etcd' then /data/etcd/log/etcd.log
& stop

#重启
systemctl restart rsyslog.service 


#配置logrotate
/home/work/etcd/log/*.log {
        # 切割周期为天
        daily
        # 最多保留10个文件
        rotate 10
        # 切割后的文件名添加日期后缀
        dateext
        # 日期格式
        dateformat -%Y%m%d
        # 切割后文件的后缀
        extension log
        # 如果日志文件不存在，不报错
        missingok
        # 日志文件大小为50M，超过50M后进行切割
        size 50M
        compress
        delaycompress
        notifempty
        # 文件权限，user，group
        create 0644 work work
        sharedscripts
        # 切割后执行的命令，让etcd重新加载配置
        postrotate
            /usr/bin/killall -HUP etcd
        endscript
}
```



## 4.2 注册systemd

```
/usr/lib/systemd/system/etcd.service

[Unit]
Description=Etcd Server
After=network.target
After=network-online.target
Wants=network-online.target

[Service]
Type=notify
WorkingDirectory=/usr/local/etcd
EnvironmentFile=/usr/local/etcd/conf/etcd.conf

# set GOMAXPROCS to number of processors
ExecStart=/bin/bash -c "GOMAXPROCS=$(nproc) /usr/local/bin/etcd"

Restart=on-failure
LimitNOFILE=65536
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=etcd # without any quote

[Install]
WantedBy=multi-user.target
```



## 4.3安装 LuaRocks

```
在APISIX中，LuaRocks扮演着包管理器的角色。它提供了一种方便的方式来管理 APISIX 的依赖关系，并使开发人员更容易管理和维护他们的安装。借助 LuaRocks，开发人员可以轻松安装、删除和管理 APISIX 所需的软件包，例如用于编码/解码 JSON 的库、处理 HTTP 请求等。这有助于确保每个人都使用相同的、经过测试的依赖项版本，并更轻松地分发和共享 APISIX 的自定义插件或模块。通过使用LuaRocks，开发人员可以花更少的时间管理依赖关系，而将更多的时间用于APISIX项目的实际开发。
```



```
curl https://raw.githubusercontent.com/apache/apisix/master/utils/linux-install-luarocks.sh -sL | bash -
```



# 5.部署apisix

## 5.1安装

```
wget https://github.com/apache/apisix/releases/download/2.10.0/apisix-2.10.0-0.el7.x86_64.rpm
rpm -Uvh apisix-2.10.0-0.el7.x86_64.rpm

```



## 5.2配置

### 配置etcd地址

```
/usr/local/apisix/conf/config.yaml
```



```shell
#
# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# If you want to set the specified configuration value, you can set the new
# in this file. For example if you want to specify the etcd address:
#
etcd:
    host:
      - "http://192.168.3.224:2379"

# To configure via environment variables, you can use `${{VAR}}` syntax. For instance:
#
# etcd:
#     host:
#       - "http://${{ETCD_HOST}}:2379"
#
# And then run `export ETCD_HOST=$your_host` before `make init`.
#
# If the configured environment variable can't be found, an error will be thrown.
apisix:
  admin_key:
    - name: "admin"
      key: edd1c9f034335f136f87ad84b625c8f1  # using fixed API token has security risk, please update it when you deploy to production environment
      role: admin
```



###  修改 apisix内置 nginx.conf

文件路径: `/data/applications/apisix/conf/nginx.conf`，目的在于开放外部访问限制，生产环境不推荐

```shell
sed -i '/deny/d' /data/applications/apisix/conf/nginx.conf && \
sed -i '/allow/d' /data/applications/apisix/conf/nginx.conf 
```

#### 

### 修改启动服务

文件路径: `/data/applications/apisix/apisix/cli/ops.lua`， 取消 `reload` 方法中的`init`（初始化 nginx.conf）



```lua
local function reload(env)
    -- reinit nginx.conf
    -- init(env) 注释掉该行

    local test_cmd = env.openresty_args .. [[ -t -q ]]
    -- When success,
    -- On linux, os.execute returns 0,
    -- On macos, os.execute returns 3 values: true, exit, 0, and we need the first.
    local test_ret = execute((test_cmd))
    if (test_ret == 0 or test_ret == true) then
        local cmd = env.openresty_args .. [[ -s reload]]
        execute(cmd)
        return
    end

    print("test openresty failed")
end
```





### 启动

1. 修改systemd

文件路径: `/usr/lib/systemd/system/apisix.service`，增加 `Restart` 选项



```shell
[Unit]
Description=apisix
Conflicts=apisix.service
After=network-online.target

[Service]
Type=forking
WorkingDirectory=/usr/local/apisix
ExecStart=/usr/bin/apisix start
ExecStop=/usr/bin/apisix stop
ExecReload=/usr/bin/apisix reload
Restart=always
```





2. 启动服务



```shell
systemctl daemon-reload && \
systemctl enable apisix.service && \
systemctl start apisix.service
```





### 验证

1. get请求调用 restful_api

鉴权key位于文件`/data/applications/apisix/conf/config.yaml`中，`apisix`  ==> `admin_key`



```shell
curl -s "http://127.0.0.1:9080/apisix/admin/services/" -H 'X-API-KEY: edd1c9f034335f136f87ad84b625c8f1' | jq .

```

正常返回如下:



```json
{
  "count":"1",
  "action":"get",
  "node":{
    "key":"/apisix/services",
    "nodes":{},
    "dir":true
  }
}
```







# 6.apisix dashboard

```
wget https://github.com/apache/apisix-dashboard/releases/download/v2.8/apisix-dashboard-2.8.0-0.el7.x86_64.rpm
rpm -Uvh apisix-dashboard-2.8.0-0.el7.x86_64.rpm
yum install apisix-dashboard-2.8.0-0.el7.x86_64.rpm -y
```

## 6.1. 安装

使用yum安装，默认安装路径在`/usr/local/apisix/dashboard`



```shell
yum localinstall -y apisix-dashboard-2.7-0.x86_64.rpm 

firewall-cmd --zone=public --add-port=9000/tcp --permanent
```





## 6.2 配置

1. 修改 allow_list 和 etcd 配置



etcd

- allow_list 添加 `0.0.0.0/0` （白名单，按需添加）
- etcd 修改 `192.168.46.60:2379`

```
/usr/local/apisix/dashboard/conf/conf.yaml
```



```shell
#
# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

# yamllint disable rule:comments-indentation
conf:
  listen:
    # host: 127.0.0.1     # the address on which the `Manager API` should listen.
                          # The default value is 0.0.0.0, if want to specify, please enable it.
                          # This value accepts IPv4, IPv6, and hostname.
    port: 9000            # The port on which the `Manager API` should listen.

  # ssl:
  #   host: 127.0.0.1     # the address on which the `Manager API` should listen for HTTPS.
                          # The default value is 0.0.0.0, if want to specify, please enable it.
  #   port: 9001            # The port on which the `Manager API` should listen for HTTPS.
  #   cert: "/tmp/cert/example.crt" # Path of your SSL cert.
  #   key:  "/tmp/cert/example.key"  # Path of your SSL key.

  allow_list:             # If we don't set any IP list, then any IP access is allowed by default.
    - 127.0.0.1           # The rules are checked in sequence until the first match is found.
    - 0.0.0.0/0
    - ::1                 # In this example, access is allowed only for IPv4 network 127.0.0.1, and for IPv6 network ::1.
                          # It also support CIDR like 192.168.1.0/24 and 2001:0db8::/32
  etcd:
    endpoints:            # supports defining multiple etcd host addresses for an etcd cluster
      - 192.168.3.224:2379
                          # yamllint disable rule:comments-indentation
                          # etcd basic auth info
    # username: "root"    # ignore etcd username if not enable etcd auth
    # password: "123456"  # ignore etcd password if not enable etcd auth
    mtls:
      key_file: ""          # Path of your self-signed client side key
      cert_file: ""         # Path of your self-signed client side cert
      ca_file: ""           # Path of your self-signed ca cert, the CA is used to sign callers' certificates
    # prefix: /apisix       # apisix config's prefix in etcd, /apisix by default
  log:
    error_log:
      level: warn       # supports levels, lower to higher: debug, info, warn, error, panic, fatal
      file_path:
        logs/error.log  # supports relative path, absolute path, standard output
                        # such as: logs/error.log, /tmp/logs/error.log, /dev/stdout, /dev/stderr
    access_log:
      file_path:
        logs/access.log  # supports relative path, absolute path, standard output
                         # such as: logs/access.log, /tmp/logs/access.log, /dev/stdout, /dev/stderr
                         # log example: 2020-12-09T16:38:09.039+0800    INFO    filter/logging.go:46    /apisix/admin/routes/r1 {"status": 401, "host": "127.0.0.1:9000", "query": "asdfsafd=adf&a=a", "requestId": "3d50ecb8-758c-46d1-af5b-cd9d1c820156", "latency": 0, "remoteIP": "127.0.0.1", "method": "PUT", "errs": []}
  max_cpu: 0             # supports tweaking with the number of OS threads are going to be used for parallelism. Default value: 0 [will use max number of available cpu cores considering hyperthreading (if any)]. If the value is negative, is will not touch the existing parallelism profile.

authentication:
  secret:
    secret              # secret for jwt token generation.
                        # NOTE: Highly recommended to modify this value to protect `manager api`.
                        # if it's default value, when `manager api` start, it will generate a random string to replace it.
  expire_time: 3600     # jwt token expire time, in second
  users:                # yamllint enable rule:comments-indentation
    - username: admin   # username and password for login `manager api`
      password: admin
    - username: user
      password: user

plugins:                          # plugin list (sorted in alphabetical order)
  - api-breaker
  - authz-keycloak
  - basic-auth
  - batch-requests
  - consumer-restriction
  - cors
  # - dubbo-proxy
  - echo
  # - error-log-logger
  # - example-plugin
  - fault-injection
  - grpc-transcode
  - hmac-auth
  - http-logger
  - ip-restriction
  - jwt-auth
  - kafka-logger
  - key-auth
  - limit-conn
  - limit-count
  - limit-req
  # - log-rotate
  # - node-status
  - openid-connect
  - prometheus
  - proxy-cache
  - proxy-mirror
  - proxy-rewrite
  - redirect
  - referer-restriction
  - request-id
  - request-validation
  - response-rewrite
  - serverless-post-function
  - serverless-pre-function
  # - skywalking
  - sls-logger
  - syslog
  - tcp-logger
  - udp-logger
  - uri-blocker
  - wolf-rbac
  - zipkin
  - server-info
  - traffic-split
```

## 6.3 启动

### 注册systemd

文件路径: `/usr/lib/systemd/system/apisix-dashboard.service`, 新增文件，编译以下内容



```shell
[Unit]
Description=apisix dashboard
After=network-online.target
After=apisix.service
Wants=apisix.service

[Service]
Type=forking
WorkingDirectory=/usr/local/apisix/dashboard

ExecStart=/bin/bash -c "/usr/bin/manager-api start -p /usr/local/apisix/dashboard/"
ExecStop=/usr/bin/manager-api stop
Restart=always
```

###  启动服务



```shell
systemctl daemon-reload && \
systemctl enable apisix-dashboard.service && \
systemctl start apisix-dashboard.service 
```

### 验证

访问: [http://192.168.3.224:9000](https://links.jianshu.com/go?to=http%3A%2F%2F192.168.3.224%3A9000)，默认用户名密码都是`admin` ，可在配置文件 `/data/applications/apisix/dashboard/conf/conf.yaml` 中定义，`authentication` ==> `users`

![image-20230209151022023](C:\Users\Administrator\Desktop\md文件\images\image-20230209151022023.png)





# 7.关于端口说明

```shell
在当前所有配置的apisix目录下的的config.yaml以及config-default.yaml都是默认的，在admin/http/https的配置都是默认走的是9080端口，
当前需要把所有端口拆分。

[root@hadoop1 conf]# ls
apisix.uid  cert  config-default.yaml  config.yaml  debug.yaml  mime.types  nginx.conf


##config-default.yaml
admin/http：9080端口
https: 9443端口



```

# 8.增加自签名证书

```
mkdir ca
cd ca
openssl genrsa -out ./CA.key 4096
openssl req -x509 -new -key ./CA.key -out ./CA.cer -days 3650 -subj /CN="LingFang"
mkdir apisix.test.lan
openssl genrsa -out ./apisix.test.lan/apisix.test.lan.pem 4096
openssl req -new -key ./apisix.test.lan/test.lan.pem -out ./apisix.test.lan/apisix.test.lan.csr -days 365
openssl x509 -days 365 -req -in ./apisix.test.lan/apisix.test.lan.csr -extensions v3_req -CAkey ./CA.key -CA ./CA.cer -CAcreateserial -out ./apisix.test.lan/apisix.test.lan.crt
```













## 

# 

# APISIX官网安装

# 192.168.46.70

## 安装 APISIX



### 通过 RPM 仓库安装

如果当前系统**没有安装 OpenResty**，请使用以下命令来安装 OpenResty 和 APISIX 仓库：

```shell
sudo yum install -y https://repos.apiseven.com/packages/centos/apache-apisix-repo-1.0-1.noarch.rpm
```

完成上述操作后使用以下命令安装 APISIX：

```shell
sudo yum install apisix
```



### 管理 APISIX 服务

APISIX 安装完成后，你可以运行以下命令初始化 NGINX 配置文件和 etcd：

```shell
apisix init
```

Copy

使用以下命令启动 APISIX：

```shell
apisix start
```



## 安装 etcd3.5.4

APISIX 使用 [etcd](https://github.com/etcd-io/etcd) 作为配置中心进行保存和同步配置。在安装 APISIX 之前，需要在你的主机上安装 etcd。

如果你在安装 APISIX 时选择了 Docker 或 Helm 安装，那么 etcd 将会自动安装；如果你选择其他方法或者需要手动安装 APISIX，请参考以下步骤安装 etcd：

### linux安装etcd

```
ETCD_VERSION='3.5.4'
wget https://github.com/etcd-io/etcd/releases/download/v${ETCD_VERSION}/etcd-v${ETCD_VERSION}-linux-amd64.tar.gz
tar -xvf etcd-v${ETCD_VERSION}-linux-amd64.tar.gz && \
  cd etcd-v${ETCD_VERSION}-linux-amd64 && \
  sudo cp -a etcd etcdctl /usr/bin/
nohup etcd >/tmp/etcd.log 2>&1 &
```



### 关于etcd3.5.4

```
https://blog.csdn.net/Keyuchen_01/article/details/126609033
```





## 后续操作

### 配置 APISIX

通过修改本地 `./conf/config.yaml` 文件，或者在启动 APISIX 时使用 `-c` 或 `--config` 添加文件路径参数 `apisix start -c <path string>`，完成对 APISIX 服务本身的基本配置。

比如将 APISIX 默认监听端口修改为 8000，其他配置保持默认，在 `./conf/config.yaml` 中只需这样配置：

“./conf/config.yaml”

```yaml
apisix:
  node_listen: 8000 # APISIX listening port
```

Copy

比如指定 APISIX 默认监听端口为 8000，并且设置 etcd 地址为 `http://foo:2379`，其他配置保持默认。在 `./conf/config.yaml` 中只需这样配置：

“./conf/config.yaml”

```yaml
apisix:
  node_listen: 8000 # APISIX listening port

deployment:
  role: traditional
  role_traditional:
    config_provider: etcd
  etcd:
    host:
      - "http://foo:2379"
```



##### WARNING

APISIX 的默认配置可以在 `./conf/config-default.yaml` 文件中看到，该文件与 APISIX 源码强绑定，请不要手动修改 `./conf/config-default.yaml` 文件。如果需要自定义任何配置，都应在 `./conf/config.yaml` 文件中完成。

##### WARNING

请不要手动修改 APISIX 安装目录下的 `./conf/nginx.conf` 文件。当 APISIX 启动时，会根据 `config.yaml` 的配置自动生成新的 `nginx.conf` 并自动启动服务。

### 更新 Admin API key[#](https://apisix.apache.org/zh/docs/apisix/installation-guide/#更新-admin-api-key)

建议修改 Admin API 的 key，保护 APISIX 的安全。

请参考如下信息更新配置文件：

./conf/config.yaml

```yaml
deployment:
  admin:
    admin_key
      -
        name: "admin"
        key: newsupersecurekey  # 请修改 key 的值
        role: admin
```

Copy

更新完成后，你可以使用新的 key 访问 Admin API：

```shell
curl http://127.0.0.1:9180/apisix/admin/routes?api_key=newsupersecurekey -i
```

Copy

### 为 APISIX 添加 systemd 配置文件[#](https://apisix.apache.org/zh/docs/apisix/installation-guide/#为-apisix-添加-systemd-配置文件)

如果你是通过 RPM 包安装 APISIX，配置文件已经自动安装，你可以直接使用以下命令：

```shell
systemctl start apisix
systemctl stop apisix
```

Copy

如果你是通过其他方法安装的 APISIX，可以参考[配置文件模板](https://github.com/api7/apisix-build-tools/blob/master/usr/lib/systemd/system/apisix.service)进行修改，并将其添加在 `/usr/lib/systemd/system/apisix.service` 路径下。





















# 延伸：

# 什么是etcd？

## 1.1 介绍

`etcd` 是使用Go语言开发的一个开源的、高可用的分布式key-value存储系统，可以用于配置共享和服务的注册和发现。



## 1.2 etcd特点

etcd 具有以下特点：

```
完全复制：集群中的每个节点都可以使用完整的存档
高可用性：Etcd可用于避免硬件的单点故障或网络问题
一致性：每次读取都会返回跨多主机的最新写入
简单：包括一个定义良好、面向用户的API（gRPC）
安全：实现了带有可选的客户端证书身份验证的自动化TLS
快速：每秒10000次写入的基准速度
可靠：使用Raft算法实现了强一致、高可用的服务存储目录
```







以下是在Linux中安装APISIX的步骤：

1. 安装OpenResty和APISIX依赖项

   - 在终端中执行以下命令安装OpenResty和APISIX依赖项：

     ```
     sudo apt-get update
     sudo apt-get install -y build-essential git curl perl openssl libssl-dev zlib1g-dev libpcre3-dev unzip
     ```

2. 下载APISIX源代码

   - 在终端中执行以下命令下载APISIX源代码：

     ```
     git clone <https://github.com/apache/apisix.git>
     ```

3. 安装APISIX

   - 在终端中进入APISIX源代码目录，并执行以下命令安装APISIX：

     ```
     cd apisix
     sudo make install
     ```

4. 启动APISIX

   - 在终端中执行以下命令启动APISIX服务：

     ```
     sudo /usr/local/apisix/bin/apisix start
     ```

   - 您可以在浏览器中访问`http://localhost:9080/`，即可看到APISIX的欢迎页面。

希望这些步骤能够帮助您成功地在Linux中安装APISIX。如果您遇到了任何问题，请查看[官方文档](https://github.com/apache/apisix/blob/master/README_CN.md)，或在社区中寻求帮助。

另外，如果您需要更高级的功能和更好的性能，可以考虑使用APISIX的企业版，它提供了更多的功能和服务，如：

- API 安全认证
- 流量控制和限速
- 响应缓存和负载均衡
- DNS 解析和服务发现
- 集成 Prometheus 和 Grafana 进行监控和报警

您可以在[这里](https://www.apache.org/dyn/closer.cgi?path=apisix/enterprise/)下载企业版APISIX的二进制包，并根据官方文档进行安装和配置。

无论是开源版还是企业版，APISIX都是一个强大的 API 网关，它具有灵活的插件体系、高性能和易于使用的特点，适合于构建各种类型的 API 和微服务。希望您能够善加利用它，为您的业务带来更好的价值和体验。





# config.yaml配置

将开发环境上的nginx.conf迁移到apisix的默认config.yaml中。定义全局。

```

```





自定义一个apisix日志格式

```
API Gateway APIsix 允许用户通过插件自定义日志格式。以下是创建自定义日志格式插件的步骤：

创建一个名为 'log
在 '日志格式
lua
Copy code
local cjson = require("cjson")
local ngx = ngx
local type = type

local _M = {}

function _M.log(config)
    local log_data = {
        request_time = ngx.now(),
        request_method = ngx.req.get_method(),
        request_uri = ngx.var.uri,
        request_host = ngx.var.host,
        request_headers = ngx.req.get_headers(),
        request_body = ngx.req.get_body_data(),
        response_status = ngx.status,
        response_headers = ngx.resp.get_headers(),
        response_body = ngx.var.response_body,
    }

    ngx.log(config.log_level, cjson.encode(log_data))
end

return _M
在上述代码中，'config

在log-format文件夹中创建一个名为 'schema.luaschema.lua的文件，该文件包含您的插件配置模式。例如，以下代码定义了一个名为log_format的字符串字段，该字段定义了您的自定义日志格式：
.lua
Copy code
return {
    fields = {
        log_format = {type = "string", default = "default_log_format"},
    }
}
在上述代码中，'log

在log-format文件夹中创建一个名为 'configconfig.yaml的文件，该文件包含您的插件配置。例如，以下代码定义了一个名为my_log_format的插件配置：
亚姆
Copy code
name: log-format
config:
  log_format: my_log_format
在上述代码中，'log_format

将 'log-format
shell
Copy code
tar -czf log-format-0.1-1.rockspec log-format
luarocks build log-format-0.1-1.rockspec
将 LuaRocks 模块安装到 APIsix 中。例如，运行以下命令：
shell
Copy code
luarocks install log-format-0.1-1.rockspec
在 APIsix 的配置文件中启用您的插件。例如，以下代码将 log-format 插件添加到 APIsix 的全局插件列表中：
亚姆
Copy code
plugins:
  - log-format
现在，您可以在 APIsix 中使用 my_log_format 自定义日志格式了。
```





# 1.需求1

PS：将nginx.conf/conf.d迁移到apisix

1.在config-default.yaml不变的情况下，增加server，修改config.yaml

如：

```
nginx_config:

    http_configuration_snippet: |
     server {
         listen 8086 ;
         #server_name 127.0.0.1 ;
     location / {
          root  /data/projects/dev-pje/statis_web ;
          index  index.html ;
     }

      location /prod-api {
        add_header Access-Control-Allow-Origin *;
        add_header 'Access-Control-Allow-Credentials' 'true';
        add_header 'Access-Control-Allow-Methods' 'GET, POST, OPTIONS';
        add_header 'Access-Control-Allow-Headers' 'DNT,web-token,app-token,Authorization,Accept,Origin,Keep-Alive,User-Agent,X-Mx-ReqToken,X-Data-Type,X-Auth-Token,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Range';
        add_header 'Access-Control-Expose-Headers' 'Content-Length,Content-Range';

        if ($request_method = 'OPTIONS') {
                add_header 'Access-Control-Max-Age' 1728000;
                add_header 'Content-Type' 'text/plain; charset=utf-8';
                add_header 'Content-Length' 0;
                return 204;
        }

        proxy_pass    http://127.0.0.1:8081/ ;
        proxy_set_header Host $host:$server_port;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
     }

```

chatGPT

```
# 定义全局配置
node_listen:
  - 0.0.0.0:9080
http:
  # 定义路由和插件
  server:
    # 定义监听端口和协议
    - port: 8086
      protocol: http
      # 定义location
      location:
        - uri: /
          type: file
          # 指定静态文件目录和文件
          file_path: /data/projects/dev-pje/statis_web
          index_files:
            - index.html
        - uri: /prod-api
          type: reverse-proxy
          # 定义反向代理到的地址
          upstream_url: http://127.0.0.1:8081
          # 定义访问控制头
          header:
            Access-Control-Allow-Origin: "*"
            Access-Control-Allow-Credentials: "true"
            Access-Control-Allow-Methods: "GET, POST, OPTIONS"
            Access-Control-Allow-Headers: "DNT,web-token,app-token,Authorization,Accept,Origin,Keep-Alive,User-Agent,X-Mx-ReqToken,X-Data-Type,X-Auth-Token,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Range"
            Access-Control-Expose-Headers: "Content-Length,Content-Range"
          # 定义OPTIONS方法
          methods:
            - GET
            - POST
            - OPTIONS
          options:
            - name: access_control_max_age
              value: "1728000"
            - name: content_type
              value: "text/plain; charset=UTF-8"
            - name: content_length
              value: "0"
          # 定义代理相关头
          proxy_header:
            Host: "$host:$server_port"
            X-Real-IP: "$remote_addr"
            X-Forwarded-For: "$proxy_add_x_forwarded_for"

```



# 2.需求2

pje后端日志

```

```





# 3.需求3

log_formatt







# 开发环境配置

# 1.config.yaml





# 2.config-default.yaml
