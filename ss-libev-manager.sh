#!/bin/bash
# chkconfig: 2345 90 10
# description: A secure socks5 proxy, designed to protect your Internet traffic.

### BEGIN INIT INFO
# Provides:          fy
# Required-Start:    $network $syslog
# Required-Stop:     $network
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Fast tunnel proxy that helps you bypass firewalls
# Description:       Start or Stop the Shadowsocks-libev server to support multiple users with ss-manager
### END INIT INFO

ssserver=/usr/local/bin/ss-server
# The params in configs are port, password and encrypt method.
configs=(
    "8388 123456 aes-128-gcm"
    "8389 123456 aes-128-gcm"
)

do_start() {
    local_port=1080
    for line in "${configs[@]}"; do
        config=($line)
        nohup ${ssserver} -s 0.0.0.0 -l $local_port -p ${config[0]} -k ${config[1]} -m ${config[2]} > /var/log/ss-libev-manager/${config[0]}.log &
        monitor=$(iptables -L -v -n | grep dpt:${config[0]})
        if [ ${#monitor} == 0 ]; then
            iptables -A OUTPUT -p tcp --sport ${config[0]}
        fi
        let "local_port++"
        echo "Port" ${config[0]} "with encrypt" ${config[2]} "started."
    done
}

do_status() {
    ps -ef | grep ss-server | grep -v grep
}

do_stop() {
    for pid in $(pgrep -f ss-server); do
        kill -9 $pid
        echo $pid" Stoped."
    done
}

do_restart() {
    do_stop
    sleep 0.5
    do_start
}

do_check() {
    for line in "${configs[@]}"; do
        config=($line)
        pid=$(pgrep -f "${config[0]} -k ${config[1]} -m ${config[2]}")
        if [ ${#pid} == 0 ]; then
            do_restart
            break
        fi
    done
}

if [ ! -d "/var/log/ss-libev-manager" ]; then
  mkdir /var/log/ss-libev-manager
fi
case "$1" in
    start|stop|restart|status|check)
    do_$1
    ;;
    "")
    do_restart
    ;;
    *)
    echo "Usage: $0 { start | stop | restart | status | check }"
    ;;
esac
