# Docker

Docker安装与部署

## 1.安装docker所需yum源

```
sudo yum install -y yum-utils device-mapper-persistent-data lvm2
```

2.安装阿里镜像源

```
sudo yum-config-manager --add-repo https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
```



docker run -p 80:80 --name mynginx -v $PWD/www:/www -v $PWD/conf/nginx.conf:/etc/nginx/nginx.conf -v $PWD/logs:/wwwlogs  -d nginx


docker-compose安装部署


curl -L https://github.com/docker/compose/releases/download/1.21.2/docker-compose-$(uname -s)-$(uname -m) -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose 
docker-compose --version


$6$WWUPDd8C$cdb92Yue7Fjut.ogp/41WiMc/TH2832gvKyvyIU7jUjesYgVOrnvG/Y/o5Jwu.MCGyao4CSdK2cWRb8dDhjue.






























