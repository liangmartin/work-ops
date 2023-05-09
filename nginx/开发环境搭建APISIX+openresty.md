# 安装APISIX

## 通过 RPM 仓库安装

如果当前系统**没有安装 OpenResty**，请使用以下命令来安装 OpenResty 和 APISIX 仓库：

```
 yum install -y https://repos.apiseven.com/packages/centos/apache-apisix-repo-1.0-1.noarch.rpm
```



完成上述操作后使用以下命令安装 APISIX：

```shell
yum install apisix
```

## 管理 APISIX 服务

APISIX 安装完成后，你可以运行以下命令初始化 NGINX 配置文件和 etcd：

```shell
apisix init
```



### apisix启动 、停止

使用以下命令启动 APISIX：

```shell
systemctl start apisix
systemctl enable apisix
systemctl stop apisix
systemctl reload apisix
systemctl restart apsix
```



# 安装 etcd3.5.4

APISIX 使用 [etcd](https://github.com/etcd-io/etcd) 作为配置中心进行保存和同步配置。在安装 APISIX 之前，需要在你的主机上安装 etcd。

如果你在安装 APISIX 时选择了 Docker 或 Helm 安装，那么 etcd 将会自动安装；如果你选择其他方法或者需要手动安装 APISIX，请参考以下步骤安装 etcd：

## linux安装etcd

```
ETCD_VERSION='3.5.4'
wget https://github.com/etcd-io/etcd/releases/download/v${ETCD_VERSION}/etcd-v${ETCD_VERSION}-linux-amd64.tar.gz
tar -xvf etcd-v${ETCD_VERSION}-linux-amd64.tar.gz && \
  cd etcd-v${ETCD_VERSION}-linux-amd64 && \
  sudo cp -a etcd etcdctl /usr/bin/
nohup etcd >/tmp/etcd.log 2>&1 &
```



### 配置

```
etcd.conf
# 节点名称
ETCD_NAME="etcd0"
# 指定数据文件存放位置
ETCD_DATA_DIR="/var/lib/etcd/"
```



### 注册服务

```
etcd.service

[Unit]
Description=Etcd Server
After=network.target
After=network-online.target
Wants=network-online.target

[Service]
User=root
Type=notify
WorkingDirectory=/var/lib/etcd/
EnvironmentFile=-/usr/local/etcd-v3.5.4-linux-amd64/etcd.conf
ExecStart=/usr/bin/etcd
#StandardOutput=/var/log/etcd/etcd.log
StandardOutput=syslog
StandardError=syslog
Restart=on-failure
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target

```



### 监听syslog日志

```
/etc/rsyslog.d/etcd.conf
if $programname == 'etcd' then /var/log/etcd/etcd.log
& stop

#重启rsyslog服务

systemtl restart rsyslog
```



### etcd启动、停止

```
systemctl enable etcds
systemctl start etcd
systemctl stop etcd
systemctl  restart etcd
```



## 关于etcd3.5.4 博客查询

```
https://blog.csdn.net/Keyuchen_01/article/details/126609033
```





# 安装可视化面板apisix-dashboard

## 安装

```
apisix-dashboard-3.0.0-0.el7.x86_64.rpm
rpm -Uvh apisix-dashboard-3.0.0-0.el7.x86_64.rpm
yum install -y apisix-dashboard-3.0.0-0.el7.x86_64.rpm
```



使用yum安装，默认安装路径在`/usr/local/apisix/dashboard`

```
yum localinstall -y apisix-dashboard-3.0.0-0.el7.x86_64.rpm

#防火墙设置
firewall-cmd --zone=public --add-port=9000/tcp --permanent
```



## 配置

### conf.yaml

1. 修改 allow_list 和 etcd 配置

- allow_list 添加 `192.168.20.0/24` （白名单，按需添加允许主机）
- etcd:endpoints 修改 `192.168.46.60:2379`（etcd节点）
- users配置 配置账号密码

```
主要配置apisix-dashboard界面的设置
cd /usr/local/apisix/dashboard/conf/conf.yaml
```



### schema.json

```
#里面主要存放的是apisix主程序的插件，当你自定义的插件想在dashboard展示，都需要更新此文件
such as :
cd /usr/local/apisix/dashboard/conf
curl 127.0.0.1:9090/v1/schema > schema.json
```



## 注册systemd

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



##  dashboard启动、停止服务

```shell
systemctl daemon-reload && \
systemctl enable apisix-dashboard.service && \
systemctl start apisix-dashboard.service 

stop:
systemctl stop apisix-dashboard
```



# apisix配置

##  config.yaml

```
 该配置主要是关于新配置，config-default.yaml为默认，config.yaml配置后覆盖config-default.yaml
 
 ps：需要严格遵守yaml格式
```





## config-default.yaml



### 配置admin、viewer

| key    | value       | md5密文                          |
| ------ | ----------- | -------------------------------- |
| admin  | cokutau@123 | 411BA738BFB32CDCA5FE7BFDC6F00E3B |
| viewer | cokutau123  | D6D5E394F82B9EE54714021E0A053B15 |



```
deployment:
  role: traditional
  role_traditional:
    config_provider: etcd
  admin:
    # Default token when use API to call for Admin API.
    # *NOTE*: Highly recommended to modify this value to protect APISIX's Admin API.
    # Disabling this configuration item means that the Admin API does not
    # require any authentication.
    admin_key:
      -
        name: admin
        key: 411BA738BFB32CDCA5FE7BFDC6F00E3B
        role: admin                 # admin: manage all configuration data
                                    # viewer: only can view configuration data
      -
        name: viewer
        key: D6D5E394F82B9EE54714021E0A053B15
        role: viewer
```

### 配置node_listen

```
    - host: 0.0.0.0
      port: 80
    - host: 0.0.0.0
      port: 81
```



## 迁移旧版nginx.conf到apisix

### log_format

 log_format为日志格式，默认是main，现在我们需要包含三种格式。



| name         | value                                                        | mean                                   |
| ------------ | ------------------------------------------------------------ | -------------------------------------- |
| main         | '$remote_addr - $remote_user [$time_local] "$request" '<br/>'$status $body_bytes_sent "$http_referer" '<br/>'"$http_user_agent" "$http_x_forwarded_for"'; | default                                |
| access_logs  | '$remote_addr - $remote_user [$time_local] "$request_time" "$upstream_response_time" "$upstream_addr" "http://$host" "$request" ' '$status $body_bytes_sent "$http_referer" ' '"$http_user_agent" "$http_x_forwarded_for"' ; | access_logs                            |
| reqbody_logs | log_format reqbody_logs escape=json '$remote_addr - $remote_user [$time_local] "$request_time" "$upstream_response_time" "$upstream_addr" "$scheme://$host" "$request" $status $body_bytes_sent "$http_referer" "$http_user_agent" "$http_x_forwarded_for" "$resp_body"'; | 当后端服务终端会记录它们的request_body |



### 配置

修改ngx_tpl.lua

```shell
/usr/local/apisix/apisix/cli/ngx_tpl.lua

log_format main escape={* http.access_log_format_escape *} '{* http.access_log_format *}';

log_format access_logs escape={* http.access_logs_format_escape *} '{* http.access_logs_format *}';

log_format reqbody_logs escape={* http.req_log_format_escape *} '{* http.req_log_format *}';
```

配置默认配置文件

```yaml
/usr/local/apisix/conf/config-default.yaml

    access_logs_format: "$remote_addr - $remote_user [$time_local] \"$request_time\" \"$upstream_response_time\" \"$upstream_addr\" \"http://$host\" \"$request\" $status $body_bytes_sent \"$http_referer\" \"$http_user_agent\" \"$http_x_forwarded_for\""

    access_logs_format_escape: default

    req_log_format: "$remote_addr - $remote_user [$time_local] \"$request_time\" \"$upstream_response_time\" \"$upstream_addr\" \"$scheme://$host\" \"$request\" $status $body_bytes_sent \"$http_referer\" \"$http_user_agent\" \"$http_x_forwarded_for\" \"$resp_body\""

    req_log_format_escape: json
```

修改日志默认为空

```
/usr/local/apisix/apisix/cli/ngx_tpl.lua

set $resp_body "";
```





# 自定义日志access_log收集插件(完成)

```
需求：
1.隔离不同日志的access_log,避免日志污染。
2.自定义独特的log_format日志格式，收集日志。
3.当nginx日志状态码为5xx的时候，返回值带上request_body参数。
4.自定义file_path文件保存位置

PS：因为apisix输出的log权限需要配置好

-rw-rw-r--. 1 game nobody     1023 Mar 31 16:36 access_vlog_apisix.log
-rw-rw-r--. 1 game nobody    52661 Apr  3 09:44 access_xxl_job_admin_apisix.log

chmod 664 xx.log

```



## nt-logger.lua

```
  /usr/local/apisix/apisix/plugins
```

```
隔离各个路由的access_log日志，避免日志污染
```



```lua
local log_util     =   require("apisix.utils.log-util")
local core         =   require("apisix.core")
local ngx          =   ngx
local io_open      =   io.open
local is_apisix_or, process = pcall(require, "resty.apisix.process")
local string_format = string.format

local plugin_name = "nt-logger"

local schema = {
    type = "object",
    properties = {
        path = {
            type = "string",
            default = "/var/log/nginx/access.log"
        }
    },
    required = {"path"}
}


local _M = {
    version = 0.1,
    priority = 399,
    name = plugin_name,
    schema = schema
}

local open_file_cache
if is_apisix_or then
    -- TODO: switch to a cache which supports inactive time,
    -- so that unused files would not be cached
    local path_to_file = core.lrucache.new({
        type = "plugin",
    })

    local function open_file_handler(conf, handler)
        local file, err = io_open(conf.path, 'a+')
        if not file then
            return nil, err
        end

        -- it will case output problem with buffer when log is larger than buffer
        file:setvbuf("no")

        handler.file = file
        handler.open_time = ngx.now() * 1000
        return handler
    end

    function open_file_cache(conf)
        local last_reopen_time = process.get_last_reopen_ms()

        local handler, err = path_to_file(conf.path, 0, open_file_handler, conf, {})
        if not handler then
            return nil, err
        end

        if handler.open_time < last_reopen_time then
            core.log.notice("reopen cached log file: ", conf.path)
            handler.file:close()

            local ok, err = open_file_handler(conf, handler)
            if not ok then
                return nil, err
            end
        end

        return handler.file
    end
end

local function get_log_level(conf)
    if not conf.log_level then
        return "error"
    end
    return string.lower(conf.log_level)
end

local function get_response_status()
    local ctx = ngx.ctx
    local upstream_status = tonumber(ctx.upstream_status)
    if upstream_status then
        return upstream_status
    end
    local status = tonumber(ngx.var.status)
    if status then
        return status
    end
    return 0
end

local function get_request_body()
    local resq_body = ngx.req.get_body_data()
    if resq_body then
        return resq_body
    end
    return "-"
end

local function log_request_body(status, body)
    if string.sub(status, 1, 1) == "5" and string.len(status) == 3 then
        return body
    end
        return "-"
end
    

local function write_file_data(conf)
    local remote_addr = ngx.var.remote_addr or "-"
    local remote_user = ngx.var.remote_user or "-"
    local time_local = ngx.var.time_local or "-"
    local request_time = ngx.var.request_time or "-"
    local upstream_response_time = ngx.var.upstream_response_time or "0.000"
    local upstream_addr = ngx.var.upstream_addr or "-"
    local scheme = ngx.var.scheme or "-"
    local host = ngx.var.host or "-"
    local request = ngx.var.request or "-"
    local status = get_response_status() or "-"
    local body_bytes_sent = ngx.var.body_bytes_sent or "-"
    local http_referer = ngx.var.http_referer or "-"
    local http_user_agent = ngx.var.http_user_agent or "-"
    local http_x_forwarded_for = ngx.var.http_x_forwarded_for or "-"
    local resq_body = log_request_body(status, get_request_body())

    local msg = string_format("%s - %s [%s] \"%.3f\" \"%.3f\" \"%s\" \"%s://%s\" \"%s\" %d %d \"%s\" \"%s\" \"%s\" \"%s\"" , remote_addr, remote_user, time_local, request_time, upstream_response_time, upstream_addr, scheme, host, request, status, body_bytes_sent, http_referer, http_user_agent, http_x_forwarded_for, resq_body)


    local file, err
    if open_file_cache then
        file, err = open_file_cache(conf)
    else
        file, err = io_open(conf.path, 'ab+')
    end

    local log_level = get_log_level(conf)
    if log_level ~= "error" and log_level ~= "warn" then
        return
    end

    if not file then
        core.log.error("failed to open file: ", conf.path, ", error info: ", err)
    else
        -- file:write(msg, "\n") will call fwrite several times
        -- which will cause problem with the log output
        -- it should be atomic
        msg = msg .. "\n"
        -- write to file directly, no need flush
        local ok, err = file:write(msg)
        if not ok then
            core.log.error("failed to write file: ", conf.path, ", error info: ", err)
        end

        -- file will be closed by gc, if open_file_cache exists
        if not open_file_cache then
            file:close()
        end
    end
end


function _M.log(conf, ctx)
    write_file_data(conf)
end


return _M


```



### 配置

```
需要在config-default.yaml的plugins 加上参数

plugins:
- nt-logger

curl 127.0.0.1:9090/v1/schema > schema.json

systemctl reload apisix
systemctl reload apisix-dashboard
```





# 自定义错误日志error_log收集插件（未）

```
需求：1.隔离不同业务的日志，避免日志污染。 只收集当前任务
```



# 自定义测试

## test-logger.lua-1

```
local core = require("apisix.core")
local log = require("apisix.utils.log-util")
local ngx_ERR = ngx.ERR
local ngx_WARN = ngx.WARN
local plugin_name = "test-logger"
local error_log_format = "[%s] lua_log:%s [%s] %s %s %s"

local _M = {
    version = 0.1,
    priority = 399,
    name = plugin_name,
    schema = {
        type = "object",
        properties = {
            log_filename = {
                type = "string",
                default = "/usr/local/apisix/logs/error.log"
            }
        },
        required = {"log_filename"}
    }
}


local open_file_cache
if is_apisix_or then

    local path_to_file = core.lrucache.new({
        type = "plugin",
    })

    local function open_file_handler(conf, handler)
        local file, err = io_open(conf.log_filename, 'a+')
        if not file then
            return nil, err
        end

        file:setvbuf("no")

        handler.file = file
        handler.open_time = ngx.now() * 1000
        return handler
    end

    function open_file_cache(conf)
        local last_reopen_time = process.get_last_reopen_ms()

        local handler, err = path_to_file(conf.log_filename, 0, open_file_handler, conf, {})
        if not handler then
            return nil, err
        end

        if handler.open_time < last_reopen_time then
            core.log.notice("reopen cached log file: ", conf.log_filename)
            handler.file:close()

            local ok, err = open_file_handler(conf, handler)
            if not ok then
                return nil, err
            end
        end

        return handler.file
    end
end


function _M.log(conf,route, ctx)
    local error_log_enabled = route.log_config and route.log_config.error_log
 --   local log_path = error_log_enabled and route.log_config.error_log.path or nil
    local log_path=conf.log_filename
    ngx.log(ngx.ERR, "this is a log_path: ", log_path, ", err: ", error_log_enabled)
    if not log_path then
        return
    end

    local logger = log:new(route.log_config or {})
    logger:set_file(log_filename)

    local request_id = ngx.ctx.tracing_id or "-"
    local client_ip = ngx.var.remote_addr or "-"
    local log_string = string.format("[%s] lua_log: test_logger [%s] %s %s",
        "NGINX", request_id, ngx.var.uri, client_ip)
    logger:log(ngx_ERR, log_string)
end

return _M

```



## error-logger.lua

```
local cjson = require("cjson")
local log = require("apisix.core.log")
local tostring = tostring
local type = type
local error = error

local ngx_log = ngx.log
local ngx_ERR = ngx.ERR
local ngx_WARN = ngx.WARN

local plugin_name = "error-logger"

local schema = {
    type = "object",
    properties = {
        path = {
            type = "string",
            default = "/var/log/nginx/error.log"
        }
    },
    required = {"path"}
}

local _M = {
    version = 0.1,
    priority = 399,
    name = plugin_name,
    schema = schema
}

local function get_log_path(conf, level, route_id)
    --return conf.log_dir .. "/" .. level .. "/" .. ngx.var.host .. "/" .. route_id .. ".log"
    return conf.path
end

function _M.log(conf)
    local level = ngx.get_phase() == "log" and ngx_WARN or ngx_ERR
    local route_id = ngx.var.upstream_http_x_apisix_matched_route_id or "-"
    --ngx_log(ngx_ERR, "failed to open file for writing log: ", level,route_id,err)

    local log_path = get_log_path(conf, level, route_id)
    local log_file = io.open(log_path, "a")
    if not log_file then
        ngx_log(ngx_ERR, "failed to open file for writing log: ", log_path)
        return
    end

    local log_msg = cjson.encode({
        remote_addr = ngx.var.remote_addr,
        remote_user = "-",
        time_local = ngx.localtime(),
        request = ngx.var.request,
        status = ngx.var.status,
        body_bytes_sent = ngx.var.body_bytes_sent,
        http_referer = ngx.var.http_referer or "-",
        http_user_agent = ngx.var.http_user_agent or "-",
        route = route_id,
        service = ngx.var.upstream_http_x_apisix_service_id or "-",
        err_message = ngx.var.err_message or "-",
        err_stack = ngx.var.err_stack or "-",
        err_trace_id = ngx.var.err_trace_id or "-",
    })

    local request_id = ngx.ctx.request_id

    local ok, err = log_file:write(log_msg .. "\n")
    if not ok then
        ngx_log(ngx_ERR, "failed to write log to file: ", err)
    end

    local ok, err = log_file:close()
    if not ok then
        ngx_log(ngx_ERR, "failed to close file for writing log: ", err)
    end
end


return _M

```



##  fk-logger.lua

```
local core          = require("apisix.core")
local ipairs = ipairs
local local_plugins = core.table.new(32, 0)
local local_plugins_hash    = core.table.new(0, 32)

local plugin_name = "fk-logger"

local schema = {
    type = "object",
    properties = {
        path = {
            type = "string",
            default = "/data/logs/dev-pje/nginx/error_xxl_job_admin_apisix.log"
        }
    },
    required = {"path"}
}

local _M = {
    version = 0.1,
    plugins = local_plugins,
    priority = 900,
    name = plugin_name,
    schema = schema
}

local function collect_logs(conf)
    local logs = {}

    for _, plugin in ipairs(local_plugins_hash) do
         core.log.warn("loaded plugin and sort by priority:",
                          " name: ", plugin.name)
        if plugin.log and plugin.log_level then
            local log_level = plugin.log_level()
            local log = plugin.log()

            if log and log_level and (log_level == "warn" or log_level == "error") then
                logs[plugin.name] = log
            end
        end
    end

    return logs
end

local function write_logs(logs, file_path)
    local file = io.open(file_path, "a")

    for plugin_name, log in pairs(logs) do
        file:write("Plugin: " .. plugin_name .. "\n")
        file:write(log .. "\n")
    end

    file:close()
end

function _M.log()
    local route = ngx.ctx.route
    local logs = collect_logs()

    if next(logs) ~= nil then
        local file_path = "/data/logs/dev-pje/nginx/error_xxl_job_admin_apisix.log"
        write_logs(logs, file_path)
    end
end
    log_level = function()
    return "warn"
end

return _M

```



## error-log-collector.lua

```
local log_path = "/data/logs/apisix/error.log"
local processed_plugins = {} --已处理的插件列表
local cjson = require("cjson.safe")
local log = require("apisix.core.log")
local json_decode = cjson.decode
local table_clone = require("table.clone")

local schema = {
    type = "object",
        properties = {
        path = {
            type = "string",
            default = "/data/logs/dev-pje/nginx/error_xxl_job_admin_apisix.log"
        }
    },
    required = {"path"}
}



local _M = {
    version = 0.1,
    priority = 1000,
    name = "error-log-collector",
    schema = schema
}


-- 首次插件加载，初始化插件的配置
function _M.init_worker()
    local conf = core.config.fetch(plugin_name)
    if not conf then
        ngx.log(ngx.ERR, "this is a log_path: ", plugin_name, ", err: ", err)
        -- 默认的日志保存路径
        conf = {
            log_dir = "/var/log/apisix",
        }
        core.config.update({
            [plugin_name] = conf
        })
    end
end

-- 提取路由的ID，用于创建路由日志保存的目录
local function extract_route_id(route_handle)
    -- 获得 route.name 或者 route.id
    return route_handle and route_handle.match_rule and
            (route_handle.match_rule.name or route_handle.match_rule.id)
end

-- 将日志输出到指定的文件中
local function write_to_file(file_path, data)
    ngx.log(ngx.ERR, "this is a log_path: ",file_path, ", err: ", err)
    local file, err = io.open(file_path, "a+")
    if not file then
        log.error("failed to open file: ", file_path, "error: ", err)
        return
    end

    local status, err = file:write(data, "\n")
    if not status then
        log.error("failed to write data to file: ", file_path, "error: ", err)
    end

    local status, err = file:close()
    if not status then
        log.error("failed to close file: ", file_path, "error: ", err)
        return
    end
end

-- 保存日志到文件中的方法
local function save_log(conf, level, msg, route_handle, plugin_name)
    local route_id = extract_route_id(route_handle)

    local log_data = {
        level = level,
        msg = msg,
        time = ngx.now(),
        route_id = route_id,
    }

    local log_file_path = conf.log_dir .. "/" .. plugin_name .. "/" .. route_id .. ".log"
    local log_str = cjson.encode(log_data)

    write_to_file(log_file_path, log_str)
end

-- 日志方法的实现
function _M.log(plugin_conf)
    -- 不处理 info 级别的日志
    if ngx.get_phase() ~= "log" or ngx.ctx.api_stash == nil or ngx.ctx.route_handle == nil or ngx.ctx.route_handle.match_rule == nil or ngx.ctx.var.upstream_status == "503" or ngx.ctx.var.upstream_status == "504" then
       return
    end

    local route_handle = ngx.ctx.route_handle
    local msg = (ngx.ctx.msg and json_decode(ngx.ctx.msg)) or ""
    local conf = table_clone(plugin_conf)

    if ngx.ctx.errmsg then
        conf.log_dir = conf.log_dir .. "/error"
        save_log(conf, "error", ngx.ctx.errmsg, route_handle, plugin_name)
    end

    if ngx.var.status >= 400 and ngx.var.status ~= 404 then
        conf.log_dir = conf.log_dir .. "/warn"
        save_log(conf, "warn", msg or "", route_handle, plugin_name)
    end
end

return _M

```



# 补充：

## 端口含义

| port | 含义                               |      |      |      |
| ---- | ---------------------------------- | ---- | ---- | ---- |
| 2379 | 用于客户端连接                     |      |      |      |
| 2380 | 用于伙伴连接（集群）               |      |      |      |
| 9080 | 类似nginx的80端口                  |      |      |      |
| 9443 | 类似nginx的443端口                 |      |      |      |
| 9180 | admin访问接口                      |      |      |      |
| 9000 | manager-api、dashbroad界面端口     |      |      |      |
| 9090 | control,对http apisx有效果         |      |      |      |
| 9091 | apisix.plugins.prometheus.exporter |      |      |      |





## etcd的单机多节点部署

| name    | ip        | port      |
| ------- | --------- | --------- |
| etcd-01 | 127.0.0.1 | 2379,2380 |
| etcd-02 | 127.0.0.1 | 2479,2480 |
| etcd-03 | 127.0.0.1 | 2579,2580 |



# 使用jenkins进行灰度原理

```
您可以通过编写 Jenkins Pipeline来实现这种灰度的更新。下面是一个简单的示例：


Copy code
pipeline {
    agent any

    stages {
        stage('Update A Nginx Config') {
            steps {
                // 更新A机器的nginx.conf配置，将流量转移到C
                sh "ssh user@a-machine 'sudo sed -i s/B-server/C-server/g /etc/nginx/nginx.conf' && ssh user@a-machine 'sudo systemctl reload nginx'"
            }
        }
        stage('Wait for B Connections to Close') {
            steps {
                // 检查B机器的d服务连接数是否为0
                script {
                    def connectionCount = sh(returnStdout: true, script: "ssh user@b-server 'netstat -an | grep 8080 | wc -l'").trim()
                    while (connectionCount != '0') {
                        sleep time: 10, unit: 'SECONDS'
                        connectionCount = sh(returnStdout: true, script: "ssh user@b-server 'netstat -an | grep 8080 | wc -l'").trim()
                    }
                }
            }
        }
        stage('Update B Java Service') {
            steps {
                // 更新B机器上的d服务
                sh "ssh user@b-server 'sudo systemctl stop d-service' && ssh user@b-server 'sudo yum update d-service' && ssh user@b-server 'sudo systemctl start d-service'"
            }
        }
        stage('Check B Java Service') {
            steps {
                // 检查B机器上的d服务是否正常启动
                script {
                    def status = sh(returnStatus: true, script: "ssh user@b-server 'sudo systemctl status d-service'")
                    if (status != 0) {
                        error("Error: Failed to start d-service on B server.")
                    }
                }
            }
        }
        stage('Update A Nginx Config') {
            steps {
                // 更新A机器的nginx.conf配置，将流量转移到B
                sh "ssh user@a-machine 'sudo sed -i s/C-server/B-server/g /etc/nginx/nginx.conf' && ssh user@a-machine 'sudo systemctl reload nginx'"
            }
        }
        stage('Wait for C Connections to Close') {
            steps {
                // 检查C机器的d服务连接数是否为0
                script {
                    def connectionCount = sh(returnStdout: true, script: "ssh user@c-server 'netstat -an | grep 8080 | wc -l'").trim()
                    while (connectionCount != '0') {
                        sleep time: 10, unit: 'SECONDS'
                        connectionCount = sh(returnStdout: true, script: "ssh user@c-server 'netstat -an | grep 8080 | wc -l'").trim()
                    }
                }
            }
        }
        stage('Update C Java Service') {
            steps {
                // 更新C机器上的d服务
                sh "ssh user@c-server 'sudo systemctl stop d-service' && ssh user@c-server 'sudo yum update d-service' && ssh user@c-server 'sudo systemctl start d-service'"
            }
        }
        stage('Check C Java Service') {
            steps {
                // 检查C机器上的d服务是否正常启动
                script {
                    def status = sh(returnStatus: true, script: "ssh user@c-server 'sudo systemctl status d-service'")
                    if (status != 0) {
                        error("Error: Failed to start d-service on C server



861401039@qq.com
如何讲这个实例高级化
对于这个实例，我们可以通过以下方式进行高级化：

自动化测试：在切换流量之前，我们可以先进行自动化测试，确保新版本的服务在B/C机器上运行正常，这可以通过Jenkins和其他测试框架来实现。

自动化部署：使用自动化部署工具（例如Ansible、Chef或Puppet）来部署新版本的服务，以减少手动操作的风险和错误。

线上监控：在进行灰度部署时，需要对线上的服务进行监控，以及时发现异常并进行处理。可以使用监控工具（例如Prometheus、Grafana）来监控服务的性能指标、日志和警报。

服务容器化：使用Docker或Kubernetes等容器化技术，将服务打包为镜像，并通过容器编排工具进行部署和管理。这样可以更加方便地进行服务的版本管理和部署。

自动化回滚：如果新版本的服务出现问题，需要及时回滚到之前的版本，可以使用自动化回滚脚本或工具来实现。

持续交付：通过持续集成和持续交付实践，实现自动化构建、测试和部署，提高交付效率和质量。可以使用Jenkins等CI/CD工具来实现。

这些高级化的实践可以提高生产环境中服务的可靠性、稳定性和安全性，降低灰度部署的风险和成本。
```











