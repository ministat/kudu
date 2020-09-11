#!/bin/bash

INSTALL_DIR="/opt/kudu"
KUDU_BIN_DIR=${INSTALL_DIR}/bin
WWW_DIR=${INSTALL_DIR}/www
DATA_DIR="/var/lib/kudu"
CONF_DIR="/etc/kudu/conf"
ETC_INIT_DIR="/etc/init.d"
LOG_DIR="/var/log/kudu"
MASTER_WAL_DIR="/var/lib/kudu/masterwal"
TSERVER_WAL_DIR="/var/lib/kudu/tserverwal"
MASTER_DATA_DIR="/hadoop/8/kudu/masterdata"
TSERVER_DATA_DIR1="/hadoop/7/kudu/tserverdata"
TSERVER_DATA_DIR2="/hadoop/8/kudu/tserverdata"
ETC_INIT_SCRIPTS=init

function pre_install() {
  local node=$1
  ssh $node "sudo yum update -y"
  ssh $node "sudo yum install -y cyrus-sasl-gssapi cyrus-sasl-plain krb5-server krb5-workstation openssl"
}

function setup_kudu_user() {
  local node=$1
  local exist=`ssh $node "getent passwd kudu > /dev/null && echo true"`
  if [ "$exist" == "" ];then
    ssh $node 'sudo /usr/sbin/useradd --shell /bin/bash -m kudu'
  else
    echo "kudu exists on $node"
  fi
}

function remove_kudu_user() {
  local node=$1
  local exist=`ssh $node "getent passwd kudu > /dev/null && echo true"`
  if [ "$exist" == "true" ];then
    ssh $node 'sudo /usr/sbin/userdel -r kudu'
  else
    echo "kudu exists on $node"
  fi
}

# assume the directories are already created
function refresh_conf() {
  local node=$1
  scp -r conf ${node}:~
  ssh ${node} "sudo mv conf/* ${CONF_DIR}/"
}

function copy_install_bin() {
  local node=$1
  ## create bin dir, copy bins
  ssh $node "sudo mkdir -p ${KUDU_BIN_DIR} && sudo chown -R kudu:kudu ${KUDU_BIN_DIR}"
  scp kudu kudu-master kudu-tserver ${node}:~
  ssh $node "sudo mv kudu kudu-master kudu-tserver ${KUDU_BIN_DIR}"
  ssh $node "sudo chown kudu:kudu ${KUDU_BIN_DIR}/*"

  ## create conf dir, copy confs
  ssh $node "sudo mkdir -p ${CONF_DIR}"
  scp -r conf ${node}:~
  ssh ${node} "sudo mv conf/* ${CONF_DIR}/"

  ## copy www
  scp -r www ${node}:~
  ssh ${node} "sudo cp -r www $INSTALL_DIR/ && rm -rf www"

  ## copy etc scripts
  scp -r init ${node}:~
  ssh ${node} "sudo mv init/* ${ETC_INIT_DIR}/"
  ssh ${node} "sudo chown kudu:kudu ${ETC_INIT_DIR}/kudu-*"

  ## create required directories
  ssh $node "sudo mkdir -p ${LOG_DIR} && sudo chmod 777 -R ${LOG_DIR}"
  ## create master directories
  ssh $node "sudo mkdir -p ${MASTER_WAL_DIR} && sudo chown kudu:kudu -R ${MASTER_WAL_DIR}"
  ssh $node "sudo mkdir -p ${MASTER_DATA_DIR} && sudo chown kudu:kudu -R ${MASTER_DATA_DIR}"

  ## create tserver directories
  ssh $node "sudo mkdir -p ${TSERVER_WAL_DIR} && sudo chown kudu:kudu -R ${TSERVER_WAL_DIR}"
  ssh $node "sudo mkdir -p ${TSERVER_DATA_DIR1} && sudo chown kudu:kudu -R ${TSERVER_DATA_DIR1}"
  ssh $node "sudo mkdir -p ${TSERVER_DATA_DIR2} && sudo chown kudu:kudu -R ${TSERVER_DATA_DIR2}"
}

function clean_all_data() {
  local node=$1
  ssh $node "sudo [ -d ${MASTER_WAL_DIR} ] && sudo rm -rf ${MASTER_WAL_DIR} && sudo mkdir -p ${MASTER_WAL_DIR} && sudo chown kudu:kudu -R ${MASTER_WAL_DIR}"
  ssh $node "sudo [ -d ${TSERVER_WAL_DIR} ] && sudo rm -rf ${TSERVER_WAL_DIR} && sudo mkdir -p ${TSERVER_WAL_DIR} && sudo chown kudu:kudu -R ${TSERVER_WAL_DIR}"
  ssh $node "sudo [ -d ${MASTER_DATA_DIR} ] && sudo rm -rf ${MASTER_DATA_DIR} && sudo mkdir -p ${MASTER_DATA_DIR} && sudo chown kudu:kudu -R ${MASTER_DATA_DIR}"
  ssh $node "sudo [ -d ${TSERVER_DATA_DIR1} ] && sudo rm -rf ${TSERVER_DATA_DIR1} && sudo mkdir -p ${TSERVER_DATA_DIR1} && sudo chown kudu:kudu -R ${TSERVER_DATA_DIR1}"
  ssh $node "sudo [ -d ${TSERVER_DATA_DIR2} ] && sudo rm -rf ${TSERVER_DATA_DIR2} && sudo mkdir -p ${TSERVER_DATA_DIR2} && sudo chown kudu:kudu -R ${TSERVER_DATA_DIR2}"
  ssh $node "sudo [ -d /var/lib/kudu/masterwal ] &&  sudo rm -rf /var/lib/kudu/masterwal && sudo mkdir /var/lib/kudu/masterwal && sudo chown -R kudu:kudu /var/lib/kudu/masterwal"
  ssh $node "sudo [ -d /var/lib/kudu/masterdata ] &&  sudo rm -rf /var/lib/kudu/masterdata && sudo mkdir /var/lib/kudu/masterdata && sudo chown -R kudu:kudu /var/lib/kudu/masterdata"
  ssh $node "sudo [ -d /var/lib/kudu/tserverwal ] &&  sudo rm -rf /var/lib/kudu/tserverwal && sudo mkdir /var/lib/kudu/tserverwal && sudo chown -R kudu:kudu /var/lib/kudu/tserverwal"
}

function start_tserver() {
  local node=$1
  local masters_host_port=$2
cat << EOF > tserver_config.sh
#!/bin/bash

existStr=\$(grep "^--tserver_master_addrs=" \$1)
if [ "\$existStr" != "" ]; then
  sed -i 's/--tserver_master_addrs=.*/--tserver_master_addrs=$masters_host_port/g' \$1
else
  echo "--tserver_master_addrs=$masters_host_port" >> \$1
fi
EOF
  scp tserver_config.sh $node:~
  ssh $node "sudo sh tserver_config.sh $CONF_DIR/tserver.gflagfile"
  ssh $node "sudo /etc/init.d/kudu-tserver start"
}

function stop_tserver() {
  local node=$1
  ssh $node "sudo /etc/init.d/kudu-tserver stop"
}

function tserver_status() {
  local node=$1
  ssh $node "sudo /etc/init.d/kudu-tserver status"
}

function start_masters() {
  local node=$1
  local masters_host_port=$2
cat << EOF > master_config.sh
#!/bin/bash

existStr=\$(grep "^--master_addresses=" \$1)
if [ "\$existStr" != "" ]; then
  sed -i 's/--master_addresses=.*/--master_addresses=$masters_host_port/g' \$1
else
  echo "--master_addresses=$masters_host_port" >> \$1
fi
EOF
  scp master_config.sh $node:~
  ssh $node "sudo sh master_config.sh $CONF_DIR/master.gflagfile"
  ssh $node "sudo /etc/init.d/kudu-master start"
}

function masters_status() {
  local node=$1
  ssh $node "sudo /etc/init.d/kudu-master status"
}

function stop_masters() {
  local node=$1
  ssh $node "sudo /etc/init.d/kudu-master stop"
}


