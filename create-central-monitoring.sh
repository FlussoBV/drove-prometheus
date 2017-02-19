#!/usr/bin/env bash

LOGNAME=DROVE-MON
PREFIX=drove-mon
NETWORK=drove-mon

# NODE EXPORTER
NODE_EXPORTER_SERVICE=${PREFIX}-node-exporter
NODE_EXPORTER_IMAGE=basi/node-exporter:latest

# CADVISOR
CADVISOR_SERVICE=${PREFIX}-cadvisor
CADVISOR_IMAGE=google/cadvisor:v0.24.1

# PROMETHEUS
PROM_SERVICE=${PREFIX}-prometheus
PROM_IMAGE=caladreas/drove-prometheus

# GRAFANA
GRAFANA_SERVICE=${PREFIX}-grafana
GRAFANA_IMAGE=grafana/grafana:4.1.1

# Pull images
docker pull $NODE_EXPORTER_IMAGE
docker pull $CADVISOR_IMAGE
docker pull $PROM_IMAGE
docker pull $GRAFANA_IMAGE
######################################

docker network ls | grep $NETWORK
RC=$?
if [ $RC != 0 ]; then
    echo "[$LOGNAME] creating network $NETWORK"
    docker network create \
    --driver overlay \
    --subnet 10.0.9.0/24 \
    --label drove \
    $NETWORK
else 
    echo "[$LOGNAME] network $NETWORK already exists"
fi

#####################################
#### NODE EXPORTER
#####################################
EXISTING=`docker service ls | grep -c $NODE_EXPORTER_SERVICE`
if [ $EXISTING -gt 0 ]
then
    echo "[$LOGNAME] service $NODE_EXPORTER_SERVICE already exists"
else
    echo "[$LOGNAME] creating$NODE_EXPORTER_SERVICE"
    docker \
      service create \
      --name $NODE_EXPORTER_SERVICE \
      --mode global \
      --network $NETWORK \
      --label com.docker.stack.namespace=$NETWORK \
      --mount type=bind,source=/proc,target=/host/proc \
      --mount type=bind,source=/sys,target=/host/sys \
      --mount type=bind,source=/,target=/rootfs \
      --mount type=bind,source=/etc/hostname,target=/etc/host_hostname \
      -e HOST_HOSTNAME=/etc/host_hostname \
       $NODE_EXPORTER_IMAGE \
      -collector.procfs /host/proc \
      -collector.sysfs /host/sys \
      -collector.filesystem.ignored-mount-points "^/(sys|proc|dev|host|etc)($|/)" \
      --collector.textfile.directory /etc/node-exporter/ \
      --collectors.enabled="conntrack,diskstats,entropy,filefd,filesystem,loadavg,mdadm,meminfo,netdev,netstat,stat,textfile,time,vmstat,ipvs"
fi
######################################
######################################

#####################################
#### C Advisor
#####################################
EXISTING=`docker service ls | grep -c $CADVISOR_SERVICE`
if [ $EXISTING -gt 0 ]
then
    echo "[$LOGNAME] service $CADVISOR_SERVICE already exists"
else
    echo "[$LOGNAME] creating$CADVISOR_SERVICE"
    docker service create --name $CADVISOR_SERVICE \
        --mode global \
        --network $NETWORK \
        --label com.docker.stack.namespace=$NETWORK \
        --container-label com.docker.stack.namespace=$NETWORK \
        --mount type=bind,src=/,dst=/rootfs:ro \
        --mount type=bind,src=/var/run,dst=/var/run:rw \
        --mount type=bind,src=/sys,dst=/sys:ro \
        --mount type=bind,src=/var/lib/docker/,dst=/var/lib/docker:ro \
        $CADVISOR_IMAGE
fi
######################################
######################################

#####################################
#### PROMETHEUS
#####################################
EXISTING=`docker service ls | grep -c $PROM_SERVICE`
if [ $EXISTING -gt 0 ]
then
    echo "[$LOGNAME] service $PROM_SERVICE already exists"
else
    echo "[$LOGNAME] creating$PROM_SERVICE"
    docker service create \
        --name $PROM_SERVICE \
        --network $NETWORK \
        --label com.docker.stack.namespace=$NETWORK \
        --container-label com.docker.stack.namespace=$NETWORK \
        -p 9090:9090 \
        $PROM_IMAGE \
        -config.file=/etc/prometheus/prometheus.yml \
        -storage.local.path=/prometheus 
fi
######################################
######################################

#####################################
#### GRAFANA
#####################################
EXISTING=`docker service ls | grep -c $GRAFANA_SERVICE`
if [ $EXISTING -gt 0 ]
then
    echo "[$LOGNAME] service $GRAFANA_SERVICE already exists"
else
    echo "[$LOGNAME] creating$GRAFANA_SERVICE"
    docker service create \
        --name $GRAFANA_SERVICE \
        --network $NETWORK \
        --label com.docker.stack.namespace=$NETWORK \
        --container-label com.docker.stack.namespace=$NETWORK \
        -p 3000:3000 \
        -e "GF_SECURITY_ADMIN_PASSWORD=password" \
        $GRAFANA_IMAGE
fi
######################################
######################################