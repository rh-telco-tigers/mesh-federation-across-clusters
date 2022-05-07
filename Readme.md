# OpenShift ServiceMesh Federation across Clusters

## Installation 

### 1. OpenShift Clusters setup

Setup two OpenShift clusters, these steps work with Hybrid Cloud model and you clusters could be on-prem or / and any supported cloud provider.

### 2. OpenShift ServiceMesh Installation

The very first step is to have at least one OpenShift cluster where we install OpenShift ServiceMesh 2.1+. Basically we have to install 4 operators in the following order:

- OpenShift Elasticsearch (Optional)
- Jaeger
- Kiali
- Red Hat OpenShift Service Mesh 

You’ll find the complete installation instructions here: [Installing the Operators - Service Mesh 2.x | Service Mesh | OpenShift Container Platform 4.10](https://docs.openshift.com/container-platform/4.10/service_mesh/v2x/installing-ossm.html)

### 3. Cloud Provider specific configuration

There are some cloud provider specific configuration needed and you can check them [here.](https://docs.openshift.com/container-platform/4.10/service_mesh/v2x/ossm-federation.html#ossm-federation-across-clusters_federation)

The steps provided here can work on Bare Metal or AWS as Cloud Provider for OpenShift Clusters.

### Steps to run

- Get the cluster API details, username and password for both clusters.
- Run setup script. This script accepts Cluster details, context name for each cluster. Context name can be any string which is used while running oc tool with multiple clusters.

Example: 

./setup.sh https://api.cluster1:6443 kubeadmin kubeadminpwd cluster1ctx https://api.cluster2:6443 kubeadmin kubeadminpwd cluster2ctx

