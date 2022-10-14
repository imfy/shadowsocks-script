### 一、安装Shadowsocks

此处直接使用@teddysun 提供的四合一版
``` bash
wget --no-check-certificate -O shadowsocks-all.sh https://raw.githubusercontent.com/teddysun/shadowsocks_install/master/shadowsocks-all.sh
chmod +x shadowsocks-all.sh
./shadowsocks-all.sh 2>&1 | tee shadowsocks-all.log
```

### 二、进行加速优化

锐速BBR根据实际环境二选一，OpenVZ和LXC架构只能使用OpenVZ版的魔改BBR，KVM和XEN架构可以选锐速或KVM版的BBR。这两者对内核要求有区别，BBR只支持较新的内核，而锐速仅支持较旧的内核（0oVicero0大佬已经做出支持新内核的锐速了，但听说效果不是很好）

#### 1. 锐速

使用的是@0oVicero0 提供的锐速破解版（原贴 https://www.hostloc.com/forum.php?mod=viewthread&tid=342860 已删除，目前可使用备份：https://github.com/Meilinhost/LotServer_Vicer ）
``` bash
bash <(wget --no-check-certificate -qO- https://github.com/Meilinhost/LotServer_Vicer/raw/master/Install.sh) install
```
Debian/Unbuntu若提示内核版本不支持，可使用以下命令自动更换内核（更换后需重启）
``` bash
bash <(wget --no-check-certificate -qO- 'https://moeclub.org/attachment/LinuxShell/Debian_Kernel.sh')
```

#### 2. 原版BBR
需要内核版本>4.9，Debian 9 和 Ubuntu 18.04 以上版本默认内核即可支持
``` bash
echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
sysctl -p
```

#### 3. BBR魔改版（木木）

木木提供的魔改版BBR仅支持OpenVZ（原文链接：https://www.bbaaz.com/thread-91-1-1.html ）
``` bash
wget https://makeai.cn/master/ovz-bbr/ovz-bbr-installer.sh && chmod +x ovz-bbr-installer.sh && ./ovz-bbr-installer.sh
```
该版好处在于控制端口和重启较为方便，但因为是lkl-haproxy版，需要开启TUN/TAP。


#### 4. BBR魔改版（南琴浪）

若需在KVM上或者无法开启TUN/TAP的OpenVZ机器上使用BBR，推荐使用南琴浪@nanqinlang 的版本（仓库链接：https://github.com/tcp-nanqinlang/wiki/wiki/general ）

其中lkl-haproxy版只能在OpenVZ架构上使用，且需要开启TUN/TAP；lkl-rinetd版也只能在OpenVZ上使用，但不需要开启TUN/TAP；general版只能在KVM上使用。


### 三、设置多端口

除了libev版，其它版本均可通过在config.json中添加端口信息实现，libev版本可通过ss-manager实现多端口，但近几个版本的ss-manager似乎有点问题，因此额外写了一个多端口控制脚本。

#### 1. 移除原有自启动服务

由于会和libev自带的自启动服务冲突，因此要先移除默认的自启动服务：
``` bash
rm /etc/init.d/shadowsocks-libev
```

#### 2. 下载ss-libev-manager并设为开机自动启动

``` bash
wget --no-check-certificate -O /etc/init.d/ss-libev-manager.sh https://raw.githubusercontent.com/imfy/shadowsocks-script/master/ss-libev-manager.sh && chmod 755 /etc/init.d/ss-libev-manager.sh
update-rc.d ss-libev-manager.sh defaults 99
```

#### 3. 下载配置文件
此处直接放到/root/ 目录下了，可根据实际需求更改文件位置。
``` bash
wget --no-check-certificate -O /root/config.json https://raw.githubusercontent.com/imfy/shadowsocks-script/master/config.json
```

#### 4. 配置多端口

可通过编辑文件开头的configs来实现端口的添加：
``` bash
vim /etc/init.d/ss-libev-manager.sh
```
例如我要开启8388和8389两个端口，密码和加密方式均设为123456和aes-128-gcm，两个端口均使用/root/config.json这个配置文件，则configs可写成如下。如需添加更多端口，按相同格式新添加行即可。
``` bash
configs=(
"/root/config.json 8388 123456 aes-128-gcm"
"/root/config.json 8389 123456 aes-128-gcm"
)
```
编辑完后执行重启指令：
``` bash
/etc/init.d/ss-libev-manager.sh restart
```

#### 4. 端口流量监控

``` bash
iptables -L -v -n
```

### 四、设置守护

受限于不同VPS的运行环境，当VPS环境较差时，ss服务可能会挂掉或者卡死，因此需要加一个监控，在ss挂掉时可自动修复。

#### 1. 安装cron

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

#### 2. 配置 cron 计划

编辑cron计划
``` bash
crontab -e
```
在文本末尾加上如下信息

BBR
``` bash
*/2 * * * * /etc/init.d/ss-libev-manager.sh check
1 */6 * * * /etc/init.d/ss-libev-manager.sh restart
1 */6 * * * systemctl restart haproxy-lkl
*/30 * * * * echo 3 > /proc/sys/vm/drop_caches
0 0 1 * * iptables -Z OUTPUT
```
锐速
``` bash
*/2 * * * * /etc/init.d/ss-libev-manager.sh check
1 */6 * * * /etc/init.d/ss-libev-manager.sh restart
1 */6 * * * /appex/bin/lotServer.sh restart
*/30 * * * * echo 3 > /proc/sys/vm/drop_caches
0 0 1 * * iptables -Z OUTPUT
```
添加的5行信息依次为：
``` bash
1. 每隔2分钟检查一次当前ss运行状态（check指令会检查是否有端口掉线，若掉线则重启）
2. 每6小时重启一次ss（因为ss有时会“假死”，进程没死但却不工作了，因此光检查进程是否活着还不够，还需要设置一个定时重启。设置成每隔6小时的01分重启是为了避免与第一条指令同时执行导致出错）
3. 每6小时重启一次加速工具（加速有时也会假死，特指nanqinlang的BBR）
4. 每30分钟清除一次缓存（Virmach的部分KVM会把内存撑爆导致ss和cron进程全被杀掉）
5. 每个月的1号重置流量统计（可根据VPS流量重置时间自行设定）
```
完成编辑后重启cron
``` bash
/etc/init.d/cron restart
```
