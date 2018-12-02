set -e
set -u

source $(dirname $0)/util.sh

BIN_DIR=""
CLUSTER_DIR=""
SEGMENT_NUM=0
SEGMENT_BASE_PORT=25432
MASTER_PORT=15432
SEGMENT_HOSTS_FILE=""
SNMP_MONITOR_ADDRESS="127.0.0.1:1620"
MIRROR_BASE_PORT=35432
REPLICATION_PORT_BASE=26432
MIRROR_REPLICATION_PORT_BASE=36432
MIRROR_ON_OFF="off"
MASTER_HOSTNAME="$(hostname)"
INITMODE="false"

function paramSet() {
  CLUSTER_PARAM_CONFIG=${CLUSTER_DIR}/conf/postgresql.conf
  sed -i -e "s/gp_snmp_monitor_address=.*\$/gp_snmp_monitor_address='${SNMP_MONITOR_ADDRESS}'/" ${CLUSTER_PARAM_CONFIG}
}

function initEnv() {
  BIN_DIR=$(dirname $0)
  BIN_DIR=$(cd ${BIN_DIR};pwd)
  CLUSTER_DIR="${BIN_DIR}/../../engine-cluster"
  CPU_NUM=$(cat /proc/cpuinfo|awk '/processor/{sum++}END{print sum}')
  SEGMENT_NUM=$((CPU_NUM - 4))
  if [ ${SEGMENT_NUM} -le 0 ];then
      SEGMENT_NUM=2
  fi
  PKG_ROOT="$(dirname $(dirname ${BIN_DIR}))"
  PKG_NAME=`cat ${BIN_DIR}/PKG_NAME`
  DEFAULT_PKG_ROOT="/home/gpadmin/${PKG_NAME}"
}

function checkAndEnsureSsh() {
  local file=$1
  local exKeyBin=$2
  if [ $# -ne 2 ];then
    echo "$0 file exKeyBin"
    return 1
  fi
  if [ -z "${file}" ] || ! [ -f "${file}" ];then
    echo "host file error!"
    return 1
  fi
  if [ -z "${exKeyBin}" ] || ! [ -x "${exKeyBin}" ];then
    echo "gpssh-exkeys error!"
    return 1
  fi
  ${exKeyBin} -f ${file}
}

function updatePkg() {
  GP_EXPORT_FILE="${BIN_DIR}/../greenplum_path.sh"
  sed -i -e "s:${DEFAULT_PKG_ROOT}:${PKG_ROOT}:g" ${GP_EXPORT_FILE}
}

function doCheck() {
  checkAndEnsureSsh ${SEGMENT_HOSTS_FILE} ${BIN_DIR}/gpssh-exkeys
  checkEnvAndPermission ${SEGMENT_HOSTS_FILE}
}

function installMaster() {
  if [ -d "${CLUSTER_DIR}" ];then
    cp -r ${BIN_DIR}/../../sample-cluster/* ${CLUSTER_DIR}
  else
    cp -r ${BIN_DIR}/../../sample-cluster/ ${CLUSTER_DIR}
  fi
  CLUSTER_EXPORT_FILE="${CLUSTER_DIR}/export-cluster.sh"
  CLUSTER_CONFIG_FILE="${CLUSTER_DIR}/conf/config"
  ONE_SEG_DIR="${CLUSTER_DIR}/data"
  DATA_DIRS="${ONE_SEG_DIR}"
  if [ ${SEGMENT_NUM} -gt 1 ];then
    for i in $(seq 2 ${SEGMENT_NUM});do
      DATA_DIRS="${DATA_DIRS} ${ONE_SEG_DIR}"
    done
  fi
  sed -i -e "s:${DEFAULT_PKG_ROOT}/gpdb/greenplum_path.sh:${PKG_ROOT}/gpdb/greenplum_path.sh:g" ${CLUSTER_EXPORT_FILE}
  sed -i -e "s:^export PGPORT=.*\$:export PGPORT=${MASTER_PORT}:" ${CLUSTER_EXPORT_FILE}
  sed -i -e "s:${DEFAULT_PKG_ROOT}/sample-cluster:${CLUSTER_DIR}:g" ${CLUSTER_EXPORT_FILE} ${CLUSTER_CONFIG_FILE}
  sed -i -e "s:^#declare -a DATA_DIRECTORY=.*\$:declare -a DATA_DIRECTORY=(${DATA_DIRS}):" ${CLUSTER_CONFIG_FILE}
  sed -i -e "s:^#MASTER_HOSTNAME=.*\$:MASTER_HOSTNAME=${MASTER_HOSTNAME}:" ${CLUSTER_CONFIG_FILE}
  sed -i -e "s:^#PORT_BASE=.*\$:PORT_BASE=${SEGMENT_BASE_PORT}:" ${CLUSTER_CONFIG_FILE}
  sed -i -e "s:^#MASTER_PORT=.*\$:MASTER_PORT=${MASTER_PORT}:" ${CLUSTER_CONFIG_FILE}
  sed -i -e "s:^#MASTER_DIRECTORY=.*\$:MASTER_DIRECTORY=${ONE_SEG_DIR}:" ${CLUSTER_CONFIG_FILE}
}

function installMirror() {
  ONE_MIR_DIR="${CLUSTER_DIR}/mirror"
  MIRROR_DIRS="${ONE_MIR_DIR}"
  if [ ${SEGMENT_NUM} -gt 1 ];then
    for i in $(seq 2 ${SEGMENT_NUM});do
      MIRROR_DIRS="${MIRROR_DIRS} ${ONE_MIR_DIR}"
    done
  fi
  sed -i -e "s:^#MIRROR_PORT_BASE=.*\$:MIRROR_PORT_BASE=${MIRROR_BASE_PORT}:" ${CLUSTER_CONFIG_FILE}
  sed -i -e "s:^#REPLICATION_PORT_BASE=.*\$:REPLICATION_PORT_BASE=${REPLICATION_PORT_BASE}:" ${CLUSTER_CONFIG_FILE}
  sed -i -e "s:^#MIRROR_REPLICATION_PORT_BASE=.*\$:MIRROR_REPLICATION_PORT_BASE=${MIRROR_REPLICATION_PORT_BASE}:" ${CLUSTER_CONFIG_FILE}
  sed -i -e "s:^#declare -a MIRROR_DATA_DIRECTORY=.*\$:declare -a MIRROR_DATA_DIRECTORY=(${MIRROR_DIRS}):" ${CLUSTER_CONFIG_FILE}
}

function checkMirrorOpts() {
  if [ "on" = "${MIRROR_ON_OFF}" ];then
    installMirror
  fi
}

function doInstall() {
  installMaster
  checkMirrorOpts
  paramSet
  copyBin ${SEGMENT_HOSTS_FILE} $(dirname ${BIN_DIR})
  copyBin ${SEGMENT_HOSTS_FILE} ${CLUSTER_DIR}
}

function usage() {
    echo -e "\033[32m $0 [OPTIONS]
    -i init os env
    -b base port of segment. default is ${SEGMENT_BASE_PORT}
    -d dir of cluster. default is ${CLUSTER_DIR}
    -h file name of hosts of segments, one host in a line
    -p master port. default is ${MASTER_PORT}
    -s segment num. default is ${SEGMENT_NUM}
    -m snmp monitor address. default is ${SNMP_MONITOR_ADDRESS}
    -M master hostname. default is localhost.
    -f mirror switch. when f is "on", mirror is on. default is off
    -r mirror base port. default is ${MIRROR_BASE_PORT}
    \033[0m
    "
}

function checkMinimalOpts() {
  if [ -z "${SEGMENT_HOSTS_FILE}" ];then
    usage
    exit 1
  fi
}

function main() {
  initEnv
  while getopts ":b:d:h:p:s:m:r:f:M:i" opt; do
    case "$opt" in
      i)
        INITMODE="true"
        ;;
      b)
        SEGMENT_BASE_PORT="${OPTARG}"
        REPLICATION_PORT_BASE=`expr ${SEGMENT_BASE_PORT} + 1000`
        ;;
      d)
        CLUSTER_DIR="${OPTARG}"
        ;;
      h)
        SEGMENT_HOSTS_FILE="${OPTARG}"
        ;;
      p)
        MASTER_PORT="${OPTARG}"
        ;;
      s)
        SEGMENT_NUM="${OPTARG}"
        ;;
      m)
	SNMP_MONITOR_ADDRESS="${OPTARG}"
	;;
      M)
	MASTER_HOSTNAME="${OPTARG}"
	;;
      r)
        MIRROR_BASE_PORT="${OPTARG}"
        MIRROR_REPLICATION_PORT_BASE=`expr ${MIRROR_BASE_PORT} + 1000`
	;;
      f)
	MIRROR_ON_OFF="${OPTARG}"
	;;
      *)
        usage
        echo "unknown opt: ${OPTARG}"
        exit 1
        ;;
    esac
  done

  checkMinimalOpts

  echo -e "\033[32m ----------------------------------\033[0m"
  echo -e "\033[32m INIT MODE:                        \033[0m" ${INITMODE}
  echo -e "\033[32m MASTER_HOSTNAME:                  \033[0m" ${MASTER_HOSTNAME}
  echo -e "\033[32m BIN_DIR:                          \033[0m" ${BIN_DIR}
  echo -e "\033[32m SEGMENT_BASE_PORT:                \033[0m" ${SEGMENT_BASE_PORT}
  echo -e "\033[32m CLUSTER_DIR:                      \033[0m" ${CLUSTER_DIR}
  echo -e "\033[32m SEGMENT_HOSTS_FILE:               \033[0m" ${SEGMENT_HOSTS_FILE}
  echo -e "\033[32m MASTER_PORT:                      \033[0m" ${MASTER_PORT}
  echo -e "\033[32m SEGMENT_NUM:                      \033[0m" ${SEGMENT_NUM}
  echo -e "\033[32m MIRROR_ON_OFF:                    \033[0m" ${MIRROR_ON_OFF}
  echo -e "\033[32m MIRROR_BASE_PORT:                 \033[0m" ${MIRROR_BASE_PORT}
  echo -e "\033[32m REPLICATION_PORT_BASE:            \033[0m" ${REPLICATION_PORT_BASE}
  echo -e "\033[32m MIRROR_REPLICATION_PORT_BASE:     \033[0m" ${MIRROR_REPLICATION_PORT_BASE}
  echo -e "\033[32m ----------------------------------\033[0m"
  echo

  updatePkg
  source "${BIN_DIR}/../greenplum_path.sh"
  doCheck
  if ! [ -d ${CLUSTER_DIR} ];then
    mkdir -p ${CLUSTER_DIR}
  fi
  CLUSTER_DIR=$(cd ${CLUSTER_DIR};pwd)

  if [ "true" = "${INITMODE}" ];then
      checkSudoPermission ${SEGMENT_HOSTS_FILE}
      local sample_dir="${BIN_DIR}/../../sample-cluster"
      updateSysConfig ${SEGMENT_HOSTS_FILE} $(dirname ${BIN_DIR}) ${sample_dir}/conf/limits.conf ${sample_dir}/conf/sysctl.conf
      exit 0
  fi
  doInstall
}

# ===== main =====
if [[ "${BASH_SOURCE[0]}" == "$0" ]];then
  main $*
fi
