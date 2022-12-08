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

## How to Monitor Pods via Kubectl

# JupyterHub User Management

## How to add Domains to the Allowlist

