export PATH := $(TOP)/bin/$(UNAME):/bin:/usr/bin
SHELL := /bin/bash
UNAME := $(shell uname)
TOP := $(shell pwd)
TF_PATH := $(TOP)/../terraform

PLAYBOOK_CMD = TF_STATE=$(TF_PATH)/$(env) ansible-playbook --private-key=../keys/id_rsa -i ./inventory
ANSIBLE_CMD = TF_STATE=$(TF_PATH)/$(env) ansible --private-key=../keys/id_rsa -i ./inventory

export PATH := $(TF_PATH)/bin/$(UNAME):$(PATH)

setup:
	@echo "Setting up Ansible Inventory"
	[[ -e "inventory" ]] || ln -s ./bin/$(UNAME)/ansible-terraform-inventory inventory
	@echo ""
	@echo "Remember to update group_vars/<env>/local_vars.yml to fit your environment."
	@echo ""
	@echo "Installing external Ansible roles"
	/bin/bash scripts/role_update.sh

check-env:
ifndef env
	$(error env is not defined)
endif

check-user:
ifndef user
	$(error user is not defined)
endif


list-init-tasks:
	ansible-playbook --list-tasks plays/init.yml

list-hub-tasks:
	ansible-playbook --list-tasks plays/hub.yml

hub/init/check: check-env
	$(PLAYBOOK_CMD) --limit hub --check --diff plays/init.yml

hub/init/apply: check-env
	$(PLAYBOOK_CMD) --limit hub plays/init.yml

hub/check: check-env
	$(PLAYBOOK_CMD) --limit hub --check --diff plays/hub.yml

hub/apply: check-env
	$(PLAYBOOK_CMD) --limit hub plays/hub.yml

clavius/init/check: check-env
	$(PLAYBOOK_CMD) --limit clavius --check --diff plays/init.yml

clavius/init/apply: check-env
	$(PLAYBOOK_CMD) --limit clavius plays/init.yml

clavius/check: check-env
	$(PLAYBOOK_CMD) --limit clavius --check --diff plays/clavius.yml

clavius/apply: check-env
	$(PLAYBOOK_CMD) --limit clavius plays/clavius.yml

quota/get: check-env
	$(PLAYBOOK_CMD) --limit hub plays/quota_tasks.yml --extra-vars get_quota=1 --extra-vars user=$(user)

quota/set: check-env check-user
ifndef refquota
	$(error refquota is not defined)
endif

	$(PLAYBOOK_CMD) --limit hub plays/quota_tasks.yml --extra-vars set_quota=1 --extra-vars user=$(user) --extra-vars refquota=$(refquota)

user/findhash: check-env check-user
	$(PLAYBOOK_CMD) --limit hub plays/find_hash.yml --extra-vars user=$(user)

backup:
	$(PLAYBOOK_CMD) --limit localhost plays/backup.yml
