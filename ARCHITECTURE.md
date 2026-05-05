# Callysto Infrastructure Architecture

This document covers the design, topology, and key architectural decisions for
the Callysto infrastructure. For operational runbooks see [PROCESSES.md](PROCESSES.md).
For a quick-start reference see [README.md](README.md).

## Table of Contents

- [System Overview](#system-overview)
- [Infrastructure Topology](#infrastructure-topology)
- [Deployment Workflow](#deployment-workflow)
- [Component Reference](#component-reference)
  - [Packer — Image Building](#packer--image-building)
  - [Terraform — Resource Provisioning](#terraform--resource-provisioning)
  - [Ansible — Configuration Management](#ansible--configuration-management)
  - [JupyterHub](#jupyterhub)
  - [SimpleSAMLphp Identity Proxy](#simplesamlphp-identity-proxy)
  - [Sharder](#sharder)
  - [Clavius](#clavius)
  - [SSL Certificate Management](#ssl-certificate-management)
  - [Monitoring — Prometheus and Grafana](#monitoring--prometheus-and-grafana)
  - [Retired Components](#retired-components)
- [Storage Architecture](#storage-architecture)
- [Network and Security](#network-and-security)
- [Authentication Flow](#authentication-flow)
- [Environments](#environments)
- [Current and Future State](#current-and-future-state)
  - [Alma Linux 9 Migration](#alma-linux-9-migration)
  - [JupyterHub v4](#jupyterhub-v4)
  - [Clavius Modernization](#clavius-modernization)

---

## System Overview

Callysto is a Canadian educational platform that provides Jupyter notebook
environments to K-12 students and educators. The infrastructure is entirely
self-managed on OpenStack, using a layered toolchain:

1. **Packer** builds base VM images (Alma Linux 9)
2. **Terraform** provisions OpenStack resources from those images
3. **Ansible** configures software on provisioned VMs
4. **Make** orchestrates all of the above through a unified CLI

All three tools have their binaries version-pinned in `./bin/` to ensure
every operator uses identical tooling regardless of local environment.

---

## Infrastructure Topology

```
Internet
    │
    │ HTTPS (443)
    ▼
┌───────────────────────────────────────────────────────────────────┐
│                        OpenStack Cloud                            │
│                                                                   │
│  ┌─────────────────────────────────────────────────────────────┐  │
│  │                    Hub Cluster                              │  │
│  │                                                             │  │
│  │   ┌──────────────────┐      ┌──────────────────────────┐   │  │
│  │   │  SimpleSAMLphp   │      │      JupyterHub v4        │   │  │
│  │   │  Identity Proxy  │◄─────│  (Caddy/Apache frontend)  │   │  │
│  │   │  (SSP, PHP)      │ auth │  Docker spawner           │   │  │
│  │   └──────────────────┘      └────────────┬─────────────┘   │  │
│  │                                          │ spawns           │  │
│  │                             ┌────────────▼─────────────┐   │  │
│  │                             │   Single-User Servers     │   │  │
│  │                             │  (Docker containers)      │   │  │
│  │                             │  ZFS-backed home dirs     │   │  │
│  │                             └──────────────────────────┘   │  │
│  │                                                             │  │
│  │   ┌──────────────────┐      ┌──────────────────────────┐   │  │
│  │   │     Sharder      │      │     Stats Server          │   │  │
│  │   │  (user routing)  │      │  Prometheus + Grafana     │   │  │
│  │   └──────────────────┘      └──────────────────────────┘   │  │
│  └─────────────────────────────────────────────────────────────┘  │
│                                                                   │
│  ┌──────────────────────┐                                        │
│  │       Clavius        │                                        │
│  │  Admin workstation   │                                        │
│  │  Cert generation     │                                        │
│  │  Image building      │                                        │
│  └──────────────────────┘                                        │
│                                                                   │
│  OpenStack Services: Nova | Cinder | Neutron | Designate         │
└───────────────────────────────────────────────────────────────────┘
```

---

## Deployment Workflow

A full environment deployment follows this sequence:

```
1. packer/build/alma
      │  Build Alma Linux 9 image in OpenStack
      ▼
2. terraform/apply ENV=<env>
      │  Provision VMs, volumes, floating IPs, DNS, security groups
      ▼
3. ansible/playbook PLAYBOOK=hub-cluster.yml ENV=<env>
      │  Install and configure all software on provisioned nodes
      ▼
4. ansible/playbook PLAYBOOK=deploy-certs.yml ENV=<env>
         Push Let's Encrypt wildcard certs from Clavius to hub nodes
```

The `Makefile` wraps every step. See [PROCESSES.md](PROCESSES.md) for the
exact commands and ordering for each scenario.

---

## Component Reference

### Packer — Image Building

**Location:** `packer/`

Packer produces OpenStack Glance images with base packages pre-installed.
This shortens Ansible provisioning time significantly for dev/CI environments
where instances are frequently rebuilt.

Current image: **Alma Linux 9** (`packer/alma.json`)

The legacy CentOS 7 builder (`packer/centos.json`) is retained for reference
but is no longer used for new deployments.

Binaries pinned in `bin/{Darwin,Linux}/packer`.

---

### Terraform — Resource Provisioning

**Location:** `terraform/`

Terraform manages all OpenStack resources: compute instances, Cinder volumes,
Neutron floating IPs, Designate DNS records, and security groups.

#### Module Structure

```
terraform/
├── modules/
│   ├── settings/   # Dev vs prod variable resolution
│   ├── hub/        # JupyterHub instance resources
│   ├── clavius/    # Admin workstation resources
│   ├── ssp/        # SimpleSAMLphp server resources
│   ├── sharder/    # Sharder resources
│   └── stats/      # Prometheus/Grafana resources
├── hub-dev/        # Development hub environment
├── hub-ci/         # CI/testing hub environment
├── hub-prod-r9/    # Production hub (current)
├── clavius/        # Admin workstation
├── prod-dns/       # DNS-only management
└── templates/      # Reference templates for new environments
    ├── dev-hub-aio.tf       # All-in-one development hub
    ├── dev-hub-cluster.tf   # Clustered development hub
    └── prod-hub-cluster.tf  # Production cluster
```

#### Key Design Decisions

**Modules as building blocks.** Each logical component (hub, SSP, sharder) is
a Terraform module. A production environment composes all modules; a dev
environment may omit some (e.g., no Sharder).

**`settings` module.** Centralizes the dev/prod branch point — things like
flavors, image IDs, and DNS zones differ between environments. Consumers call
this module and use its outputs rather than hardcoding values.

**Terraform state is local.** State files (`terraform.tfstate`) live on disk
alongside the `.tf` files. See [CLAVIUS_PROPOSAL.md](CLAVIUS_PROPOSAL.md) for
the implications and planned improvements.

Inventory for Ansible is generated from Terraform state at runtime via
[ansible-terraform-inventory](https://github.com/jtopjian/ansible-terraform-inventory).
The Makefile handles this automatically.

---

### Ansible — Configuration Management

**Location:** `ansible/`

Ansible configures all software on VMs after Terraform provisions them.
Terraform provisions, Ansible configures — the two tools have distinct roles.

#### Directory Structure

```
ansible/
├── plays/
│   ├── hub-cluster.yml    # Full production hub (hub + SSP + sharder + stats)
│   ├── hub-aio.yml        # All-in-one hub (dev)
│   ├── clavius.yml        # Admin workstation
│   ├── deploy-certs.yml   # SSL certificate push
│   ├── backup.yml         # Sensitive data backup
│   ├── ban_user.yml       # User management
│   ├── update_packages.yml
│   └── imports/           # Component sub-plays (not run directly)
│       ├── hub.yml
│       ├── ssp.yml
│       ├── stats.yml
│       └── sharder.yml
├── roles/
│   ├── internal/          # Custom Callysto roles (20 roles)
│   └── external/          # Ansible Galaxy roles
├── group_vars/            # Variables by group
├── host_vars/             # Variables by host
└── local_vars.yml         # Site-specific secrets (gitignored)
```

#### Internal Roles

| Role | Purpose |
|---|---|
| `jupyterhub` | JupyterHub installation and configuration |
| `dockerspawner` | Docker-based single-user server spawning |
| `ssp-idp-multi` | SimpleSAMLphp identity proxy configuration |
| `shibboleth` | Shibboleth SP for institutional SAML |
| `zfs` | ZFS pool creation and quota management |
| `caddy` | Reverse proxy and SSL termination |
| `docker-extra` | Docker daemon configuration and storage |
| `callysto-ssl` | Certificate distribution |
| `ssh-public-keys` | Team SSH key management |
| `sharder` | User routing/isolation service |
| `openstack-tools` | OpenStack CLI installation |
| `kubernetes` | kubectl and k8s tooling |
| `syzygyauthenticator` | JupyterHub authenticator integration |
| `jhub-docker-cull` | Idle server culling |
| `callysto-html` | Hub UI customization |
| `base-packages` | EPEL and base system packages |
| `sysstat` | Host metrics collection |
| `rrsync` | Restricted rsync for certificate push |
| `callysto-ssl` | SSL certificate management |

#### External Roles (Ansible Galaxy)

- `geerlingguy.docker` — Docker runtime
- `geerlingguy.apache` — Apache web server
- `geerlingguy.nodejs` — Node.js
- `devsec.hardening` — SSH and OS hardening
- `prometheus.prometheus` — Prometheus server
- `grafana.grafana` — Grafana dashboards

#### Configuration Layering

Ansible variables are resolved in this priority order (highest to lowest):

```
local_vars.yml          # Secrets and site overrides (not in git)
host_vars/<hostname>/   # Per-host settings
group_vars/<group>/     # Per-group settings (infra, ssp, sharder, all)
role defaults           # Fallback defaults in roles/*/defaults/main.yml
```

All sensitive values (passwords, keys, secrets) belong in `local_vars.yml`.
Copy `local_vars.yml.example` to `local_vars.yml` to start.

---

### JupyterHub

**Version:** v4 (current)
**Location:** `ansible/roles/internal/jupyterhub/`

JupyterHub is the core service — it authenticates users and launches
per-user notebook servers as Docker containers.

#### Key Architectural Choices

**Docker Spawner.** Single-user servers run as Docker containers using
`dockerspawner`. This provides isolation between users and makes image
management independent of the hub OS. The notebook image is configurable
in `local_vars.yml`.

**ZFS home directories.** User home directories live on ZFS volumes, giving
per-user quota enforcement without separate filesystems. See
[Storage Architecture](#storage-architecture).

**Authenticator.** The hub authenticates against the SSP identity proxy via
Shibboleth SP. The Shibboleth SP receives a Targeted ID attribute
(`eduPersonTargetedID`) which JupyterHub uses as the username, ensuring stable
identifiers across login method changes.

**Idle culling.** The `jhub-docker-cull` role installs a culling service that
stops idle single-user containers after a configurable timeout. This manages
resource consumption on shared nodes.

**Caddy / Apache frontend.** A reverse proxy (Caddy or Apache) sits in front
of JupyterHub to handle SSL termination and serve the custom HTML theme
(`callysto-html`).

---

### SimpleSAMLphp Identity Proxy

**Location:** `ansible/roles/internal/ssp-idp-multi/`

The SSP identity proxy is a federation layer that accepts logins from multiple
external sources and presents a single, unified identity to JupyterHub.

#### Why an Identity Proxy?

JupyterHub needs a single, stable user identifier. External providers
(Google, Microsoft, school SAML IdPs) each issue different identifier formats.
SSP normalizes all of them into a Targeted ID before passing credentials to
JupyterHub, which means:

- The hub's user database stays stable even if a school changes its IdP
- New auth sources can be added without modifying the hub
- Mock accounts for development don't require changes outside SSP

#### Supported Auth Sources

| Type | Protocol | Notes |
|---|---|---|
| Google | OAuth2/OIDC | Requires Google Cloud Console app registration |
| Microsoft | OAuth2/OIDC | Requires Microsoft App Registration |
| Institutional SAML | SAML 2.0 | Must publish metadata URL; must release `eduPersonPrincipalName` |
| Mock (dev) | n/a | Enabled via `ssp_develop: True` in `local_vars.yml` |

#### Attribute Flow

```
External IdP  →  SSP Identity Proxy  →  JupyterHub (via Shibboleth SP)
  Google UID       Targeted ID              Stable username
  MS email    →   (hashed, opaque)   →     (used as homedir key)
  ePPN
```

Generic OIDC support (beyond Google/Microsoft) requires adding a new auth
source to the `ssp-idp-multi` Ansible role — the SSP module is available but
not yet wired in.

---

### Sharder

**Location:** `ansible/roles/internal/sharder/`, `terraform/modules/sharder/`

The Sharder is a routing layer that distributes users across JupyterHub nodes
in a clustered deployment. It ensures a given user always lands on the same
hub node (session affinity), which matters because home directories are local
to each node.

In a single-node (all-in-one) deployment, the Sharder is not used.

---

### Clavius

**Location:** `terraform/modules/clavius/`, `ansible/plays/clavius.yml`

Clavius is a shared admin workstation — a persistent VM that all team members
SSH into to perform infrastructure operations. It currently runs several
distinct functions:

| Function | Description |
|---|---|
| **Certificate generation** | Runs `dehydrated` + Designate DNS hooks to generate wildcard Let's Encrypt certs, then pushes them to all servers |
| **Docker image building** | Builds custom JupyterHub notebook images |
| **Ops tooling** | OpenStack CLI, kubectl, Ansible, Terraform, hubtraf (load testing) |
| **Team access point** | All team members SSH here to run deployments and maintenance |

Clavius holds significant persistent state: encrypted home volumes, Terraform
state references, built Docker images, and SSL private keys. This makes it a
single point of failure for several critical operations. See
[CLAVIUS_PROPOSAL.md](CLAVIUS_PROPOSAL.md) for a detailed modernization proposal.

---

### SSL Certificate Management

Let's Encrypt wildcard certificates are generated using
[dehydrated](https://github.com/lukas2511/dehydrated) with an OpenStack
Designate DNS-01 challenge hook. This allows wildcard certs (`*.callysto.ca`)
without exposing any web server to the public.

**Generation flow:**

```
dehydrated (on Clavius)
  → creates DNS TXT record via OpenStack Designate
  → Let's Encrypt validates
  → cert written to letsencrypt/{dev,prod}/certs/
  → deploy-certs.yml Ansible play pushes certs to all nodes via rrsync
```

Certificates cover both production (`callysto.ca`) and development
(`callysto.farm`) zones. Configuration lives in `letsencrypt/`.

---

### Monitoring — Prometheus and Grafana

**Location:** `ansible/roles/external/` (prometheus, grafana), `terraform/modules/stats/`

Each deployed environment includes a dedicated stats server.

| Component | Role |
|---|---|
| Prometheus | Scrapes and stores metrics from all nodes |
| Grafana | Dashboard UI at `https://stats.<domain>/grafana/` |
| Node Exporter | Host OS metrics (CPU, memory, disk, network) |
| cAdvisor | Container-level metrics for Docker workloads |

Nginx or Apache proxies Grafana and Prometheus endpoints with SSL termination.
Monitoring is toggled per-environment in `local_vars.yml`.

---

### Retired Components

#### edX / Tutor

The Open edX deployment has been retired. It was managed via
[Tutor](https://docs.tutor.overhang.io), which ran edX as a Docker Compose
application on a dedicated OpenStack VM. Custom themes and images were built on
Clavius and deployed to the edX VM.

The `terraform/modules/edx/` module and the edX sections of
[PROCESSES.md](PROCESSES.md) are retained for historical reference.

---

## Storage Architecture

User data is stored on ZFS volumes attached to each hub node.

```
OpenStack Cinder volume
    │ (attached as /dev/sdX)
    ▼
ZFS pool (mirror configuration)
    │
    ├── /tank/home/<user-hash>/   ← User home directory
    └── /tank/home/<user-hash>/   ← Additional users...
```

**Why ZFS?**

- Per-user disk quotas without separate block devices per user
- Efficient snapshotting (planned for backups)
- Mirror configuration for durability against single-disk failure
- The `zfs` Ansible role handles pool creation and quota management

User directories are keyed by the Targeted ID hash (e.g., `20fa03478e...`),
not a human-readable username. This provides stability if an upstream IdP
changes how it formats usernames.

---

## Network and Security

All VMs use OpenStack security groups with minimal ingress rules:

| Component | Open Ports |
|---|---|
| Hub | 443 (HTTPS), 22 (SSH, restricted) |
| SSP | 443 (HTTPS), 22 (SSH, restricted) |
| Stats | 443 (HTTPS), 22 (SSH, restricted) |
| Clavius | 22 (SSH) |

SSH hardening is applied via the `devsec.hardening` role across all nodes.

Firewalld is the host-level firewall, configured per role in
`ansible/group_vars/infra/firewalld.yml`.

All external traffic is HTTPS only. SSL is terminated at the Caddy or Apache
reverse proxy layer on each node.

---

## Authentication Flow

End-to-end login sequence for a student accessing JupyterHub:

```
1. Student visits https://hub.callysto.ca
2. Hub redirects to Shibboleth SP
3. Shibboleth SP redirects to SSP Identity Proxy
4. SSP presents login options (Google, Microsoft, School)
5. Student authenticates with chosen provider
6. Provider returns OAuth2/SAML assertion to SSP
7. SSP normalizes identifier → Targeted ID
8. SSP returns SAML assertion to Shibboleth SP
9. Shibboleth SP passes eduPersonTargetedID to JupyterHub
10. JupyterHub maps Targeted ID to user record
11. JupyterHub spawns Docker container with ZFS-mounted home dir
```

---

## Environments

| Environment | Directory | Purpose |
|---|---|---|
| `hub-dev` | `terraform/hub-dev/` | Development and testing |
| `hub-ci` | `terraform/hub-ci/` | CI/automated testing |
| `hub-prod-r9` | `terraform/hub-prod-r9/` | Production (current) |
| `clavius` | `terraform/clavius/` | Admin workstation |
| `prod-dns` | `terraform/prod-dns/` | DNS zone management only |

Templates for new environments are in `terraform/templates/`:
- `dev-hub-aio.tf` — single-VM all-in-one (good for a personal dev environment)
- `dev-hub-cluster.tf` — multi-VM clustered dev
- `prod-hub-cluster.tf` — production cluster baseline

To create a new environment, copy a template into a new directory and adjust
the `settings` module inputs and any environment-specific resource names.

---

## Current and Future State

### Alma Linux 9 Migration

**Status: Complete (merged to master)**

The base OS has been migrated from CentOS 7 to Alma Linux 9. CentOS 7 reached
end-of-life in June 2024; Alma Linux 9 is the community-supported RHEL 9 fork
and provides the same package ecosystem with long-term support.

The Packer build file `packer/alma.json` produces the current base image.
The legacy `packer/centos.json` is retained for reference.

**Outstanding:** Clavius itself still runs CentOS 7 and should be migrated
or replaced as part of the Clavius replacement effort described below.

### JupyterHub v4

**Status: Current**

The hub runs JupyterHub v4 with the Docker spawner. Key changes from v3:

- Updated `jupyterhub_config.py` template in the `jupyterhub` Ansible role
- Updated `dockerspawner` and authenticator dependencies
- Configuration uses the new v4 API patterns for spawner and authenticator

### Clavius Modernization

Clavius currently runs CentOS 7 (EOL) and conflates several distinct
responsibilities into a single persistent VM, creating operational risk.
Three architectural options for modernizing or replacing it — along with
ASCII topology diagrams and a migration plan — are detailed in
[CLAVIUS_PROPOSAL.md](CLAVIUS_PROPOSAL.md).
