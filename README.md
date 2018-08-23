Those are copied and modified from @teddysun.


一、下载安装
首先需要将脚本下载到某个固定路径下，比如 /opt 下，再赋予执行权限。
执行以下命令：

wget --no-check-certificate -O /opt/shadowsocks-crond.sh https://raw.githubusercontent.com/imfy/shadowsocks-script/master/shadowsocks-crond.sh
chmod 755 /opt/shadowsocks-crond.sh


二、检查 cron 进程
执行以下命令，检查 cron 进程是否存在：

ps -ef | grep -v grep | grep cron

如果存在返回值，则表示 cron 已经正确安装并处于启动中。
否则，则需要安装 cron。

CentOS/Redhat/Amazon 执行如下命令：

yum install -y crontabs

Debian/Ubuntu 执行如下命令：

apt-get install -y cron


三、配置 cron 计划
假设监视脚本路径就是 /opt/shadowsocks-crond.sh
假设设为每 5 分钟监视一次。
那么配置 cron 计划如下：

(crontab -l ; echo "*/5 * * * * /opt/shadowsocks-crond.sh") | crontab -

以上表示，在保留原有的 cron 设置的前提下，追加设置
*/5 * * * * /opt/shadowsocks-crond.sh
即每过 5 分钟，执行一次脚本 /opt/shadowsocks-crond.sh

这样系统便会每 5 分钟检查一下 Shadowsocks 进程是否存在，如果不存在了会自动重新启动。
脚本每次运行会写日志的，日志完整路径如下：
/var/log/shadowsocks-crond.log
