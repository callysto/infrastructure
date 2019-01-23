CURDIR := $(shell pwd)
UNAME = $(shell uname)
TF_PATH := $(CURDIR)/terraform
ANSIBLE_PATH := $(CURDIR)/ansible
PACKER_PATH := $(CURDIR)/packer
export PATH := $(CURDIR)/bin:$(CURDIR)/bin/$(UNAME):$(PATH)

SHELL := /bin/bash

# SSH information
KEY_DIR := $(CURDIR)/keys
PRIVATE_KEY := $(KEY_DIR)/id_rsa
PUBLIC_KEY := $(KEY_DIR)/id_rsa.pub
SSH_CMD = ssh -i $(PRIVATE_KEY) -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no

# Ansible information
PLAYBOOK_CMD = TF_STATE=$(TF_PATH)/$(ENV) ansible-playbook --private-key=$(PRIVATE_KEY) -i ./inventory
ANSIBLE_CMD = TF_STATE=$(TF_PATH)/$(ENV) ansible --private-key=$(PRIVATE_KEY) -i ./inventory

# Packer information
PACKER_CMD = packer

# Global tasks
help: tasks

tasks:
	@grep -A1 ^HELP Makefile | sed -e ':begin;$$!N;s/HELP: \(.*\)\n\(.*:\).*/\2 \1/;tbegin;P;D' | grep -v \\\-\\\- | sort | awk -F: '{printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

# Checks
check-env:
ifndef ENV
	$(error ENV is not defined)
endif

check-group:
ifndef GROUP
	$(error GROUP is not defined)
endif

check-group-optional:
ifdef GROUP
export _GROUP = $(GROUP)
else
export _GROUP = all
endif

check-host:
ifndef HOST
	$(error HOST is not defined)
endif

check-module:
ifdef MODULE
export _MODULE = $(MODULE)
else
	$(error MODULE is not defined)
endif

check-args:
ifdef ARGS
export _ARGS = -a "$(ARGS)"
else
export _ARGS =
endif

check-playbook:
ifndef PLAYBOOK
	$(error PLAYBOOK is not defined)
else
export _PLAYBOOK = plays/$(PLAYBOOK).yml
endif

check-refquota:
ifndef REFQUOTA
	$(error REFQUOTA is not defined)
endif

check-target:
ifndef TARGET
	$(error TARGET is not defined)
endif

check-user:
ifndef USER
	$(error USER is not defined)
endif

# Terraform tasks
HELP: Runs any first steps when this repository is first cloned
terraform/setup:
	@echo "There are no steps to run at this time"

HELP: Runs "terraform init" for $ENV
terraform/init: check-env
	@cd $(TF_PATH)/$(ENV) ; \
	terraform init

HELP: Runs "terraform plan" for $ENV
terraform/plan: terraform/init
	@cd $(TF_PATH)/$(ENV) ; \
	terraform plan

HELP: Runs "terraform apply" for $ENV
terraform/apply: terraform/plan
	@cd $(TF_PATH)/$(ENV) ; \
	terraform apply

HELP: Runs "terraform apply -auto-approve" for $ENV
terraform/auto-apply: terraform/plan
	@cd $(TF_PATH)/$(ENV) ; \
	terraform apply -auto-approve

HELP: Runs "terraform destroy" for $ENV
terraform/destroy: check-env
	@cd $(TF_PATH)/$(ENV) ; \
	terraform destroy

HELP: Runs "terraform destroy -auto-approve" for $ENV
terraform/auto-destroy: check-env
	@cd $(TF_PATH)/$(ENV) ; \
	terraform destroy -auto-approve

HELP: Runs "terraform show" for $ENV
terraform/show: check-env
	@cd $(TF_PATH)/$(ENV) ; \
	terraform show

HELP: Lists available targets in $ENV
terraform/list-targets: check-env
	@cd $(TF_PATH)/$(ENV) ; \
	terraform show | grep :$$ | tr -d : | sort

HELP: Runs "terraform taint" on a $TARGET in $ENV
terraform/taint: check-env check-target
	@cd $(TF_PATH)/$(ENV) ; \
	terraform taint $(TARGET)

HELP: Rebuilds an instance and volumes in $ENV
terraform/hub/rebuild: check-env
	@make terraform/taint ENV=$(ENV) TARGET=openstack_compute_instance_v2.hub
	@make terraform/taint ENV=$(ENV) TARGET=openstack_blockstorage_volume_v2.zfs.0
	@make terraform/taint ENV=$(ENV) TARGET=openstack_blockstorage_volume_v2.zfs.1
	@make terraform/auto-apply ENV=$(ENV)

HELP: Creates a new dev Terraform $ENV
terraform/hub/new/dev: check-env
	@cd $(TF_PATH) ; \
	/usr/bin/cp -a hub-dev-template hub-$(ENV) ; \
	/usr/bin/sed -i -e 's/ENV/$(ENV)/g' hub-$(ENV)/main.tf ; \
	/usr/bin/mkdir $(ANSIBLE_PATH)/group_vars/hub-$(ENV) ; \
	/usr/bin/cp $(ANSIBLE_PATH)/local_vars.yml.example $(ANSIBLE_PATH)/group_vars/hub-$(ENV)/local_vars.yml
	@echo ""
	@echo "Make sure to edit $(ANSIBLE_PATH)/group_vars/hub-$(ENV)/local_vars.yml."
	@echo ""

HELP: Creates a new production Terraform $ENV
terraform/hub/new/prod: check-env
	@cd $(TF_PATH) ; \
	/usr/bin/cp -a hub-prod-template hub-$(ENV) ; \
	/usr/bin/sed -i -e 's/ENV/$(ENV)/g' hub-$(ENV)/main.tf ; \
	/usr/bin/mkdir $(ANSIBLE_PATH)/group_vars/hub-$(ENV) ; \
	/usr/bin/cp $(ANSIBLE_PATH)/local_vars.yml.example $(ANSIBLE_PATH)/group_vars/hub-$(ENV)/local_vars.yml
	@echo ""
	@echo "Make sure to edit $(ANSIBLE_PATH)/group_vars/hub-$(ENV)/local_vars.yml."
	@echo ""

# Ansible tasks
HELP: Runs any first steps when this repository is first cloned
ansible/setup:
	@cd $(ANSIBLE_PATH) ; \
	echo "Setting up Ansible Inventory" ; \
	[[ -e "inventory" ]] || ln -s ../bin/$(UNAME)/ansible-terraform-inventory inventory ; \
	echo "" ; \
	echo "Remember to update group_vars/<env>/local_vars.yml to fit your environment." ; \
	echo "" ; \
	echo "Installing external Ansible roles" ; \
	/bin/bash scripts/role_update.sh

HELP: Lists plays
ansible/list-playbooks:
	@cd $(ANSIBLE_PATH) ; \
	grep -RH ^## plays/ | sed -e 's/\(plays\/\)\(.*\)\(.yml\)/\2/' | sort | awk 'BEGIN {FS = ":## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

HELP: Lists the tasks in a $PLAYBOOK in $ENV
ansible/list-tasks: check-playbook
	@cd $(ANSIBLE_PATH) ; \
	$(PLAYBOOK_CMD) --list-tasks $(_PLAYBOOK)

HELP: Lists all hosts in $ENV
ansible/hosts: check-env
	@cd $(ANSIBLE_PATH) ; \
	$(ANSIBLE_CMD) all --list-hosts

HELP: Lists the hosts in $GROUP in $ENV
ansible/hosts/group: check-env check-group-optional
	@cd $(ANSIBLE_PATH) ; \
	$(ANSIBLE_CMD) $(_GROUP) --list-hosts

HELP: Lists the hosts in $PLAYBOOK in $ENV
ansible/hosts/playbook: check-env check-playbook
	@cd $(ANSIBLE_PATH) ; \
	$(PLAYBOOK_CMD) $(_PLAYBOOK) --list-hosts

HELP: Runs $PLAYBOOK on $GROUP in check-mode in $ENV
ansible/playbook/check: check-env check-playbook check-group
	@cd $(ANSIBLE_PATH) ; \
	$(PLAYBOOK_CMD) --check --diff --limit $(GROUP) $(_PLAYBOOK)

HELP: Runs $PLAYBOOK on $GROUP for reals in $ENV
ansible/playbook: check-env check-playbook check-group
	@cd $(ANSIBLE_PATH) ; \
	$(PLAYBOOK_CMD) --limit $(GROUP) $(_PLAYBOOK)

HELP: Returns the ipv4 address of $HOST in $ENV
ansible/get-ipv4: check-env check-host
	@cd $(ANSIBLE_PATH) ;\
	$(ANSIBLE_CMD) $(HOST) -m setup -a "filter=ansible_default_ipv4" | grep \"address | sed -e 's/[\", ]//g' | cut -d: -f2

HELP: Returns the ssh user of $HOST in $ENV
ansible/get-ssh-user: check-env check-host
	@cd $(ANSIBLE_PATH) ; \
	$(ANSIBLE_CMD) $(HOST) -m debug -a "msg={{ ansible_user }}" | grep msg | sed -e 's/[\", ]//g' | cut -d: -f2

HELP: Pings the hosts in $GROUP in $ENV
ansible/ping: check-env check-group-optional
	@cd $(ANSIBLE_PATH) ; \
	$(ANSIBLE_CMD) $(_GROUP) -m ping

HELP: Executes $MODULE on $GROUP with $ARGS in $ENV
ansible/exec: check-env check-group-optional check-module check-args
	@cd $(ANSIBLE_PATH) ; \
	$(ANSIBLE_CMD) $(_GROUP) -m $(_MODULE) $(_ARGS)

# Quota tasks
HELP: Gets a quota for $USER in $ENV
quota/get: check-env check-user
	@cd $(ANSIBLE_PATH) ; \
	$(PLAYBOOK_CMD) --limit hub plays/quota_tasks.yml --extra-vars user=$(USER)

HELP: Sets a quota to $REFQUOTA for $USER in $ENV
quota/set: check-env check-user check-refquota
	@cd $(ANSIBLE_PATH) ; \
	$(PLAYBOOK_CMD) --limit hub plays/quota_tasks.yml --extra-vars set_quota=1 --extra-vars user=$(USER) --extra-vars refquota=$(REFQUOTA)

# User tasks
HELP: Finds a hash for $USER in $ENV
user/findhash: check-env check-user
	@cd $(ANSIBLE_PATH) ; \
	$(PLAYBOOK_CMD) --limit hub plays/find_hash.yml --extra-vars user=$(USER)

# Backup tasks
HELP: Performs a backup of sensitive data
backup:
	@cd $(ANSIBLE_PATH) ; \
	$(PLAYBOOK_CMD) --limit localhost plays/backup.yml

# Packer tasks
HELP: Builds the JupyterHub OpenStack image
packer/build/hub:
	@cd $(PACKER_PATH) ; \
	$(PACKER_CMD) build -var region=Calgary -var flavor=m1.large -var image_name="CentOS 7" -var network_id=b0b12e8f-a695-480e-9dc2-3dc8ac2d55fd hub.json

# Let's Encrypt tasks
letsencrypt/generate: check-env
	@cd letsencrypt/$(ENV) ; \
	unset OS_USERNAME ; \
	unset OS_PASSWORD ; \
	RECIPIENT=sysadmin@callysto.ca dehydrated -c --accept-terms -f 'config' -k './hook.sh'

# SSH tasks
HELP: SSH to a given $HOST in $ENV
ssh/shell: check-env check-host
	@_host=$(shell make ansible/get-ipv4 ENV=$(ENV) HOST=$(HOST)) ; \
	_user=$(shell make ansible/get-ssh-user ENV=$(ENV) HOST=$(HOST)) ; \
	$(SSH_CMD) $$_user@$$_host
