# Prometheus 

​		Prometheus(由go语言(golang)开发)是一套开源的监控&报警&时间序列数据库的组合。适合监控docker容器。因为kubernetes(俗称k8s)的流行带动 了prometheus的发展。 

其优势概括：

​	    易于管理

​		轻易获取服务内部状态

　　高效灵活的查询语句

　　支持本地和远程存储

　　采用http协议，默认pull模式拉取数据，也可以通过中间网关push数据

　　支持自动发现

　　可扩展

　　易集成



## 普罗米修斯原理架构图

![img](prometheus%E7%9A%84%E6%90%AD%E5%BB%BA%E5%8F%8A%E4%BD%BF%E7%94%A8.assets/prometheus1)

##  组件介绍

- **Prometheus Server**: 用于收集和存储时间序列数据。

- **Client Library**: 客户端库，为需要监控的服务生成相应的 metrics 并暴露给 Prometheus server。当 Prometheus server 来 pull 时，直接返回实时状态的 metrics。

- **Push Gateway**: 主要用于短期的 jobs。由于这类 jobs 存在时间较短，可能在 Prometheus 来 pull 之前就消失了。为此，这次 jobs 可以直接向 Prometheus server 端推送它们的 metrics。这种方式主要用于服务层面的 metrics，对于机器层面的 metrices，需要使用 node exporter。

- **Exporters**: 用于暴露已有的第三方服务的 metrics 给 Prometheus。

- **Alertmanager**: 从 Prometheus server 端接收到 alerts 后，会进行去除重复数据，分组，并路由到对收的接受方式，发出报警。常见的接收方式有：电子邮件，pagerduty，OpsGenie, webhook 等。

- 一些其他的工具。

  

  ## 实验环境准备       prometheus+grafana+alertmanager

| 服务器           | IP地址          |
| ---------------- | --------------- |
| Prometneus服务器 | 192.168.116.129 |
| 被监控服务器     | 192.168.116.130 |
| grafana服务器    | 192.168.116.131 |

 

1. 主机名

```
各自配置好主机名 
# hostnamectl set-hostname --static server.cluster.com 
或者
echo master > /etc/hostname
echo node1  > /etc/hostname
echo node2  > /etc/hostname
三台都互相绑定IP与主机名 
# vim /etc/hosts            
192.168.116.129  master
192.168.116.130  node1
192.168.116.131  node2

echo "192.168.116.129 master
192.168.116.130 node1
192.168.116.131 node2">>/etc/hosts
```

2.时间同步(时间同步一定要确认一下)

```
 yum install -y  ntpdate && ntpdate time.windows.com
```

3.关闭防火墙,selinux

```
# systemctl stop firewalld 
# systemctl disable firewalld 
# iptables -F
```

# 1、安装prometheus

从[ https://prometheus.io/download/](https://blog.csdn.net/heian_99/article/details/103952955?utm_medium=distribute.pc_relevant.none-task-blog-BlogCommendFromMachineLearnPai2-1.nonecase&depth_1-utm_source=distribute.pc_relevant.none-task-blog-BlogCommendFromMachineLearnPai2-1.nonecase) 下载相应版本，安装到服务器上
官网提供的是二进制版，解压就能用，不需要编译

上传prometheus-2.5.0.linux-amd64.tar.gz

![img](prometheus%E7%9A%84%E6%90%AD%E5%BB%BA%E5%8F%8A%E4%BD%BF%E7%94%A8.assets/20200113101351305.png)

```
tar -zxvf prometheus-2.5.0.linux-amd64.tar.gz -C /usr/local/
mv /usr/local/prometheus-2.5.0.linux-amd64/  /usr/local/prometheus
```

![img](prometheus%E7%9A%84%E6%90%AD%E5%BB%BA%E5%8F%8A%E4%BD%BF%E7%94%A8.assets/20200113101351306.png)

直接使用默认配置文件启动

```
/usr/local/prometheus/prometheus --config.file="/usr/local/prometheus/prometheus.yml" &
```

确认端口(9090)

```
ss -anltp | grep 9090
```

![img](prometheus%E7%9A%84%E6%90%AD%E5%BB%BA%E5%8F%8A%E4%BD%BF%E7%94%A8.assets/20200113101351307.png)

## ①、prometheus界面

通过浏览器访问http://服务器IP:9090就可以访问到prometheus的主界面

![img](prometheus%E7%9A%84%E6%90%AD%E5%BB%BA%E5%8F%8A%E4%BD%BF%E7%94%A8.assets/20200113101351308.png)

默认只监控了本机一台，点Status -->点Targets -->可以看到只监控了本 机

![](prometheus%E7%9A%84%E6%90%AD%E5%BB%BA%E5%8F%8A%E4%BD%BF%E7%94%A8.assets/20200113101351309.png)



##### 问题：

​	①为了避免时区的混乱，prometheus所有的组件内部都强制使用Unix时间，对外展示使用UTC时间。 如图

![1600238613344](prometheus%E7%9A%84%E6%90%AD%E5%BB%BA%E5%8F%8A%E4%BD%BF%E7%94%A8.assets/1600238613344.png)

​     2.16.0版本已经支持Prometheus Web UI选择本地时区了， 点击Try experimental React UI进去新UI ，如下：

![1600239816667](prometheus%E7%9A%84%E6%90%AD%E5%BB%BA%E5%8F%8A%E4%BD%BF%E7%94%A8.assets/1600239816667.png)

## ②、主机数据展示

通过http://服务器IP:9090/metrics可以查看到监控的数据

![img](prometheus%E7%9A%84%E6%90%AD%E5%BB%BA%E5%8F%8A%E4%BD%BF%E7%94%A8.assets/2020082403)

在web主界面可以通过关键字查询监控项

![img](prometheus%E7%9A%84%E6%90%AD%E5%BB%BA%E5%8F%8A%E4%BD%BF%E7%94%A8.assets/2020082404)

## ③、监控远程Linux主机

① 在远程linux主机(被监控端agent1)上安装node_exporter组件
下载地址: <https://prometheus.io/download/>

上传node_exporter-0.16.0.linux-amd64.tar.gz

![img](prometheus%E7%9A%84%E6%90%AD%E5%BB%BA%E5%8F%8A%E4%BD%BF%E7%94%A8.assets/20200113102232475.png)

```
tar -zxvf node_exporter-0.16.0.linux-amd64.tar.gz -C /usr/local/
mv /usr/local/node_exporter-0.16.0.linux-amd64/ /usr/local/node_exporter
```

里面就一个启动命令node_exporter,可以直接使用此命令启动

```
nohup /usr/local/node_exporter/node_exporter & 
```

![img](prometheus%E7%9A%84%E6%90%AD%E5%BB%BA%E5%8F%8A%E4%BD%BF%E7%94%A8.assets/2020082405)

确认端口(9100)

![img](prometheus%E7%9A%84%E6%90%AD%E5%BB%BA%E5%8F%8A%E4%BD%BF%E7%94%A8.assets/20200113102549361.png)

**扩展: nohup命令: 如果把启动node_exporter的终端给关闭,那么进程也会 随之关闭。nohup命令会帮你解决这个问题。**

 

② 通过浏览器访问http://被监控端IP:9100/metrics就可以查看到 node_exporter在被监控端收集的监控信息

![img](prometheus%E7%9A%84%E6%90%AD%E5%BB%BA%E5%8F%8A%E4%BD%BF%E7%94%A8.assets/2020082406)

③ 回到prometheus服务器的配置文件里添加被监控机器的配置段

在主配置文件最后加上下面三行

```
vim /usr/local/prometheus/prometheus.yml 
```

```
  - job_name: 'node1'
  static_configs:
   - targets: ['192.168.116.130:9100']
```

![img](prometheus%E7%9A%84%E6%90%AD%E5%BB%BA%E5%8F%8A%E4%BD%BF%E7%94%A8.assets/2020082407)

```
- job_name: 'agent1'                   # 取一个job名称来代 表被监控的机器   
  static_configs:   
  - targets: ['10.1.1.14:9100']        # 这里改成被监控机器 的IP，后面端口接9100
```

改完配置文件后,重启服务

```
 pkill prometheus 
```

确认端口没有进程占用

![img](prometheus%E7%9A%84%E6%90%AD%E5%BB%BA%E5%8F%8A%E4%BD%BF%E7%94%A8.assets/2020082408)

```
/usr/local/prometheus/prometheus --config.file="/usr/local/prometheus/prometheus.yml" &
```

 确认端口被占用，说 明重启成功

![img](prometheus%E7%9A%84%E6%90%AD%E5%BB%BA%E5%8F%8A%E4%BD%BF%E7%94%A8.assets/2020082409)

④ 回到web管理界面 -->点Status -->点Targets -->可以看到多了一台监控目标

![img](prometheus%E7%9A%84%E6%90%AD%E5%BB%BA%E5%8F%8A%E4%BD%BF%E7%94%A8.assets/2020802410)

**prometheus转成系统服务**

```
vim  /lib/systemd/system/prometheus.service

[Service]
Restart=on-failure
WorkingDirectory=/usr/local/prometheus/
ExecStart=/usr/local/prometheus/prometheus --config.file=/usr/local/prometheus/prometheus.yml
[Install]
WantedBy=multi-user.target

#systemctl daemon-reload
#systemctl start prometheus
#systemctl enable prometheus
```

#其他exporter同理



**Promsql介绍**



# 2、安装grafana

## ① 安装grafana

下载地址:<https://grafana.com/grafana/download>

上传grafana-5.3.4-1.x86_64.rpm

![img](prometheus%E7%9A%84%E6%90%AD%E5%BB%BA%E5%8F%8A%E4%BD%BF%E7%94%A8.assets/20200113140643778.png)

我这里选择的rpm包，下载后直接rpm -ivh安装就OK

【失败原因缺少组件，可以yum安装组件】

```
rpm -ivh /root/Desktop/grafana-5.3.41.x86_64.rpm
```

![img](prometheus%E7%9A%84%E6%90%AD%E5%BB%BA%E5%8F%8A%E4%BD%BF%E7%94%A8.assets/grafana-2020082420)

或者第二种方法【yum安装会自动安装缺少的组件的】

```
yum localinstall -y grafana-5.3.4-1.x86_64.rpm 
```

![img](prometheus%E7%9A%84%E6%90%AD%E5%BB%BA%E5%8F%8A%E4%BD%BF%E7%94%A8.assets/20200113140902426.png)

启动服务

```
systemctl start grafana-server 
systemctl enable grafana-server 
```

## ② 访问grafana 

通过浏览器访问 http:// grafana服务器IP:3000就到了登录界面,使用默 认的admin用户,admin密码就可以登陆了

![img](prometheus%E7%9A%84%E6%90%AD%E5%BB%BA%E5%8F%8A%E4%BD%BF%E7%94%A8.assets/grafana-2020082421)

## ③ 配置grafana 

下面我们把prometheus服务器收集的数据做为一个数据源添加到 grafana,让grafana可以得到prometheus的数据。

![img](prometheus%E7%9A%84%E6%90%AD%E5%BB%BA%E5%8F%8A%E4%BD%BF%E7%94%A8.assets/grafana-2020082422)

 

![img](prometheus%E7%9A%84%E6%90%AD%E5%BB%BA%E5%8F%8A%E4%BD%BF%E7%94%A8.assets/grafana-2020082423)

![img](prometheus%E7%9A%84%E6%90%AD%E5%BB%BA%E5%8F%8A%E4%BD%BF%E7%94%A8.assets/grafana-2020082424)

a  为添加好的数据源做图形显示

![img](prometheus%E7%9A%84%E6%90%AD%E5%BB%BA%E5%8F%8A%E4%BD%BF%E7%94%A8.assets/grafana-2020082425)

![img](prometheus%E7%9A%84%E6%90%AD%E5%BB%BA%E5%8F%8A%E4%BD%BF%E7%94%A8.assets/grafana-2020082426)

 

![img](prometheus%E7%9A%84%E6%90%AD%E5%BB%BA%E5%8F%8A%E4%BD%BF%E7%94%A8.assets/grafana-2020082427)

![img](prometheus%E7%9A%84%E6%90%AD%E5%BB%BA%E5%8F%8A%E4%BD%BF%E7%94%A8.assets/grafana-2020082428)

b 保存

![img](prometheus%E7%9A%84%E6%90%AD%E5%BB%BA%E5%8F%8A%E4%BD%BF%E7%94%A8.assets/grafana-2020082429)

c 最后在dashboard可以查看到

![img](prometheus%E7%9A%84%E6%90%AD%E5%BB%BA%E5%8F%8A%E4%BD%BF%E7%94%A8.assets/grafana-2020082430)

d 匹配条件显示

![img](prometheus%E7%9A%84%E6%90%AD%E5%BB%BA%E5%8F%8A%E4%BD%BF%E7%94%A8.assets/grafana-2020082431)



e  配置grafana-node_exporter仪表版

- 导入Prometheus仪表版，Dashboards–Manage–import
- 在 Granfana.com-Dashboard中填写8919，点击load即可。（https://grafana.com/dashboards 中可以直接搜索prometheus，copy ID to Clipboard，grafana官网提供了大量的仪表板模板可以使用）
  ![在这里插入图片描述](prometheus%E7%9A%84%E6%90%AD%E5%BB%BA%E5%8F%8A%E4%BD%BF%E7%94%A8.assets/20190613123249866.png)

**·**    进入仪表板就可以在仪表版看到相应的监控

![image-20201012114748900](prometheus%E7%9A%84%E6%90%AD%E5%BB%BA%E5%8F%8A%E4%BD%BF%E7%94%A8.assets/image-20201012114748900.png)

# 3、Altermanager监控告警

## ①、介绍

​		实现prometheus的告警，需要通过altermanager这个组件；在prometheus服务端写告警规则，在altermanager组件配置邮箱

Alertmanager与Prometheus是相互分离的两个组件。Prometheus服务器根据报警规则将警报发送给Alertmanager，然后Alertmanager将silencing、inhibition、aggregation等消息通过电子邮件、dingtalk和HipChat发送通知。

Alertmanager处理由例如Prometheus服务器等客户端发来的警报。它负责删除重复数据、分组，并将警报通过路由发送到正确的接收器，比如电子邮件、Slack、dingtalk等。Alertmanager还支持groups,silencing和警报抑制的机制。



​		Prometheus以scrape_interval（默认为1m）规则周期，从监控目标上收集信息。其中scrape_interval可以基于全局或基于单个metric定义；然后将监控信息持久存储在其本地存储上。

Prometheus以evaluation_interval（默认为1m）另一个独立的规则周期，对告警规则做定期计算。其中evaluation_interval只有全局值；然后更新告警状态。

其中包含三种告警状态：

inactive：没有触发阈值

pending：已触发阈值但未满足告警持续时间

firing：已触发阈值且满足告警持续时间

举一个例子，阈值告警的配置如下：

![img](prometheus%E7%9A%84%E6%90%AD%E5%BB%BA%E5%8F%8A%E4%BD%BF%E7%94%A8.assets/webp) 

**·** 收集到的mysql_uptime>=30,告警状态为inactive

**·** 收集到的mysql_uptime<30,且持续时间小于10s，告警状态为pending

**·** 收集到的mysql_uptime<30,且持续时间大于10s，告警状态为firing

⚠ 注意：配置中的**for**语法就是用来设置告警持续时间的；如果配置中不设置**for**或者设置为0，那么pending状态会被直接跳过。

## ②、告警分组、抑制、静默

 · 分组：group

· 抑制：inhibitor

· 静默：silencer

 通过三个延时参数，告警实现了

 分组等待的合并发送（group_wait），

未解决告警的重复提醒（repeat_interval），

分组变化后快速提醒（group_interval）。 

##  ③、安装altermanager

```
cd /usr/local/src
wget https://github.com/prometheus/alertmanager/releases/download/v0.19.0/alertmanager-0.19.0.linux-amd64.tar.gz  # 下载altermanager
tar xvf alertmanager-0.19.0.linux-amd64.tar.gz -C /usr/local/  #解压至指定文件夹
cd .. ; mv alertmanager* alertmanager
vim /usr/local/alertmanager/altermanager.yml  # altermanager配置邮箱，如下
nohup ./alertmanager --config.file=alertmanager.yml  &  # 根据配置启动altermanager
```

![image-20201012112139706](prometheus%E7%9A%84%E6%90%AD%E5%BB%BA%E5%8F%8A%E4%BD%BF%E7%94%A8.assets/image-20201012112139706.png)

## ④、修改prometheus配置文件

#vim prometheus/prometheus.yml

![image-20201012113017338](prometheus%E7%9A%84%E6%90%AD%E5%BB%BA%E5%8F%8A%E4%BD%BF%E7%94%A8.assets/image-20201012113017338.png)

  

## ⑤、编写规则文件

```
vim /usr/local/prometheus/rules/rules.yml
#创建并编写规则文件(要求与配置中名称一致)
```



```
groups:
    - name: test-rules
      rules:
      - alert: InstanceDown
        expr: up == 0
        for: 2m
        labels:
          status: warning
        annotations:
          summary: "{{$labels.instance}}: has been down"
          description: "{{$labels.instance}}: job {{$labels.job}} has been down"
    - name: base-monitor-rule
      rules:
      - alert: NodeCpuUsage
        expr: (100 - (avg by (instance) (rate(node_cpu{job=~".*",mode="idle"}[2m])) * 100)) > 99
        for: 15m
        labels:
          service_name: test
          level: warning
        annotations:
          description: "{{$labels.instance}}: CPU usage is above 99% (current value is: {{ $value }}"
      - alert: NodeMemUsage
        expr: avg by  (instance) ((2- (node_memory_MemFree{} + node_memory_Buffers{} + node_memory_Cached{})/node_memory_MemTotal{}) * 100) > 80
        for: 15m
        labels:
          service_name: test
          level: warning
        annotations:
          description: "{{$labels.instance}}: MEM usage is above 90% (current value is: {{ $value }}"
      - alert: NodeDiskUsage
        expr: (1 - node_filesystem_free{fstype!="rootfs",mountpoint!="",mountpoint!~"/(run|var|sys|dev).*"} / node_filesystem_size) * 100 > 80
        for: 2m
        labels:
          service_name: test
          level: warning
        annotations:
          description: "{{$labels.instance}}: Disk usage is above 80% (current value is: {{ $value }}"
      - alert: NodeFDUsage
        expr: avg by (instance) (node_filefd_allocated{} / node_filefd_maximum{}) * 100 > 80
for: 2m
        labels:
          service_name: test
          level: warning
        annotations:
          description: "{{$labels.instance}}: File Descriptor usage is above 80% (current value is: {{ $value }}"
      - alert: NodeLoad15
        expr: avg by (instance) (node_load15{}) > 100
        for: 2m
        labels:
          service_name: test
          level: warning
        annotations:
          description: "{{$labels.instance}}: Load15 is above 100 (current value is: {{ $value }}"
      - alert: NodeAgentStatus
        expr: avg by (instance) (up{}) == 0
        for: 2m
        labels:
          service_name: test
          level: warning
        annotations:
          description: "{{$labels.instance}}: Node Agent is down (current value is: {{ $value }}"
      - alert: NodeProcsBlocked
        expr: avg by (instance) (node_procs_blocked{}) > 100
        for: 2m
        labels:
          service_name: test
          level: warning
        annotations:
          description: "{{$labels.instance}}: Node Blocked Procs detected!(current value is: {{ $value }}"
      - alert: NodeTransmitRate
        expr:  avg by (instance) (floor(irate(node_network_transmit_bytes{device="eth0"}[2m]) / 1024 / 1024)) > 100
        for: 2m
        labels:
          service_name: test
          level: warning
        annotations:
description: "{{$labels.instance}}: Node Transmit Rate  is above 100MB/s (current value is: {{ $value }}"
      - alert: NodeReceiveRate
        expr:  avg by (instance) (floor(irate(node_network_receive_bytes{device="eth0"}[2m]) / 1024 / 1024)) > 100
        for: 2m
        labels:
          service_name: test
          level: warning
        annotations:
          description: "{{$labels.instance}}: Node Receive Rate  is above 100MB/s (current value is: {{ $value }}"
      - alert: NodeDiskReadRate
        expr: avg by (instance) (floor(irate(node_disk_bytes_read{}[2m]) / 1024 / 1024)) > 50
        for: 2m
        labels:
          service_name: test
          level: warning
        annotations:
          description: "{{$labels.instance}}: Node Disk Read Rate is above 50MB/s (current value is: {{ $value }}"
      - alert: NodeDiskWriteRate
        expr: avg by (instance) (floor(irate(node_disk_bytes_written{}[2m]) / 1024 / 1024)) > 50
        for: 2m
        labels:
          service_name: test
          level: warning
        annotations:
          description: "{{$labels.instance}}: Node Disk Write Rate is above 50MB/s (current value is: {{ $value }}"

```



## ⑥、重启prometheus并查看规则

systemctl restart prometheus

访问http://loalhost:9090/alerts ，即可查看规则

![image-20201012113913071](prometheus%E7%9A%84%E6%90%AD%E5%BB%BA%E5%8F%8A%E4%BD%BF%E7%94%A8.assets/image-20201012113913071.png)



## ⑦、查看报错邮件

报警邮件如下：
![image-20201012114029075](prometheus%E7%9A%84%E6%90%AD%E5%BB%BA%E5%8F%8A%E4%BD%BF%E7%94%A8.assets/image-20201012114029075.png)











# 4、监控指标（metrics）

Prometheus提供了一种称为PromQL（Prometheus查询语言）的功能查询语言，它使用户可以实时选择和汇总时间序列数据。表达式的结果可以显示为图形，可以在Prometheus的表达式浏览器中显示为表格数据 

目前提供四种metrics类型，分别是：Counter, Gauge, Summary and Histogram

- **counter**：一个计数器是代表一个累积指标单调递增计数器，它的值只能增加或在重新启动时重置为零。
- **Gauge**：表示单个数值，可以任意地上升和下降的度量。常用于测量值，如温度或当前内存使用情况，但也可用于可以上下的“计数”，例如并发请求的数量。
- **Summary**：摘要采样观察（通常是请求持续时间和响应大小等）。
- **Histogram**：跟踪存储桶中事件的大小和数量。这允许分位数的可聚合计算。



## ①、prometheus自定义监控指标

Prometheus 自定义exporter 监控key

当Prometheus的node_exporter中没有我们需要的一些监控项时，就可以如zabbix一样定制一些key，让其支持我们所需要的监控项。

例如，我要根据 逻辑cpu核数 来确定load的告警值，现在就要添加一个统计 逻辑cpu核数的 key

```
用一个shell脚本实现多个监控项key value的添加

cat /usr/local/node_exporter/key/key_runner
#! /bin/bash
prom_file=/usr/local/node_exporter/key/key.prom

IFS=";"

export TERM=vt100

key_value="
Logical_CPU_core_total  `cat /proc/cpuinfo| grep "processor"| wc -l`;
logined_users_total     `who | wc -l`;
procs_total             `/bin/top -b -n 1|grep Tasks|sed 's/,/\n/g'|grep total|awk '{ print $(NF-1) }'`;
procs_running            `/bin/top -b -n 1|grep Tasks|sed 's/,/\n/g'|grep running|awk '{ print $(NF-1) }'`"

for i in $key_value
do
    IFS=" "
    j=(`echo $i`)
    key=${j[0]}
    value=${j[1]}
    echo $key $value >> "$prom_file".tmp
done

cat "$prom_file".tmp > $prom_file
rm -rf "$prom_file".tmp
IFS=$OLD_IFS
执行效果

[root@Prometheus key]# ll
total 8
-rw-r--r-- 1 root root  82 Mar 11 16:45 key.prom
-rwxr-xr-x 1 root root 628 Mar  1 19:23 key_runner
[root@Prometheus key]# cat key.prom
Logical_CPU_core_total 4
logined_users_total 2
procs_total 129
procs_running 1

#shell脚本一般写个死循环或者写定时任务 来定时获取value，以上脚本只是附在node-exporter上，也可以定时推送至pushgateway，由prometheus定时拉取
```

## ②、pushgateway

Pushgateway是prometheus的一个重要组件，利用该组件可以实现自动以监控指标，从字面意思来看，该部件不是将数据push到prometheus，而是作为一个中间组件收集外部push来的数据指标，prometheus会定时从pushgateway上pull数据。

![img](prometheus%E7%9A%84%E6%90%AD%E5%BB%BA%E5%8F%8A%E4%BD%BF%E7%94%A8.assets/1489604-20190629141707811-1292572935.png)

　　pushgateway并不是将Prometheus的pull改成了push，它只是允许用户向他推送指标信息，并记录。而Prometheus每次从 pushgateway拉取的数据并不是期间用户推送上来的所有数据，而是client端最后一次push上来的数据。因此需设置client端向pushgateway端push数据的时间小于等于prometheus去pull数据的时间，这样一来可以保证prometheus的数据是最新的。

**【注意】**如果client一直没有推送新的指标到pushgateway，那么Prometheus获取到的数据是client最后一次push的数据，直到指标消失（默认5分钟）。
Prometheus本身是不会存储指标的，但是为了防止pushgateway意外重启、工作异常等情况的发送，在pushgateway处允许指标暂存，参数--persistence.interval=5m，默认保存5分钟，5分钟后，本地存储的指标会删除。

**使用pushgateway的理由：**
　　1、prometheus默认采用pull模式，由于不在一个网络或者防火墙的问题，导致prometheus 无法拉取各个节点的数据。
　　2、监控业务数据时，需要将不同数据汇总，然后由prometheus统一收集

**pushgateway的缺陷：**
　　1、多个节点的数据汇总到pushgateway，当它宕机后影响很大
　　2、pushgateway可以持续化推送所有的监控数据，即使监控已经下线，还会获取旧的监控数据。需手动清理不需要的数据
　　3、重启后数据丢失



**部署pushgateway**

上传pushgateway-1.2.0.linux-amd64.tar.gz到 /usr/local/src/

tar -xzvf pushgateway-1.2.0.linux-amd64.tar.gz  -C /usr/local/

cd .. ; mv pushgateway-1.2.0   pushgateway

配置prometheus发现pushgateway 规则如下

![image-20201012152507236](prometheus%E7%9A%84%E6%90%AD%E5%BB%BA%E5%8F%8A%E4%BD%BF%E7%94%A8.assets/image-20201012152507236.png)

重启prometheus ：systemctl restart prometheus  登陆web UI，查看prometheus的targets

![image-20201012152849243](prometheus%E7%9A%84%E6%90%AD%E5%BB%BA%E5%8F%8A%E4%BD%BF%E7%94%A8.assets/image-20201012152849243.png)

**测试**

```
向pushgateway发送数据
echo  "test 123" | curl --data-binary @- http://pushgatewayIP:9091/metrics/job/test
```

　　上述测试的目的是，在被监控的机器上，想pushgateway发送了一条数据，内容是“test 123”，指标名称是“test”，指标值是“123”；

　　http://pushgatewayIP:9091/metrics/job/test，此次也声名了，在pushgateway处建立一个job为test的指标。



```
推送的API路径
所有的推送都是通过HTTP完成的，API路径如下：  
/metrics/job/<JOBNAME>{/<LABEL_NAME>/<LABEL_VALUE>} 
JOBNAME：job标签的值
/ 是转义符
```

　　登陆prometheus webUI查询指标是否生成

![img](prometheus%E7%9A%84%E6%90%AD%E5%BB%BA%E5%8F%8A%E4%BD%BF%E7%94%A8.assets/1489604-20190629143811236-1274118754.png)

**pushgateway发送数据的API格式**

API格式：

　　**http://pustgatewayIP/metrices/job/job名/标签名/标签值***（一般 标签名 采用 instance）

**例子：
　　http://pustgatewayIP/metrics/job/ 
　　　　/sb/instance/si
　　　　/testjob/abc/pushgateway1
　　　　/testjob/yyy/pushgateway1
**　　分别触发上述三个API，打开pushgateway的web UI

![img](prometheus%E7%9A%84%E6%90%AD%E5%BB%BA%E5%8F%8A%E4%BD%BF%E7%94%A8.assets/1489604-20190629144737955-1211416005.png)

### 发送的数据类型

 　**1、发送counter类型**

可以一次发送单个，也可以发送多个数据

```
cat <<EOF | curl --data-binary @- http://pushgatewayIP:9091/metrics/job/docker_runtime/instance/xa-lsr-billubuntu
    # TYPE docker_runtime counter
    docker_runtime{name="cadvisor"} 33
    docker_runtime{name="nginx"} 331
    docker_runtime{name="abc"} 332
EOF
```

　　**2、发送gauage类型**

可以一次发送单个，也可以发送多个数据

```
cat <<EOF | curl --data-binary @- http://pushgatewayIP:9091/metrics/job/docker_runtime/instance/xa-lsr-billubuntu
    # TYPE docker_runtime gauge
    # HELP docker_runtime time sec
    docker_runtime{name="nginx"} 22
   docker_runtime{name="cadvisor"} 22
   docker_runtime{name="bbc"} 22
EOF
```



example

每5秒获取等待连接数

```
#!/bin/bash
while [ ture ]; do

#instance_name=`hostname -f | cut -d'.' -f1`  #获取本机名，用于后面的的标签
label="count_netstat_wait_connections"  #定义key名
count_netstat_wait_connections=`netstat -an | grep -i wait | wc -l`  #获取数据的命令
echo "$label: $count_netstat_wait_connections"
echo "$label  $count_netstat_wait_connections" | curl --data-binary @- http://localhost:9091/metrics/job/pushgateway

/bin/sleep 5
done

```

**【注意】**

**注意上传数据的类型**

​		如果上传的数据类型是 UNTYPE 那么 prometheus将无法识别，导致整个pushgateway数据无法接受！因此需要格外关注发送的数据格式。
数据类型只有四种 counter gauge summary histogram

二、python向pushgateway发送数据

**安装prometheus客户端**

　　**pip install prometheus_client**

**1、counter类型**

\#counter是可增长的，重启时候会被置成0，用于任务个数，只增不减
\#使用flask构建一个建议的网页

```
import prometheus_client
from prometheus_client import Counter
from prometheus_client.core import CollectorRegistry
from flask import Response, Flask
 
app = Flask(__name__)
 
requests_total = Counter("request_count", "Total request cout of the host")
 
@app.route("/metrics")
def requests_count():
    requests_total.inc()
    # requests_total.inc(2) 每一次刷新会增加2
    return Response(prometheus_client.generate_latest(requests_total),
                    mimetype="text/plain")
 
@app.route('/')
def index():
    requests_total.inc()
    return "Hello World"
 
if __name__ == "__main__":
    app.run(host="0.0.0.0")
```

结果：　

　[![img](prometheus%E7%9A%84%E6%90%AD%E5%BB%BA%E5%8F%8A%E4%BD%BF%E7%94%A8.assets/1489604-20190629151825095-1903045889.png)](https://img2018.cnblogs.com/blog/1489604/201906/1489604-20190629151825095-1903045889.png)

2、gauage类型

```
import prometheus_client
from prometheus_client import Counter,Gauge
from prometheus_client.core import CollectorRegistry
from flask import Response, Flask
 
app = Flask(__name__)
 
g = Gauge("random_value", "Random value of the request")
 
@app.route("/metrics")
def s():
    with open("a.txt",'r') as f:
        num=f.read()
    g.set(num)
    return Response(prometheus_client.generate_latest(g),
                    mimetype="text/plain")
 
 
@app.route('/')
def index():
    requests_total.inc()
    return "Hello World"
 
if __name__ == "__main__":
app.run(host="0.0.0.0")
```

结果：　

　![img](prometheus%E7%9A%84%E6%90%AD%E5%BB%BA%E5%8F%8A%E4%BD%BF%E7%94%A8.assets/1489604-20190629152044160-1236542689.png)

以上作用是在本地生成一个小型网站，下一步是将选定的数据发送到pushgateway 

```
#在被监控机上写python代码
#CollectorRegistry可以同时注册多个自定义指标并返回给prometheus
 
     
importprometheus_client
fromprometheus_clientimportGauge
fromprometheus_client.coreimportCollectorRegistry
importrequests
 
defv1(): #获取监控数据的值
    return2.3
 
defv2():
    return3.60
 
n1=v1()
n2=v2()
 
REGISTRY=CollectorRegistry(auto_describe=False)
#自定义指标必须利用CollectorRegistry进行注册，注册后返回给prometheus
#CollectorRegistry必须提供register，一个指标收集器可以注册多个collectoryregistry
 
 
jin=Gauge("jin_kou","zhegezuoyongshijinkoudaxiao",["l1",'l2','instance'],registry=REGISTRY)
chu=Gauge("chu_kou","zhegezuoyongshichukoudaxiao",["l1",'l2','instance'],registry=REGISTRY)
    #“jin_kou” 指标名称
    # "zhegezuoyongshichukoudaxiao"  指标的注释信息
    # "[]"  定义标签的类别及个数
 
jin.labels(l1="label1",l2="label2",instance="windows1").inc(n1)
chu.labels(l1="label1",l2="label2",instance="windows1").inc(n2)
    #“[]”中有几个，就需要写几个个数要完全一致
 
requests.post("http://pushgatewayIP:9091/metrics/job/python/",data=prometheus_client.generate_latest(REGISTRY))
    #向指定的API发送post信息，将注册的信息发过去
    #API中的 “python”是 job的名字
```

　结果：

![img](prometheus%E7%9A%84%E6%90%AD%E5%BB%BA%E5%8F%8A%E4%BD%BF%E7%94%A8.assets/1489604-20190629152327729-387707060.png)

## prometheus自带查询指标定义解析（节选）

```
#prometheus自带查询指标定义解析
go_gc_duration_seconds：持续时间秒
go_gc_duration_seconds_sum：gc-持续时间-秒数-总和
go_memstats_alloc_bytes：Go内存统计分配字节
go_memstats_alloc_bytes_total：Go内存统计分配字节总数
go_memstats_buck_hash_sys_bytes：用于剖析桶散列表的堆空间字节
go_memstats_frees_total：内存释放统计
go_memstats_gc_cpu_fraction：垃圾回收占用服务CPU工作的时间总和
go_memstats_gc_sys_bytes：垃圾回收标记元信息使用的内存字节
go_memstats_heap_alloc_bytes：服务分配的堆内存字节数
go_memstats_heap_idle_bytes：申请但是未分配的堆内存或者回收了的堆内存（空闲）字节数
go_memstats_heap_inuse_bytes：正在使用的堆内存字节数
go_memstats_heap_objects：堆内存块申请的量
go_memstats_heap_released_bytes：返回给OS的堆内存
go_memstats_heap_sys_bytes：系统分配的作为运行栈的内存
go_memstats_last_gc_time_seconds：垃圾回收器最后一次执行时间
go_memstats_lookups_total：被runtime监视的指针数
go_memstats_mallocs_total：服务malloc的次数
go_memstats_mcache_inuse_bytes：mcache结构体申请的字节数(不会被视为垃圾回收)
go_memstats_mcache_sys_bytes：操作系统申请的堆空间用于mcache的字节数
go_memstats_mspan_inuse_bytes：用于测试用的结构体使用的字节数
go_memstats_mspan_sys_bytes：系统为测试用的结构体分配的字节数
go_memstats_next_gc_bytes：垃圾回收器检视的内存大小
go_memstats_other_sys_bytes：golang系统架构占用的额外空间
go_memstats_stack_inuse_bytes：正在使用的栈字节数
go_memstats_stack_sys_bytes：系统分配的作为运行栈的内存
go_memstats_sys_bytes：服务现在系统使用的内存
go_threads：线程

jvm_buffer_count_buffers：jvm缓冲区计数缓冲区：
jvm_buffer_memory_used_bytes：jvm缓冲区内存已用字节
jvm_buffer_total_capacity_bytes：jvm缓冲区总容量字节
jvm_classes_loaded_classes：jvm_classes加载的类
jvm_classes_unloaded_classes_total：自Java虚拟机开始执行以来已卸载的类总数
jvm_gc_max_data_size_bytes：jvm_gc_最大数据大小字节：
jvm_gc_memory_allocated_bytes_total：在一个GC之后到下一个GC之前增加年轻代内存池的大小
jvm_gc_memory_promoted_bytes_total：GC之前到GC之后，老年代的大小正向增加的计数
system_cpu_count：Java虚拟机可用的处理器数量
process_uptime_seconds：Java虚拟机的正常运行时间
jvm_threads_states_threads：当前处于NEW状态的线程数
jvm_memory_committed_bytes：可供Java虚拟机使用的已提交的内存量
system_cpu_usage:最近的cpu利用率
jvm_threads_peak_threads：自Java虚拟机启动或重置峰值以来的活动线程峰值
jvm_memory_used_bytes：已用内存量
jvm_threads_daemon_threads：当前活动的守护程序线程数
process_cpu_usage：JVM的CPU利用率
process_start_time_seconds：进程的开始时间
jvm_gc_max_data_size_bytes：老年代的最大内存量
jvm_gc_live_data_size_bytes：full GC老年代的大小
jvm_threads_live_threads：当前活动线程数，包括守护程序线程和非守护程序线程
jvm_buffer_memory_used_bytes：已使用缓冲池大小
jvm_buffer_count_buffers：缓冲区数量
logback_events_total：日志备份事件总计
net_conntrack_dialer_conn_attempted_total：网络连接拨号尝试次数总计
net_conntrack_dialer_conn_closed_total：网络连接拨号器关闭总计
net_conntrack_dialer_conn_established_total：网络连接拨号器建立网络连接总数
net_conntrack_dialer_conn_failed_total：网络连接拨号失败总计
net_conntrack_listener_conn_accepted_total：网络连接监听接受总计
net_conntrack_listener_conn_closed_total：网络连接监听关闭总计

prometheus_rule_evaluation_duration_seconds：所有的 rules(recording/alerting) 的计算的时间（分位值），这个可以用来分析规则是否过于复杂以及系统的状态是否繁忙
prometheus_rule_evaluation_duration_seconds_count：执行所有的 rules 的累积时长，没怎么用到
prometheus_rule_group_duration_seconds：具体的 rule group 的耗时
prometheus_rule_group_interval_seconds：具体的 rule group 的执行间隔（如果没有异常，应该和配置中的一致，如果不一致了，那很可能系统负载比较高）
prometheus_rule_group_iterations_missed_total：因为系统繁忙导致被忽略的 rule 执行数量
prometheus_rule_group_last_duration_seconds：最后一次的执行耗时
prometheus_tsdb_blocks_loaded：当前已经加载到内存中的块数量
prometheus_tsdb_compactions_triggered_total：压缩操作被触发的次数（可能很多，但不是每次出发都会执行）
prometheus_tsdb_compactions_total：启动到目前位置压缩的次数（默认是 2 小时一次）
prometheus_tsdb_compactions_failed_total：压缩失败的次数
prometheus_tsdb_head_chunks：head 中存放的 chunk 数量
prometheus_tsdb_head_chunks_created_total：head 中创建的 chunks 数量
prometheus_tsdb_head_chunks_removed_total：head 中移除的 chunks 数量
prometheus_tsdb_head_gc_duration_seconds：head gc 的耗时（分位值）
prometheus_tsdb_head_max_time：head 中的有效数据的最大时间（这个比较有价值）
prometheus_tsdb_head_min_time：head 中的有效数据的最小时间（这个比较有价值）
prometheus_tsdb_head_samples_appended_total：head 中添加的 samples 的总数（可以看增长速度）
prometheus_tsdb_head_series：head 中保存的 series 数量
prometheus_tsdb_reloads_total：rsdb 被重新加载的次数
prometheus_local_storage_memory_series: 时间序列持有的内存当前块数量
prometheus_local_storage_memory_chunks: 在内存中持久块的当前数量
prometheus_local_storage_chunks_to_persist: 当前仍然需要持久化到磁盘的的内存块数量
prometheus_local_storage_persistence_urgency_score: 紧急程度分数
prometheus_local_storage_memory_chunks：本地存储器内存块
process_resident_memory_bytes：进程内存字节
prometheus_notifications_total （针对Prometheus 服务器）
process_cpu_seconds_total （由客户端库导出）
http_request_duration_seconds （用于所有HTTP请求）

system_cpu_usage：系统cpu使用率
tomcat_cache_access_total：tomcat缓存访问总计
tomcat_global_error_total：tomcat全局错误总计
tomcat_global_received_bytes_total：tomcat_全局接收到的字节总数
tomcat_global_request_max_seconds：tomcat全局请求最大秒数
tomcat_global_request_seconds_count：tomcat全局请求秒数
tomcat_global_request_seconds_sum：tomcat全局请求秒数求和
tomcat_global_sent_bytes_total：tomcat全局发送字节总计
tomcat_servlet_error_total：tomcat_servlet错误总计
tomcat_servlet_request_max_seconds：tomcat_servlet_请求最大秒数
tomcat_servlet_request_seconds_count：tomcat_servlet_请求秒数
tomcat_servlet_request_seconds_sum：tomcat_servlet_请求秒数求和
tomcat_sessions_active_current_sessions：tomcat_当前活跃会话数
tomcat_sessions_active_max_sessions：tomcat_活跃会话最大数量
tomcat_sessions_created_sessions_total：tomcat会话创建会话总数
tomcat_sessions_expired_sessions_total：tomcat过期会话数总计
tomcat_sessions_rejected_sessions_total：tomcat拒绝会话数总计
tomcat_threads_busy_threads：tomcat繁忙线程
tomcat_threads_current_threads：tomcat线程当前线程数

......
```



# 5、常用的exporters

## ①、mysql_exporter

在被管理机agent1上安装mysqld_exporter组件
下载地址:[ https://prometheus.io/download/](https://blog.csdn.net/heian_99/article/details/103956583)

上传mysqld_exporter组件

![img](prometheus%E7%9A%84%E6%90%AD%E5%BB%BA%E5%8F%8A%E4%BD%BF%E7%94%A8.assets/2020082411.png)

### 1、安装mysqld_exporter组件

```
tar xf mysqld_exporter-0.11.0.linux-amd64.tar.gz -C /usr/local/
mv /usr/local/mysqld_exporter-0.11.0.linux-amd64/  /usr/local/mysqld_exporter 
ls /usr/local/mysqld_exporter
```

![img](prometheus%E7%9A%84%E6%90%AD%E5%BB%BA%E5%8F%8A%E4%BD%BF%E7%94%A8.assets/2020082412)

### 3、安装mariadb数据库,并授权

```
yum install mariadb\* -y 
systemctl restart mariadb 
systemctl enable mariadb 
mysql
```

```
MariaDB [(none)]> grant select,replication client,process ON *.* to 'mysql_monitor'@'localhost' identified by '123'; 

#1、process通过这个权限，用户可以执行SHOW PROCESSLIST和KILL命令。默认情况下，每个用户都可以执行SHOW PROCESSLIST命令，但是只能查询本用户的进程。
2、replication client拥有此权限可以查询master server、slave server状态
```

(注意:授权ip为localhost，因为不是prometheus服务器来直接找mariadb 获取数据，而是prometheus服务器找mysql_exporter,mysql_exporter 再找mariadb。所以这个localhost是指的mysql_exporter的IP)

```
MariaDB [(none)]> flush privileges;
MariaDB [(none)]> quit
```

![img](prometheus%E7%9A%84%E6%90%AD%E5%BB%BA%E5%8F%8A%E4%BD%BF%E7%94%A8.assets/2020082413)

创建一个mariadb配置文件，写上连接的用户名与密码(和上面的授权的用户名 和密码要对应)

```
vim /usr/local/mysqld_exporter/.my.cnf 
```

```
[client] 
user=mysql_monitor
password=123
```

![img](prometheus%E7%9A%84%E6%90%AD%E5%BB%BA%E5%8F%8A%E4%BD%BF%E7%94%A8.assets/2020082414)

### 3、启动mysqld_exporter

```
nohup /usr/local/mysqld_exporter/mysqld_exporter --config.my.cnf=/usr/local/mysqld_exporter/.my.cnf &
```

确认端口(9104)

![img](prometheus%E7%9A%84%E6%90%AD%E5%BB%BA%E5%8F%8A%E4%BD%BF%E7%94%A8.assets/2020082415)

 回到prometheus服务器的配置文件里添加被监控的mariadb的配置段

在主配置文件最后再加上下面三行

```
vim /usr/local/prometheus/prometheus.yml 
```

```
  - job_name: 'mariadb'
    static_configs:
    - targets: ['192.168.116.130:9104'] 
```



![img](prometheus%E7%9A%84%E6%90%AD%E5%BB%BA%E5%8F%8A%E4%BD%BF%E7%94%A8.assets/2020082416)

```
- job_name: 'agent1_mariadb'  # 取一个job 名称来代表被监控的mariadb   
  static_configs:   
  - targets: ['10.1.1.14:9104']     # 这里改成 被监控机器的IP，后面端口接9104
```

改完配置文件后,重启服务

回到web管理界面 --》点Status --》点Targets --》可以看到监控 mariadb了

![img](prometheus%E7%9A%84%E6%90%AD%E5%BB%BA%E5%8F%8A%E4%BD%BF%E7%94%A8.assets/2020082417)

 

![img](prometheus%E7%9A%84%E6%90%AD%E5%BB%BA%E5%8F%8A%E4%BD%BF%E7%94%A8.assets/2020082418)





​	在创建用户并且授权之后，可以使用systemctl 来托管mysqld_exporter，并填上授权用户和密码

vim /usr/lib/systemd/system/mysqld_exporter.service

```
[Unit]
Description=mysqld_exporter
After=network.target
[Service]
Type=simple
User=mysql
Environment=DATA_SOURCE_NAME=exporter:exporter123@(localhost:3306)/
ExecStart=/usr/local/mysqld_exporter/mysqld_exporter --web.listen-address=0.0.0.0:9104
  --config.my-cnf /etc/my.cnf \
  --collect.slave_status \
  --collect.slave_hosts \
  --log.level=error \
  --collect.info_schema.processlist \
  --collect.info_schema.innodb_metrics \
  --collect.info_schema.innodb_tablespaces \
  --collect.info_schema.innodb_cmp \
  --collect.info_schema.innodb_cmpmem
Restart=on-failure
[Install]
WantedBy=multi-user.targe
```



### 4、Granfana 导入Mysql 监控图表。

推荐 <https://grafana.com/grafana/dashboards/7362> 监控模板，导出Download JSON。 Granfana进入Create->Import导入Dashboards。 



## ②、jmx_exporter

Prometheus监控Java应用（Tomcat）

### 1、下载exporter

```
wget https://repo1.maven.org/maven2/io/prometheus/jmx/jmx_prometheus_javaagent/0.3.1/jmx_prometheus_javaagent-0.3.1.jar
```

### 2、配置 jmx exporter tomcat.yml: 

```
---   
lowercaseOutputLabelNames: true
lowercaseOutputName: true
rules:
- pattern: 'Catalina<type=GlobalRequestProcessor, name=\"(\w+-\w+)-(\d+)\"><>(\w+):'
  name: tomcat_$3_total
  labels:
    port: "$2"
    protocol: "$1"
  help: Tomcat global $3
  type: COUNTER
- pattern: 'Catalina<j2eeType=Servlet, WebModule=//([-a-zA-Z0-9+&@#/%?=~_|!:.,;]*[-a-zA-Z0-9+&@#/%=~_|]), name=([-a-zA-Z0-9+/$%~_-|!.]*), J2EEApplication=none, J2EEServer=none><>(requestCount|maxTime|processingTime|errorCount):'
  name: tomcat_servlet_$3_total
  labels:
    module: "$1"
    servlet: "$2"
  help: Tomcat servlet $3 total
  type: COUNTER
- pattern: 'Catalina<type=ThreadPool, name="(\w+-\w+)-(\d+)"><>(currentThreadCount|currentThreadsBusy|keepAliveCount|pollerThreadCount|connectionCount):'
  name: tomcat_threadpool_$3
  labels:
    port: "$2"
    protocol: "$1"
  help: Tomcat threadpool $3
  type: GAUGE
- pattern: 'Catalina<type=Manager, host=([-a-zA-Z0-9+&@#/%?=~_|!:.,;]*[-a-zA-Z0-9+&@#/%=~_|]), context=([-a-zA-Z0-9+/$%~_-|!.]*)><>(processingTime|sessionCounter|rejectedSessions|expiredSessions):'
  name: tomcat_session_$3_total
  labels:
    context: "$2"
    host: "$1"
  help: Tomcat session $3 total
  type: COUNTER
```



### 3、配置 tomcat catalina.sh，让 jmx_exporter 跟 tomcat 一起启动 

```
JAVA_OPTS="-javaagent:/tmp/tomcat/bin/jmx_prometheus_javaagent-0.3.1.jar=30013:/tmp/tomcat/bin/jmx_exporter.yml"
```



![1598341359674](prometheus%E7%9A%84%E6%90%AD%E5%BB%BA%E5%8F%8A%E4%BD%BF%E7%94%A8.assets/1598341359674.png)



### 4、在prometheus.yml中添加: 

```
- job_name: 'jmx_tomcat'
    static_configs:
    - targets: ['10.10.16.42:30013']

```

重启prometheus服务

### 5、浏览器访问

浏览器访问prometheus_server <http://10.10.16.41:9090/targets> 

![1598341696724](prometheus%E7%9A%84%E6%90%AD%E5%BB%BA%E5%8F%8A%E4%BD%BF%E7%94%A8.assets/1598341696724.png)

### 6、导入grafana模板8563

使用https://grafana.com/dashboards/8563模板，添加job名称,导入 grafana 中，可以点右上方设置按钮对模板信息进行修改 

结果如下：

![1598342244643](prometheus%E7%9A%84%E6%90%AD%E5%BB%BA%E5%8F%8A%E4%BD%BF%E7%94%A8.assets/1598342244643.png)

https://grafana.com/dashboards/3457模板也不错，需手动输入instance 

![1598344014430](prometheus%E7%9A%84%E6%90%AD%E5%BB%BA%E5%8F%8A%E4%BD%BF%E7%94%A8.assets/1598344014430.png)





# 6、数据持久化

参考：https://www.cnblogs.com/cheyunhua/p/11376756.html







（未完待续）