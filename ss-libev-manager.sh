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

get_icmp_prohibited() { if [ $1 == iptables ]; then echo icmp-host-prohibited; else echo icmp6-adm-prohibited; fi }

do_if_not_exist() {
    monitor=$(eval $1)
    if [ ${#monitor} == 0 ]; then
        eval $2
    fi
}

check_chains() {
    do_if_not_exist   "$1 -nvL | grep SSIN"            "$1 -N SSIN"
    do_if_not_exist   "$1 -nvL INPUT | grep SSIN"      "$1 -A INPUT -j SSIN"
    do_if_not_exist   "$1 -nvL | grep SSOUT"           "$1 -N SSOUT"
    do_if_not_exist   "$1 -nvL OUTPUT | grep SSOUT"    "$1 -A OUTPUT -j SSOUT"
}

accept_all() {
    do_if_not_exist    "$1 -nvL | grep 'tcp dpt:$2'"    "$1 -A SSIN -p tcp --dport $2"
    do_if_not_exist    "$1 -nvL | grep 'udp dpt:$2'"    "$1 -A SSIN -p udp --dport $2"
    do_if_not_exist    "$1 -nvL | grep 'tcp spt:$2'"    "$1 -A SSOUT -p tcp --sport $2"
    do_if_not_exist    "$1 -nvL | grep 'udp spt:$2'"    "$1 -A SSOUT -p udp --sport $2"
}

accept_ip() {
    do_if_not_exist    "$1 -nvL | grep '$2.*tcp dpt:$3'"    "$1 -A SSIN -p tcp -s $2 --dport $3 -j ACCEPT"
    do_if_not_exist    "$1 -nvL | grep '$2.*udp dpt:$3'"    "$1 -A SSIN -p udp -s $2 --dport $3 -j ACCEPT"
    do_if_not_exist    "$1 -nvL | grep '$2.*tcp spt:$3'"    "$1 -A SSOUT -p tcp -d $2 --sport $3 -j ACCEPT"
    do_if_not_exist    "$1 -nvL | grep '$2.*udp spt:$3'"    "$1 -A SSOUT -p udp -d $2 --sport $3 -j ACCEPT"
}

reject_all() {
    icmp_prohibited=$(get_icmp_prohibited $1)
    do_if_not_exist    "$1 -nvL | grep 'REJECT.*tcp dpt:$2'"    "$1 -A SSIN -p tcp --dport $2 -j REJECT --reject-with tcp-reset"
    do_if_not_exist    "$1 -nvL | grep 'REJECT.*udp dpt:$2'"    "$1 -A SSIN -p udp --dport $2 -j REJECT --reject-with $icmp_prohibited"
    do_if_not_exist    "$1 -nvL | grep 'REJECT.*tcp spt:$2'"    "$1 -A SSOUT -p tcp --sport $2 -j REJECT --reject-with tcp-reset"
    do_if_not_exist    "$1 -nvL | grep 'REJECT.*udp spt:$2'"    "$1 -A SSOUT -p udp --sport $2 -j REJECT --reject-with $icmp_prohibited"
}

set_rules() {
    cmd=$1
    port=$2
    if [ $cmd == iptables ]; then allow_list=($(echo ${allow_list_v4[@]})); else allow_list=($(echo ${allow_list_v6[@]})); fi
    if [ ${#allow_list[@]} -ne 0 ]; then
        for ip in ${allow_list[@]}; do
            accept_ip $cmd $ip $port
        done
        reject_all $cmd $port
    else
        accept_all $cmd $port
    fi
    echo "Add $port $cmd monitor."
    if [ ${#monitor} -ne 0 ]; then
        echo "No changes with $1."
    fi
}

do_start() {
    check_chains iptables
    check_chains ip6tables
    local_port=1080
    for line in "${configs[@]}"; do
        config=($line)
        nohup ${ssserver} -c ${config[0]} -l $local_port -p ${config[1]} -k ${config[2]} -m ${config[3]} > /var/log/ss-libev-manager/${config[1]}.log &
        set_rules iptables ${config[1]}
        set_rules ip6tables ${config[1]}
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