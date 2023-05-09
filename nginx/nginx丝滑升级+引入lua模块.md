# 测试nginx丝滑升级+引入lua模块



```
nginx在不停止服务的情况下丝滑升级，并且引入lua模块

```











## lua-nginx-module

```
ngx_lua_module 是一个nginx http模块，它把 lua 解析器内嵌到 nginx，用来解析并执行lua 语言编写的网页后台脚本
```







## ngx_devel_kit

```
NDK（nginx development kit）模块是一个拓展nginx服务器核心功能的模块，第三方模块开发可以基于它来快速实现。

NDK提供函数和宏处理一些基本任务，减轻第三方模块开发的代码量。

开发者如果要依赖这个模块做开发，需要将这个模块一并参与nginx编译，同时需要在自己的模块配置中声明所需要使用的特性。

```





# 1.安装luaJIT模块

```
wget http://luajit.org/download/LuaJIT-2.0.2.tar.gz

tar -axv -f LuaJIT-2.0.2.tar.gz 

cd LuaJIT-2.0.2

make PREFIX=/usr/local/luajit
make install PREFIX=/usr/local/luajit

#添加环境变量
[root@localhost ~]# export LUAJIT_LIB=/usr/local/luajit/lib
[root@localhost ~]# export LUAJIT_INC=/usr/local/luajit/include/luajit-2.0
```





# 2.安装lua-nginx-module/ngx_devel_kit

```

#下载安装Lua模块及依赖（lua-nginx用当前版本，高版本不兼容会报错，被坑过）

wget -c 'https://github.com/openresty/lua-nginx-module/archive/v0.10.22.tar.gz' -O lua-nginx-module-0.10.22.tar.gz
wget -c 'https://github.com/simplresty/ngx_devel_kit/archive/v0.3.1rc1.tar.gz' -O ngx_devel_kit-0.3.1rc1.tar.gz
tar xzf lua-nginx-module-0.10.22.tar.gz
tar xzf ngx_devel_kit-0.3.1rc1.tar.gz
```



# 3.进入原本的nginx目录

```
cd nginx-1.16.1

nginx -V ###查看原来的nginx配置

nginx version: nginx/1.16.1
built by gcc 4.8.5 20150623 (Red Hat 4.8.5-44) (GCC) 
built with OpenSSL 1.1.1c FIPS  28 May 2019 (running with OpenSSL 1.1.1g FIPS  21 Apr 2020)
TLS SNI support enabled
configure arguments: --prefix=/usr/share/nginx --sbin-path=/usr/sbin/nginx --modules-path=/usr/lib64/nginx/modules --conf-path=/etc/nginx/nginx.conf --error-log-path=/var/log/nginx/error.log --http-log-path=/var/log/nginx/access.log --http-client-body-temp-path=/var/lib/nginx/tmp/client_body --http-proxy-temp-path=/var/lib/nginx/tmp/proxy --http-fastcgi-temp-path=/var/lib/nginx/tmp/fastcgi --http-uwsgi-temp-path=/var/lib/nginx/tmp/uwsgi --http-scgi-temp-path=/var/lib/nginx/tmp/scgi --pid-path=/run/nginx.pid --lock-path=/run/lock/subsys/nginx --user=nginx --group=nginx --with-file-aio --with-ipv6 --with-http_ssl_module --with-http_v2_module --with-http_realip_module --with-stream_ssl_preread_module --with-http_addition_module --with-http_xslt_module=dynamic --with-http_image_filter_module=dynamic --with-http_sub_module --with-http_dav_module --with-http_flv_module --with-http_mp4_module --with-http_gunzip_module --with-http_gzip_static_module --with-http_random_index_module --with-http_secure_link_module --with-http_degradation_module --with-http_slice_module --with-http_stub_status_module --with-http_perl_module=dynamic --with-http_auth_request_module --with-mail=dynamic --with-mail_ssl_module --with-pcre --with-pcre-jit --with-stream=dynamic --with-stream_ssl_module --with-google_perftools_module --with-debug --with-cc-opt='-O2 -g -pipe -Wall -Wp,-D_FORTIFY_SOURCE=2 -fexceptions -fstack-protector-strong --param=ssp-buffer-size=4 -grecord-gcc-switches -specs=/usr/lib/rpm/redhat/redhat-hardened-cc1 -m64 -mtune=generic' --with-ld-opt='-Wl,-z,relro -specs=/usr/lib/rpm/redhat/redhat-hardened-ld -Wl,-E'

```



# 4.with-ld-opt更改

前：

```
--with-ld-opt='-Wl,-z,relro -specs=/usr/lib/rpm/redhat/redhat-hardened-ld -Wl,-E'
```



后：

```
--with-ld-opt='-Wl,-rpath,/usr/local/luajit/lib,-z,relro -specs=/usr/lib/rpm/redhat/redhat-hardened-ld -Wl,-E'
```



# 5.修改配置文件内容引进3个模块

如开发环境（末尾引进了）



```
./configure --prefix=/usr/share/nginx --sbin-path=/usr/sbin/nginx --modules-path=/usr/lib64/nginx/modules --conf-path=/etc/nginx/nginx.conf --error-log-path=/var/log/nginx/error.log --http-log-path=/var/log/nginx/access.log --http-client-body-temp-path=/var/lib/nginx/tmp/client_body --http-proxy-temp-path=/var/lib/nginx/tmp/proxy --http-fastcgi-temp-path=/var/lib/nginx/tmp/fastcgi --http-uwsgi-temp-path=/var/lib/nginx/tmp/uwsgi --http-scgi-temp-path=/var/lib/nginx/tmp/scgi --pid-path=/run/nginx.pid --lock-path=/run/lock/subsys/nginx --user=nginx --group=nginx --with-file-aio --with-ipv6 --with-http_ssl_module --with-http_v2_module --with-http_realip_module --with-stream_ssl_preread_module --with-http_addition_module --with-http_xslt_module=dynamic --with-http_image_filter_module=dynamic --with-http_sub_module --with-http_dav_module --with-http_flv_module --with-http_mp4_module --with-http_gunzip_module --with-http_gzip_static_module --with-http_random_index_module --with-http_secure_link_module --with-http_degradation_module --with-http_slice_module --with-http_stub_status_module --with-http_perl_module=dynamic --with-http_auth_request_module --with-mail=dynamic --with-mail_ssl_module --with-pcre --with-pcre-jit --with-stream=dynamic --with-stream_ssl_module --with-google_perftools_module --with-debug --with-cc-opt='-O2 -g -pipe -Wall -Wp,-D_FORTIFY_SOURCE=2 -fexceptions -fstack-protector-strong --param=ssp-buffer-size=4 -grecord-gcc-switches -specs=/usr/lib/rpm/redhat/redhat-hardened-cc1 -m64 -mtune=generic' --with-ld-opt='-Wl,-rpath,/usr/local/luajit/lib,-z,relro -specs=/usr/lib/rpm/redhat/redhat-hardened-ld -Wl,-E' --add-module=/usr/local/luajit/lua-nginx-module-0.10.9rc7 --add-module=/usr/local/luajit/ngx_devel_kit-0.3.1rc1
```



```
./configure --prefix=/usr/share/nginx --sbin-path=/usr/sbin/nginx --modules-path=/usr/lib64/nginx/modules --conf-path=/etc/nginx/nginx.conf --error-log-path=/var/log/nginx/error.log --http-log-path=/var/log/nginx/access.log --http-client-body-temp-path=/var/lib/nginx/tmp/client_body --http-proxy-temp-path=/var/lib/nginx/tmp/proxy --http-fastcgi-temp-path=/var/lib/nginx/tmp/fastcgi --http-uwsgi-temp-path=/var/lib/nginx/tmp/uwsgi --http-scgi-temp-path=/var/lib/nginx/tmp/scgi --pid-path=/run/nginx.pid --lock-path=/run/lock/subsys/nginx --user=nginx --group=nginx --with-file-aio --with-ipv6 --with-http_ssl_module --with-http_v2_module --with-http_realip_module --with-stream_ssl_preread_module --with-http_addition_module --with-http_xslt_module=dynamic --with-http_image_filter_module=dynamic --with-http_sub_module --with-http_dav_module --with-http_flv_module --with-http_mp4_module --with-http_gunzip_module --with-http_gzip_static_module --with-http_random_index_module --with-http_secure_link_module --with-http_degradation_module --with-http_slice_module --with-http_stub_status_module --with-http_perl_module=dynamic --with-http_auth_request_module --with-mail=dynamic --with-mail_ssl_module --with-pcre --with-pcre-jit --with-stream=dynamic --with-stream_ssl_module --with-google_perftools_module --with-debug --with-cc-opt='-O2 -g -pipe -Wall -Wp,-D_FORTIFY_SOURCE=2 -fexceptions -fstack-protector-strong --param=ssp-buffer-size=4 -grecord-gcc-switches -specs=/usr/lib/rpm/redhat/redhat-hardened-cc1 -m64 -mtune=generic' --with-ld-opt='-Wl,-rpath,/usr/local/luajit/lib,-z,relro -specs=/usr/lib/rpm/redhat/redhat-hardened-ld -Wl,-E' --add-module=/usr/local/src/test/ngx_devel_kit-0.3.1rc1 --add-module=/usr/local/src/test/lua-nginx-module-0.10.9rc7
```





# 6.备份原来的nginx二进制文件

```
cd /usr/sbin
ls
cp nginx nginx_old.bak
nginx nginx_old.bak
```





# 7.报错

```
checking for OS
 + Linux 3.10.0-957.27.2.el7.x86_64 x86_64
checking for C compiler ... found
 + using GNU C compiler
 + gcc version: 4.8.5 20150623 (Red Hat 4.8.5-44) (GCC) 
checking for gcc -pipe switch ... found
checking for --with-ld-opt="-Wl,-rpath,/usr/local/luajit/lib,-z,relro -specs=/usr/lib/rpm/redhat/redhat-hardened-ld -Wl,-E" ... not found
./configure: error: the invalid value in --with-ld-opt="-Wl,-rpath,/usr/local/luajit/lib,-z,relro -specs=/usr/lib/rpm/redhat/redhat-hardened-ld -Wl,-E"

[root@DEV-PJE-Server1 nginx-1.16.1]# ll /usr/lib/rpm/redhat/redhat-hardened-ld
[root@DEV-PJE-Server1 nginx-1.16.1]# yum -y install /usr/lib/rpm/redhat/redhat-hardened-ld

```





# 8.继续

```
Configuration summary
  + using system PCRE library
  + using system OpenSSL library
  + using system zlib library

  nginx path prefix: "/usr/share/nginx"
  nginx binary file: "/usr/sbin/nginx"
  nginx modules path: "/usr/lib64/nginx/modules"
  nginx configuration prefix: "/etc/nginx"
  nginx configuration file: "/etc/nginx/nginx.conf"
  nginx pid file: "/run/nginx.pid"
  nginx error log file: "/var/log/nginx/error.log"
  nginx http access log file: "/var/log/nginx/access.log"
  nginx http client request body temporary files: "/var/lib/nginx/tmp/client_body"
  nginx http proxy temporary files: "/var/lib/nginx/tmp/proxy"
  nginx http fastcgi temporary files: "/var/lib/nginx/tmp/fastcgi"
  nginx http uwsgi temporary files: "/var/lib/nginx/tmp/uwsgi"
  nginx http scgi temporary files: "/var/lib/nginx/tmp/scgi"




```

# 9.执行

```
## 下载新的源码包，开始编译，此处从1.16.1升级至1.16.1，只能 make ，千万不能执行 make install


make -j 2

cd objs/
[root@node1 objs]# ls     # 编译过后，objs 目录下会生成二进制启动文件
```



# 10.丝滑升级

```
复制启动文件

[root@localhost ~]# cp /root/nginx-1.10.3/objs/nginx /usr/local/nginx/sbin/
平滑升级

nginx -t

[root@localhost nginx-1.10.3]# make upgrade
查看版本
```

```
https://zhuanlan.zhihu.com/p/370257037
```

```
https://blog.csdn.net/weixin_45603969/article/details/129128528
```



```
-rwxr-xr-x 1 root root  174840 11月  1 2020 ngx_stream_module.so.old
-rwxr-xr-x 1 root root  101368 11月  1 2020 ngx_mail_module.so.old
-rwxr-xr-x 1 root root   24576 11月  1 2020 ngx_http_xslt_filter_module.so
-rwxr-xr-x 1 root root   24528 11月  1 2020 ngx_http_perl_module.so
-rwxr-xr-x 1 root root   24600 11月  1 2020 ngx_http_image_filter_module.so
-rwxr-xr-x 1 root root  742144 4月  26 15:52 ngx_mail_module.so
-rwxr-xr-x 1 root root 1292328 4月  26 15:53 ngx_stream_module.so
[root@TEST-PJE1-Server1 modules]# 
[root@TEST-PJE1-Server1 modules]# pwd
/usr/lib64/nginx/modules

```



# 11.配置log_format形式

## 1.nginx.conf

```
log_format access_collect_logs escape=json  '$remote_addr - $remote_user [$time_local] "$request_time" "$upstream_response_time" "$upstream_addr" "http://$host" "$request" '
                                   '$status $body_bytes_sent "$http_referer" '
                                   '"$http_user_agent" "$http_x_forwarded_for" '
                                   '"$resp_body"';

```





## 2.data_collect.conf

```
#Nginx configure for data_collect 
upstream data_collect {
        server test-pje.data-collect.server1:8082 weight=10  ;
        #server cokutau-data-collect-server2:8082 weight=5 max_fails=1 fail_timeout=30s;
}


server {
        listen 80 ;
        server_name collect-sdk.test-pje1.cokutau.cn ;
        #access_log /data/logs/test-pje1/nginx/access_data_collect.log access_logs;
        #error_log /data/logs/test-pje1/nginx/error_data_collect.log notice;
        error_log /data/logs/test-pje1/nginx/error_data_collect.log ;
        access_log /data/logs/test-pje1/nginx/access_data_collect.log access_collect_logs;

        #只收集5XX状态码的body      
        set_by_lua_block $resp_body {
            return "-"
        }

        lua_need_request_body on;
        log_by_lua_block {
        if ngx.status == 502 then
            local resp_body = ngx.req.get_body_data()
            if resp_body then
                ngx.var.resp_body = resp_body
            end
        end
        }

        location / {
                proxy_pass http://data_collect;
		client_max_body_size 500m;
		proxy_connect_timeout  60;
                proxy_read_timeout     300;
                proxy_send_timeout     60;
                proxy_set_header Host $host;
                proxy_set_header X-Real-IP $remote_addr;
                proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
                include /etc/nginx/conf.d/test-pje1/common/allow_ip.include ;
                deny all ;
        }

        location /collect/ADRecord {
                proxy_pass http://data_collect/collect/ADRecord ;
                client_max_body_size 500m;
                proxy_connect_timeout  60;
                proxy_read_timeout     300;
                proxy_send_timeout     60;
                proxy_set_header Host $host;
                proxy_set_header X-Real-IP $remote_addr;
                proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        }

        #临时
#       location /collect/actionRecords {
#               deny all ;
#       }
}
```





## 3.nginx_traffic_collect.conf

```
#Nginx configure for data_collect 
upstream traffic_collect {
        server test-pje.traffic-collect.server1:8084 weight=10  ;
        #server cokutau-data-collect-server2:8082 weight=5 max_fails=1 fail_timeout=30s;
}


server {
        listen 80 ;
        server_name collect-traffic.test-pje1.cokutau.cn ;
        #access_log /data/logs/test-pje1/nginx/access_traffic_collect.log access_logs;
        #error_log /data/logs/test-pje1/nginx/error_data_collect.log notice;
        error_log /data/logs/test-pje1/nginx/error_traffic_collect.log ;
        access_log /data/logs/test-pje1/nginx/access_traffic_collect.log access_collect_logs;

        #只收集5XX状态码的body      
        set_by_lua_block $resp_body {
            return "-"
        }

        lua_need_request_body on;
        log_by_lua_block {
        if ngx.status == 502 then
            local resp_body = ngx.req.get_body_data()
            if resp_body then
                ngx.var.resp_body = resp_body
            end
        end
        }

        location / {
                proxy_pass http://traffic_collect ;
                proxy_set_header Host $host;
                proxy_set_header X-Real-IP $remote_addr;
                proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
                include /etc/nginx/conf.d/test-pje1/common/allow_ip.include ;
                deny all ;
        }


	location /collect/appClick {
                proxy_pass http://data_collect/collect/appClick ;
                proxy_set_header Host $host;
                proxy_set_header X-Real-IP $remote_addr;
                proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
		access_log /data/logs/test-pje1/nginx/access_data_collect.log access_logs;
		error_log /data/logs/test-pje1/nginx/error_data_collect.log ;
                include /etc/nginx/conf.d/test-pje1/common/allow_ip.include ;
                deny all ;

	}
#        location /collect/ADRecord {
#                proxy_pass http://data_collect/collect/ADRecord ;
#                proxy_set_header Host $host;
#                proxy_set_header X-Real-IP $remote_addr;
#                proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
#        }

        #临时
#       location /collect/actionRecords {
#               deny all ;
#       }
}

```

