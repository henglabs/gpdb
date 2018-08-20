set -e

function uniq_name(){
    echo `date '+%F-%H-%M-%S-%N'`
}

function pkg_name(){
    echo "gpdb-${BRANCH}-${PLATFORM}-cluster"
}

function get_nexus_url() {
    echo "https://nexus.hengshi.org/content/repositories/releases/org/greenplum/gpdb/${BRANCH}/`pkg_name`.tar.gz"
}

function rename_if_exists(){
    if [ -e "$1" ];then
        mv "$1" "$1-bk-`uniq_name`"
    fi
}

function get_sys_info(){
    CPU_NUM=`cat /proc/cpuinfo |grep "cpu cores"|sort|uniq|awk '{print $4}'`
}

function copy_python_libs(){
    PY_DEST_DIR="$1"
    cp -r /usr/lib64/python2.7/site-packages/psutil* ${PY_DEST_DIR}/
    cp -r /usr/lib/python2.7/site-packages/lockfile* ${PY_DEST_DIR}/
    cp -r /usr/lib/python2.7/site-packages/paramiko* ${PY_DEST_DIR}/
    cp -r /usr/lib/python2.7/site-packages/setuptools* ${PY_DEST_DIR}/
    cp -r /usr/lib/python2.7/site-packages/pkg_resources* ${PY_DEST_DIR}/
    cp -r /usr/lib/python2.7/site-packages/conan* ${PY_DEST_DIR}/
    cp -r /usr/lib64/python2.7/site-packages/pycrypto* ${PY_DEST_DIR}/
    cp -r /usr/lib/python2.7/site-packages/pyasn1* ${PY_DEST_DIR}/
    cp -r /usr/lib64/python2.7/site-packages/bcrypt* ${PY_DEST_DIR}/
    cp -r /usr/lib64/python2.7/site-packages/cryptography* ${PY_DEST_DIR}/
    cp -r /usr/lib64/python2.7/site-packages/PyNaCl* ${PY_DEST_DIR}/
    cp -r /usr/lib/python2.7/site-packages/future* ${PY_DEST_DIR}/
    cp -r /usr/lib64/python2.7/site-packages/pygments* ${PY_DEST_DIR}/
    cp -r /usr/lib/python2.7/site-packages/pluginbase* ${PY_DEST_DIR}/
    cp -r /usr/lib/python2.7/site-packages/pylint* ${PY_DEST_DIR}/
    cp -r /usr/lib/python2.7/site-packages/patch* ${PY_DEST_DIR}/
    cp -r /usr/lib/python2.7/site-packages/colorama* ${PY_DEST_DIR}/
    cp -r /usr/lib/python2.7/site-packages/distro* ${PY_DEST_DIR}/
    cp -r /usr/lib/python2.7/site-packages/six* ${PY_DEST_DIR}/
    cp -r /usr/lib/python2.7/site-packages/bottle* ${PY_DEST_DIR}/
    cp -r /usr/lib64/python2.7/site-packages/PyYAML* ${PY_DEST_DIR}/
    cp -r /usr/lib/python2.7/site-packages/astroid* ${PY_DEST_DIR}/
    cp -r /usr/lib/python2.7/site-packages/fasteners* ${PY_DEST_DIR}/
    cp -r /usr/lib/python2.7/site-packages/node_semver* ${PY_DEST_DIR}/
    cp -r /usr/lib/python2.7/site-packages/requests* ${PY_DEST_DIR}/
    cp -r /usr/lib/python2.7/site-packages/PyJWT* ${PY_DEST_DIR}/
    cp -r /usr/lib64/python2.7/site-packages/cffi* ${PY_DEST_DIR}/
    cp -r /usr/lib64/python2.7/site-packages/_cffi_backend.so ${PY_DEST_DIR}/
    cp -r /usr/lib64/python2.7/site-packages/.libs_cffi_backend ${PY_DEST_DIR}/
    cp -r /usr/lib/python2.7/site-packages/enum* ${PY_DEST_DIR}/
    cp -r /usr/lib/python2.7/site-packages/asn1crypto* ${PY_DEST_DIR}/
    cp -r /usr/lib/python2.7/site-packages/idna* ${PY_DEST_DIR}/
    cp -r /usr/lib/python2.7/site-packages/ipaddress* ${PY_DEST_DIR}/
    cp -r /usr/lib/python2.7/site-packages/singledispatch* ${PY_DEST_DIR}/
    cp -r /usr/lib/python2.7/site-packages/isort* ${PY_DEST_DIR}/
    cp -r /usr/lib/python2.7/site-packages/configparser* ${PY_DEST_DIR}/
    cp -r /usr/lib/python2.7/site-packages/backports* ${PY_DEST_DIR}/
    cp -r /usr/lib/python2.7/site-packages/mccabe* ${PY_DEST_DIR}/
    cp -r /usr/lib64/python2.7/site-packages/wrapt* ${PY_DEST_DIR}/
    cp -r /usr/lib64/python2.7/site-packages/lazy_object_proxy* ${PY_DEST_DIR}/
    cp -r /usr/lib/python2.7/site-packages/monotonic* ${PY_DEST_DIR}/
    cp -r /usr/lib/python2.7/site-packages/certifi* ${PY_DEST_DIR}/
    cp -r /usr/lib/python2.7/site-packages/chardet* ${PY_DEST_DIR}/
    cp -r /usr/lib/python2.7/site-packages/urllib3* ${PY_DEST_DIR}/
    cp -r /usr/lib/python2.7/site-packages/pycparser* ${PY_DEST_DIR}/
    cp -r /usr/lib64/python2.7/site-packages/nacl ${PY_DEST_DIR}/
    cp -r /usr/lib64/python2.7/site-packages/python_gssapi* ${PY_DEST_DIR}/
    cp -r /usr/lib64/python2.7/site-packages/gssapi* ${PY_DEST_DIR}/
}

function build_centos7(){
    # prepare build dir
    BUILD_ROOT="build-`uniq_name`"
    mkdir ${BUILD_ROOT}
    cd ${BUILD_ROOT}
    BUILD_ROOT=`pwd`
    INSTALL_DIR=`pwd`/`pkg_name`
    mkdir ${INSTALL_DIR}
    mkdir ${INSTALL_DIR}/gpdb ${INSTALL_DIR}/sample-cluster
    mkdir ${INSTALL_DIR}/sample-cluster/conf ${INSTALL_DIR}/sample-cluster/data ${INSTALL_DIR}/sample-cluster/mirror
    get_sys_info
    # install deps
    if ! gcc --version;then
        sudo yum install gcc
    fi
    sudo yum install -y python2 python-devel wget which krb5-devel
    if ! which pip;then
        wget "https://bootstrap.pypa.io/get-pip.py"
        sudo python get-pip.py
    fi
    sudo pip install psutil lockfile paramiko setuptools conan pycrypto
    if sudo pip uninstall -y python-gssapi;then
        #
        true
    fi
    sudo pip install python-gssapi
    tmpfile="tmp-`uniq_name`"
    sudo yum repolist >${tmpfile}
    if ! grep epel ${tmpfile};then
        wget "https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm"
        sudo rpm -ivh epel-release-latest-7.noarch.rpm
    fi
    sudo yum makecache
    sudo yum install -y man passwd sudo tar which git mlocate links make bzip2 net-tools \
         autoconf automake libtool m4 gcc gcc-c++ gdb bison flex gperf maven indent \
         libuuid-devel krb5-devel libgsasl-devel expat-devel libxml2-devel \
         perl-ExtUtils-Embed pam-devel python-devel libcurl-devel snappy-devel \
         thrift-devel libyaml-devel libevent-devel bzip2-devel openssl-devel \
         openldap-devel protobuf-devel readline-devel net-snmp-devel apr-devel \
         libesmtp-devel python-pip json-c-devel java-1.7.0-openjdk-devel lcov cmake3 \
         openssh-clients openssh-server perl-JSON perl-Env xerces-c-devel xerces-c \
         perl-devel perl-ExtUtils-Embed readline readline-devel zlib-devel python-wrapt
    sudo ln -sf /usr/bin/cmake3 /usr/bin/cmake
    # build gpdb
    cd ${SCRIPT_DIR}/../
    cd depends
    ./configure --prefix=${INSTALL_DIR}/gpdb
    make
    make install_local
    cd ..
    export LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:${INSTALL_DIR}/gpdb/lib
    export LIBRARY_PATH=${LIBRARY_PATH}:${INSTALL_DIR}/gpdb/lib
    export CPATH=${CPATH}:${INSTALL_DIR}/gpdb/include
    ./configure --enable-snmp --with-perl --with-python --with-libxml --with-gssapi --prefix=${INSTALL_DIR}/gpdb
    make -j ${CPU_NUM}
    make install
    GPHOME_CMD="\$( cd \"\$( dirname \"\${BASH_SOURCE[0]}\" )\" ;pwd )"
    sed -i "1 s:^.*\$:GPHOME=${GPHOME_CMD}:" ${INSTALL_DIR}/gpdb/greenplum_path.sh
    cd ${BUILD_ROOT}
    cp /usr/lib64/libxerces-c.so /usr/lib64/libxerces-c-3.1.so ${INSTALL_DIR}/gpdb/lib
    copy_python_libs ${INSTALL_DIR}/gpdb/lib/python
    cat >${INSTALL_DIR}/sample-cluster/conf/hostfile <<eof
localhost
eof

    cat >${INSTALL_DIR}/sample-cluster/conf/postgresql.conf <<eof
# name or IP address(es) (and optionally the port) of the SNMP monitor(s) that will receive the alerts.
gp_snmp_monitor_address=''
eof
    cat >${INSTALL_DIR}/sample-cluster/conf/config <<eof
# Set this to anything you like
ARRAY_NAME="Hengshi Engine Cluster"
CLUSTER_NAME="Hengshi Engine Cluster"

# This file must exist in the same directory that you execute gpinitsystem in
MACHINE_LIST_FILE=/home/gpadmin/`pkg_name`/sample-cluster/conf/hostfile

# This names the data directories for the Segment Instances and the Entry Postmaster
SEG_PREFIX=SegDataDir

# This is the port at which to contact the resulting Greenplum database, e.g.
#   psql -p \$PORT_BASE -d template1
#PORT_BASE=

# Prefix for script created database
DATABASE_PREFIX=SampleDatabase

# Array of data locations for each hosts Segment Instances, the number of directories in this array will
# set the number of segment instances per host
#declare -a DATA_DIRECTORY=

# Name of host on which to setup the QD
#MASTER_HOSTNAME=

# Name of directory on that host in which to setup the QD
#MASTER_DIRECTORY=

#MASTER_PORT=

#mirror segment port numbers
#MIRROR_PORT_BASE=

#specifies the base number by which the port numbers for the primary file replication process are calculated
#REPLICATION_PORT_BASE=

#specifies the data storage location(s) where the utility will create the mirror segment data directories
#declare -a MIRROR_DATA_DIRECTORY=

#specifies the base number by which the port numbers for the mirror file replication process are calculated
#MIRROR_REPLICATION_PORT_BASE=

# Hosts to allow to connect to the QD (and Segment Instances)
# By default, allow everyone to connect (0.0.0.0/0)
IP_ALLOW=0.0.0.0/0

# Shell to use to execute commands on all hosts
TRUSTED_SHELL=ssh

CHECK_POINT_SEGMENTS=8

ENCODING=UNICODE

# Array of mirror data locations for each hosts Segment Instances, the number of directories in this array will
# set the number of segment instances per host

# Path for Greenplum mgmt utils and Greenplum binaries
export MASTER_DATA_DIRECTORY
export TRUSTED_SHELL

# Keep max_connection settings to reasonable values for
# installcheck good execution.

DEFAULT_QD_MAX_CONNECT=150
QE_CONNECT_FACTOR=5
eof
    cat >${INSTALL_DIR}/sample-cluster/export-cluster.sh <<eof
source /home/gpadmin/`pkg_name`/gpdb/greenplum_path.sh
export MASTER_DATA_DIRECTORY=/home/gpadmin/`pkg_name`/sample-cluster/data/SegDataDir-1
export PGPORT=15432
eof
    cat >${INSTALL_DIR}/sample-cluster/conf/limits.conf <<eof
* soft nofile 65536
* hard nofile 65536
* soft nproc 131072
* hard nproc 131072
eof
    cat >${INSTALL_DIR}/sample-cluster/conf/sysctl.conf <<eof
kernel.shmmax = 1000000000
kernel.shmmni = 4096
kernel.shmall = 4000000000
kernel.sem = 250 2018500 100 8074
kernel.sysrq = 1
kernel.core_uses_pid = 1
kernel.msgmnb = 65536
kernel.msgmax = 65536
kernel.msgmni = 2048
net.ipv4.tcp_syncookies = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv4.tcp_tw_recycle = 1
net.ipv4.tcp_max_syn_backlog = 200000
net.ipv4.conf.all.arp_filter = 1
net.ipv4.ip_local_port_range = 1281 65535
net.core.netdev_max_backlog = 200000
fs.nr_open = 3000000
kernel.threads-max = 798720
kernel.pid_max = 798720
net.core.rmem_max = 2097152
net.core.wmem_max = 2097152
eof
    cp ${SCRIPT_DIR}/install-cluster.sh ${INSTALL_DIR}/gpdb/bin/
    cp ${SCRIPT_DIR}/expand-cluster.sh ${INSTALL_DIR}/gpdb/bin/
    cp ${SCRIPT_DIR}/util.sh ${INSTALL_DIR}/gpdb/bin/
    echo `pkg_name` >${INSTALL_DIR}/gpdb/bin/PKG_NAME
    chmod +x ${INSTALL_DIR}/gpdb/bin/install-cluster.sh
    chmod +x ${INSTALL_DIR}/gpdb/bin/expand-cluster.sh
    tar -cvzf `pkg_name`.tar.gz `pkg_name`
}

function do_upload() {
    cd ${BUILD_ROOT}
    url=`get_nexus_url`
    curl -v -udeployment:hengshi123 --upload-file `pkg_name`.tar.gz ${url}
}

function usage() {
    echo -e "\033[32m $0 [OPTIONS]
    -p platform. [centos7] TODO more platforms
    -u upload nexus? [true|false]
    \033[0m
    "
}

function main() {
    while getopts ":p:u:" opt; do
        case "$opt" in
            p)
                PLATFORM="${OPTARG}"
                ;;
            u)
                UPLOAD="${OPTARG}"
                ;;
            *)
                usage
                exit 1
                ;;
        esac
    done

    PLATFORM=${PLATFORM:-centos7}
    UPLOAD=${UPLOAD:-false}
    SCRIPT_DIR=`dirname $0`
    SCRIPT_DIR=$(cd ${SCRIPT_DIR};pwd)
    BRANCH=$(cat ${SCRIPT_DIR}/tagname)

    echo -e "\033[32m ----------------------\033[0m"
    echo -e "\033[32m platform:             \033[0m" ${PLATFORM}
    echo -e "\033[32m upload:               \033[0m" ${UPLOAD}
    echo -e "\033[32m branch:               \033[0m" ${BRANCH}
    echo -e "\033[32m script dir:           \033[0m" ${SCRIPT_DIR}
    echo -e "\033[32m ----------------------\033[0m"
    echo

    case "${PLATFORM}" in
        centos7)
            build_centos7
            ;;
        *)
            echo "unsupported platform ${PLATFORM}"
            usage
            exit 1
            ;;
    esac
    if [ "${UPLOAD}" == "true" ];then
        do_upload
    fi
}

# ===== main =====
if [[ "${BASH_SOURCE[0]}" == "$0" ]];then
    main $*
fi
