# Callysto Ops Processes

The following sections describe various operational processes for maanging
the Callysto environment as deployed by 2i2c on GKE.

# Table of Contents

> General Infrastructure Management

* [Scaling Up or Down the Number of Nodes](#scaling-up-or-down-the-number-of-nodes)
* [How to Access GKE via Kubectl](#how-to-access-gke-via-kubectl)
* [How to Monitor Pods via Kubectl](#how-to-monitor-pods-via-kubectl)

# General Infrastructure Management

## Scaling Up or Down the Number of Nodes

We normally have 2 nodes running. Our rule of thumb is 50-70 users per node for hackathons.

1. Log onto the Google Cloud Console and find our pool on GKE: [https://console.cloud.google.com/kubernetes/clusters/details/northamerica-northeast1/callysto-cluster/nodes?project=callysto-202316](Google Cloud Console)
2. Set a new value for the autoscaler minimum number of nodes (4)
3. Set the actual number of nodes (also 4).
4. Check node is added and in ready state
5. Log in, use it, then shut down my pod

After the event we can decide to scale this up or down. If the nodes are to be torn down, we'll do...

1. Set autoscaler minimum back to 0
2. Confirm nodes are removed

Additional Information:

https://github.com/2i2c-org/infrastructure/issues/787
https://github.com/2i2c-org/infrastructure/issues/1918

## How to Access GKE via Kubectl

## How to Monitor Pods via Kubectl
