Those are copied and modified from @teddysun.

# 一、安装Shadowsock

此处直接使用@teddysun 提供的四合一版
``` bash
wget --no-check-certificate -O shadowsocks-all.sh https://raw.githubusercontent.com/teddysun/shadowsocks_install/master/shadowsocks-all.sh
chmod +x shadowsocks-all.sh
./shadowsocks-all.sh 2>&1 | tee shadowsocks-all.log
```

# 二、进行加速优化

锐速BBR根据实际环境二选一

## 1. 锐速

使用的是@0oVicero0 提供的锐速破解版（原贴链接：https://www.hostloc.com/forum.php?mod=viewthread&tid=342860 ）
``` bash
wget --no-check-certificate -O appex.sh https://raw.githubusercontent.com/0oVicero0/serverSpeeder_Install/master/appex.sh && chmod +x appex.sh && bash appex.sh install
```

## 2. BBR魔改版（仅OpenVZ）

使用的是木木提供的魔改版BBR（原文链接：https://www.bbaaz.com/thread-91-1-1.html ）
``` bash
wget https://makeai.cn/master/ovz-bbr/ovz-bbr-installer.sh && chmod +x ovz-bbr-installer.sh && ./ovz-bbr-installer.sh
```
注意好处在于可以自由控制端口和重启，但需要开启TUN/TAP


## 3. BBR魔改版

若需在KVM上或者无法开启TUN/TAP的机器上使用BBR，推荐使用南琴浪@nanqinlang 的版本
仓库链接：https://github.com/tcp-nanqinlang/wiki/wiki/general

# 三、设置多端口

除了libev版，其它版本均可通过在config.json中添加端口信息实现，libev版本可通过ss-manager实现多端口，但近几个版本的ss-manager似乎有点问题，因此额外写了一个多端口控制脚本。
``` bash
rm /etc/init.d/shadowsocks-libev
wget --no-check-certificate -O /etc/init.d/ss-libev-manager.sh https://raw.githubusercontent.com/imfy/shadowsocks-script/master/ss-libev-manager.sh && chmod +x /etc/init.d/ss-libev-manager.sh
```
可通过编辑文件开头的configs来实现端口的添加：
``` bash
vim /etc/init.d/ss-libev-manager.sh
```
编辑完后执行重启指令：
``` bash
/etc/init.d/ss-libev-manager.sh restart
```

# 四、设置守护

受限于不同VPS的运行环境，当VPS较差时，ss服务可能会挂掉或者卡死，因此需要加一个监控，使得ss挂掉时可自动修复。

## 1. 安装cron

先检查 cron 进程是否存在：
``` bash
ps -ef | grep -v grep | grep cron
```
如果存在返回值，则表示 cron 已经正确安装并处于启动中。
否则，则需要安装 cron。
CentOS/Redhat/Amazon 执行如下命令：
``` bash
yum install -y crontabs
```
Debian/Ubuntu 执行如下命令：
``` bash
apt-get install -y cron
```

## 2. 配置 cron 计划

BBR
``` bash
*/2 * * * * /etc/init.d/ss-libev-manager.sh check
01 */6 * * * /etc/init.d/ss-libev-manager.sh restart
01 */6 * * * systemctl restart haproxy-lkl
*/30 * * * * echo 3 > /proc/sys/vm/drop_caches
```
锐速
``` bash
*/2 * * * * /etc/init.d/ss-libev-manager.sh check
01 */6 * * * /etc/init.d/ss-libev-manager.sh restart
01 */6 * * * /appex/bin/serverSpeeder.sh restart
*/30 * * * * echo 3 > /proc/sys/vm/drop_caches
```
