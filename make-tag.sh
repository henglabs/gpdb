set -e
if [ $# -ne 1 ];then
    echo "bash $0 tagname(like 5.13.0.2)"
    exit 1
fi
TAG="$1"
SCRIPT_DIR=`dirname $0`
SCRIPT_DIR=$(cd ${SCRIPT_DIR};pwd)
cd ${SCRIPT_DIR}
TMP_BRANCH="tmp-$$"
git checkout -b ${TMP_BRANCH}
echo "${TAG}" >hengshi-build/tagname
git add hengshi-build/tagname
git commit -m "make tag ${TAG}"
git tag ${TAG}
git push origin ${TAG}
git checkout ${TAG}
git branch -d ${TMP_BRANCH}
git checkout hs-5.13.0-master
