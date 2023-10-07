# Callysto Ops Processes

The following sections describe various operational processes for maanging
the Callysto environment as deployed by 2i2c on GKE.

# Table of Contents

> General Infrastructure Management

* [Scaling Up or Down the Number of Nodes](#scaling-up-or-down-the-number-of-nodes)
* [How to Access GKE via Kubectl](#how-to-access-gke-via-kubectl)
* [How to Monitor Pods via Kubectl](#how-to-monitor-pods-via-kubectl)
* [Image Updates](#how-to-update-the-2i2c-image)
> JupyterHub User Management

* [How to add Domains to the Allowlist](#how-to-add-domains-to-the-allowlist)

# General Infrastructure Management

## Scaling Up or Down the Number of Nodes

We normally have 0 nodes in our nb_user pool running. They are automatically scaled up by Kubernetes. 

When we need to scale up (warm up) nodes before a hackathon, our rule of thumb is 50-70 users per node for hackathons.

1. Log onto the Google Cloud Console and find our nb_user pool on GKE: [Google Cloud Console](https://console.cloud.google.com/kubernetes/clusters/details/northamerica-northeast1/callysto-cluster/nodes?project=callysto-202316)
2. Set a new value for the autoscaler minimum number of nodes (eg. 2)
3. Click Save
4. Optionally, but recommended - click edit again and set the number of nodes to the minimum you set (eg. 2)
5. Check the node is added on the Pool status page.
6. Wait for a notice that the node has been set up and is ready to be used (this takes 20-25 minutes)
7. Log into https://2i2c.callysto.ca to ensure that you can log in and use the environment

After the event we can decide to scale this up or down. If the nodes are to be torn down, we'll do...

1. Set autoscaler minimum back to 0
2. Confirm nodes are removed

Additional Information:

https://github.com/2i2c-org/infrastructure/issues/787  
https://github.com/2i2c-org/infrastructure/issues/1918

## How to scale nodes using the CLI

You can start and stop nodes via the command line:

**How to start a node**
```
make hackathon/start
```
The script will run and ask you how many nodes you would like. Once you enter the amount of nodes it will provision them and adjust your autoscale.

**How to stop nodes**
```
make hackathon/stop
```
This shuts down, deletes, and changes the minimum nodes back to zero.



## How to Access GKE via Kubectl
Explicit documentation for this is not yet available, but will basically follow the [google kubectl setup docs](https://cloud.google.com/kubernetes-engine/docs/how-to/cluster-access-for-kubectl). Along with our cluster parameters.

SSH into Clavuis 

Clavius is currently set up to run kubectl, however if needed in the future setup instructions are [here](https://cloud.google.com/kubernetes-engine/docs/how-to/cluster-access-for-kubectl)

run kubectl to view resources 
```bash
# View Pods
kubectl get pods --all-namespaces
# View Services
kubectl get services  --all-namespaces
```

## How to Monitor Pods via Kubectl
Assuming kubectl is installed the following namespaces are available in our cluster
```bash
$ kubectl get namespaces
NAME              STATUS   AGE
cert-manager      Active   223d
default           Active   223d
kube-node-lease   Active   223d
kube-public       Active   223d
kube-system       Active   223d
prod              Active   217d
staging           Active   222d
support           Active   223d
```

The user pods should be in either the `prod` or `staging` namespace, e.g.
```bash
$ kubectl -n prod get pods
NAME                                     READY   STATUS    RESTARTS   AGE
continuous-image-puller-8d7sw            1/1     Running   0          9h
hub-5cfb88999c-hgq55                     2/2     Running   0          6h35m
jupyter-123712781462591347147            1/1     Running   0          3h5m
jupyter-823456747138123105324            1/1     Running   0          3h5m
jupyter-123995775666754321331            1/1     Running   0          3h5m
proxy-7874d464f-m74nk                    1/1     Running   0          14d
shared-volume-metrics-55c5cc4974-7bzb6   1/1     Running   0          14d
```
The user pods are prefixed those prefixed with the name `jupyter`, and you can interact with them via e.g.
```bash
$ kubectl get logs jupyter-123712781462591347147
...
[I 2023-04-05 23:20:50.478 SingleUserLabApp handlers:454] Restoring connection for f734bfac-a7bd-42cb-9f97-e7a4ef12384e:703e91973b00443683b137c06332d91f
[W 2023-04-05 23:22:20.481 SingleUserLabApp zmqhandlers:227] WebSocket ping timeout after 90002 ms.
[I 2023-04-05 23:22:25.484 SingleUserLabApp kernelmanager:321] Starting buffering for f734bfac-a7bd-42cb-9f97-e7a4ef12384e:703e91973b00443683b137c06332d91f

$ kubectl -n prod exec --stdin --tty jupyter-123712781462591347147 -- /bin/bash
```

Monitoring pods cannot be done live with kubectl, however you can get pod metrics with the folloing commands:
```
# Get pod metrics 
kubectl top pods -n <namespace> --containers
# or
kubectl top pods --all-namespaces
```
The pods that we are most concerned with are these:
| NAMESPACE      | NAME                          |
| -------------- | ----------------------------- |
| prod           | home-metrics-774c8b8684-6q2gv |
| prod           | hub-6cfbbcb654-m4v4j          |
| prod           | proxy-7f969467cf-gzs8t        |
| staging        | home-metrics-774c8b8684-xhclq |
| staging        | hub-5556444d88-s8d48          |
| staging        | proxy-5c8f478b4-4wnh7         |

They are the production and staging pods for the hub. Note that the names may vary slightly. The namespace and first part of the names will be the same (home-metrics for example), however the characters appended to the end may change (774c8b8684-6q2gv in this case).

Note that CPU represents compute processing and is specified in units of [Kubernetes CPUs](https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/#meaning-of-cpu). 

Memory is specified in units of bytes. 


## How to update the 2i2c image
The image used on the 2i2c cluster is usually taken from [2i2c-image](https://github.com/callysto/2i2c-image). The 2i2c-notebook image is used as the base layer and the pims-r has minor modifications on op of this base to allow it to run in our legacy cluster. Image updates _were_ handled as pull requests against the [2i2c-infrastructure](https://github.com/2i2c-org/infrastructure/) repo, but we can now manage them via the configuratior. Simply visit 2i2c.callysto.ca and log in as one of the admin users (see the `admin_users` section of [our config](https://github.com/2i2c-org/infrastructure/blob/master/config/clusters/callysto/common.values.yaml). From the control panel, select `Services->configurator` and update the image name to something like `callysto/2i2c:0.1.5`, where `callysto` is our dockerhub org, `2i2c` is the image and `0.1.5` is the desired tag.

# JupyterHub User Management

## How to add Domains to the Allowlist
Domains are controlled in the 2i2c-infrastructure repository by adding entries to [common.valyes.yml](https://github.com/2i2c-org/infrastructure/blob/e03c2e5e35e5899e911e1ad8b13ac981297bb452/config/clusters/callysto/common.values.yaml#L111). That file can't be edited directly so changes should be proposed as a pull-request against [2i2c.org/infrastructure:master](https://github.com/2i2c.org/infrastructure). Currently pull-requests must be manually reviewed by 2i2c admins before merging, but we are working to have this specific type of change also be reviewable by callysto admins.

New domains should be added under the following key (e.g. to add `new.domain.ca`)

```yaml
jupyterhub:
  hub:
    config:
      EmailAuthenticatingCILoginOAuthenticator:
        allowed_domains:
          - 2i2c.org
          ...
          - new.domain.ca
```
Where the `...` represents any other existing entries. We've been trying to keep the entries in alphabetical order but there are some exceptions for "special" entries.
