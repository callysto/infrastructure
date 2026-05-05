# Callysto Infrastructure

This repository contains all infrastructure-as-code for the [Callysto](https://callysto.ca) project —
an educational platform built around JupyterHub, running on OpenStack.

## Documentation

| Document | Purpose |
|---|---|
| **README.md** (this file) | Component overview and quick-start reference |
| [ARCHITECTURE.md](ARCHITECTURE.md) | Deep-dive design, topology, and future-state planning |
| [PROCESSES.md](PROCESSES.md) | Step-by-step operational runbooks |
| [2i2c_PROCESSES.md](2i2c_PROCESSES.md) | GKE-specific procedures for the 2i2c deployment |

## OpenStack Requirements

Callysto runs exclusively on OpenStack. You need access to a cloud with the
following services:

- **Nova** — compute instances
- **Cinder** — block storage (ZFS pools, Docker storage)
- **Neutron** — networking and floating IPs
- **Designate** — DNS records

## Architecture at a Glance

```
                        ┌──────────────────────────────────┐
                        │           OpenStack Cloud         │
   Users ──HTTPS──►     │                                  │
                        │  ┌──────┐   ┌─────┐   ┌──────┐  │
                        │  │ SSP  │   │ Hub │   │Stats │  │
                        │  │ IdP  │◄──│ v4  │──►│/Graf.│  │
                        │  └──────┘   └──┬──┘   └──────┘  │
                        │               │                   │
                        │          ┌────▼─────┐             │
                        │          │ Sharder  │             │
                        │          │ (routing)│             │
                        │          └──────────┘             │
                        │                                   │
                        │  ┌──────────┐   ┌──────────────┐ │
                        │  │ Clavius  │   │   edX/Tutor  │ │
                        │  │(admin)   │   │              │ │
                        │  └──────────┘   └──────────────┘ │
                        └──────────────────────────────────┘
```

See [ARCHITECTURE.md](ARCHITECTURE.md) for a full topology diagram and component descriptions.

## Master Makefile

The root `Makefile` is the primary interface for all operations.

```bash
make help                          # List all available targets
make terraform/list-environments   # List Terraform environments
make ansible/list-playbooks        # List Ansible playbooks
```

## Packer

Packer builds OpenStack VM images (Alma Linux 9) with pre-installed packages
to reduce environment build times.

```bash
make packer/build/alma    # Build the current Alma Linux 9 base image
```

Binaries for Darwin and Linux are bundled in `./bin/` to ensure version consistency.

## Terraform

Terraform provisions OpenStack resources (compute, networking, DNS, storage).
All Terraform files live under `./terraform/`.

### Modules

| Module | Purpose |
|---|---|
| `settings` | Environment-specific variable resolution (dev vs prod) |
| `hub` | JupyterHub compute, networking, volumes, DNS, security groups |
| `clavius` | Central admin workstation |
| `ssp` | SimpleSAMLphp identity proxy server |
| `sharder` | User routing/isolation layer |
| `stats` | Prometheus + Grafana monitoring server |
| `edx` | Open edX (Tutor) server |

### Deploying an Environment

```bash
make terraform/plan ENV=hub-dev      # Preview changes
make terraform/apply ENV=hub-dev     # Apply changes
make terraform/destroy ENV=hub-dev   # Tear down
make terraform/list-environments     # List all environments
```

Environments are directories under `./terraform/` (e.g., `hub-dev`, `hub-prod-r9`, `clavius`).

## Ansible

Ansible provisions software on the infrastructure that Terraform creates.
Inventory is generated automatically from Terraform state via
[ansible-terraform-inventory](https://github.com/jtopjian/ansible-terraform-inventory).

```bash
make ansible/playbook PLAYBOOK=hub-cluster.yml ENV=hub-dev        # Full hub deploy
make ansible/playbook/check PLAYBOOK=hub-cluster.yml ENV=hub-dev  # Dry run
make ansible/list-playbooks        # List all playbooks
make ansible/list-environments     # List environment-level playbooks
```

Configuration lives in `ansible/group_vars/`, `ansible/host_vars/`, and
`ansible/local_vars.yml` (copy from `ansible/local_vars.yml.example`).

### Playbook Imports

`ansible/plays/imports/` contains component-level plays (`hub.yml`, `ssp.yml`,
`stats.yml`, `sharder.yml`) that are composed into full environment playbooks.
They are not intended to be run directly.

## Identity Proxy (SimpleSAMLphp)

An SSP identity proxy federates Google, Microsoft, and institutional SAML/OIDC
providers into a single login flow for JupyterHub.

### Required `local_vars.yml` Variables

```yaml
ssp_idp_multi_salt:
ssp_idp_multi_admin_password:
ssp_refresh_key:
ssp_idp_multi_saml_cert:
ssp_idp_multi_saml_key:
```

Generate SAML keys:

```bash
openssl req -new -x509 -days 3650 -nodes -sha256 \
  -out saml.crt -keyout saml.pem \
  -subj "/C=CA/ST=Alberta/L=Calgary/O=Callysto/OU=Infra/CN=hub-dev.callysto.farm"
```

### Configuring Auth Sources

```yaml
ssp_idp_multi_sources:
  - type: google
    display_name: Google
    client_id: <id>
    client_secret: <secret>

  - type: microsoft
    display_name: Microsoft
    client_id: <id>
    client_secret: <secret>

  - type: saml
    display_name: Example School
    metadata_url: https://school.example.com/idp/metadata
```

Provide this SP metadata URL to institutional IdPs:
`https://hub.callysto.ca/simplesaml/module.php/saml/sp/metadata.php/default-sp`

SAML IdPs must release `eduPersonPrincipalName` (`urn:oid:1.3.6.1.4.1.5923.1.1.1.6`).
The proxy converts it to a Targeted ID at the SSP layer.

### Development (Mock) Accounts

```yaml
ssp_develop: True
```

Adds a "Login with mock account" button. Test credentials: `user1/password`, `user2/password`.

## SSL Certificates (Let's Encrypt)

Wildcard certificates are generated via [dehydrated](https://github.com/lukas2511/dehydrated)
using OpenStack Designate DNS challenges. Certificates are generated centrally and
pushed to all servers.

Configuration: `letsencrypt/{dev,prod}/`
See [PROCESSES.md — Generating Let's Encrypt Certificates](PROCESSES.md#generating-lets-encrypt-certificates).

## Metrics and Monitoring

Each environment includes a stats server with:

- **Prometheus** — metrics collection and storage
- **Grafana** — dashboards at `https://stats.<domain>/grafana/`
- **Node Exporter** + **cAdvisor** — host and container metrics

## edX Infrastructure

edX is deployed via [Tutor](https://docs.tutor.overhang.io). See
[PROCESSES.md — edX Management](PROCESSES.md#edx-management) for full
operational procedures.
