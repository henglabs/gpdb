HS_PREFIX="zzzz-hengshi-"
GREENPLUM_DEPS=(rsync net-tools net-snmp)

function checkSudoPermission() {
    local file=$1
    if [ $# -ne 1 ];then
        echo "$0 file"
        return 1
    fi
    if [ -z "${file}" ] || ! [ -f "${file}" ];then
        echo "host file error!"
        return 1
    fi
    while read line || [ -n "$line" ];do
        if [ -n "${line}" ];then
            # check sudo permission
            if ! ssh $line "sudo echo OK" </dev/null;then
              echo "${line} has no sudo permission!"
              return 1
            fi
        fi
    done<${file}
}
function checkEnvAndPermission() {
  local file=$1
  if [ $# -ne 1 ];then
    echo "$0 file"
    return 1
  fi
  if [ -z "${file}" ] || ! [ -f "${file}" ];then
    echo "host file error!"
    return 1
  fi
  # hostname check
  while read line || [ -n "$line" ];do
    if [ -n "${line}" ];then
      ssh $line "hostname" </dev/null
    fi
  done<${file} |sort |uniq -c |\
  while read count host || [ -n "$host" ];do
    if [ $count -ne 1 ];then
      echo "hostname ${host} is duplicated!"
      return 1
    fi
  done
  while read line || [ -n "$line" ];do #防止最后一行无换行符时漏读
    if [ -n "${line}" ];then
      # rsync check
      hasRsync=`ssh $line "if rsync --version >/dev/null 2>&1;then echo true;else echo false;fi" </dev/null`
      if [ "${hasRsync}" == "false" ];then
        echo "${line}: rsync is not installed!"
        return 1
      fi
    fi
  done<${file}
}

function copyBin() {
  local file=$1
  local binRootDir=$2
  if [ $# -ne 2 ];then
    echo "$0 file binRootDir"
    return 1
  fi
  if [ -z "${file}" ] || ! [ -f "${file}" ];then
    echo "host file error!"
    return 1
  fi
  if [ -z "${binRootDir}" ] || ! [ -d "${binRootDir}" ];then
    echo "binRootDir error!"
    return 1
  fi
  while read line || [ -n "$line" ];do
    if [ -n "${line}" ];then
      copied=`ssh $line "if [ -d ${binRootDir} ];then echo true;else echo false;fi" </dev/null`
      if [ "${copied}" == "false" ];then
        ssh $line "mkdir -p ${binRootDir}" </dev/null
        rsync -avrzP -e ssh ${binRootDir}/ $line:${binRootDir}
      fi
    fi
  done<${file}
}

function installSysDeps() {
  local file=$1
  while read line || [ -n "$line" ];do
      ssh $line "sudo yum install -y ${GREENPLUM_DEPS[@]}" </dev/null
  done<${file}
}

function updateSysConfig() {
  local file=$1
  local binRootDir=$2
  local limitsConf=$3
  local sysctlConf=$4
  if [ $# -ne 4 ];then
    echo "$0 file binRootDir limitsConf sysctlConf"
    return 1
  fi
  if [ -z "${file}" ] || ! [ -f "${file}" ];then
    echo "host file error!"
    return 1
  fi
  if [ -z "${binRootDir}" ] || ! [ -d "${binRootDir}" ];then
    echo "binRootDir error!"
    return 1
  fi
  if [ -z "${limitsConf}" ] || ! [ -f "${limitsConf}" ];then
    echo "limitsConf file error!"
    return 1
  fi
  if [ -z "${sysctlConf}" ] || ! [ -f "${sysctlConf}" ];then
    echo "sysctlConf file error!"
    return 1
  fi
  local tmpLimitsConf=/tmp/${HS_PREFIX}limits.conf
  local tmpSysctlConf=/tmp/${HS_PREFIX}sysctl.conf
  local remoteLimitsConf="/etc/security/limits.d/${HS_PREFIX}limits.conf"
  local remoteSysctlConf="/etc/sysctl.d/${HS_PREFIX}sysctl.conf"
  local sysbak="~/sysbak"
  while read line || [ -n "$line" ];do
    if [ -n "${line}" ];then
      rsync -avrzP -e ssh ${limitsConf} $line:${tmpLimitsConf}
      rsync -avrzP -e ssh ${sysctlConf} $line:${tmpSysctlConf}
      ssh $line "mkdir -p ${sysbak}; if [ -f ${remoteLimitsConf} ];then cp ${remoteLimitsConf} ${sysbak}/limits.conf.bk.`date +%s`; fi;if [ -f ${remoteSysctlConf} ];then cp ${remoteSysctlConf} ${sysbak}/sysctl.conf.bk.`date +%s`; fi;sudo mv ${tmpLimitsConf} ${remoteLimitsConf};sudo mv ${tmpSysctlConf} ${remoteSysctlConf};sudo sysctl --system" </dev/null
    fi
  done<${file}
}

function getNoFileLimit() {
  ulimit -n
}

function getNProcLimit() {
  ulimit -u
}

function checkHostSysConfig() {
  # check sem
  sem=`cat /proc/sys/kernel/sem|awk '{print $1" "$2" "$3" "$4}'`
  semmsl=`cat /proc/sys/kernel/sem|awk '{print $1}'`
  semmns=`cat /proc/sys/kernel/sem|awk '{print $2}'`
  semopm=`cat /proc/sys/kernel/sem|awk '{print $3}'`
  semmni=`cat /proc/sys/kernel/sem|awk '{print $4}'`
  # if [ "${sem}" != "250 2018500 100 8074" ];then
  if [ $semmsl -lt 250 ] || [ $semmns -lt 2018500 ] || [ $semopm -lt 100 ] || [ $semmni -lt 8074 ]; then
    echo "kernel.sem is not set properly, please check it manually in /etc/sysctl.conf and /etc/sysctl.d/*.conf"
    return 1
  fi
  # check limits
  if [ `getNoFileLimit` -lt 65536 ];then
    echo "open files limit is not set properly, please check it manually in /etc/security/limits.conf and /etc/security/limits.d/*.conf"
    return 1
  fi
  if [ `getNProcLimit` -lt 131072 ];then
    echo "max user processes is not set properly, please check it manually in /etc/security/limits.conf and /etc/security/limits.d/*.conf"
    return 1
  fi
}

function checkSysConfig() {
  local file=$1
  local binRootDir=$2
  if [ $# -ne 2 ];then
    echo "$0 file binRootDir"
    return 1
  fi
  if [ -z "${file}" ] || ! [ -f "${file}" ];then
    echo "host file error!"
    return 1
  fi
  if [ -z "${binRootDir}" ] || ! [ -d "${binRootDir}" ];then
    echo "binRootDir error!"
    return 1
  fi
  while read line || [ -n "$line" ];do
    if [ -n "${line}" ];then
      ok=`ssh $line "source ${binRootDir}/bin/util.sh;if checkHostSysConfig;then echo true;else echo false;fi" </dev/null`
      if [ "${ok}" != "true" ];then
        echo "${line} checkHostSysConfig fail! ${ok}"
        return 1
      fi
    fi
  done<${file}
}
