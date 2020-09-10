#!/bin/bash
. ./utils.sh

if [ $# -ne 1 ];then
  echo "$0: <node_list>"
  exit 1
fi

nodes=$1

for i in $(cat $nodes)
do
  c=$(echo $i|cut -c1)
  if [ "$c" == "#" ];then 
    continue
  fi
  pre_install $i
  echo "==finish: $i"
done
