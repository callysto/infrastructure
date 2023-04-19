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


