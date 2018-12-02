set -e
set -u

source $(dirname $0)/util.sh

BIN_DIR=""
CLUSTER_DIR=""
SEGMENT_HOSTS_FILE=""
NEW_SEGMENT_HOSTS_FILE=""
DO_REBALANCE=""

function initEnv() {
  BIN_DIR=$(dirname $0)
  BIN_DIR=$(cd ${BIN_DIR};pwd)
}

function checkAndEnsureExpandSsh() {
  local file=$1
  local expandFile=$2
  local exKeyBin=$3
  if [ $# -ne 3 ];then
    echo "$0 file expandFile exKeyBin"
    return 1
  fi
  if [ -z "${file}" ] || ! [ -f "${file}" ];then
    echo "host file error!"
    return 1
  fi
  if [ -z "${expandFile}" ] || ! [ -f "${expandFile}" ];then
    echo "expandFile file error!"
    return 1
  fi
  if [ -z "${exKeyBin}" ] || ! [ -x "${exKeyBin}" ];then
    echo "gpssh-exkeys error!"
    return 1
  fi
  ${exKeyBin} -e ${file} -x ${expandFile}
}

function doCheck() {
  checkAndEnsureExpandSsh ${SEGMENT_HOSTS_FILE} ${NEW_SEGMENT_HOSTS_FILE} ${BIN_DIR}/gpssh-exkeys
  checkEnvAndPermission ${NEW_SEGMENT_HOSTS_FILE}
}

function doExpand() {
  copyBin ${NEW_SEGMENT_HOSTS_FILE} $(dirname ${BIN_DIR})
  updateSysConfig ${SEGMENT_HOSTS_FILE} $(dirname ${BIN_DIR}) ${CLUSTER_DIR}/conf/limits.conf ${CLUSTER_DIR}/conf/sysctl.conf
  source ${CLUSTER_DIR}/export-cluster.sh
  cp -r ${CLUSTER_DIR}/data/SegDataDir-1 ${CLUSTER_DIR}/data/SegDataDir-1-bk-`date +%s`
  EXPAND_DB="hs_expand_db"
  psql postgres -c "CREATE DATABASE ${EXPAND_DB}"
  while read line || [ -n "$line" ];do
    if [ -n "${line}" ];then
      ssh $line "if ! [ -d ${CLUSTER_DIR}/data ];then mkdir -p ${CLUSTER_DIR}/data;fi" </dev/null
      ssh $line "if ! [ -d ${CLUSTER_DIR}/mirror ];then mkdir -p ${CLUSTER_DIR}/mirror;fi" </dev/null
    fi
  done<${NEW_SEGMENT_HOSTS_FILE}
  gpexpand -f ${NEW_SEGMENT_HOSTS_FILE} -D ${EXPAND_DB}
  EXPAND_INPUTFILE=`ls -tr gpexpand_inputfile_*|tail -n 1`
  echo "EXPAND_INPUTFILE: ${EXPAND_INPUTFILE}"
  gpexpand -i ${EXPAND_INPUTFILE} -D ${EXPAND_DB}
}

function cleanExpandMsg() {
  gpexpand -c -D ${EXPAND_DB}
  psql postgres -c "DROP DATABASE IF EXISTS ${EXPAND_DB}"
}

function usage() {
    echo -e "\033[32m $0 [OPTIONS]
    -d dir of cluster.
    -h file name of hosts of segments, one host in a line
    -n file name of new hosts of segments, one host in a line
    -b if you want to rebalance data afterwards, please set it 'y', else set 'n'
    \033[0m
    "
}

function checkMinimalOpts() {
  if [ -z "${CLUSTER_DIR}" ] || [ -z "${SEGMENT_HOSTS_FILE}" ] || [ -z "${NEW_SEGMENT_HOSTS_FILE}" ] || [ -z "${DO_REBALANCE}" ];then
    usage
    exit 1
  fi
}

function main() {
  initEnv
  while getopts ":d:h:n:b:" opt; do
    case "$opt" in
      d)
        CLUSTER_DIR="${OPTARG}"
        ;;
      h)
        SEGMENT_HOSTS_FILE="${OPTARG}"
        ;;
      n)
        NEW_SEGMENT_HOSTS_FILE="${OPTARG}"
        ;;
      b)
	DO_REBALANCE="${OPTARG}"
	;;
      *)
        usage
        exit 1
        ;;
    esac
  done
  CLUSTER_DIR=$(cd ${CLUSTER_DIR};pwd)

  checkMinimalOpts

  echo -e "\033[32m ---------------------------\033[0m"
  echo -e "\033[32m BIN_DIR:                   \033[0m" ${BIN_DIR}
  echo -e "\033[32m CLUSTER_DIR:               \033[0m" ${CLUSTER_DIR}
  echo -e "\033[32m SEGMENT_HOSTS_FILE:        \033[0m" ${SEGMENT_HOSTS_FILE}
  echo -e "\033[32m NEW_SEGMENT_HOSTS_FILE:    \033[0m" ${NEW_SEGMENT_HOSTS_FILE}
  echo -e "\033[32m ---------------------------\033[0m"
  echo

  source "${BIN_DIR}/../greenplum_path.sh"
  doCheck
  doExpand
  if [[ "y" != "${DO_REBALANCE}" ]];then
    echo "clean the expand message..."
    cleanExpandMsg  
  fi

}

# ===== main =====
if [[ "${BASH_SOURCE[0]}" == "$0" ]];then
  main $*
fi
