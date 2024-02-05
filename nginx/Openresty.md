## 需求说明

公司微服务，为了在出现5xx状态码或特殊4xx状态码的时候，快速定位问题和解决问题，决定在nginx访问日志中加入错误请求的的响应（response）信息。经过调研和充分测试后决定使用openresty来实现，这里记录下实现方法。

## openresty 简介

OpenResty® 是一个基于 [Nginx](http://openresty.org/cn/nginx.html) 与 Lua 的高性能 Web 平台，其内部集成了大量精良的 Lua 库、第三方模块以及大多数的依赖项。用于方便地搭建能够处理超高并发、扩展性极高的动态 Web 应用、Web 服务和动态网关。

## openresty安装

环境说明：

操作系统：centos 7.2

openresty：openresty-1.13.6.1

1、安装依赖环境

```
yum install readline-devel pcre-devel openssl-devel perl c++ gcc gcc-c++  systemtap-sdt-devel -yyum install readline-devel pcre-devel openssl-devel perl c++ gcc gcc-c++  systemtap-sdt-devel -y
```

2、下载解压openresty

```
wget https://openresty.org/download/openresty-1.13.6.1.tar.gz
tar -xvf openresty-1.13.6.1.tar.gz -C /usr/local/
```

3、下载解压依赖模块

```
wget https://codeload.github.com/FRiCKLE/ngx_cache_purge/zip/master  -P ngx_cache_purge.zip
unzip ngx_cache_purge.zip -d /usr/local/openresty-1.13.6.1/bundle/
wget https://ftp.pcre.org/pub/pcre/pcre-8.38.tar.gz
tar -xvf pcre-8.38.tar.gz -C  /usr/local/openresty-1.13.6.1/bundle/
wget https://github.com/FRiCKLE/ngx_cache_purge/archive/2.3.tar.gz 
tar -xvf 2.3.tar.gz  -C /usr/local/openresty-1.13.6.1/bundle/
wget https://www.openssl.org/source/openssl-1.1.0g.tar.gz
tar xf openssl-1.1.0g.tar.gz -C /usr/local/openresty-1.13.6.1/bundle/
```

4、编译安装

```
./configure --user=nginx --group=nginx --with-pcre=./bundle/pcre-8.38 --with-stream --with-stream_ssl_module --with-http_v2_module --without-mail_pop3_module --without-mail_imap_module --without-mail_smtp_module --with-http_stub_status_module --with-http_realip_module --with-http_addition_module --with-http_auth_request_module --with-http_secure_link_module --with-http_random_index_module --with-http_gzip_static_module --with-http_sub_module --with-http_dav_module --with-http_flv_module --with-http_mp4_module --with-http_gunzip_module --with-threads --with-file-aio --with-dtrace-probes --with-stream --with-stream --with-stream_ssl_module --with-http_ssl_module --add-module=./bundle/ngx_cache_purge-2.3/
gmake
gmake install
```

5、openresty安装完成后目录结构如下

```
[root@c7-node1 ~]# ll /usr/local/openresty
总用量 244
drwxr-xr-x.  2 root root    123 4月   2 17:20 bin
-rw-r--r--.  1 root root  22924 4月   2 17:20 COPYRIGHT
drwxr-xr-x.  6 root root     56 4月   2 17:20 luajit
drwxr-xr-x.  6 root root     70 4月   2 17:20 lualib
drwxr-xr-x. 12 root root    165 4月   2 17:22 nginx
drwxr-xr-x. 44 root root   4096 4月   2 17:20 pod
-rw-r--r--.  1 root root 218352 4月   2 17:20 resty.index
drwxr-xr-x.  5 root root     47 4月   2 17:20 site
```

## 测试

安装完成之后，我们来验证下openresty能否正常解析lua代码。

1、修改nginx配置文件

```

# cd /usr/local/openresty
# vim nginx/conf/nginx.conf
```

将nginx默认配置的location修改为如下内容

```
location / {
        default_type 'text/html';
        content_by_lua 'ngx.say("hello world")';
}
```

2、测试配置，并启动

```
# ./bin/openresty -t
nginx: the configuration file /usr/local/openresty/nginx/conf/nginx.conf syntax is ok
nginx: configuration file /usr/local/openresty/nginx/conf/nginx.conf test is successful
# ./bin/openresty
```

3、访问测试，用浏览器访问服务器的ip地址，如果出现如下内容，说明环境安装是没问题的
[![luatest](..\images\luatest.png)](http://www.fblinux.com/wp-content/uploads/2018/04/luatest.png)

## openresty 开启 response日志功能

1、修改nginx log格式

```
# vim nginx/conf/nginx.conf
    log_format main  escape=json '{ "@timestamp": "$time_local", '
                         '"remote_addr": "$remote_addr", '
                         '"upstream_addr": "$upstream_addr",'
                         '"remote_user": "$remote_user", '
                         '"body_bytes_sent": "$body_bytes_sent", '
                         '"request_time": "$request_time", '
                         '"status": "$status", '
                         '"request": "$request", '
                         '"request_method": "$request_method", '
                         '"http_referrer": "$http_referer", '
                         '"body_bytes_sent":"$body_bytes_sent", '
                         '"http_x_forwarded_for": "$http_x_forwarded_for", '
                         '"host":""$host",'
                         '"remote_addr":""$remote_addr",'
                         '"http_user_agent": "$http_user_agent",'
                         '"http_uri": "$uri",'
                         '"req_body":"$resp_body",'
                         '"http_host":"$http_host" }'
```

2、nginxc增加一个server配置段，注意配置文件中的目录需要自己创建，文章省略了此步骤，我代理的服务器是我们公司一个测试服务器的地址，你可以任意代理，只要能模拟出2xx和4xx、5xx状态码即可。

```
# vim nginx/conf/conf.d/test.conf
server{
    listen 8041;
    access_log  /data/logs/nginx/test.log  main;
            # lua代码
                        set $resp_body "";
                        body_filter_by_lua '
                    # 最大截取500字节返回体
                        local resp_body = string.sub(ngx.arg[1], 1, 500)
                        ngx.ctx.buffered = (ngx.ctx.buffered or"") .. resp_body
                    # 判断response是否不为空，并且状态码大于400
                        if ngx.arg[2] and ngx.status &gt;= 400  then
                                ngx.var.resp_body = ngx.ctx.buffered
                        end
                  ';
 
    location / {
         proxy_pass http://test;
    }
}
upstream test {
     server 10.1.13.105:8041  max_fails=2 fail_timeout=6s;
}
```

3、测试配置，并重载openresty配置

```
[root@c7-node1 openresty]# ./bin/openresty -t
nginx: the configuration file /usr/local/openresty/nginx/conf/nginx.conf syntax is ok
nginx: configuration file /usr/local/openresty/nginx/conf/nginx.conf test is successful
[root@c7-node1 openresty]# ./bin/openresty
```

4、访问测试，并观察日志

先来一个200请求，观察访问日志

[![200access](..\images\200access-1024x117.png)](http://www.fblinux.com/wp-content/uploads/2018/04/200access.png)

此时看我们nginx的访问日志req_body 字段是没有数据记录。

[![200log](..\images\200log-1024x45.png)](http://www.fblinux.com/wp-content/uploads/2018/04/200log.png)

我们在来一个404请求，观察是否会记录response信息

[![404access](..\images\404access-1024x351.png)](http://www.fblinux.com/wp-content/uploads/2018/04/404access.png)

此时看我们nginx的访问日志req_body 字段，response信息被完整的记录下来，说明我们的配置是成功的

[![404log](..\images\404log-1024x102.png)](http://www.fblinux.com/wp-content/uploads/2018/04/404log.png)

## 后续

到此我们的nginx访问日志记录response信息的配置就完成了，这样以后每天在ELK中检索日志，只需要通过kibana过滤出所有5xx的状态码，就可以第一时间看到服务器响应给客户端的错误内容，方便运维和开发人员快速解决问题。









接下来，你需要编写一段OpenResty的代码来捕获非200的请求并将它们记录到你指定的日志文件中。可以使用OpenResty提供的ngx.location.capture API来实现这一点。例



```
local res = ngx.location.capture("/non-200-requests", {    args = ngx.var.args }) if res.status ~= 200 then    ngx.log(ngx.INFO, "Non-200 request: ", res.body) end


client_body_buffer_size 




local request_body = ngx.req.get_body_data()

```









可以将 OpenResty 配置为收集状态代码大于 400 的请求的请求正文。OpenResty 是一个建立在 NGINX HTTP 服务器之上的 Web 服务器，它允许您使用 Lua 编程语言自定义 NGINX 的行为。

若要收集状态代码大于 400 的请求的请求正文，可以在 NGINX 服务器上下文中运行的 Lua 脚本中使用该方法。此方法将请求正文作为字符串返回，然后可以按照您喜欢的任何方式记录或处理该字符串。`ngx.req.get_body_data()`

下面是如何使用此方法收集状态代码大于 400 的请求的请求正文的示例：

```
Copy codelocation / {
    if ($status >= 400) {
        set $request_body "";
        set $request_body_length 0;
        ngx.req.read_body();
        set $request_body ngx.req.get_body_data();
        set $request_body_length length($request_body);
    }
}
```

在此示例中，该方法用于在调用以字符串形式检索请求正文之前从客户端读取请求正文。然后，此字符串存储在变量中，稍后可以在 NGINX 配置中使用该变量来记录请求正文或对其执行其他操作。`ngx.req.read_body()``ngx.req.get_body_data()``$request_body`

请务必注意，此示例只是使用 OpenResty 收集状态代码大于 400 的请求的请求正文的一种方法。根据您的特定需求和要求，您可能可以使用其他方法或技术。









log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                  '$status $body_bytes_sent "$http_referer" '
                  '"$http_user_agent" "$http_x_forwarded_for" '
                  '$request_body';

location / {
    access_log /var/log/nginx/access.log main;

    # Use lua-nginx-module to capture the request body
    # of non-200 status code requests
    lua_need_request_body on;
    log_by_lua_block {
        if ngx.status ~= 200 then
            local request_body = ngx.req.get_body_data()
            if request_body then
                ngx.var.request_body = request_body
            end
        end
    }
}













# 实验



1.安装openresty

2.conf

```
server {
    listen 8080 ;
    server_name localhost;
    access_log /var/log/openresty/access-8080.log json_log;
    access_log /var/log/openresty/accss-8081.log test_log;
    error_log /var/log/openresty/error-8080.log ;
    set $resp_body "";
    
    lua_need_request_body on;
    log_by_lua_block {
    if ngx.status ~= 200 then
        local resp_body = ngx.req.get_body_data()
        if resp_body then
            ngx.var.resp_body = resp_body
        end
    end
}


    location /collect/logoutRecord {
    proxy_pass http://test;
     }
   } 

upstream test {
     server 192.168.46.109:1234  max_fails=2 fail_timeout=6s;
} 
server {
    listen 8080 ;
    server_name localhost;
    access_log /var/log/openresty/access-8080.log json_log;
    access_log /var/log/openresty/accss-8081.log test_log;
    error_log /var/log/openresty/error-8080.log ;
    set $resp_body "";
    
    lua_need_request_body on;
    log_by_lua_block {
    if ngx.status ~= 200 then
        local resp_body = ngx.req.get_body_data()
        if resp_body then
            ngx.var.resp_body = resp_body
        end
    end
}


    location /collect/logoutRecord {
    proxy_pass http://test;
     }
   } 

upstream test {
     server 192.168.46.109:1234  max_fails=2 fail_timeout=6s;
} 

```







3.nginx.conf

```

#user  nobody;
worker_processes  auto;

error_log /var/log/openresty/error.log;
#error_log  logs/error.log;
#error_log  logs/error.log  notice;
#error_log  logs/error.log  info;

#pid        logs/nginx.pid;


events {
    worker_connections  1024;
}


http {
    include       mime.types;
    default_type  application/octet-stream;

    log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
                      '$status $body_bytes_sent "$http_referer" '
                      '"$http_user_agent" "$http_x_forwarded_for"';
#
    #log_format json_log  escape=json '{"host":"$http_host $request","timestamp":"$msec","from_ip":"$remote_addr","read_ip":""$http_x_forwarded_for","url":"$request_uri","body":"$request_body","response_body": "$response_body"}'; 


    log_format json_log  escape=json '{ "@timestamp": "$time_local", '
                         '"remote_addr": "$remote_addr", '
                         '"upstream_addr": "$upstream_addr",'
                         '"remote_user": "$remote_user", '
                         '"body_bytes_sent": "$body_bytes_sent", '
                         '"request_time": "$request_time", '
                         '"status": "$status", '
                         '"request": "$request", '
                         '"request_method": "$request_method", '
                         '"http_referrer": "$http_referer", '
                         '"body_bytes_sent":"$body_bytes_sent", '
                         '"http_x_forwarded_for": "$http_x_forwarded_for", '
                         '"host":""$host",'
                         '"remote_addr":""$remote_addr",'
                         '"http_user_agent": "$http_user_agent",'
                         '"http_uri": "$uri",'
                         '"req_body": "$resp_body",'
                         '"http_host":"$http_host" }';


    log_format  test_log '$remote_addr - $remote_user [$time_local] "$request_time" "$upstream_response_time" "$upstream_addr" "$scheme://$host" "$request" '
                         '$status $body_bytes_sent "$http_referer" '
                         '"$http_user_agent" "$http_x_forwarded_for" ' 
                         '"$resp_body" ';


    access_log  /var/log/openresty/access.log  main;
    sendfile        on;
    tcp_nopush      on;
    tcp_nodelay     on;
    #keepalive_timeout  0;
    keepalive_timeout  65;
    types_hash_max_size 2048;
    #gzip  on;
    include /usr/local/openresty/nginx/conf/conf.d/*.conf;
    
    server {
        listen       80 default_server;
        server_name  localhost;

        #charset koi8-r;

        #access_log  logs/host.access.log  main;

        #Load configuration files for the default server block.
        include /usr/local/openresty/nginx/conf/default.d/*.conf;


        location / {
            root   html;
            index  index.html index.htm;
        }

        #error_page  404              /404.html;

        # redirect server error pages to the static page /50x.html
        #
        error_page   500 502 503 504  /50x.html;
        location = /50x.html {
            root   html;
        }

        # proxy the PHP scripts to Apache listening on 127.0.0.1:80
        #
        #location ~ \.php$ {
        #    proxy_pass   http://127.0.0.1;
        #}

        # pass the PHP scripts to FastCGI server listening on 127.0.0.1:9000
        #
        #location ~ \.php$ {
        #    root           html;
        #    fastcgi_pass   127.0.0.1:9000;
        #    fastcgi_index  index.php;
        #    fastcgi_param  SCRIPT_FILENAME  /scripts$fastcgi_script_name;
        #    include        fastcgi_params;
        #}

        # deny access to .htaccess files, if Apache's document root
        # concurs with nginx's one
        #
        #location ~ /\.ht {
        #    deny  all;
        #}
    }


    # another virtual host using mix of IP-, name-, and port-based configuration
    #
    #server {
    #    listen       8000;
    #    listen       somename:8080;
    #    server_name  somename  alias  another.alias;

    #    location / {
    #        root   html;
    #        index  index.html index.htm;
    #    }
    #}


    # HTTPS server
    #
    #server {
    #    listen       443 ssl;
    #    server_name  localhost;

    #    ssl_certificate      cert.pem;
    #    ssl_certificate_key  cert.key;

    #    ssl_session_cache    shared:SSL:1m;
    #    ssl_session_timeout  5m;

    #    ssl_ciphers  HIGH:!aNULL:!MD5;
    #    ssl_prefer_server_ciphers  on;

    #    location / {
    #        root   html;
    #        index  index.html index.htm;
    #    }
    #}

}

```







```
fastcgi_buffers 32 8k;        #指定本地需要用多少和多大的缓冲区来缓冲FastCGI的应答   
client_body_buffer_size 1024k; #缓冲区代理缓冲用户端请求的最大字节数

```



