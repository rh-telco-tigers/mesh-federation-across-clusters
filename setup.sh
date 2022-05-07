#!/bin/bash

CLUSTER1_URL=$1
CLUSTER1_USER=$2
CLUSTER1_PWD=$3
CLUSTER1_CONTEXT_NAME=$4
CLUSTER2_URL=$5
CLUSTER2_USER=$6
CLUSTER2_PWD=$7
CLUSTER2_CONTEXT_NAME=$8

echo "***** Clusters Details *****"
echo "CLUSTER1 URL : $CLUSTER1_URL"
echo "CLUSTER1 USER : $CLUSTER1_USER"
echo "CLUSTER1 PWD : $CLUSTER1_PWD"
echo "CLUSTER1 CONTEXT NAME : $CLUSTER1_CONTEXT_NAME"
echo "CLUSTER2 URL : $CLUSTER2_URL"
echo "CLUSTER2 USER : $CLUSTER2_USER"
echo "CLUSTER2 PWD : $CLUSTER2_PWD"
echo "CLUSTER2 CONTEXT NAME : $CLUSTER2_CONTEXT_NAME"



oc login -u $CLUSTER1_USER -p $CLUSTER1_PWD  $CLUSTER1_URL
oc config rename-context $(oc config current-context) $CLUSTER1_CONTEXT_NAME

oc login -u $CLUSTER2_USER -p $CLUSTER2_PWD  $CLUSTER2_URL
oc config rename-context $(oc config current-context) $CLUSTER2_CONTEXT_NAME

#switch context
oc config use-context $CLUSTER1_CONTEXT_NAME

cp stage-mesh/smp_template.yaml stage-mesh/smp.yaml
cp prod-mesh/smp_template.yaml prod-mesh/smp.yaml

#Prod cluster
#Step1
echo "***** Creating projects for prod-mesh *****"
oc new-project prod-mesh
oc new-project prod-bookinfo

echo "***** Installing control plane for prod-mesh *****"
oc apply -f prod-mesh/smcp.yaml
oc apply -f prod-mesh/smmr.yaml

echo "***** Waiting for prod-mesh installation to complete *****"
oc wait --for condition=Ready -n prod-mesh smmr/default --timeout 300s

echo "***** Installing bookinfo application in prod-mesh *****"
oc apply -n prod-bookinfo -f https://raw.githubusercontent.com/Maistra/istio/maistra-2.0/samples/bookinfo/platform/kube/bookinfo.yaml
oc apply -n prod-bookinfo -f https://raw.githubusercontent.com/Maistra/istio/maistra-2.0/samples/bookinfo/networking/bookinfo-gateway.yaml
oc apply -n prod-bookinfo -f https://raw.githubusercontent.com/Maistra/istio/maistra-2.0/samples/bookinfo/networking/destination-rule-all.yaml

CLUSTER1_SERVICE_HOST_NAME=$(oc -n prod-mesh get svc stage-mesh-ingress -o json | jq -r '.status.loadBalancer.ingress[].hostname')


#Step2
echo "***** Retrieving Istio CA Root certificates *****"
rm prod_mesh_cert.pem
oc get configmap -n prod-mesh istio-ca-root-cert -o jsonpath='{.data.root-cert\.pem}' > prod_mesh_cert.pem

#switch context
oc config use-context $CLUSTER2_CONTEXT_NAME

#Stage cluster
#Step1
echo "***** Creating projects for stage-mesh *****"
oc new-project stage-mesh
oc new-project stage-bookinfo

echo "***** Installing control plane for stage-mesh *****"
oc apply -f stage-mesh/smcp.yaml
oc apply -f stage-mesh/smmr.yaml

echo "***** Waiting for stage-mesh installation to complete *****"
oc wait --for condition=Ready -n stage-mesh smmr/default --timeout 300s

echo "***** Installing details v2 service in stage-mesh *****"
oc apply -n stage-bookinfo -f stage-mesh/stage-detail-v2-deployment.yaml
oc apply -n stage-bookinfo -f stage-mesh/stage-detail-v2-service.yaml

CLUSTER2_SERVICE_HOST_NAME=$(oc -n stage-mesh get svc prod-mesh-ingress -o json | jq -r '.status.loadBalancer.ingress[].hostname')

#Step2
echo "***** Retrieving Istio CA Root certificates *****"
rm stage_mesh_cert.pem
oc get configmap -n stage-mesh istio-ca-root-cert -o jsonpath='{.data.root-cert\.pem}' > stage_mesh_cert.pem

#Step3
oc create cm prod-mesh-ca-root-cert --from-file=root-cert.pem=prod_mesh_cert.pem -n stage-mesh

#switch context
oc config use-context $CLUSTER1_CONTEXT_NAME

#Step3
oc create cm stage-mesh-ca-root-cert --from-file=root-cert.pem=stage_mesh_cert.pem -n prod-mesh

#Step4
echo "***** Enabling federation for prod-mesh *****"
sed -i.bak "s/remote-cluster-name/$CLUSTER2_SERVICE_HOST_NAME/" prod-mesh/smp.yaml
oc apply -f prod-mesh/smp.yaml
oc apply -f prod-mesh/iss.yaml

#switch context
oc config use-context $CLUSTER2_CONTEXT_NAME

#Step4
echo "***** Enabling federation for stage-mesh *****"
sed -i.bak "s/remote-cluster-name/$CLUSTER1_SERVICE_HOST_NAME/" stage-mesh/smp.yaml
oc apply -f stage-mesh/smp.yaml
oc apply -f stage-mesh/ess.yaml

rm stage-mesh/smp.yaml.bak
rm prod-mesh/smp.yaml.bak

#switch context
oc config use-context $CLUSTER1_CONTEXT_NAME

#Step5
oc apply -n prod-bookinfo -f prod-mesh/vs-mirror-details.yaml

echo "***** Waiting for communication between Service Meshes to establish, status will be active / connected (true) if established otherwise inactive / connected (false). Sometimes it might little bit more time, depending on the location of OCP environments. *****"
sleep 3m

oc -n prod-mesh get servicemeshpeer stage-mesh -o json | jq .status

#switch context
oc config use-context $CLUSTER2_CONTEXT_NAME

oc -n stage-mesh get servicemeshpeer prod-mesh -o json | jq .status

#switch context
oc config use-context $CLUSTER1_CONTEXT_NAME

BOOKINFO_URL=$(oc -n prod-mesh get route istio-ingressgateway -o json | jq -r .spec.host)
curl http://$BOOKINFO_URL/productpage
