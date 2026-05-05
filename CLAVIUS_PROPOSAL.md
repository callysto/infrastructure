# Clavius Modernization Proposal

This document analyzes the current role of Clavius in the Callysto
infrastructure, identifies the risks of the present design, and proposes
three architectural options for modernizing it. See [ARCHITECTURE.md](ARCHITECTURE.md)
for broader infrastructure context.

## Table of Contents

- [Current State](#current-state)
- [Problem Statement](#problem-statement)
- [Requirements for a Replacement](#requirements-for-a-replacement)
- [Option A: Full CI/CD Pipeline](#option-a-full-cicd-pipeline)
- [Option B: Remote State + Lightweight Ops VM](#option-b-remote-state--lightweight-ops-vm)
- [Option C: Rebuilt Clavius (In-Place Upgrade)](#option-c-rebuilt-clavius-in-place-upgrade)
- [Comparison](#comparison)
- [Recommendation](#recommendation)
- [Migration Plan](#migration-plan)

---

## Current State

Clavius is a shared admin workstation — a single persistent VM that all team
members SSH into to perform infrastructure operations. It runs **CentOS 7**
(reached end-of-life June 2024).

### What Clavius Does Today

```
┌─────────────────────────────────────────────────────────────────┐
│                     Clavius (CentOS 7)                          │
│                                                                 │
│  ┌─────────────────┐   ┌──────────────────┐                    │
│  │ dehydrated      │   │ Docker daemon     │                    │
│  │ Let's Encrypt   │──►│ Image builds      │                    │
│  │ cert generation │   │ (notebook images) │                    │
│  └────────┬────────┘   └──────────────────┘                    │
│           │                                                     │
│           │ rrsync push                                         │
│           ▼                                                     │
│  ┌──────────────────────────────────────┐                       │
│  │  All Hub / SSP / Stats nodes         │                       │
│  └──────────────────────────────────────┘                       │
│                                                                 │
│  ┌───────────────────┐   ┌────────────────────────────────┐    │
│  │ OpenStack CLI     │   │ Ansible + Terraform             │    │
│  │ DNS / Nova / etc  │   │ Local terraform.tfstate files   │    │
│  └───────────────────┘   └────────────────────────────────┘    │
│                                                                 │
│  ┌───────────────────┐                                         │
│  │ hubtraf           │                                         │
│  │ (load testing)    │                                         │
│  └───────────────────┘                                         │
│                                                                 │
│  Team SSH access ◄──── all operators log in here               │
└─────────────────────────────────────────────────────────────────┘

Persistent state on disk:
  /home/ptty2u/           20 GB  home volume (LUKS encrypted)
  /var/lib/docker/       100 GB  Docker image cache
  terraform.tfstate       local  infrastructure state
  letsencrypt/*/certs/    local  SSL private keys + certificates
```

---

## Problem Statement

Clavius conflates five distinct responsibilities into one persistent, largely
undocumented VM. This creates several operational risks:

| Risk | Impact |
|---|---|
| **CentOS 7 EOL** | No upstream security patches since June 2024 |
| **Single point of failure for certs** | If Clavius is lost, wildcard certs cannot be renewed and services go dark at expiry |
| **Local Terraform state** | State loss = Terraform can no longer manage existing resources; manual reconciliation required |
| **No reproducibility** | Clavius state is not fully codified in Ansible; rebuilding from scratch would take significant undocumented effort |
| **Shared mutable environment** | All operators share one environment; a mistake by one affects everyone |
| **Docker image cache is not backed up** | Image rebuilds are time-consuming; cache loss delays deployments |

---

## Requirements for a Replacement

Any replacement must:

1. Eliminate the CentOS 7 OS (EOL)
2. Remove the single point of failure for certificate renewal
3. Store Terraform state in a durable, versioned backend outside of any single VM
4. Be fully reproducible from code — no manual state that cannot be recreated
5. Preserve the ability for operators to run interactive `make` commands
6. Not require a disruptive all-at-once migration

---

## Option A: Full CI/CD Pipeline

All automated tasks move into a CI/CD pipeline (GitHub Actions or a self-hosted
GitLab CI instance). A minimal "jump box" VM replaces Clavius for emergency
SSH access only.

### Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                     GitHub / GitLab CI                              │
│                                                                     │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │  Scheduled workflow (weekly)                                 │   │
│  │  cert-renewal.yml                                            │   │
│  │    dehydrated + Designate hook → Let's Encrypt               │   │
│  │    deploy-certs.yml Ansible play                             │   │
│  └──────────────────────────────────────────────────────────────┘   │
│                                                                     │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │  Triggered on image repo push                                │   │
│  │  build-images.yml                                            │   │
│  │    docker build → push to GHCR / Docker Hub                  │   │
│  └──────────────────────────────────────────────────────────────┘   │
│                                                                     │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │  Manual trigger                                              │   │
│  │  terraform.yml / ansible.yml                                 │   │
│  │    Terraform plan/apply, Ansible playbooks                   │   │
│  └──────────────────────────────────────────────────────────────┘   │
└──────────────────────────┬──────────────────────────────────────────┘
                           │ (self-hosted runner on OpenStack network,
                           │  or VPN tunnel to OpenStack API)
                           ▼
┌─────────────────────────────────────────────────────────────────────┐
│                        OpenStack Cloud                              │
│                                                                     │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐             │
│  │   Hub nodes  │  │  SSP / Stats │  │  Jump box    │             │
│  │              │  │              │  │  (SSH only)  │             │
│  └──────────────┘  └──────────────┘  └──────────────┘             │
│                                                                     │
│  Terraform state ──► HCP Terraform / S3-compatible remote backend  │
└─────────────────────────────────────────────────────────────────────┘

Secrets:
  OpenStack credentials ──► CI secrets / environment variables
  SSH private key        ──► CI secrets
  Let's Encrypt hook key ──► CI secrets
```

### Pros and Cons

**Pros:**
- Fully reproducible and auditable — all actions are recorded in pipeline logs
- Automatic, scheduled certificate renewal with no manual intervention
- No persistent state on any single VM
- Changes are code-reviewed (PR → pipeline run)
- Team visibility: anyone can see what ran and when

**Cons:**
- Requires network access from CI runners to the OpenStack API — likely needs
  a self-hosted runner deployed inside the OpenStack network
- All secrets (OpenStack credentials, SSH keys, Let's Encrypt hook) must be
  stored securely in CI and rotated regularly
- Interactive ad-hoc operations (user management, quota changes) need to become
  pipeline jobs or be handled via the jump box
- Highest initial setup effort of the three options

---

## Option B: Remote State + Lightweight Ops VM

Split Clavius responsibilities across purpose-fit systems. Automated tasks move
to CI or scheduled jobs. A lightweight Alma Linux 9 ops VM replaces Clavius for
interactive work, but holds no critical persistent state.

### Architecture

```
┌──────────────────────────────────────────────────────────────────────┐
│  GitHub Actions (or GitLab CI)                                       │
│                                                                      │
│  build-images.yml ──► docker build ──► GitHub Container Registry    │
│                                                 │                    │
└─────────────────────────────────────────────────┼────────────────────┘
                                                  │ hub pulls image
                                                  ▼
┌─────────────────────────────────────────────────────────────────────┐
│  HCP Terraform (or S3-compatible object store)                      │
│  Remote terraform.tfstate (versioned, locked)                       │
└────────────────────────────────┬────────────────────────────────────┘
                                 │ state read/write
                                 ▼
┌─────────────────────────────────────────────────────────────────────┐
│                        OpenStack Cloud                              │
│                                                                     │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │                  Ops VM (Alma Linux 9)                       │   │
│  │                                                              │   │
│  │  Ops tooling: Ansible, Terraform CLI, OpenStack CLI,         │   │
│  │               make, hubtraf, kubectl                         │   │
│  │                                                              │   │
│  │  Cert generation: dehydrated + Designate hook                │   │
│  │    (cron or manual; certs pushed via rrsync)                 │   │
│  │                                                              │   │
│  │  NO persistent critical state:                               │   │
│  │    tfstate  ──► remote backend                               │   │
│  │    images   ──► built in CI, pulled by hub                   │   │
│  │    certs    ──► re-generatable at any time                   │   │
│  │                                                              │   │
│  │  Can be destroyed and rebuilt from Ansible in < 30 min       │   │
│  └──────────────────────────────────────────────────────────────┘   │
│                                                                     │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐             │
│  │   Hub nodes  │  │  SSP / Stats │  │   Sharder    │             │
│  └──────────────┘  └──────────────┘  └──────────────┘             │
└─────────────────────────────────────────────────────────────────────┘
```

### Pros and Cons

**Pros:**
- Each responsibility moves to a system designed for it (remote state, CI, ops VM)
- Migration is incremental — each piece can be moved independently
- Ops VM remains available for interactive `make` workflows with no workflow change
- Ops VM becomes stateless enough to rebuild from Ansible if lost
- Remote Terraform state eliminates the most critical single point of failure
- HCP Terraform free tier covers small teams

**Cons:**
- More systems to understand (HCP Terraform, CI, ops VM)
- Cert generation still lives on the ops VM — adds a cron job and some state
  (private keys); this can later be moved to CI if desired
- Requires a one-time migration of Terraform state files

---

## Option C: Rebuilt Clavius (In-Place Upgrade)

Replace the CentOS 7 VM with a new Alma Linux 9 instance running the same
responsibilities, but with better hygiene: automated backups, full Ansible
provisioning, and an off-site copy of Terraform state.

### Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                  New Clavius (Alma Linux 9)                     │
│                                                                 │
│  ┌─────────────────┐   ┌──────────────────┐                    │
│  │ dehydrated      │   │ Docker daemon     │                    │
│  │ Let's Encrypt   │──►│ Image builds      │                    │
│  │ cert generation │   │ (notebook images) │                    │
│  └────────┬────────┘   └──────────────────┘                    │
│           │ rrsync push                                         │
│           ▼                                                     │
│  ┌──────────────────────────────────────┐                       │
│  │  All Hub / SSP / Stats nodes         │                       │
│  └──────────────────────────────────────┘                       │
│                                                                 │
│  ┌───────────────────┐   ┌────────────────────────────────┐    │
│  │ OpenStack CLI     │   │ Ansible + Terraform             │    │
│  │                   │   │ Local tfstate + remote copy     │    │
│  └───────────────────┘   └────────────────────────────────┘    │
│                                                                 │
│  ┌───────────────────────────────────────────┐                 │
│  │ Automated backups (daily cron)            │                 │
│  │   Home volume ──► OpenStack Object Store  │                 │
│  │   tfstate     ──► OpenStack Object Store  │                 │
│  │   Docker layers (optional, large)         │                 │
│  └──────────────────────────┬────────────────┘                 │
└─────────────────────────────┼───────────────────────────────────┘
                              │
                              ▼
              OpenStack Swift Object Storage
              (backup destination)
```

### Pros and Cons

**Pros:**
- Lowest migration effort of the three options
- Zero workflow change for operators
- Addresses the CentOS 7 EOL risk immediately
- Automated backups reduce (but don't eliminate) data loss risk

**Cons:**
- Does not eliminate the single point of failure — if the new Clavius is
  lost before a backup runs, recent state may be unrecoverable
- Certificate renewal and Docker builds remain manual / VM-dependent
- Reproducibility is still limited by whatever state accumulates between
  Ansible runs
- The same operational risks return as the VM ages

---

## Comparison

| Criterion | A: Full CI/CD | B: Remote State + Ops VM | C: Rebuilt Clavius |
|---|---|---|---|
| Eliminates CentOS 7 EOL | Yes | Yes | Yes |
| Removes cert renewal SPOF | Yes | Partial (cron on ops VM) | No |
| Removes Terraform state SPOF | Yes | Yes | Partial (off-site copy) |
| Ops VM is fully reproducible | Yes (no VM) | Yes | No |
| Workflow change for operators | High | Low–Medium | None |
| Migration effort | High | Medium | Low |
| Ongoing maintenance complexity | Medium | Medium | Low |
| Best fit for | Teams comfortable with CI | **Callysto (recommended)** | Short timelines |

---

## Recommendation

**Implement Option B**, starting with the two highest-value steps:

1. **Migrate Terraform state to a remote backend** (HCP Terraform free tier, or
   an S3-compatible backend such as OpenStack Swift with the S3 API).
   This eliminates the most critical single point of failure with minimal
   disruption to existing workflows.

2. **Move Docker image builds to GitHub Actions** and push images to GitHub
   Container Registry. Hub nodes pull images from the registry rather than
   from Clavius. This removes the 100 GB Docker cache dependency from the ops VM.

Once these two steps are complete, the ops VM holds no critical unique state and
can be rebuilt from Ansible at any time. The remaining work (new Alma Linux 9
ops VM, cert renewal automation) can proceed at a comfortable pace.

Option A (full CI/CD) is the long-term ideal but requires a self-hosted runner
on the OpenStack network and a more significant workflow change. It is worth
pursuing after Option B stabilizes, particularly for certificate renewal.

---

## Migration Plan

### Phase 1 — Remote Terraform State (1–2 days)

1. Create an HCP Terraform organization and workspace (free tier), or configure
   an OpenStack Swift bucket with the S3-compatible API for use as a Terraform
   backend
2. For each environment directory (`hub-dev`, `hub-prod-r9`, `clavius`, etc.):
   - Add a `backend` block to the Terraform configuration
   - Run `terraform init -migrate-state` to upload the local state
   - Verify with `terraform plan` (should show no changes)
3. Remove local `terraform.tfstate` files from the repository (they are
   already gitignored, but confirm)
4. Update `PROCESSES.md` with the new state backend details

### Phase 2 — Docker Image Builds in CI (3–5 days)

1. Create a GitHub Actions workflow in the notebook image repository that:
   - Builds the JupyterHub notebook Docker image on push to `main`
   - Pushes the image to GitHub Container Registry (`ghcr.io/callysto/...`)
2. Update `local_vars.yml` on each hub to reference the registry image
   instead of a locally-built one
3. Validate by restarting a single-user server and confirming it pulls from
   the registry
4. Remove Docker build procedures from Clavius

### Phase 3 — New Ops VM (2–3 days)

1. Update `terraform/modules/clavius/` to use the Alma Linux 9 image
2. Update `ansible/plays/clavius.yml` to remove Docker image build tooling
   (Docker daemon is no longer needed for builds)
3. Provision the new ops VM in a separate Terraform workspace
4. Migrate SSH keys and OpenStack credentials
5. Validate all `make` targets work from the new VM
6. Decommission old Clavius

### Phase 4 — Certificate Renewal Automation (optional follow-on)

Move `dehydrated` certificate generation to a scheduled GitHub Actions workflow
with a self-hosted runner on the OpenStack network, removing the last
time-sensitive manual operation from the ops VM.
