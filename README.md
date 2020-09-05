18 May, 2019

# Work in progress: current state

Recent updates

- Use dockerhub images; separate 'manager' and 'worker'.
- Document use on gcloud
- Re-organized files for easier build & deploy

## Start minikube or gcloud

Use minikube for (local) development, or gcloud for scalable deployment.

Start the minikube VM with

    minikube start

For gcloud, see [below][].

[below]: #google-cloud-work-in-progress

## Create application in kubernetes

In kubernetes, create a redis service and running redis application,
an _RStudio_ service, an _RStudio_ 'manager', and five _R_ worker
'jobs'.

    kubectl apply -f k8s/

The two services, redis and manager pods, and worker pods should all
be visible and healthy with

    kubectl get all

## Log in to R

Via your browser on the port 300001 at the ip address returned by
minikube or gcloud

    ## For minikube, use...
    minikube ip

    ## For gcloud, use any 'EXTERNAL-IP' from
    kubectl get nodes --output wide

e.g.,

    http://192.168.99.101:30001

this will provide access to RStudio, with user `rstudio` and password
`bioc`. Alternatively, connect to R at the command line with

    kubectl exec -it manager -- /bin/bash

## Use

Define a simple function

    fun = function(i) {
        Sys.sleep(1)
        Sys.info()[["nodename"]]
    }

Create a `RedisParam` to connect to the job queue and communicate with
the workers, and use `BiocParallel::register()` to make this the
default back-end

    library(RedisParam)

    p <- RedisParam(workers = 5, jobname = "demo", is.worker = FALSE)
    register(bpstart(p))

Use `bplapply()` for parallel evaluation

    system.time(res <- bplapply(1:13, fun))
    table(unlist(res))

## Clean up

Quit and exit the R manager (or simply leave your RStudio session in
the browser)

    > q()     # R
    # exit    # manager

Clean up kubernetes

    $ kubectl delete -f k8s/

Stop minikube or gcloud

    ## minikube...
    minikube stop

    ## ..or gcloud
    gcloud container clusters delete [CLUSTER_NAME]

# Google cloud [WORK IN PROGRESS]

One uses Google kubernetes service rather than minikube. Make sure
that minikube is not running

    minikube stop

## Enable kubernetes service

Make sure the Kubernetes Engine API is enables by visiting
`https://console.cloud.google.com`.

Make sure the appropriate project is selected (dropdown in the blue
menu bar).

Choose `APIs & Services` the hamburger (top left) dropdown, and `+
ENABLE APIS & SERVICES` (center top).

## Configure gcloud

At the command line, make sure the correct account is activated and
the correct project associated with the account

    gcloud auth list
    gclod config list

Use `gcloud config help` / `gcloud config set help` and eventually
`gcloud config set core/project VALUE` to udpate the project and
perhaps other information, e.g., `compute/zone` and `compute/region`.

## Start and authenticate the gcloud kubernetes engine

A guide to [exposing applications][1] guide is available; we'll most
closely follow the section [Creating a Service of type NodePort][2].

Create a cluster (replace `[CLUSTER_NAME]` with an appropriate
identifier)

    gcloud container clusters create [CLUSTER_NAME]

Authenticate with the cluster

    gcloud container clusters get-credentials [CLUSTER_NAME]

Create a whole in the firewall that surrounds our cloud (30001 is from
k8s/rstudio-service.yaml)

    gcloud compute firewall-rules create test-node-port --allow tcp:30001

At this stage, we can use `kubectl apply ...` etc., as above.

[1]: https://cloud.google.com/kubernetes-engine/docs/how-to/exposing-apps
[2]: https://cloud.google.com/kubernetes-engine/docs/how-to/exposing-apps#creating_a_service_of_type_nodeport

# Docker images

Docker images for the manager and worker are available at dockerhub as
[mtmorgan/bioc-redis-manager][] and
[mtmorgan/bioc-redis-worker][]. They were built as

    docker build -t nitesh1989/bioc-redis-worker:devel -f docker/Dockerfile.worker docker
    docker build -t nitesh1989/bioc-redis-manager:devel -f docker/Dockerfile.manager docker

[mtmorgan/bioc-redis-manager]: https://cloud.docker.com/u/mtmorgan/repository/docker/mtmorgan/bioc-redis-manager
[mtmorgan/bioc-redis-worker]: https//cloud.docker.com/u/mtmorgan/repository/docker/mtmorgan/bioc-redis-worker

The _R_ manager docker file -- is from `rocker/rstudio:3.6.0`
providing _R_ _RStudio_ server, and additional infrastructure to
support [RedisParam][].  The _R_ worker docker file -- is from
`rocker/r-base:latest` providing _R_, and additional infrastructure to
support [RedisParam][].

If one were implementing a particularly workflow, likely the worker
(and perhaps manager) images would be built from a more complete image
like [Bioconductor/AnVIL_Docker][] customized with required packages.

[RedisParam]: https://github.com/mtmorgan/RedisParam
[Bioconductor/AnVIL_Docker]: https://github.com/Bioconductor/AnVIL_Docker

For use of local images, one needs to build these in the minikube environment

    eval $(minikube docker-env)
    docker build ...

# TODO

A little further work will remove the need to create the
`RedisParam()` in the R session.

The create / delete steps can be coordinated by a [helm] chart, so
that a one-liner will give a URL to a running RStudio backed by
arbitary number of workers.

[helm]: https://helm.sh/


## Test persistent disk

### Create repo on GCR and upload docker images

gcloud container images list --repository us.gcr.io/bioconductor-rpci-280116

### Create disk

https://kubernetes.io/docs/concepts/storage/volumes/#gcepersistentdisk

- `gcePersistentDisk` doesn't work since the volume can be mounted on
  only a single pod at a time.

```
A feature of PD is that they can be mounted as read-only by multiple
consumers simultaneously. This means that you can pre-populate a PD
with your dataset and then serve it in parallel from as many Pods as
you need. Unfortunately, PDs can only be mounted by a single consumer
in read-write mode - no simultaneous writers allowed.
```

Command to start disk:

	gcloud compute disks create --size=500GB --zone=us-east1-b nt-data-disk

Error state:

```
~ ❯❯❯ kubectl describe pod/worker-4c6c4
Name:           worker-4c6c4
Namespace:      default
Priority:       0
Node:           gke-niteshk8scluster-default-pool-c33c9779-7j09/10.142.0.15
Start Time:     Fri, 04 Sep 2020 08:24:56 -0400
Labels:         controller-uid=e38b3ce9-09ff-4abc-b182-b166fb597626
                job-name=worker
Annotations:    kubernetes.io/limit-ranger: LimitRanger plugin set: cpu request for container worker
Status:         Pending
IP:
IPs:            <none>
Controlled By:  Job/worker
Containers:
  worker:
    Container ID:
    Image:         us.gcr.io/bioconductor-rpci-280116/bioc-redis-worker:devel
    Image ID:
    Port:          <none>
    Host Port:     <none>
    Command:
      R
    Args:
      -f
      /home/docker/worker.R
    State:          Waiting
      Reason:       ContainerCreating
    Ready:          False
    Restart Count:  0
    Requests:
      cpu:        100m
    Environment:  <none>
    Mounts:
      /host from test-mount (rw)
      /var/run/secrets/kubernetes.io/serviceaccount from default-token-6r876 (ro)
Conditions:
  Type              Status
  Initialized       True
  Ready             False
  ContainersReady   False
  PodScheduled      True
Volumes:
  test-mount:
    Type:       GCEPersistentDisk (a Persistent Disk resource in Google Compute Engine)
    PDName:     nt-data-disk
    FSType:     ext4
    Partition:  0
    ReadOnly:   false
  default-token-6r876:
    Type:        Secret (a volume populated by a Secret)
    SecretName:  default-token-6r876
    Optional:    false
QoS Class:       Burstable
Node-Selectors:  <none>
Tolerations:     node.kubernetes.io/not-ready:NoExecute for 300s
                 node.kubernetes.io/unreachable:NoExecute for 300s
Events:
  Type     Reason              Age               From                     Message
  ----     ------              ----              ----                     -------
  Normal   Scheduled           42s               default-scheduler        Successfully assigned default/worker-4c6c4 to gke-niteshk8scluster-default-pool-c33c9779-7j09
  Warning  FailedAttachVolume  3s (x5 over 36s)  attachdetach-controller  AttachVolume.Attach failed for volume "test-mount" : googleapi: Error 400: RESOURCE_IN_USE_BY_ANOTHER_RESOURCE - The disk resource 'projects/bioconductor-rpci-280116/zones/us-east1-b/disks/nt-data-disk' is already being used by 'projects/bioconductor-rpci-280116/zones/us-east1-b/instances/gke-niteshk8scluster-default-pool-c33c9779-jw3l'
 ```

### Mount NFS volume

https://github.com/kubernetes/examples/tree/master/staging/volumes/nfs

### Start k8s cluster

gcloud container clusters create --zone us-east1-b --num-nodes=5 niteshk8scluster

gcloud container clusters get-credentials niteshk8scluster

gcloud compute firewall-rules create test-node-port --allow tcp:30001

kubectl apply -f k8s/

### delete k8s cluster

kubectl delete -f k8s/

gcloud container clusters delete niteshk8scluster
