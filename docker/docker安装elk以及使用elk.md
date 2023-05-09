# docker安装elk以及使用elk（7.7.1）



## 1.安装docker

此处省略



```
docker version
```



### 1.1 查找镜像

```
docker search elasticsearch
docker pull elasticsearch:7.7.1
docker images ls


```



### 1.2 创建挂载目录

```
mkdir -p /data/elk/es/{config,data,logs}
```



### 1.3赋予权限

```
chown -R 1000:1000 /data/elk/es


```



### 1.4.创建挂载用配置

elasticsearch.yml

```
cat /data/elk/es/config/elasticsearch.yml 
cluster.name: "my-es"
network.host: 0.0.0.0
http.port: 9200
http.cors.enabled: true
http.cors.allow-origin: "*"
```



运行 es 7.7.1

```
docker run -it  -d -p 9200:9200 -p 9300:9300 --name es -e ES_JAVA_OPTS="-Xms512m -Xmx512m" -e "discovery.type=single-node" --restart=always -v /data/elk/es/config/elasticsearch.yml:/usr/share/elasticsearch/config/elasticsearch.yml -v /data/elk/es/data:/usr/share/elasticsearch/data -v /data/elk/es/logs:/usr/share/elasticsearch/logs elasticsearch:7.7.1
```



## 2.安装kibana



### 2.1 elasticsearch容器ip



```

172.17.0.2
```





### 2.2 配置文件

```
cat /data/elk/kibana/kibana.yml
#Default Kibana configuration for docker target
server.name: kibana
server.host: "0"
elasticsearch.hosts: ["http://172.17.0.3:9200"]
xpack.monitoring.ui.container.elasticsearch.enabled: true


```





### 2.4.运行kibana

```
docker run -d --restart=always --log-driver json-file --log-opt max-size=100m --log-opt max-file=2 --name kibana -p 5601:5601 -v /data/elk/kibana/kibana.yml:/usr/share/kibana/config/kibana.yml kibana:7.7.1


```



### 2.5.检查kibana容器配置文件



```
docker exec -it kibana /bin/bash
```







## 3.部署logstash

### 3.1获取镜像

```
docker pull logstash:7.7.1
```



### 3.2.获取配置文件

```
docker cp logstash:/usr/share/logstash /data/elk/
```



```
docker run -d --name=logstash logstash:7.7.1
mkdir /data/elk/logstash/config/conf.d
chmod 777 -R /data/elk/logstash
```



```
vi /data/elk/logstash/config/logstash.yml


http.host: "0.0.0.0"
xpack.monitoring.elasticsearch.hosts: [ "http://192.168.31.196:9200" ]
path.config: /usr/share/logstash/config/conf.d/*.conf
path.logs: /usr/share/logstash/logs
```



```
vi /data/elk/logstash/config/conf.d/syslog.conf
```

```
input {
     file {
     type => "openldap"
     path => "/var/log/log/ldap/*"
     start_position => "beginning"
     stat_interval => "5"
     }
}
output {
     elasticsearch {
     hosts => ["192.168.46.20:9200"]
     index => "openldap-%{+YYYY.MM.dd}"
     }
}
```



### 3.3.运行logstash

```
docker run -d \
     --name=logstash \
     --restart=always \
     -p 5044:5044 \
     -v /data/elk/logstash:/usr/share/logstash \
	 -v /var/log/log/ldap/:/var/log/log/ldap/ \
	 -v /var/log/messages:/var/log/messages \
     logstash:7.7.1
```





# 查看索引

```
 curl http://localhost:9200/_cat/indices?v
```





# 删除索引

```
curl -XDELETE http://localhost:9200/system-syslog-2022.02
```





## 4.创建filebeat

```
wget https://artifacts.elastic.co/downloads/beats/filebeat/filebeat-7.7.1-x86_64.rpm
rpm -ivh filebeat-7.7.1-x86_64.rpm
```



```
filebeat.inputs:

- type: log
  enabled: true
  paths:
    - "/var/log/ldap/humanizer.log"
    - "/var/log/ldap/ldap.log-2022*"
      json.keys_under_root: true
      json.overwrite_keys: true  
      json.add_error_key: true
      filebeat.config.modules:
      path: ${path.config}/modules.d/*.yml
      reload.enabled: false
      setup.template.settings:
      index.number_of_shards: 1
      setup.kibana:
      output.elasticsearch:
      hosts: ["192.168.46.20:9200"]
      logging.level: debug


```











































