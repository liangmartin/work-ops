# Redis主从复制





主从复制，是指将一台 Redis 服务器的数据，复制到其他的 Redis 服务器。前者称为主节点（Master/Leader）,后者称为从节点（Slave/Follower）， 数据的复制是单向的！只能由主节点复制到从节点（主节点以写为主、从节点以读为主）—— 读写分离。



| 机器  | 作用   |
| ----- | ------ |
| mater | 写请求 |
| slave | 读请求 |



# 一、配置

![image-20220929152642995](C:\Users\Administrator\Desktop\md文件\images\image-20220929152642995.png)





# 二、启动



![image-20220929152817702](C:\Users\Administrator\Desktop\md文件\images\image-20220929152817702.png)



# 三、主从复制



## 1、从机配置

![image-20220929152905243](C:\Users\Administrator\Desktop\md文件\images\image-20220929152905243.png)

## 2、主机配置

![image-20220929152926363](C:\Users\Administrator\Desktop\md文件\images\image-20220929152926363.png)



## 3、从机查看

![image-20220929152943259](C:\Users\Administrator\Desktop\md文件\images\image-20220929152943259.png)



# Redis哨兵模式































































