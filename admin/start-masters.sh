#!/bin/bash
#set -x 
. ./utils.sh

if [ $# -ne 2 ];then
  echo "$0: <node_list> <master_host_port_list>"
  exit 1
fi

nodes=$1
master_list=$2

for i in $(cat $nodes)
do
  c=$(echo $i|cut -c1)
  if [ "$c" == "#" ];then 
    continue
  fi
  echo $i
  start_masters $i $master_list
done

