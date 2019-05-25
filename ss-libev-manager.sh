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
    *)
    echo "Usage: $0 { start | stop | restart | status | check }"
    ;;
esac
