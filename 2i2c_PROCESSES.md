# Callysto Ops Processes

The following sections describe various operational processes for maanging
the Callysto environment as deployed by 2i2c on GKE.

# Table of Contents

> General Infrastructure Management

* [Scaling Up or Down the Number of Nodes](#scaling-up-or-down-the-number-of-nodes)
* [How to Access GKE via Kubectl](#how-to-access-gke-via-kubectl)
* [How to Monitor Pods via Kubectl](#how-to-monitor-pods-via-kubectl)

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

## How to Access GKE via Kubectl
Explicit documentation for this is not yet available, but will basically follow the [google kubectl setup docs](https://cloud.google.com/kubernetes-engine/docs/how-to/cluster-access-for-kubectl). Along with our cluster parameters.

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
