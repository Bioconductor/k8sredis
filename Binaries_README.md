# RedisParam to create Bioconductor Binaries

This app is used to create a 

## Create a new storage bucket

The Google bucket bucket needs to be in the form of a CRAN repository. 

## Docker images used

bioconductor/bioc-redis-manager:devel

bioconductor/bioc-redis-worker:<list options>

## Mount NFS volume

The persistent disk used in this K8s application is an NFS server. 

	https://github.com/kubernetes/examples/tree/master/staging/volumes/nfs

## Start k8s cluster

	## https://cloud.google.com/kubernetes-engine/docs/concepts/cluster-architecture 

	gcloud container clusters create \
		--zone us-east1-b \
		--num-nodes=6 \
		--machine-type=e2-standard-4 niteshk8scluster

	gcloud container clusters get-credentials niteshk8scluster

	gcloud compute firewall-rules create test-node-port --allow tcp:30001

## delete k8s cluster

Delete persistent volume and bioc-redis

	kubectl delete -f k8s/bioc-redis/
	kubectl delete -f k8s/nfs-volume/

	gcloud container clusters delete niteshk8scluster

## exec into a node

	kubectl exec --stdin --tty pod/manager -- /bin/bash


## Detailed order 

	## NFS volume needs to be 500Gi to accomodate both libraries and binaries
	kubectl create -f k8s/nfs-server-gce-pv.yaml
	kubectl create -f k8s/nfs-server-rc.yaml
	kubectl create -f k8s/nfs-server-service.yaml
	kubectl create -f k8s/nfs-pv.yaml
	kubectl create -f k8s/nfs-pvc.yaml

	kubectl create -f k8s/bioc-redis/rstudio-service.yaml
	kubectl create -f k8s/bioc-redis/redis-service.yaml
	kubectl create -f k8s/bioc-redis/redis-pod.yaml
	kubectl create -f k8s/bioc-redis/manager-pod.yaml
	kubectl create -f k8s/bioc-redis/worker-jobs.yaml

## Create kubernetes secret

	kubectl describe secrets/bioc-binaries-service-account-auth

```
Name:         bioc-binaries-service-account-auth
Namespace:    default
Labels:       <none>
Annotations:  <none>

Type:  Opaque

Data
====
service_account_key:  2353 bytes
```


## Quick start for k8sredis build binaries

Assumption: The user has a service account key from `bioconductor-rpci` project.

Step 0: Start k8s cluster on GCE

	gcloud container clusters create \
			--zone us-east1-b \
			--num-nodes=6 \
			--machine-type=e2-standard-4 niteshk8scluster

	gcloud container clusters get-credentials niteshk8scluster

Step 1: Start service NFS using this commands

	kubectl apply -f k8s/nfs-volume/

Step 2: Create a kubectl secret 

	kubectl create secret generic \
		bioc-binaries-service-account-auth \
		--from-file=service_account_key=bioconductor-rpci-280116-6b5690824bc0.json

Step 3: Start Redis, Rstudio, Manager and worker pods

	kubectl apply -f k8s/bioc-redis/

Step 4: Delete cluster

	kubectl delete -f k8s/bioc-redis/
	kubectl delete -f k8s/nfs-volume/
	
	gcloud container clusters delete niteshk8scluster


## TODO

1. Cluster size requirements and quota.

	https://cloud.google.com/compute/quotas

2. kube_install script should be run from 

		source("https://github.com/nturaga/BiocKubeInstall/blob/master/pkg_dependency_graph.R")

3. Demo end to end run , and then discuss further automation.

4. Automation ideas,

	- pkg_dependency_graph.R script automation, instead of updating the "image" with a new script each time.
	
	- docker CMD or ENTRYPOINT.sh
	

https://storage.googleapis.com/anvil-rstudio-bioconductor-test/0.99/3.11/src/contrib/ABAData_1.19.0_R_x86_64-pc-linux-gnu.tar.gz

	## Bucket needs a unique name
	## -c standard: >99.99% in multi-regions and dual-regions
	## -l bucket is created in the location US, which is multi-region
	## --retention <number>d (should usually be 1 year, provide only for release and devel)
	gsutil mb -b on -c standard -l us gs://test-bioc-cran-bucket

	## Create directory structure with an empty PACKAGES file
	touch PACKAGES
	gsutil cp PACKAGES gs://test-bioc-cran-bucket/0.99/3.11/src/contrib/PACAKGES

	## make bucket public
	## Making all objects in a bucket publicly readable
	gsutil iam -r ch allUsers:objectViewer gs://test-bioc-cran-bucket/
	
	## make it requester pays?
	
