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
    "/root/config.json 8388 123456 aes-128-gcm"
    "/root/config.json 8389 123456 aes-128-gcm"
)

# 更新后请先使用【iptables -F】或【ip6tables -F】清除规则
allow_list=()
allow_list_ip6=()

do_start() {
    local_port=1080
    for line in "${configs[@]}"; do
        config=($line)
        nohup ${ssserver} -c ${config[0]} -l $local_port -p ${config[1]} -k ${config[2]} -m ${config[3]} > /var/log/ss-libev-manager/${config[1]}.log &
        monitor=$(iptables -L -v -n | grep spt:${config[1]})
        monitor6=$(ip6tables -L -v -n | grep spt:${config[1]})
        if [ ${#monitor} == 0 ]; then
            if [ ${#allow_list[@]} -ne 0 ]; then
                for ip in ${allow_list[@]}; do
                    iptables -A INPUT -p tcp -s $ip --dport ${config[1]} -j ACCEPT
                    iptables -A INPUT -p udp -s $ip --dport ${config[1]} -j ACCEPT
                    iptables -A OUTPUT -p tcp -d $ip --sport ${config[1]} -j ACCEPT
                    iptables -A OUTPUT -p udp -d $ip --sport ${config[1]} -j ACCEPT
                done
                iptables -A INPUT -p tcp --dport ${config[1]} -j REJECT --reject-with tcp-reset
                iptables -A INPUT -p udp --dport ${config[1]} -j REJECT --reject-with icmp-host-prohibited
                iptables -A OUTPUT -p tcp --sport ${config[1]} -j REJECT --reject-with tcp-reset
                iptables -A OUTPUT -p udp --sport ${config[1]} -j REJECT --reject-with icmp-host-prohibited
            else
                iptables -A INPUT -p tcp --dport ${config[1]}
                iptables -A INPUT -p udp --dport ${config[1]}
                iptables -A OUTPUT -p tcp --sport ${config[1]}
                iptables -A OUTPUT -p udp --sport ${config[1]}
            fi
            echo "Add iptables monitor."
        fi
        if [ ${#monitor6} == 0 ]; then
            if [ ${#allow_list_ip6[@]} -ne 0 ]; then
                for ip in ${allow_list_ip6[@]}; do
                    ip6tables -A INPUT -p tcp -s $ip --dport ${config[1]} -j ACCEPT
                    ip6tables -A INPUT -p udp -s $ip --dport ${config[1]} -j ACCEPT
                    ip6tables -A OUTPUT -p tcp -d $ip --sport ${config[1]} -j ACCEPT
                    ip6tables -A OUTPUT -p udp -d $ip --sport ${config[1]} -j ACCEPT
                done
                ip6tables -A INPUT -p tcp --dport ${config[1]} -j REJECT --reject-with tcp-reset
                ip6tables -A INPUT -p udp --dport ${config[1]} -j REJECT --reject-with icmp6-adm-prohibited
                ip6tables -A OUTPUT -p tcp --sport ${config[1]} -j REJECT --reject-with tcp-reset
                ip6tables -A OUTPUT -p udp --sport ${config[1]} -j REJECT --reject-with icmp6-adm-prohibited
            else
                ip6tables -A INPUT -p tcp --dport ${config[1]}
                ip6tables -A INPUT -p udp --dport ${config[1]}
                ip6tables -A OUTPUT -p tcp --sport ${config[1]}
                ip6tables -A OUTPUT -p udp --sport ${config[1]}
            fi
            echo "Add ip6tables monitor."
        fi
        if [ ${#monitor} -ne 0 ] && [ ${#monitor6} -ne 0 ]; then
            echo "No changes with iptables and ip6tables."
        fi
        let "local_port++"
        echo "Port" ${config[1]} "with encrypt" ${config[3]} "started."
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
