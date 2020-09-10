#!/bin/bash
. ./utils.sh
if [ $# -ne 1 ];then
  echo "$0: <node_list>"
  exit 1
fi

nodes=$1

for i in $(cat $nodes)
do
  echo $i
  setup_kudu_user $i
  copy_install_bin $i
done

