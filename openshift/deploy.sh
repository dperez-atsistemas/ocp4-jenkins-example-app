#!/bin/bash
#GET DOMAIN
str="$(oc get route -o=jsonpath='{.items[0].spec.host}' -n default)"
DOMAIN=""
IFS='.' # hyphen (-) is set as delimiter
read -ra ADDR <<< "$str" # str is read into an array as tokens separated by IFS
check=0
for i in "${ADDR[@]}"; do # access each element of array
    if [ $check -eq 1 ]; then
        DOMAIN="${DOMAIN}.${i}"
    fi
    check=1
done
IFS=' '

CI_PROJECT="$USER-cicd"
DEV_PROJECT="$USER-jv-dev"
PROD_PROJECT="$USER-jv-prod"
DEV_URL="hello-java-dev${DOMAIN}"
PROD_URL="hello-java-prod${DOMAIN}"
GOGS_USER="gogs"
REPO="openshift-jee-sample"
GOGS_ROUTE="gogs-op${DOMAIN}"
GIT_URL="http://${GOGS_ROUTE}/${GOGS_USER}/${REPO}.git"
IMG="app-jv"
FULL_IMG="${DEV_PROJECT}/${IMG}"
FULL_IMG_TAG_PRO="${FULL_IMG}:prod"
FULL_IMG_TAG_DEV="${FULL_IMG}:latest"
REGISTRY_URL="docker-registry.default.svc:5000"
IMG_URL="${REGISTRY_URL}/${FULL_IMG}"
DEV_IMG="${IMG_URL}:latest"
PROD_IMG="${IMG_URL}:prod"
BUILD_IMG="${IMG}:latest"
IMGS_PROD="${IMG}:prod"
WEBHOOK="M0dDlKMbJcm_5PV_xSza"


if [ "$1" == "--delete" ]; then
 oc delete project $CI_PROJECT
 oc delete project $DEV_PROJECT
 oc delete project $PROD_PROJECT
 exit 0
fi


oc create -f https://raw.githubusercontent.com/wildfly/wildfly-s2i/wf-18.0/imagestreams/wildfly-centos7.json -n openshift
oc new-project ${PROD_PROJECT} && oc new-project ${DEV_PROJECT} && oc new-project ${CI_PROJECT}
oc new-app -f https://raw.githubusercontent.com/OpenShiftDemos/gogs-openshift-docker/master/openshift/gogs-template.yaml --param=GOGS_VERSION=0.11.34 --param=HOSTNAME=$GOGS_ROUTE --param=SKIP_TLS_VERIFY=true

sleep 10

GOGS_SVC=$(oc get svc gogs -o template --template='{{.spec.clusterIP}}')
oc rollout status dc gogs

if [ "$1" == "--ephemeral" ]; then
  oc new-app jenkins-ephemeral -n ${CI_PROJECT}
else
  oc new-app jenkins-persistent -n ${CI_PROJECT}
fi


# sleep 90

sleep 5
echo "CREATING GOGS_USER..."
_RETURN=$(curl -o /dev/null -sL --post302 -w "%{http_code}" http://$GOGS_ROUTE/user/sign_up \
    --form user_name=$GOGS_USER \
    --form password=$GOGS_USER \
    --form retype=$GOGS_USER \
    --form email=$GOGS_USER@gogs.com)


echo "CREATING REPO..."
sleep 5

read -r -d '' _DATA_JSON << EOM
{
  "clone_addr": "$GIT_URL",
  "uid": 1,
  "repo_name": "$REPO"
}
EOM

_RETURN=$(curl -o /dev/null -sL -w "%{http_code}" -H "Content-Type: application/json" -d "$_DATA_JSON" -u $GOGS_USER:$GOGS_USER -X POST http://$GOGS_ROUTE/api/v1/repos/migrate)

echo "PUSHING... Use credentials $GOGS_USER:$GOGS_USER if ask"
sleep 3

git remote remove origin
git init .
git add .
git remote add origin ${GIT_URL}
git push origin master

#DEV
echo "CREATING DEV..."
oc process -f ./openshift/template.yml -p APP_URL=${DEV_URL} -p GIT_URL=${GIT_URL} -p BUILD_IMG=${BUILD_IMG} -p APP_IMAGE=${DEV_IMG} -p APP_NAMESPACE=${DEV_PROJECT} -p CICD_NAMESPACE=${CI_PROJECT} | oc create -f -

#PIPELINE & IMS
echo "CREATING PIPE..."
oc process -f ./openshift/cicd.yml -p WEBHOOK=${WEBHOOK} -p IMG_DEV=${FULL_IMG_TAG_DEV} -p IMG_PROD=${FULL_IMG_TAG_PRO} -p GIT_URL=${GIT_URL} -p IMG=${IMG} -p PROD_NAMESPACE=${PROD_PROJECT} -p DEV_NAMESPACE=${DEV_PROJECT} -p CICD_NAMESPACE=${CI_PROJECT} | oc create -f -

oc get builds -n ${DEV_PROJECT} | grep 456456 > /dev/null
while [ $? -eq 1 ] ; do 
    sleep 1
    oc get builds -n ${DEV_PROJECT} | grep Complete > /dev/null
done
sleep 3
oc tag ${IMG}:latest ${IMG}:prod -n ${DEV_PROJECT}
#https://master.io:8443/apis/build.openshift.io/v1/namespaces/david-cicd/buildconfigs/david-jv-dev/webhooks/M0dDlKMbJcm_5PV_xSza/generic

echo "CREATING WEBHOOK..."
MASTER=$(oc whoami --show-server)
API_HOOK=$(oc get bc -o jsonpath='{.items[0].metadata.selfLink}')
WEBHOOK_SECRET=$(oc get bc -o jsonpath='{.items[0].spec.triggers[0].generic.secret}' -n ${CI_PROJECT})
WEBHOOK_URL="${MASTER}${API_HOOK}/webhooks/${WEBHOOK_SECRET}/generic"

read -r -d '' _DATA_JSON << EOM
{
  "type": "gogs",
  "config": {
    "url": "$WEBHOOK_URL",
    "content_type": "json"
  },
  "events": [
    "push"
    ],
  "active": true
}
EOM

_RETURN=$(curl -o /dev/null -sL -w "%{http_code}" -H "Content-Type: application/json" -d "$_DATA_JSON" -u $GOGS_USER:$GOGS_USER -X POST http://$GOGS_ROUTE/api/v1/repos/$GOGS_USER/$REPO/hooks)

#PROD
echo "CREATING PROD..."
oc process -f ./openshift/template_prod.yml -p APP_URL=${PROD_URL} -p GIT_URL=${GIT_URL} -p APP_IMGS=${IMGS_PROD} -p APP_IMAGE=${PROD_IMG} -p APP_NAMESPACE=${PROD_PROJECT} -p DEV_NAMESPACE=${DEV_PROJECT} | oc create -f -

echo "CREATING ROLES..."
oc -n ${DEV_PROJECT} policy add-role-to-user edit system:serviceaccount:${PROD_PROJECT}:default
oc -n ${DEV_PROJECT} policy add-role-to-user edit system:serviceaccount:${CI_PROJECT}:jenkins
oc -n ${PROD_PROJECT} policy add-role-to-user edit system:serviceaccount:${CI_PROJECT}:jenkins

echo "--------------------"
echo "GOGS credentials => $GOGS_USER:$GOGS_USER"
echo "READY"

