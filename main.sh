#!/bin/bash
set -Eeuo pipefail
set -o nounset
set -o errexit

if hash docker 2>/dev/null; then
     .
elif hash podman 2>/dev/null; then
    alias docker=podman
else
    echo >&2 "Script requires docker or podman.  Aborting."
    exit 1
fi

docker pull zabbix/zabbix-server-mysql

export ZABBIX_NET_NAME=zabbix-net
docker network create --subnet 172.20.0.0/16 --ip-range 172.20.240.0/20 "${ZABBIX_NET_NAME}"


docker run --name mysql-server -t \
             -e MYSQL_DATABASE="zabbix" \
             -e MYSQL_USER="zabbix" \
             -e MYSQL_PASSWORD="zabbix_pwd" \
             -e MYSQL_ROOT_PASSWORD="root_pwd" \
             --network="${ZABBIX_NET_NAME}" \
             --restart unless-stopped \
             -d mysql:8.0-oracle \
             --character-set-server=utf8 --collation-server=utf8_bin \
             --default-authentication-plugin=mysql_native_password


docker run --name zabbix-java-gateway -t \
             --network="${ZABBIX_NET_NAME}" \
             --restart unless-stopped \
             -d zabbix/zabbix-java-gateway:alpine-6.4-latest


docker run --name zabbix-server-mysql -t \
             -e DB_SERVER_HOST="mysql-server" \
             -e MYSQL_DATABASE="zabbix" \
             -e MYSQL_USER="zabbix" \
             -e MYSQL_PASSWORD="zabbix_pwd" \
             -e MYSQL_ROOT_PASSWORD="root_pwd" \
             -e ZBX_JAVAGATEWAY="zabbix-java-gateway" \
             --network="${ZABBIX_NET_NAME}" \
             -p 10051:10051 \
             --restart unless-stopped \
             -d zabbix/zabbix-server-mysql:alpine-6.4-latest


docker run --name zabbix-web-nginx-mysql -t \
             -e ZBX_SERVER_HOST="zabbix-server-mysql" \
             -e DB_SERVER_HOST="mysql-server" \
             -e MYSQL_DATABASE="zabbix" \
             -e MYSQL_USER="zabbix" \
             -e MYSQL_PASSWORD="zabbix_pwd" \
             -e MYSQL_ROOT_PASSWORD="root_pwd" \
             --network="${ZABBIX_NET_NAME}" \
             -p 8081:8080 \
             --restart unless-stopped \
             -d zabbix/zabbix-web-nginx-mysql:alpine-6.4-latest


docker run --name zabbix-agent \
     --network="${ZABBIX_NET_NAME}" \
     -p 10050:10050 \
     -e ZBX_SERVER_HOST="zabbix-server-mysql" \
     -d zabbix/zabbix-agent:6.4-alpine-latest