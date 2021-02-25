# k8sredis - Kubernetes application to create Bioconductor package binaries

Author:

1. Martin Morgan

2. Nitesh Turaga

This kubernetes app is used to create binary packages for Bioconductor
and store them on Google cloud storage.

## Docker images

The image for the manager is pod is built from the file
`Dockerfile.manager` and is available on the Bioconductor organization
page on Dockerhub as,

	bioconductor/bioc-redis:manager

The images for the worker pods are build from the files under the
following pattern, `Dockerfile.worker.RELEASE_X_Y`. For example, the
image for the worker for Bioconductor release 3.12 is under
`Dockerfile.worker.RELEASE_3_12`. These images are available on
Dockerhub as

	bioconductor/bioc-redis:RELEASE_3_13

	bioconductor/bioc-redis:RELEASE_3_12

To build the docker images locally,

	docker build -t bioconductor/bioc-redis:manager -f \
		docker/Dockerfile.manager docker

	docker build -t bioconductor/bioc-redis-worker:RELEASE_3_12 -f \
		docker/Dockerfile.worker.RELEASE_3_12 docker

The docker images are build on top of the
`bioconductor/bioconductor_docker` images. The manager node inherits
from the `devel` image, and the worker nodes inherit from the
respective Bioconductor release version needed for packages, i.e,
`RELEASE_3_12` or `RELEASE_3_13` and so on.

The `manager` image has _Google cloud SDK_ installed along with some
settings for Redis which are not needed on the worker image.

## NFS server

The manager pod and the worker pods share an NFS server as a volume
mount in this K8s application. The volume mount logic and code is
taken from the kubernetes examples given at this link:

	https://github.com/kubernetes/examples/tree/master/staging/volumes/nfs

## Quick start for k8sredis build binaries

Assumption: The user has a service account key from project with
permission as Storage account admin. Refer to vignette from
https://github.com/Bioconductor/BiocKubeInstall package for more
details

Step 0: Start k8s cluster on GCE

    gcloud container clusters create \
        --zone us-east1-b \
        --num-nodes 4 \
        --enable-autoscaling \
        --min-nodes 1 \
        --max-nodes 6 \
        --machine-type=e2-standard-4 niteshk8scluster

	gcloud container clusters get-credentials niteshk8scluster

Step 1: Start service NFS using this commands

	kubectl apply -f k8s/nfs-volume/

Step 2: Create a kubectl secret. You must have the file
`bioc-binaries.json` on your local machine. To create a kubernetes
secret and download it you need to be a service account admin. Please
refer to the documentation refering to _Create kubernetes secret_.

	kubectl create secret generic \
		bioc-binaries-service-account-auth \
		--from-file=service_account_key=bioc-binaries.json

	## Describe key
	kubectl describe secrets/bioc-binaries-service-account-auth

Step 3: Start Redis, Rstudio, Manager and worker pods

	kubectl apply -f k8s/bioc-redis/

Step 4: Delete cluster

	kubectl delete -f k8s/bioc-redis/
	kubectl delete -f k8s/nfs-volume/

	gcloud container clusters delete niteshk8scluster

## Logging into a pod

	kubectl exec --stdin --tty pod/manager -- /bin/bash

### Create kubernetes secret

Create a service account key. The service account key has 'Storage
Admin' permissions, so it can upload the binaries to a google
bucket.

	## Create service account
	gcloud iam service-accounts create bioc-binaries \
	   --display-name "Storage Admin SA" \
	   --description "Bioc Binaries storage admin"

	## List service account
	gcloud iam service-accounts list \
		--filter bioc-binaries@fancy-house-303821.iam.gserviceaccount.com

	## Download service account key locally
	gcloud iam service-accounts keys create \
		bioc-binaries.json \
		--iam-account bioc-binaries@fancy-house-303821.iam.gserviceaccount.com

	## Add 'Storage Admin' role to service account.
	gcloud projects add-iam-policy-binding fancy-house-303821 \
		--member \
		"serviceAccount:bioc-binaries@fancy-house-303821.iam.gserviceaccount.com" \
		--role "roles/storage.admin"

## Detailed launch sequence of the K8s app (not recommended)

Launch the NFS server first,

	kubectl create -f k8s/nfs-server-gce-pv.yaml
	kubectl create -f k8s/nfs-server-rc.yaml
	kubectl create -f k8s/nfs-server-service.yaml
	kubectl create -f k8s/nfs-pv.yaml
	kubectl create -f k8s/nfs-pvc.yaml

then the bioc-redis application,

	kubectl create -f k8s/bioc-redis/rstudio-service.yaml
	kubectl create -f k8s/bioc-redis/redis-service.yaml
	kubectl create -f k8s/bioc-redis/redis-pod.yaml
	kubectl create -f k8s/bioc-redis/manager-pod.yaml
	kubectl create -f k8s/bioc-redis/worker-jobs.yaml
