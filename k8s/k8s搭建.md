



## 1、准备工作



## **1.1 集群信息**

机器均为8C8G的虚拟机，硬盘为100G。

| IP            | Hostname                                        |
| ------------- | ----------------------------------------------- |
| 10.31.18.1    | tiny-kubeproxy-free-master-18-1.k8s.tcinternal  |
| 10.31.18.11   | tiny-kubeproxy-free-worker-18-11.k8s.tcinternal |
| 10.31.18.12   | tiny-kubeproxy-free-worker-18-12.k8s.tcinternal |
| 10.18.64.0/18 | podSubnet                                       |
| 10.18.0.0/18  | serviceSubnet                                   |





## **1.2 检查mac和product_uuid**

同一个k8s集群内的所有节点需要确保`mac`地址和`product_uuid`均唯一，开始集群初始化之前需要检查相关信息

```bash
# 检查mac地址
ip link 
ifconfig -a

# 检查product_uuid
sudo cat /sys/class/dmi/id/product_uuid
```



## **1.3 配置ssh免密登录（可选）**

如果k8s集群的节点有多个网卡，确保每个节点能通过正确的网卡互联访问

```bash
# 在root用户下面生成一个公用的key，并配置可以使用该key免密登录
su root
ssh-keygen
cd /root/.ssh/
cat id_rsa.pub >> authorized_keys
chmod 600 authorized_keys


cat >> ~/.ssh/config <<EOF
Host tiny-kubeproxy-free-master-18-1.k8s.tcinternal
    HostName 10.31.18.1
    User root
    Port 22
    IdentityFile ~/.ssh/id_rsa

Host tiny-kubeproxy-free-worker-18-11.k8s.tcinternal
    HostName 10.31.18.11
    User root
    Port 22
    IdentityFile ~/.ssh/id_rsa

Host tiny-kubeproxy-free-worker-18-12.k8s.tcinternal
    HostName 10.31.18.12
    User root
    Port 22
    IdentityFile ~/.ssh/id_rsa
EOF
```



## **1.4 修改hosts文件**

```bash
cat >> /etc/hosts <<EOF
10.31.18.1 tiny-kubeproxy-free-master-18-1.k8s.tcinternal
10.31.18.11 tiny-kubeproxy-free-worker-18-11.k8s.tcinternal
10.31.18.12 tiny-kubeproxy-free-worker-18-12.k8s.tcinternal
EOF
```



## **1.5 关闭swap内存**

```bash
# 使用命令直接关闭swap内存
swapoff -a
# 修改fstab文件禁止开机自动挂载swap分区
sed -i '/swap / s/^\(.*\)$/#\1/g' /etc/fstab
```



## **1.6 配置时间同步**

这里可以根据自己的习惯选择ntp或者是chrony同步均可，同步的时间源服务器可以选择阿里云的`ntp1.aliyun.com`或者是国家时间中心的`ntp.ntsc.ac.cn`。

### **使用ntp同步**

```text
# 使用yum安装ntpdate工具
yum install ntpdate -y

# 使用国家时间中心的源同步时间
ntpdate ntp.ntsc.ac.cn

# 最后查看一下时间
hwclock
```

### **使用chrony同步**

```bash
# 使用yum安装chrony
yum install chrony -y

# 设置开机启动并开启chony并查看运行状态
systemctl enable chronyd.service
systemctl start chronyd.service
systemctl status chronyd.service

# 当然也可以自定义时间服务器
vim /etc/chrony.conf

# 修改前
$ grep server /etc/chrony.conf
# Use public servers from the pool.ntp.org project.
server 0.centos.pool.ntp.org iburst
server 1.centos.pool.ntp.org iburst
server 2.centos.pool.ntp.org iburst
server 3.centos.pool.ntp.org iburst

# 修改后
$ grep server /etc/chrony.conf
# Use public servers from the pool.ntp.org project.
server ntp.ntsc.ac.cn iburst

# 重启服务使配置文件生效
systemctl restart chronyd.service

# 查看chrony的ntp服务器状态
chronyc sourcestats -v
chronyc sources -v
```



## **1.7 关闭selinux**

```bash
# 使用命令直接关闭
setenforce 0

# 也可以直接修改/etc/selinux/config文件
sed -i 's/^SELINUX=enforcing$/SELINUX=disabled/' /etc/selinux/config
```



## **1.8 配置防火墙**

k8s集群之间通信和服务暴露需要使用较多端口，为了方便，直接禁用防火墙

```bash
# centos7使用systemctl禁用默认的firewalld服务
systemctl disable firewalld.service
```



## **1.9 配置netfilter参数**

这里主要是需要配置内核加载`br_netfilter`和`iptables`放行`ipv6`和`ipv4`的流量，确保集群内的容器能够正常通信。

```text
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
br_netfilter
EOF

cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
sudo sysctl --system
```



## **1.10 关闭IPV6（不建议）**

和之前部署其他的CNI不一样，cilium很多服务监听默认情况下都是双栈的（使用cilium-cli操作的时候），因此建议开启系统的IPV6网络支持（即使没有可用的IPV6路由也可以）

当然没有ipv6网络也是可以的，只是在使用cilium-cli的一些开启port-forward命令时会报错而已。

```bash
# 直接在内核中添加ipv6禁用参数
grubby --update-kernel=ALL --args=ipv6.disable=1
```



## **1.11 配置IPVS（可以不用）**

IPVS是专门设计用来应对负载均衡场景的组件，[kube-proxy 中的 IPVS 实现](https://link.zhihu.com/?target=https%3A//github.com/kubernetes/kubernetes/blob/master/pkg/proxy/ipvs/README.md%23run-kube-proxy-in-ipvs-mode)通过减少对 iptables 的使用来增加可扩展性。在 iptables 输入链中不使用 PREROUTING，而是创建一个假的接口，叫做 kube-ipvs0，当k8s集群中的负载均衡配置变多的时候，IPVS能实现比iptables更高效的转发性能。

**如果我们使用的是cilium来完全替代kube-proxy，那么实际上就用不到ipvs和iptables，因此这一步理论上是可以跳过的。**

> 因为cilium需要升级系统内核，因此这里的内核版本高于4.19
> 注意在4.19之后的内核版本中使用`nf_conntrack`模块来替换了原有的`nf_conntrack_ipv4`模块
> (**Notes**: use `nf_conntrack` instead of `nf_conntrack_ipv4` for Linux kernel 4.19 and later)

```bash
# 在使用ipvs模式之前确保安装了ipset和ipvsadm
sudo yum install ipset ipvsadm -y

# 手动加载ipvs相关模块
modprobe -- ip_vs
modprobe -- ip_vs_rr
modprobe -- ip_vs_wrr
modprobe -- ip_vs_sh
modprobe -- nf_conntrack

# 配置开机自动加载ipvs相关模块
cat <<EOF | sudo tee /etc/modules-load.d/ipvs.conf
ip_vs
ip_vs_rr
ip_vs_wrr
ip_vs_sh
nf_conntrack
EOF

sudo sysctl --system
# 最好重启一遍系统确定是否生效

$ lsmod | grep -e ip_vs -e nf_conntrack
nf_conntrack_netlink    49152  0
nfnetlink              20480  2 nf_conntrack_netlink
ip_vs_sh               16384  0
ip_vs_wrr              16384  0
ip_vs_rr               16384  0
ip_vs                 159744  6 ip_vs_rr,ip_vs_sh,ip_vs_wrr
nf_conntrack          159744  5 xt_conntrack,nf_nat,nf_conntrack_netlink,xt_MASQUERADE,ip_vs
nf_defrag_ipv4         16384  1 nf_conntrack
nf_defrag_ipv6         24576  2 nf_conntrack,ip_vs
libcrc32c              16384  4 nf_conntrack,nf_nat,xfs,ip_vs
$ cut -f1 -d " "  /proc/modules | grep -e ip_vs -e nf_conntrack
nf_conntrack_netlink
ip_vs_sh
ip_vs_wrr
ip_vs_rr
ip_vs
nf_conntrack
```

## **1.12 配置Linux内核（cilium必选）**

cilium和其他的cni组件最大的不同在于其底层使用了ebpf技术，而该技术对于Linux的系统内核版本有较高的要求，完成的要求可以查看官网的[详细链接](https://link.zhihu.com/?target=https%3A//docs.cilium.io/en/latest/operations/system_requirements/)，这里我们着重看内核版本、内核参数这两个部分。

### **Linux内核版本**

默认情况下我们可以参考cilium官方给出的一个系统要求总结。因为我们是在k8s集群中部署（使用容器），因此只需要关注Linux内核版本和etcd版本即可。根据前面部署的经验我们可以知道1.23.6版本的k8s默认使用的etcd版本是`3.5.+`，因此重点就来到了Linux内核版本这里。

| Requirement            | Minimum Version | In cilium container |
| ---------------------- | --------------- | ------------------- |
| Linux kernel           | >= 4.9.17       | no                  |
| Key-Value store (etcd) | >= 3.1.0        | no                  |
| clang+LLVM             | >= 10.0         | yes                 |
| iproute2               | >= 5.9.0        | yes                 |

> This requirement is only needed if you run `cilium-agent` natively. If you are using the Cilium container image `cilium/cilium`, clang+LLVM is included in the container image.
> iproute2 is only needed if you run `cilium-agent` directly on the host machine. iproute2 is included in the `cilium/cilium` container image.

毫无疑问CentOS7内置的默认内核版本3.10.x版本的内核是无法满足需求的，但是在升级内核之前，我们再看看其他的一些要求。

cilium官方还给出了[一份列表](https://link.zhihu.com/?target=https%3A//docs.cilium.io/en/latest/operations/system_requirements/%23required-kernel-versions-for-advanced-features)描述了各项高级功能对内核版本的要求：

| Cilium Feature                                              | Minimum Kernel Version        |
| ----------------------------------------------------------- | ----------------------------- |
| IPv4 fragment handling                                      | >= 4.10                       |
| Restrictions on unique prefix lengths for CIDR policy rules | >= 4.11                       |
| IPsec Transparent Encryption in tunneling mode              | >= 4.19                       |
| WireGuard Transparent Encryption                            | >= 5.6                        |
| Host-Reachable Services                                     | >= 4.19.57, >= 5.1.16, >= 5.2 |
| Kubernetes Without kube-proxy                               | >= 4.19.57, >= 5.1.16, >= 5.2 |
| Bandwidth Manager                                           | >= 5.1                        |
| Local Redirect Policy (beta)                                | >= 4.19.57, >= 5.1.16, >= 5.2 |
| Full support for Session Affinity                           | >= 5.7                        |
| BPF-based proxy redirection                                 | >= 5.7                        |
| BPF-based host routing                                      | >= 5.10                       |
| Socket-level LB bypass in pod netns                         | >= 5.7                        |
| Egress Gateway (beta)                                       | >= 5.2                        |
| VXLAN Tunnel Endpoint (VTEP) Integration                    | >= 5.2                        |

可以看到如果需要满足上面所有需求的话，需要内核版本高于5.10，本着学习测试研究作死的精神，反正都升级了，干脆就升级到新一些的版本吧。这里我们可以直接[使用elrepo源来升级内核](https://link.zhihu.com/?target=https%3A//tinychen.com/20190612-centos-update-kernel/)到较新的内核版本。

```bash
# 查看elrepo源中支持的内核版本
$ yum --disablerepo="*" --enablerepo="elrepo-kernel" list available
Loaded plugins: fastestmirror
Loading mirror speeds from cached hostfile
Available Packages
elrepo-release.noarch                                                                   7.0-5.el7.elrepo                                                           elrepo-kernel
kernel-lt.x86_64                                                                        5.4.192-1.el7.elrepo                                                       elrepo-kernel
kernel-lt-devel.x86_64                                                                  5.4.192-1.el7.elrepo                                                       elrepo-kernel
kernel-lt-doc.noarch                                                                    5.4.192-1.el7.elrepo                                                       elrepo-kernel
kernel-lt-headers.x86_64                                                                5.4.192-1.el7.elrepo                                                       elrepo-kernel
kernel-lt-tools.x86_64                                                                  5.4.192-1.el7.elrepo                                                       elrepo-kernel
kernel-lt-tools-libs.x86_64                                                             5.4.192-1.el7.elrepo                                                       elrepo-kernel
kernel-lt-tools-libs-devel.x86_64                                                       5.4.192-1.el7.elrepo                                                       elrepo-kernel
kernel-ml.x86_64                                                                        5.17.6-1.el7.elrepo                                                        elrepo-kernel
kernel-ml-devel.x86_64                                                                  5.17.6-1.el7.elrepo                                                        elrepo-kernel
kernel-ml-doc.noarch                                                                    5.17.6-1.el7.elrepo                                                        elrepo-kernel
kernel-ml-headers.x86_64                                                                5.17.6-1.el7.elrepo                                                        elrepo-kernel
kernel-ml-tools.x86_64                                                                  5.17.6-1.el7.elrepo                                                        elrepo-kernel
kernel-ml-tools-libs.x86_64                                                             5.17.6-1.el7.elrepo                                                        elrepo-kernel
kernel-ml-tools-libs-devel.x86_64                                                       5.17.6-1.el7.elrepo                                                        elrepo-kernel
perf.x86_64                                                                             5.17.6-1.el7.elrepo                                                        elrepo-kernel
python-perf.x86_64                                                                      5.17.6-1.el7.elrepo                                                        elrepo-kernel

# 看起来ml版本的内核比较满足我们的需求,直接使用yum进行安装
sudo yum --enablerepo=elrepo-kernel install kernel-ml -y
# 使用grubby工具查看系统中已经安装的内核版本信息
sudo grubby --info=ALL
# 设置新安装的5.17.6版本内核为默认内核版本，此处的index=0要和上面查看的内核版本信息一致
sudo grubby --set-default-index=0
# 查看默认内核是否修改成功
sudo grubby --default-kernel
# 重启系统切换到新内核
init 6
# 重启后检查内核版本是否为新的5.17.6
uname -a
```

### **Linux内核参数**

首先我们查看自己当前内核版本的参数，基本上可以分为`y`、`n`、`m`三个选项

- y：yes，Build directly into the kernel. 表示该功能被编译进内核中，默认启用
- n：no，Leave entirely out of the kernel. 表示该功能未被编译进内核中，不启用
- m：module，Build as a module, to be loaded if needed. 表示该功能被编译为模块，按需启用

```text
# 查看当前使用的内核版本的编译参数
cat /boot/config-$(uname -r)
```

cilium官方对各项功能所需要开启的[内核参数列举](https://link.zhihu.com/?target=https%3A//docs.cilium.io/en/latest/operations/system_requirements/%23linux-kernel)如下：

> In order for the eBPF feature to be enabled properly, the following kernel configuration options must be enabled. This is typically the case with distribution kernels. When an option can be built as a module or statically linked, either choice is valid.
> 为了正确启用 eBPF 功能，必须启用以下内核配置选项。这通常因内核版本情况而异。任何一个选项都可以构建为模块或静态链接，两个选择都是有效的。

我们暂时只看最基本的`Base Requirements`

```text
CONFIG_BPF=y
CONFIG_BPF_SYSCALL=y
CONFIG_NET_CLS_BPF=y
CONFIG_BPF_JIT=y
CONFIG_NET_CLS_ACT=y
CONFIG_NET_SCH_INGRESS=y
CONFIG_CRYPTO_SHA1=y
CONFIG_CRYPTO_USER_API_HASH=y
CONFIG_CGROUPS=y
CONFIG_CGROUP_BPF=y
```

对比我们使用的`5.17.6-1.el7.elrepo.x86_64`内核可以发现有两个模块是为m

```bash
$ egrep "^CONFIG_BPF=|^CONFIG_BPF_SYSCALL=|^CONFIG_NET_CLS_BPF=|^CONFIG_BPF_JIT=|^CONFIG_NET_CLS_ACT=|^CONFIG_NET_SCH_INGRESS=|^CONFIG_CRYPTO_SHA1=|^CONFIG_CRYPTO_USER_API_HASH=|^CONFIG_CGROUPS=|^CONFIG_CGROUP_BPF=" /boot/config-5.17.6-1.el7.elrepo.x86_64
CONFIG_BPF=y
CONFIG_BPF_SYSCALL=y
CONFIG_BPF_JIT=y
CONFIG_CGROUPS=y
CONFIG_CGROUP_BPF=y
CONFIG_NET_SCH_INGRESS=m
CONFIG_NET_CLS_BPF=m
CONFIG_NET_CLS_ACT=y
CONFIG_CRYPTO_SHA1=y
CONFIG_CRYPTO_USER_API_HASH=y
```

缺少的这两个模块我们可以在`/usr/lib/modules/$(uname -r)`目录下面找到它们：

```bash
$ realpath ./kernel/net/sched/sch_ingress.ko
/usr/lib/modules/5.17.6-1.el7.elrepo.x86_64/kernel/net/sched/sch_ingress.ko
$ realpath ./kernel/net/sched/cls_bpf.ko
/usr/lib/modules/5.17.6-1.el7.elrepo.x86_64/kernel/net/sched/cls_bpf.ko
```

确认相关内核模块存在我们直接加载内核即可：

```bash
# 直接使用modprobe命令加载
$ modprobe cls_bpf
$ modprobe sch_ingress
$ lsmod | egrep "cls_bpf|sch_ingress"
sch_ingress            16384  0
cls_bpf                24576  0

# 配置开机自动加载cilium所需相关模块
cat <<EOF | sudo tee /etc/modules-load.d/cilium-base-requirements.conf
cls_bpf
sch_ingress
EOF
```

其他cilium高级功能所需要的内核功能也类似，这里不做赘述。

## 2、安装container runtime

## **2.1 安装containerd**

详细的官方文档可以参考[这里](https://link.zhihu.com/?target=https%3A//kubernetes.io/docs/setup/production-environment/container-runtimes/)，由于在刚发布的1.24版本中移除了`docker-shim`，因此安装的`版本≥1.24`的时候需要注意`容器运行时`的选择。这里我们安装的版本为最新的1.24，因此我们不能继续使用docker，这里我们将其换为[containerd](https://link.zhihu.com/?target=https%3A//kubernetes.io/docs/setup/production-environment/container-runtimes/%23containerd)

### **修改Linux内核参数**

```bash
# 首先生成配置文件确保配置持久化
cat <<EOF | sudo tee /etc/modules-load.d/containerd.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

# Setup required sysctl params, these persist across reboots.
cat <<EOF | sudo tee /etc/sysctl.d/99-kubernetes-cri.conf
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF

# Apply sysctl params without reboot
sudo sysctl --system
```

### **安装containerd**

centos7比较方便的部署方式是利用已有的yum源进行安装，这里我们可以使用docker官方的yum源来安装`containerd`

```bash
# 导入docker官方的yum源
sudo yum install -y yum-utils device-mapper-persistent-data lvm2

sudo yum-config-manager --add-repo  https://download.docker.com/linux/centos/docker-ce.repo

# 查看yum源中存在的各个版本的containerd.io
yum list containerd.io --showduplicates | sort -r

# 直接安装最新版本的containerd.io
yum install containerd.io -y

# 启动containerd
sudo systemctl start containerd

# 最后我们还要设置一下开机启动
sudo systemctl enable --now containerd
```

### **关于CRI**

官方表示，对于k8s来说，不需要安装`cri-containerd`，并且该功能会在后面的2.0版本中废弃。

> **FAQ**: For Kubernetes, do I need to download `cri-containerd-(cni-)<VERSION>-<OS-<ARCH>.tar.gz` too?
> **Answer**: No.
> As the Kubernetes CRI feature has been already included in `containerd-<VERSION>-<OS>-<ARCH>.tar.gz`, you do not need to download the `cri-containerd-....` archives to use CRI.
> The `cri-containerd-...` archives are [deprecated](https://link.zhihu.com/?target=https%3A//github.com/containerd/containerd/blob/main/RELEASES.md%23deprecated-features), do not work on old Linux distributions, and will be removed in containerd 2.0.

### **安装cni-plugins**

使用yum源安装的方式会把runc安装好，但是并不会安装cni-plugins，因此这部分还是需要我们自行安装。

> The `containerd.io` package contains runc too, but does not contain CNI plugins.

我们直接在[github上面](https://link.zhihu.com/?target=https%3A//github.com/containernetworking/plugins/releases)找到系统对应的架构版本，这里为amd64，然后解压即可。

```bash
# Download the cni-plugins-<OS>-<ARCH>-<VERSION>.tgz archive from https://github.com/containernetworking/plugins/releases , verify its sha256sum, and extract it under /opt/cni/bin:

# 下载源文件和sha512文件并校验
$ wget https://github.com/containernetworking/plugins/releases/download/v1.1.1/cni-plugins-linux-amd64-v1.1.1.tgz
$ wget https://github.com/containernetworking/plugins/releases/download/v1.1.1/cni-plugins-linux-amd64-v1.1.1.tgz.sha512
$ sha512sum -c cni-plugins-linux-amd64-v1.1.1.tgz.sha512

# 创建目录并解压
$ mkdir -p /opt/cni/bin
$ tar Cxzvf /opt/cni/bin cni-plugins-linux-amd64-v1.1.1.tgz
```



## **2.2 配置cgroup drivers**

CentOS7使用的是`systemd`来初始化系统并管理进程，初始化进程会生成并使用一个 root 控制组 (`cgroup`), 并充当 `cgroup` 管理器。 `Systemd` 与 `cgroup` 集成紧密，并将为每个 `systemd` 单元分配一个 `cgroup`。 我们也可以配置`容器运行时`和 `kubelet` 使用 `cgroupfs`。 连同 `systemd` 一起使用 `cgroupfs` 意味着将有两个不同的 `cgroup 管理器`。而当一个系统中同时存在cgroupfs和systemd两者时，容易变得不稳定，因此最好更改设置，令容器运行时和 kubelet 使用 `systemd` 作为 `cgroup` 驱动，以此使系统更为稳定。 对于`containerd`, 需要设置配置文件`/etc/containerd/config.toml`中的 `SystemdCgroup` 参数。

> 参考k8s官方的说明文档：
> [https://kubernetes.io/docs/setup/production-environment/container-runtimes/#containerd-systemd](https://link.zhihu.com/?target=https%3A//kubernetes.io/docs/setup/production-environment/container-runtimes/%23containerd-systemd)

```bash
[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc]
  ...
  [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
    SystemdCgroup = true
```

接下来我们开始配置containerd的cgroup driver

```bash
# 查看默认的配置文件，我们可以看到是没有启用systemd
$ containerd config default | grep SystemdCgroup
            SystemdCgroup = false
            
# 使用yum安装的containerd的配置文件非常简单
$ cat /etc/containerd/config.toml | egrep -v "^#|^$"
disabled_plugins = ["cri"]

# 导入一个完整版的默认配置文件模板为config.toml
$ mv /etc/containerd/config.toml /etc/containerd/config.toml.origin
$ containerd config default > /etc/containerd/config.toml
# 修改SystemdCgroup参数并重启
$ sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml
$ systemctl restart containerd

# 查看containerd状态的时候我们可以看到cni相关的报错
# 这是因为我们先安装了cni-plugins但是还没有安装k8s的cni插件
# 属于正常情况
$ systemctl status containerd -l
May 12 09:57:31 tiny-kubeproxy-free-master-18-1.k8s.tcinternal containerd[5758]: time="2022-05-12T09:57:31.100285056+08:00" level=error msg="failed to load cni during init, please check CRI plugin status before setting up network for pods" error="cni config load failed: no network config found in /etc/cni/net.d: cni plugin not initialized: failed to load cni config"
```



## **2.3 关于kubelet的cgroup driver**

k8s官方有[详细的文档](https://link.zhihu.com/?target=https%3A//kubernetes.io/docs/tasks/administer-cluster/kubeadm/configure-cgroup-driver/)介绍了如何设置kubelet的`cgroup driver`，需要特别注意的是，在1.22版本开始，如果没有手动设置kubelet的cgroup driver，那么默认会设置为systemd

> **Note:** In v1.22, if the user is not setting the `cgroupDriver` field under `KubeletConfiguration`, `kubeadm` will default it to `systemd`.

一个比较简单的指定kubelet的`cgroup driver`的方法就是在`kubeadm-config.yaml`加入`cgroupDriver`字段

```yaml
# kubeadm-config.yaml
kind: ClusterConfiguration
apiVersion: kubeadm.k8s.io/v1beta3
kubernetesVersion: v1.21.0
---
kind: KubeletConfiguration
apiVersion: kubelet.config.k8s.io/v1beta1
cgroupDriver: systemd
```

我们可以直接查看configmaps来查看初始化之后集群的kubeadm-config配置。

```text
$ kubectl describe configmaps kubeadm-config -n kube-system
Name:         kubeadm-config
Namespace:    kube-system
Labels:       <none>
Annotations:  <none>

Data
====
ClusterConfiguration:
----
apiServer:
  extraArgs:
    authorization-mode: Node,RBAC
  timeoutForControlPlane: 4m0s
apiVersion: kubeadm.k8s.io/v1beta3
certificatesDir: /etc/kubernetes/pki
clusterName: kubernetes
controllerManager: {}
dns: {}
etcd:
  local:
    dataDir: /var/lib/etcd
imageRepository: registry.aliyuncs.com/google_containers
kind: ClusterConfiguration
kubernetesVersion: v1.23.6
networking:
  dnsDomain: cali-cluster.tclocal
  serviceSubnet: 10.88.0.0/18
scheduler: {}


BinaryData
====

Events:  <none>
```

当然因为我们需要安装的版本高于1.22.0并且使用的就是systemd，因此可以不用再重复配置。

## 3、安装kube三件套

> 对应的官方文档可以参考这里
> [https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/#installing-kubeadm-kubelet-and-kubectl](https://link.zhihu.com/?target=https%3A//kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/%23installing-kubeadm-kubelet-and-kubectl)

kube三件套就是`kubeadm`、`kubelet` 和 `kubectl`，三者的具体功能和作用如下：

- `kubeadm`：用来初始化集群的指令。
- `kubelet`：在集群中的每个节点上用来启动 Pod 和容器等。
- `kubectl`：用来与集群通信的命令行工具。

需要注意的是：

- `kubeadm`不会帮助我们管理`kubelet`和`kubectl`，其他两者也是一样的，也就是说这三者是相互独立的，并不存在谁管理谁的情况；
- `kubelet`的版本必须小于等于`API-server`的版本，否则容易出现兼容性的问题；
- `kubectl`并不是集群中的每个节点都需要安装，也并不是一定要安装在集群中的节点，可以单独安装在自己本地的机器环境上面，然后配合`kubeconfig`文件即可使用`kubectl`命令来远程管理对应的k8s集群；

CentOS7的安装比较简单，我们直接使用官方提供的`yum`源即可。需要注意的是这里需要设置`selinux`的状态，但是前面我们已经关闭了selinux，因此这里略过这步。

```bash
# 直接导入谷歌官方的yum源
cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-\$basearch
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
exclude=kubelet kubeadm kubectl
EOF

# 当然如果连不上谷歌的源，可以考虑使用国内的阿里镜像源
cat <<EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-x86_64/
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://mirrors.aliyun.com/kubernetes/yum/doc/yum-key.gpg https://mirrors.aliyun.com/kubernetes/yum/doc/rpm-package-key.gpg
EOF


# 接下来直接安装三件套即可
sudo yum install -y kubelet kubeadm kubectl --disableexcludes=kubernetes

# 如果网络环境不好出现gpgcheck验证失败导致无法正常读取yum源，可以考虑关闭该yum源的repo_gpgcheck
sed -i 's/repo_gpgcheck=1/repo_gpgcheck=0/g' /etc/yum.repos.d/kubernetes.repo
# 或者在安装的时候禁用gpgcheck
sudo yum install -y kubelet kubeadm kubectl --nogpgcheck --disableexcludes=kubernetes

# 如果想要安装特定版本，可以使用这个命令查看相关版本的信息
sudo yum list --nogpgcheck kubelet kubeadm kubectl --showduplicates --disableexcludes=kubernetes


# 安装完成后配置开机自启kubelet
sudo systemctl enable --now kubelet
```

## 4、初始化集群

## **4.1 编写配置文件**

在集群中所有节点都执行完上面的三点操作之后，我们就可以开始创建k8s集群了。因为我们这次不涉及高可用部署，因此初始化的时候直接在我们的目标master节点上面操作即可。

```bash
# 我们先使用kubeadm命令查看一下主要的几个镜像版本
$ kubeadm config images list
k8s.gcr.io/kube-apiserver:v1.24.0
k8s.gcr.io/kube-controller-manager:v1.24.0
k8s.gcr.io/kube-scheduler:v1.24.0
k8s.gcr.io/kube-proxy:v1.24.0
k8s.gcr.io/pause:3.7
k8s.gcr.io/etcd:3.5.3-0
k8s.gcr.io/coredns/coredns:v1.8.6

# 为了方便编辑和管理，我们还是把初始化参数导出成配置文件
$ kubeadm config print init-defaults > kubeadm-kubeproxy-free.conf
```

- 考虑到大多数情况下国内的网络无法使用谷歌的[http://k8s.gcr.io](https://link.zhihu.com/?target=http%3A//k8s.gcr.io)镜像源，我们可以直接在配置文件中修改`imageRepository`参数为阿里的镜像源
- `kubernetesVersion`字段用来指定我们要安装的k8s版本
- `localAPIEndpoint`参数需要修改为我们的master节点的IP和端口，初始化之后的k8s集群的apiserver地址就是这个
- `criSocket`从1.24.0版本开始已经默认变成了`containerd`
- `podSubnet`、`serviceSubnet`和`dnsDomain`两个参数默认情况下可以不用修改，这里我按照自己的需求进行了变更
- `nodeRegistration`里面的`name`参数修改为对应master节点的`hostname`
- 新增配置块使用ipvs，具体可以参考[官方文档](https://link.zhihu.com/?target=https%3A//github.com/kubernetes/kubernetes/blob/master/pkg/proxy/ipvs/README.md%23cluster-created-by-kubeadm)

```yaml
apiVersion: kubeadm.k8s.io/v1beta3
bootstrapTokens:
- groups:
  - system:bootstrappers:kubeadm:default-node-token
  token: abcdef.0123456789abcdef
  ttl: 24h0m0s
  usages:
  - signing
  - authentication
kind: InitConfiguration
localAPIEndpoint:
  advertiseAddress: 10.31.18.1
  bindPort: 6443
nodeRegistration:
  criSocket: unix:///var/run/containerd/containerd.sock
  imagePullPolicy: IfNotPresent
  name: tiny-kubeproxy-free-master-18-1.k8s.tcinternal
  taints: null
---
apiServer:
  timeoutForControlPlane: 4m0s
apiVersion: kubeadm.k8s.io/v1beta3
certificatesDir: /etc/kubernetes/pki
clusterName: kubernetes
controllerManager: {}
dns: {}
etcd:
  local:
    dataDir: /var/lib/etcd
imageRepository: registry.aliyuncs.com/google_containers
kind: ClusterConfiguration
kubernetesVersion: 1.24.0
networking:
  dnsDomain: free-cluster.tclocal
  serviceSubnet: 10.18.0.0/18
  podSubnet: 10.18.64.0/18
scheduler: {}
---
apiVersion: kubeproxy.config.k8s.io/v1alpha1
kind: KubeProxyConfiguration
mode: ipvs
```

## **4.2 初始化集群**

此时我们再查看对应的配置文件中的镜像版本，就会发现已经变成了对应阿里云镜像源的版本

参考cilium官方的[教程](https://link.zhihu.com/?target=https%3A//docs.cilium.io/en/stable/gettingstarted/kubeproxy-free/%23quick-start)我们可以在集群初始化的时候添加参数`--skip-phases=addon/kube-proxy`跳过kube-proxy的安装

```bash
# 查看一下对应的镜像版本，确定配置文件是否生效
$ kubeadm config images list --config  kubeadm-kubeproxy-free.conf
registry.aliyuncs.com/google_containers/kube-apiserver:v1.24.0
registry.aliyuncs.com/google_containers/kube-controller-manager:v1.24.0
registry.aliyuncs.com/google_containers/kube-scheduler:v1.24.0
registry.aliyuncs.com/google_containers/kube-proxy:v1.24.0
registry.aliyuncs.com/google_containers/pause:3.7
registry.aliyuncs.com/google_containers/etcd:3.5.3-0
registry.aliyuncs.com/google_containers/coredns:v1.8.6

# 确认没问题之后我们直接拉取镜像
$ kubeadm config images pull --config kubeadm-kubeproxy-free.conf
[config/images] Pulled registry.aliyuncs.com/google_containers/kube-apiserver:v1.24.0
[config/images] Pulled registry.aliyuncs.com/google_containers/kube-controller-manager:v1.24.0
[config/images] Pulled registry.aliyuncs.com/google_containers/kube-scheduler:v1.24.0
[config/images] Pulled registry.aliyuncs.com/google_containers/kube-proxy:v1.24.0
[config/images] Pulled registry.aliyuncs.com/google_containers/pause:3.7
[config/images] Pulled registry.aliyuncs.com/google_containers/etcd:3.5.3-0
[config/images] Pulled registry.aliyuncs.com/google_containers/coredns:v1.8.6

# 初始化，注意添加参数跳过kube-proxy的安装
$ kubeadm init --config kubeadm-kubeproxy-free.conf --skip-phases=addon/kube-proxy
[init] Using Kubernetes version: v1.24.0
[preflight] Running pre-flight checks
[preflight] Pulling images required for setting up a Kubernetes cluster
[preflight] This might take a minute or two, depending on the speed of your internet connection
[preflight] You can also perform this action in beforehand using 'kubeadm config images pull'
...此处略去一堆输出...
```

当我们看到下面这个输出结果的时候，我们的集群就算是初始化成功了。

```bash
Your Kubernetes control-plane has initialized successfully!

To start using your cluster, you need to run the following as a regular user:

  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config

Alternatively, if you are the root user, you can run:

  export KUBECONFIG=/etc/kubernetes/admin.conf

You should now deploy a pod network to the cluster.
Run "kubectl apply -f [podnetwork].yaml" with one of the options listed at:
  https://kubernetes.io/docs/concepts/cluster-administration/addons/

Then you can join any number of worker nodes by running the following on each as root:

kubeadm join 10.31.18.1:6443 --token abcdef.0123456789abcdef \
        --discovery-token-ca-cert-hash sha256:7772f5461bdf4dc399618dc226e2d718d35f14b079e904cd68a5b148eaefcbdd
```

## **4.3 配置kubeconfig**

刚初始化成功之后，我们还没办法马上查看k8s集群信息，需要配置kubeconfig相关参数才能正常使用kubectl连接apiserver读取集群信息。

```bash
 # 对于非root用户，可以这样操作
 mkdir -p $HOME/.kube
 sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
 sudo chown $(id -u):$(id -g) $HOME/.kube/config
 
 # 如果是root用户，可以直接导入环境变量
 export KUBECONFIG=/etc/kubernetes/admin.conf
 
 # 添加kubectl的自动补全功能
 echo "source <(kubectl completion bash)" >> ~/.bashrc
```

> 前面我们提到过`kubectl`不一定要安装在集群内，实际上只要是任何一台能连接到`apiserver`的机器上面都可以安装`kubectl`并且根据步骤配置`kubeconfig`，就可以使用`kubectl`命令行来管理对应的k8s集群。

配置完成后，我们再执行相关命令就可以查看集群的信息了。

```bash
 $ kubectl cluster-info
 Kubernetes control plane is running at https://10.31.18.1:6443
 CoreDNS is running at https://10.31.18.1:6443/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy
 
 To further debug and diagnose cluster problems, use 'kubectl cluster-info dump'.
 
 
 $ kubectl get nodes -o wide
 NAME                                             STATUS     ROLES           AGE     VERSION   INTERNAL-IP   EXTERNAL-IP   OS-IMAGE                KERNEL-VERSION               CONTAINER-RUNTIME
 tiny-kubeproxy-free-master-18-1.k8s.tcinternal   NotReady   control-plane   2m46s   v1.24.0   10.31.18.1    <none>        CentOS Linux 7 (Core)   5.17.6-1.el7.elrepo.x86_64   containerd://1.6.4
 
 $ kubectl get pods -A -o wide
 NAMESPACE     NAME                                                                     READY   STATUS    RESTARTS   AGE     IP           NODE
           NOMINATED NODE   READINESS GATES
 kube-system   coredns-74586cf9b6-shpt4                                                 0/1     Pending   0          2m42s   <none>       <none>
           <none>           <none>
 kube-system   coredns-74586cf9b6-wgvgm                                                 0/1     Pending   0          2m42s   <none>       <none>
           <none>           <none>
 kube-system   etcd-tiny-kubeproxy-free-master-18-1.k8s.tcinternal                      1/1     Running   0          2m56s   10.31.18.1   tiny-kubeproxy-free-master-18-1.k8s.tcinternal   <none>           <none>
 kube-system   kube-apiserver-tiny-kubeproxy-free-master-18-1.k8s.tcinternal            1/1     Running   0          2m57s   10.31.18.1   tiny-kubeproxy-free-master-18-1.k8s.tcinternal   <none>           <none>
 kube-system   kube-controller-manager-tiny-kubeproxy-free-master-18-1.k8s.tcinternal   1/1     Running   0          2m55s   10.31.18.1   tiny-kubeproxy-free-master-18-1.k8s.tcinternal   <none>           <none>
 kube-system   kube-scheduler-tiny-kubeproxy-free-master-18-1.k8s.tcinternal            1/1     Running   0          2m55s   10.31.18.1   tiny-kubeproxy-free-master-18-1.k8s.tcinternal   <none>           <none>
 
 # 这时候查看daemonset可以看到是没有kube-proxy的
 $ kubectl get ds -A
 No resources found
```

## **4.4 添加worker节点**

这时候我们还需要继续添加剩下的两个节点作为worker节点运行负载，直接在剩下的节点上面运行集群初始化成功时输出的命令就可以成功加入集群。

因为我们前面的kubeadm初始化master节点的时候没有启用kube-proxy，所以在添加节点的时候会出现警告，但是不影响我们继续添加节点。

```bash
$ kubeadm join 10.31.18.1:6443 --token abcdef.0123456789abcdef \
>         --discovery-token-ca-cert-hash sha256:7772f5461bdf4dc399618dc226e2d718d35f14b079e904cd68a5b148eaefcbdd
[preflight] Running pre-flight checks
[preflight] Reading configuration from the cluster...
[preflight] FYI: You can look at this config file with 'kubectl -n kube-system get cm kubeadm-config -o yaml'
W0512 10:34:36.673112    7960 configset.go:78] Warning: No kubeproxy.config.k8s.io/v1alpha1 config is loaded. Continuing without it: configmaps "kube-proxy" is forbidden: User "system:bootstrap:abcdef" cannot get resource "configmaps" in API group "" in the namespace "kube-system"
[kubelet-start] Writing kubelet configuration to file "/var/lib/kubelet/config.yaml"
[kubelet-start] Writing kubelet environment file with flags to file "/var/lib/kubelet/kubeadm-flags.env"
[kubelet-start] Starting the kubelet
[kubelet-start] Waiting for the kubelet to perform the TLS Bootstrap...

This node has joined the cluster:
* Certificate signing request was sent to apiserver and a response was received.
* The Kubelet was informed of the new secure connection details.

Run 'kubectl get nodes' on the control-plane to see this node join the cluster.
```

如果不小心没保存初始化成功的输出信息也没有关系，我们可以使用kubectl工具查看或者生成token

```bash
# 查看现有的token列表
$ kubeadm token list
TOKEN                     TTL         EXPIRES                USAGES                   DESCRIPTION                                                EXTRA GROUPS
abcdef.0123456789abcdef   23h         2022-05-13T02:28:58Z   authentication,signing   <none>                                                     system:bootstrappers:kubeadm:default-node-token

# 如果token已经失效，那就再创建一个新的token
$ kubeadm token create
ri4jzg.wkn47l10cjvefep5
$ kubeadm token list
TOKEN                     TTL         EXPIRES                USAGES                   DESCRIPTION                                                EXTRA GROUPS
abcdef.0123456789abcdef   23h         2022-05-13T02:28:58Z   authentication,signing   <none>                                                     system:bootstrappers:kubeadm:default-node-token
ri4jzg.wkn47l10cjvefep5   23h         2022-05-13T02:40:15Z   authentication,signing   <none>                                                     system:bootstrappers:kubeadm:default-node-token

# 如果找不到--discovery-token-ca-cert-hash参数，则可以在master节点上使用openssl工具来获取
$ openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt | openssl rsa -pubin -outform der 2>/dev/null | openssl dgst -sha256 -hex | sed 's/^.* //'
7772f5461bdf4dc399618dc226e2d718d35f14b079e904cd68a5b148eaefcbdd
```



添加完成之后我们再查看集群的节点可以发现这时候已经多了两个node，但是此时节点的状态还是`NotReady`，接下来就需要部署CNI了。

```bash
$ kubectl get nodes
NAME                                              STATUS     ROLES           AGE     VERSION
tiny-kubeproxy-free-master-18-1.k8s.tcinternal    NotReady   control-plane   11m     v1.24.0
tiny-kubeproxy-free-worker-18-11.k8s.tcinternal   NotReady   <none>          5m57s   v1.24.0
tiny-kubeproxy-free-worker-18-12.k8s.tcinternal   NotReady   <none>          65s     v1.24.0
```

## 5、安装CNI

## **5.1 部署helm3**

cilium的部署依赖helm3，因此我们在部署cilium之前需要先[安装helm3](https://link.zhihu.com/?target=https%3A//helm.sh/docs/intro/install/)。

helm3的部署非常的简单，我们只要去[GitHub](https://link.zhihu.com/?target=https%3A//github.com/helm/helm/releases)找到对应系统版本的二进制文件，下载解压后放到系统的执行目录就可以使用了。

```bash
$ wget https://get.helm.sh/helm-v3.8.2-linux-amd64.tar.gz
$ tar -zxvf helm-v3.8.2-linux-amd64.tar.gz
$ cp -rp linux-amd64/helm /usr/local/bin/
$ helm version
version.BuildInfo{Version:"v3.8.2", GitCommit:"6e3701edea09e5d55a8ca2aae03a68917630e91b", GitTreeState:"clean", GoVersion:"go1.17.5"}
```

## **5.2 部署cilium**

完整的部署指南可以[参考官方文档](https://link.zhihu.com/?target=https%3A//docs.cilium.io/en/stable/gettingstarted/kubeproxy-free/)，首先我们添加helm的repo。

```bash
$ helm repo add cilium https://helm.cilium.io/
"cilium" has been added to your repositories
$ helm repo list
NAME    URL
cilium  https://helm.cilium.io/
```

参考官网的文档，这里我们需要指定集群的APIserver的IP和端口

```text
 helm install cilium ./cilium \
     --namespace kube-system \
     --set kubeProxyReplacement=strict \
     --set k8sServiceHost=REPLACE_WITH_API_SERVER_IP \
     --set k8sServicePort=REPLACE_WITH_API_SERVER_PORT
```

但是考虑到cilium默认使用的`podCIDR`为`10.0.0.0/8`，很可能会和我们集群内的网络冲突，最好的方案就是初始化的时候指定`podCIDR`，关于初始化的时候podCIDR的设置，可以参考官方的这个[文章](https://link.zhihu.com/?target=https%3A//docs.cilium.io/en/stable/gettingstarted/ipam-cluster-pool/)。

```text
helm install cilium cilium/cilium --version 1.11.4 \
    --namespace kube-system \
    --set kubeProxyReplacement=strict \
    --set k8sServiceHost=REPLACE_WITH_API_SERVER_IP \
    --set k8sServicePort=REPLACE_WITH_API_SERVER_PORT \
	--set ipam.operator.clusterPoolIPv4PodCIDRList=<IPv4CIDR> \
	--set ipam.operator.clusterPoolIPv4MaskSize=<IPv4MaskSize>
```

最后可以得到我们的初始化安装参数

```text
helm install cilium cilium/cilium --version 1.11.4 \
    --namespace kube-system \
    --set kubeProxyReplacement=strict \
    --set k8sServiceHost=10.31.18.1 \
    --set k8sServicePort=6443 \
	--set ipam.operator.clusterPoolIPv4PodCIDRList=10.18.64.0/18 \
	--set ipam.operator.clusterPoolIPv4MaskSize=24
```

然后我们使用指令进行安装

```bash
$ helm install cilium cilium/cilium --version 1.11.4 --namespace kube-system     --set kubeProxyReplacement=strict --set k8sServiceHost=10.31.18.1 --set k8sServicePort=6443 --set ipam.operator.clusterPoolIPv4PodCIDRList=10.18.64.0/18 --set ipam.operator.clusterPoolIPv4MaskSize=24
W0512 11:03:06.636996    8753 warnings.go:70] spec.template.spec.affinity.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution.nodeSelectorTerms[1].matchExpressions[0].key: beta.kubernetes.io/os is deprecated since v1.14; use "kubernetes.io/os" instead
W0512 11:03:06.637058    8753 warnings.go:70] spec.template.metadata.annotations[scheduler.alpha.kubernetes.io/critical-pod]: non-functional in v1.16+; use the "priorityClassName" field instead
NAME: cilium
LAST DEPLOYED: Thu May 12 11:03:04 2022
NAMESPACE: kube-system
STATUS: deployed
REVISION: 1
TEST SUITE: None
NOTES:
You have successfully installed Cilium with Hubble.

Your release version is 1.11.4.

For any further help, visit https://docs.cilium.io/en/v1.11/gettinghelp
```

此时我们再查看集群的daemonset和deployment状态：

```bash
# 这时候查看集群的daemonset和deployment状态可以看到cilium相关的服务已经正常
$ kubectl get ds -A
NAMESPACE     NAME     DESIRED   CURRENT   READY   UP-TO-DATE   AVAILABLE   NODE SELECTOR   AGE
kube-system   cilium   3         3         3       3            3           <none>          4m57s
$ kubectl get deploy -A
NAMESPACE     NAME              READY   UP-TO-DATE   AVAILABLE   AGE
kube-system   cilium-operator   2/2     2            2           5m4s
kube-system   coredns           2/2     2            2           39m
```

再查看所有的pod，状态都正常，ip也和我们初始化的时候分配的ip段一致，说明初始化的参数设置生效了。

```bash
# 再查看所有的pod，状态都正常，ip按预期进行了分配
$ kubectl get pods -A -o wide
NAMESPACE     NAME                                                                     READY   STATUS    RESTARTS   AGE     IP             NODE
             NOMINATED NODE   READINESS GATES
kube-system   cilium-97fn7                                                             1/1     Running   0          7m14s   10.31.18.11    tiny-kubeproxy-free-worker-18-11.k8s.tcinternal   <none>           <none>
kube-system   cilium-k2gxc                                                             1/1     Running   0          7m14s   10.31.18.12    tiny-kubeproxy-free-worker-18-12.k8s.tcinternal   <none>           <none>
kube-system   cilium-operator-86884f4747-c2ps5                                         1/1     Running   0          7m14s   10.31.18.12    tiny-kubeproxy-free-worker-18-12.k8s.tcinternal   <none>           <none>
kube-system   cilium-operator-86884f4747-zrm4m                                         1/1     Running   0          7m14s   10.31.18.11    tiny-kubeproxy-free-worker-18-11.k8s.tcinternal   <none>           <none>
kube-system   cilium-t69js                                                             1/1     Running   0          7m14s   10.31.18.1     tiny-kubeproxy-free-master-18-1.k8s.tcinternal    <none>           <none>
kube-system   coredns-74586cf9b6-shpt4                                                 1/1     Running   0          41m     10.18.65.64    tiny-kubeproxy-free-master-18-1.k8s.tcinternal    <none>           <none>
kube-system   coredns-74586cf9b6-wgvgm                                                 1/1     Running   0          41m     10.18.65.237   tiny-kubeproxy-free-master-18-1.k8s.tcinternal    <none>           <none>
kube-system   etcd-tiny-kubeproxy-free-master-18-1.k8s.tcinternal                      1/1     Running   0          41m     10.31.18.1     tiny-kubeproxy-free-master-18-1.k8s.tcinternal    <none>           <none>
kube-system   kube-apiserver-tiny-kubeproxy-free-master-18-1.k8s.tcinternal            1/1     Running   0          41m     10.31.18.1     tiny-kubeproxy-free-master-18-1.k8s.tcinternal    <none>           <none>
kube-system   kube-controller-manager-tiny-kubeproxy-free-master-18-1.k8s.tcinternal   1/1     Running   0          41m     10.31.18.1     tiny-kubeproxy-free-master-18-1.k8s.tcinternal    <none>           <none>
kube-system   kube-scheduler-tiny-kubeproxy-free-master-18-1.k8s.tcinternal            1/1     Running   0          41m     10.31.18.1     tiny-kubeproxy-free-master-18-1.k8s.tcinternal    <none>           <none>
```

这时候我们再进入pod中检查cilium的状态

```bash
# --verbose参数可以查看详细的状态信息
# cilium-97fn7需要替换为任意一个cilium的pod
$ kubectl exec -it -n kube-system cilium-97fn7 -- cilium status --verbose
Defaulted container "cilium-agent" out of: cilium-agent, mount-cgroup (init), clean-cilium-state (init)
KVStore:                Ok   Disabled
Kubernetes:             Ok   1.24 (v1.24.0) [linux/amd64]
Kubernetes APIs:        ["cilium/v2::CiliumClusterwideNetworkPolicy", "cilium/v2::CiliumEndpoint", "cilium/v2::CiliumNetworkPolicy", "cilium/v2::CiliumNode", "core/v1::Namespace", "core/v1::Node", "core/v1::Pods", "core/v1::Service", "discovery/v1::EndpointSlice", "networking.k8s.io/v1::NetworkPolicy"]
KubeProxyReplacement:   Strict   [eth0 10.31.18.11 (Direct Routing)]
Host firewall:          Disabled
Cilium:                 Ok   1.11.4 (v1.11.4-9d25463)
NodeMonitor:            Listening for events on 8 CPUs with 64x4096 of shared memory
Cilium health daemon:   Ok
IPAM:                   IPv4: 2/254 allocated from 10.18.66.0/24,
Allocated addresses:
  10.18.66.223 (health)
  10.18.66.232 (router)
BandwidthManager:       Disabled
Host Routing:           Legacy
Masquerading:           IPTables [IPv4: Enabled, IPv6: Disabled]
Clock Source for BPF:   ktime
Controller Status:      21/21 healthy
  Name                                                                          Last success   Last error   Count   Message
  bpf-map-sync-cilium_ipcache                                                   3s ago         8m59s ago    0       no error
  cilium-health-ep                                                              41s ago        never        0       no error
  dns-garbage-collector-job                                                     59s ago        never        0       no error
  endpoint-2503-regeneration-recovery                                           never          never        0       no error
  endpoint-82-regeneration-recovery                                             never          never        0       no error
  endpoint-gc                                                                   3m59s ago      never        0       no error
  ipcache-inject-labels                                                         8m49s ago      8m53s ago    0       no error
  k8s-heartbeat                                                                 29s ago        never        0       no error
  mark-k8s-node-as-available                                                    8m41s ago      never        0       no error
  metricsmap-bpf-prom-sync                                                      4s ago         never        0       no error
  resolve-identity-2503                                                         3m41s ago      never        0       no error
  resolve-identity-82                                                           3m42s ago      never        0       no error
  sync-endpoints-and-host-ips                                                   42s ago        never        0       no error
  sync-lb-maps-with-k8s-services                                                8m42s ago      never        0       no error
  sync-node-with-ciliumnode (tiny-kubeproxy-free-worker-18-11.k8s.tcinternal)   8m53s ago      8m55s ago    0       no error
  sync-policymap-2503                                                           33s ago        never        0       no error
  sync-policymap-82                                                             30s ago        never        0       no error
  sync-to-k8s-ciliumendpoint (2503)                                             11s ago        never        0       no error
  sync-to-k8s-ciliumendpoint (82)                                               2s ago         never        0       no error
  template-dir-watcher                                                          never          never        0       no error
  update-k8s-node-annotations                                                   8m53s ago      never        0       no error
Proxy Status:   OK, ip 10.18.66.232, 0 redirects active on ports 10000-20000
Hubble:         Ok   Current/Max Flows: 422/4095 (10.31%), Flows/s: 0.75   Metrics: Disabled
KubeProxyReplacement Details:
  Status:                 Strict
  Socket LB Protocols:    TCP, UDP
  Devices:                eth0 10.31.18.11 (Direct Routing)
  Mode:                   SNAT
  Backend Selection:      Random
  Session Affinity:       Enabled
  Graceful Termination:   Enabled
  XDP Acceleration:       Disabled
  Services:
  - ClusterIP:      Enabled
  - NodePort:       Enabled (Range: 30000-32767)
  - LoadBalancer:   Enabled
  - externalIPs:    Enabled
  - HostPort:       Enabled
BPF Maps:   dynamic sizing: on (ratio: 0.002500)
  Name                          Size
  Non-TCP connection tracking   65536
  TCP connection tracking       131072
  Endpoint policy               65535
  Events                        8
  IP cache                      512000
  IP masquerading agent         16384
  IPv4 fragmentation            8192
  IPv4 service                  65536
  IPv6 service                  65536
  IPv4 service backend          65536
  IPv6 service backend          65536
  IPv4 service reverse NAT      65536
  IPv6 service reverse NAT      65536
  Metrics                       1024
  NAT                           131072
  Neighbor table                131072
  Global policy                 16384
  Per endpoint policy           65536
  Session affinity              65536
  Signal                        8
  Sockmap                       65535
  Sock reverse NAT              65536
  Tunnel                        65536
Encryption:                                                     Disabled
Cluster health:                                                 3/3 reachable   (2022-05-12T03:12:22Z)
  Name                                                          IP              Node        Endpoints
  tiny-kubeproxy-free-worker-18-11.k8s.tcinternal (localhost)   10.31.18.11     reachable   reachable
  tiny-kubeproxy-free-master-18-1.k8s.tcinternal                10.31.18.1      reachable   reachable
  tiny-kubeproxy-free-worker-18-12.k8s.tcinternal               10.31.18.12     reachable   reachable
```

其实到这里cilium的部署就可以说是ok了的，整个集群的cni都处于正常状态，其余的工作负载也都能够正常运行了。

## **5.3 部署hubble**

cilium还有一大特点就是其可观测性比其他的cni要优秀很多，想要体验到cilium的可观测性，我们就需要在k8s集群中[安装hubble](https://link.zhihu.com/?target=https%3A//docs.cilium.io/en/stable/gettingstarted/hubble_setup/%23hubble-setup)。同时hubble提供了ui界面来更好的实现集群内网络的可观测性，这里我们也一并把`hubble-ui`安装上。

### **helm3安装hubble**

我们继续接着上面的helm3来安装hubble，因为我们已经安装了cilium，因此这里需要使用`upgrade`来进行升级安装，并且使用`--reuse-values`来复用之前的安装参数

```bash
helm upgrade cilium cilium/cilium --version 1.11.4 \
   --namespace kube-system \
   --reuse-values \
   --set hubble.relay.enabled=true \
   --set hubble.ui.enabled=true
```

然后我们直接进行安装

```bash
$ helm upgrade cilium cilium/cilium --version 1.11.4 \
>    --namespace kube-system \
>    --reuse-values \
>    --set hubble.relay.enabled=true \
>    --set hubble.ui.enabled=true
Release "cilium" has been upgraded. Happy Helming!
NAME: cilium
LAST DEPLOYED: Thu May 12 11:34:43 2022
NAMESPACE: kube-system
STATUS: deployed
REVISION: 2
TEST SUITE: None
NOTES:
You have successfully installed Cilium with Hubble Relay and Hubble UI.

Your release version is 1.11.4.

For any further help, visit https://docs.cilium.io/en/v1.11/gettinghelp
```

随后我们查看相关的集群状态，可以看到相对应的pod、deploy和svc都工作正常

```bash
$ kubectl get pod -A | grep hubble
kube-system   hubble-relay-cdf4c8cdd-wgdqg                                             1/1     Running   0          66s
kube-system   hubble-ui-86856f9f6c-vw8lt                                               3/3     Running   0          66s
$ kubectl get deploy -A | grep hubble
kube-system   hubble-relay      1/1     1            1           74s
kube-system   hubble-ui         1/1     1            1           74s
$ kubectl get svc -A | grep hubble
kube-system   hubble-relay   ClusterIP   10.18.58.2     <none>        80/TCP                   82s
kube-system   hubble-ui      ClusterIP   10.18.22.156   <none>        80/TCP                   82s
```

### **cilium-cli安装hubble**

使用cilium-cli功能来安装hubble也非常简单：

```bash
# 首先安装cilium-cli工具
# cilium的cli工具是一个二进制的可执行文件
$ curl -L --remote-name-all https://github.com/cilium/cilium-cli/releases/latest/download/cilium-linux-amd64.tar.gz{,.sha256sum}
$ sha256sum --check cilium-linux-amd64.tar.gz.sha256sum
cilium-linux-amd64.tar.gz: OK
$ sudo tar xzvfC cilium-linux-amd64.tar.gz /usr/local/bin
cilium

# 然后直接启用hubble
$ cilium hubble enable
# 再启用hubble-ui
$ cilium hubble enable --ui
# 接着查看cilium状态
$ cilium status
    /¯¯\
 /¯¯\__/¯¯\    Cilium:         OK
 \__/¯¯\__/    Operator:       OK
 /¯¯\__/¯¯\    Hubble:         OK
 \__/¯¯\__/    ClusterMesh:    disabled
    \__/

Deployment        cilium-operator    Desired: 2, Ready: 2/2, Available: 2/2
Deployment        hubble-relay       Desired: 1, Ready: 1/1, Available: 1/1
Deployment        hubble-ui          Desired: 1, Ready: 1/1, Available: 1/1
DaemonSet         cilium             Desired: 3, Ready: 3/3, Available: 3/3
Containers:       cilium             Running: 3
                  cilium-operator    Running: 2
                  hubble-relay       Running: 1
                  hubble-ui          Running: 1
Cluster Pods:     4/4 managed by Cilium
Image versions    hubble-relay       quay.io/cilium/hubble-relay:v1.11.4@sha256:460d50bd0c6bcdfa3c62b0488541c102a4079f5def07d2649ff67bc24fd0dd3f: 1
                  hubble-ui          quay.io/cilium/hubble-ui:v0.8.5@sha256:4eaca1ec1741043cfba6066a165b3bf251590cf4ac66371c4f63fbed2224ebb4: 1
                  hubble-ui          quay.io/cilium/hubble-ui-backend:v0.8.5@sha256:2bce50cf6c32719d072706f7ceccad654bfa907b2745a496da99610776fe31ed: 1
                  hubble-ui          docker.io/envoyproxy/envoy:v1.18.4@sha256:e5c2bb2870d0e59ce917a5100311813b4ede96ce4eb0c6bfa879e3fbe3e83935: 1
                  cilium             quay.io/cilium/cilium:v1.11.4@sha256:d9d4c7759175db31aa32eaa68274bb9355d468fbc87e23123c80052e3ed63116: 3
                  cilium-operator    quay.io/cilium/operator-generic:v1.11.4@sha256:bf75ad0dc47691a3a519b8ab148ed3a792ffa2f1e309e6efa955f30a40e95adc: 2
```

### **安装hubble客户端**

和cilium一样，hubble也提供了一个客户端来让我们操作，不同的是我们

```bash
# 首先我们需要安装hubble的客户端，安装原理和过程与安装cilium几乎一致
$ export HUBBLE_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/hubble/master/stable.txt)
$ curl -L --remote-name-all https://github.com/cilium/hubble/releases/download/$HUBBLE_VERSION/hubble-linux-amd64.tar.gz{,.sha256sum}
$ sha256sum --check hubble-linux-amd64.tar.gz.sha256sum
$ sudo tar xzvfC hubble-linux-amd64.tar.gz /usr/local/bin
$ rm hubble-linux-amd64.tar.gz{,.sha256sum}
```

然后我们需要暴露hubble api服务的端口，直接使用kubectl的port-forward功能把hubble-relay这个服务的80端口暴露到4245端口上

```bash
# 仅暴露在IPV4网络中
$ kubectl port-forward -n kube-system svc/hubble-relay --address 0.0.0.0 4245:80 &
# 同时暴露在IPV6和IPV4网络中
$ kubectl port-forward -n kube-system svc/hubble-relay --address 0.0.0.0 --address :: 4245:80 &
```

如果使用cilium-cli工具安装的hubble也可以使用cilium暴露api端口，需要注意的是该命令默认会暴露到IPV6和IPV4网络中，如果宿主机节点不支持ipv6网络会报错

```bash
$ cilium hubble port-forward&
```

api端口暴露完成之后我们就可以测试一下hubble客户端的工作状态是否正常

```text
$ hubble status
Handling connection for 4245
Healthcheck (via localhost:4245): Ok
Current/Max Flows: 10,903/12,285 (88.75%)
Flows/s: 5.98
Connected Nodes: 3/3
```

### **暴露hubble-ui**

官方介绍里面是使用cilium工具直接暴露hubble-ui的访问端口到宿主机上面的12000端口

```bash
# 将hubble-ui这个服务的80端口暴露到宿主机上面的12000端口上面
$ cilium hubble ui&
[2] 5809
ℹ️  Opening "http://localhost:12000" in your browser...
```

实际上执行的操作等同于下面这个命令

```bash
# 同时暴露在IPV6和IPV4网络中
# kubectl port-forward -n kube-system svc/hubble-ui --address 0.0.0.0 --address :: 12000:80

# 仅暴露在IPV4网络中
# kubectl port-forward -n kube-system svc/hubble-ui --address 0.0.0.0 12000:80
```

这里我们使用nodeport的方式来暴露hubble-ui，首先我们查看原来的`hubble-ui`这个svc的配置

```bash
$ kubectl get svc -n kube-system hubble-ui -o yaml
...此处略去一堆输出...
  - name: http
    port: 80
    protocol: TCP
    targetPort: 8081
  selector:
    k8s-app: hubble-ui
  sessionAffinity: None
  type: ClusterIP
...此处略去一堆输出...
```

我们把默认的ClusterIP修改为`NodePort`，并且指定端口为`nodePort: 30081`

```bash
$ kubectl get svc -n kube-system hubble-ui -o yaml
...此处略去一堆输出...
  ports:
  - name: http
    nodePort: 30081
    port: 80
    protocol: TCP
    targetPort: 8081
  selector:
    k8s-app: hubble-ui
  sessionAffinity: None
  type: NodePort
...此处略去一堆输出...
```

修改前后对比查看状态

```bash
# 修改前，使用ClusterIP
$ kubectl get svc -A | grep hubble-ui
kube-system   hubble-ui      ClusterIP   10.18.22.156   <none>        80/TCP                   82s

# 修改后，使用NodePort
$ kubectl get svc -A | grep hubble-ui
kube-system   hubble-ui      NodePort    10.18.22.156   <none>        80:30081/TCP             47m
```

这时候我们在浏览器中访问`http://10.31.18.1:30081`就可以看到hubble的ui界面了



![img](https://pic1.zhimg.com/80/v2-3a8e0aaec375c9aba4a78b8d089a8ac7_720w.webp?source=1940ef5c)



## 6、部署测试用例

集群部署完成之后我们在k8s集群中部署一个nginx测试一下是否能够正常工作。首先我们创建一个名为`nginx-quic`的命名空间（`namespace`），然后在这个命名空间内创建一个名为`nginx-quic-deployment`的`deployment`用来部署pod，最后再创建一个`service`用来暴露服务，这里我们先使用`nodeport`的方式暴露端口方便测试。

```yaml
$ cat nginx-quic.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: nginx-quic

---

apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-quic-deployment
  namespace: nginx-quic
spec:
  selector:
    matchLabels:
      app: nginx-quic
  replicas: 4
  template:
    metadata:
      labels:
        app: nginx-quic
    spec:
      containers:
      - name: nginx-quic
        image: tinychen777/nginx-quic:latest
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 80

---

apiVersion: v1
kind: Service
metadata:
  name: nginx-quic-service
  namespace: nginx-quic
spec:
  externalTrafficPolicy: Cluster
  selector:
    app: nginx-quic
  ports:
  - protocol: TCP
    port: 8080 # match for service access port
    targetPort: 80 # match for pod access port
    nodePort: 30088 # match for external access port
  type: NodePort
```

部署完成后我们直接查看状态

```bash
# 直接部署
$ kubectl apply -f nginx-quic.yaml
namespace/nginx-quic created
deployment.apps/nginx-quic-deployment created
service/nginx-quic-service created

# 查看deployment的运行状态
$ kubectl get deployment -o wide -n nginx-quic
NAME                    READY   UP-TO-DATE   AVAILABLE   AGE     CONTAINERS   IMAGES                          SELECTOR
nginx-quic-deployment   4/4     4            4           2m49s   nginx-quic   tinychen777/nginx-quic:latest   app=nginx-quic

# 查看service的运行状态
$ kubectl get service -o wide -n nginx-quic
NAME                 TYPE       CLUSTER-IP     EXTERNAL-IP   PORT(S)          AGE   SELECTOR
nginx-quic-service   NodePort   10.18.54.119   <none>        8080:30088/TCP   3m    app=nginx-quic

# 查看pod的运行状态
$ kubectl get pods -o wide -n nginx-quic
NAME                                     READY   STATUS    RESTARTS   AGE     IP             NODE                                              NOMINATED NODE   READINESS GATES
nginx-quic-deployment-5d9b4fbb47-4gc6g   1/1     Running   0          3m10s   10.18.66.66    tiny-kubeproxy-free-worker-18-11.k8s.tcinternal   <none>           <none>
nginx-quic-deployment-5d9b4fbb47-4j5p6   1/1     Running   0          3m10s   10.18.64.254   tiny-kubeproxy-free-worker-18-12.k8s.tcinternal   <none>           <none>
nginx-quic-deployment-5d9b4fbb47-8gg9j   1/1     Running   0          3m10s   10.18.66.231   tiny-kubeproxy-free-worker-18-11.k8s.tcinternal   <none>           <none>
nginx-quic-deployment-5d9b4fbb47-9bv2t   1/1     Running   0          3m10s   10.18.64.5     tiny-kubeproxy-free-worker-18-12.k8s.tcinternal   <none>           <none>

# 查看IPVS规则
# 由于使用了cilium的kube-proxy-free方案，这时候Linux网络中是没有ipvs规则的
$ ipvsadm -ln
IP Virtual Server version 1.2.1 (size=4096)
Prot LocalAddress:Port Scheduler Flags
  -> RemoteAddress:Port           Forward Weight ActiveConn InActConn
  
# 查看cilium里面的状态
$ kubectl exec -it -n kube-system cilium-97fn7 -- cilium service list
Defaulted container "cilium-agent" out of: cilium-agent, mount-cgroup (init), clean-cilium-state (init)
ID   Frontend            Service Type   Backend
1    10.18.0.1:443       ClusterIP      1 => 10.31.18.1:6443
2    10.18.0.10:9153     ClusterIP      1 => 10.18.65.237:9153
                                        2 => 10.18.65.64:9153
3    10.18.0.10:53       ClusterIP      1 => 10.18.65.237:53
                                        2 => 10.18.65.64:53
4    10.18.22.156:80     ClusterIP      1 => 10.18.64.53:8081
5    10.18.58.2:80       ClusterIP      1 => 10.18.66.189:4245
6    10.31.18.11:30081   NodePort       1 => 10.18.64.53:8081
7    0.0.0.0:30081       NodePort       1 => 10.18.64.53:8081
8    10.18.54.119:8080   ClusterIP      1 => 10.18.64.254:80
                                        2 => 10.18.66.66:80
                                        3 => 10.18.64.5:80
                                        4 => 10.18.66.231:80
9    10.31.18.11:30088   NodePort       1 => 10.18.64.254:80
                                        2 => 10.18.66.66:80
                                        3 => 10.18.64.5:80
                                        4 => 10.18.66.231:80
10   0.0.0.0:30088       NodePort       1 => 10.18.64.254:80
                                        2 => 10.18.66.66:80
                                        3 => 10.18.64.5:80
                                        4 => 10.18.66.231:80
```

最后我们进行测试，这个nginx-quic的镜像默认情况下会返回在nginx容器中获得的用户请求的IP和端口

```bash
# 首先我们在集群内进行测试
# 直接访问pod
$ curl 10.18.64.254:80
10.18.65.204:60032
# 直接访问service的ClusterIP，这时请求会被转发到pod中
$ curl 10.18.54.119:8080
10.18.65.204:38774

# 直接访问nodeport，这时请求会被转发到pod中，不会经过ClusterIP
# 此时实际返回的IP要取决于被转发到的后端pod是否在当前的k8s节点上
$ curl 10.31.18.1:30088
10.18.65.204:51254
$ curl 10.31.18.11:30088
10.18.65.204:38784
$ curl 10.31.18.12:30088
10.18.65.204:60048

# 接着我们在集群外进行测试
# 直接访问三个节点的nodeport，这时请求会被转发到pod中，不会经过ClusterIP
# 此时实际返回的IP要取决于被转发到的后端pod是否在当前的k8s节点上
$ curl 10.31.18.1:30088
10.18.65.204:43586
$ curl 10.31.18.11:30088
10.18.66.232:63415
$ curl 10.31.18.11:30088
10.31.100.100:12192
$ curl 10.31.18.12:30088
10.18.64.152:40782
$ curl 10.31.18.12:30088
10.31.100.100:12178
```







## K8S结合CI&CD持续交付和集中管理配置



```
搭了k8s
```







如何丝滑关闭k8s





在关闭Kubernetes集群之前，你需要确保你的应用程序已经全部停止，并且所有的数据都已经安全备份。以下是在Linux上丝滑关闭Kubernetes的步骤：

1. 关闭应用程序

在关闭Kubernetes集群之前，你需要停止所有运行的应用程序，并等待所有容器都退出。可以使用以下命令检查所有Pod是否处于Terminating状态：

```
sqlCopy code
kubectl get pod --all-namespaces
```

如果所有的Pod都已经处于Terminating状态，可以继续下一步。

1. 删除Deployment、StatefulSet和DaemonSet

使用以下命令删除所有的Deployment、StatefulSet和DaemonSet：

```
cssCopy code
kubectl delete deployment,statefulset,daemonset --all --grace-period=30 --timeout=60s
```

1. 删除Service和Ingress

使用以下命令删除所有的Service和Ingress：

```
cssCopy code
kubectl delete service,ingress --all --grace-period=30 --timeout=60s
```

1. 删除ConfigMap和Secret

使用以下命令删除所有的ConfigMap和Secret：

```
cssCopy code
kubectl delete configmap,secret --all --grace-period=30 --timeout=60s
```

1. 删除PersistentVolumeClaim和StorageClass

使用以下命令删除所有的PersistentVolumeClaim和StorageClass：

```
cssCopy code
kubectl delete persistentvolumeclaim,storageclass --all --grace-period=30 --timeout=60s
```

1. 删除Node

使用以下命令从Kubernetes集群中删除Node：

```
cssCopy codekubectl drain <node_name> --delete-local-data --force --ignore-daemonsets
kubectl delete node <node_name>
```

其中`<node_name>`为要删除的节点的名称。

1. 停止kubelet和kube-proxy

使用以下命令停止kubelet和kube-proxy：

```
vbnetCopy codesudo systemctl stop kubelet
sudo systemctl stop kube-proxy
```

1. 停止容器运行时

使用以下命令停止容器运行时：

```
vbnetCopy code
sudo systemctl stop docker
```

1. 停止etcd

使用以下命令停止etcd：

```
vbnetCopy code
sudo systemctl stop etcd
```

现在，你已经成功地关闭了Kubernetes集群。如果你想重新启动Kubernetes集群，需要按照逆序重新启动上述所有组件。









在启动Kubernetes集群之前，你需要确保你的服务器上已经安装了Docker和kubelet组件，并且所有的网络配置都正确设置。以下是在Linux上正常启动Kubernetes的步骤：

1. 启动etcd

使用以下命令启动etcd：

```
sqlCopy code
sudo systemctl start etcd
```

1. 启动kube-apiserver

使用以下命令启动kube-apiserver：

```
sqlCopy code
sudo systemctl start kube-apiserver
```

1. 启动kube-controller-manager

使用以下命令启动kube-controller-manager：

```
sqlCopy code
sudo systemctl start kube-controller-manager
```

1. 启动kube-scheduler

使用以下命令启动kube-scheduler：

```
sqlCopy code
sudo systemctl start kube-scheduler
```

1. 启动kubelet

使用以下命令启动kubelet：

```
sqlCopy code
sudo systemctl start kubelet
```

1. 启动kube-proxy

使用以下命令启动kube-proxy：

```
sqlCopy code
sudo systemctl start kube-proxy
```

1. 验证集群状态

使用以下命令验证Kubernetes集群的状态：

```
csharpCopy code
kubectl get nodes
```

如果集群中的所有节点都显示为Ready状态，说明Kubernetes集群已经成功启动。

现在，你已经成功地启动了Kubernetes集群。你可以使用kubectl命令来管理集群，部署应用程序和监视集群的状态。
