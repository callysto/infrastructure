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
	@echo "Creating group_vars/hub/local_vars.yml from the example template"
	[[ -f "group_vars/hub/local_vars.yml" ]] || cp local_vars.yml.example group_vars/hub/local_vars.yml
	@echo ""
	@echo "Update group_vars/hub/local_vars.yml to fit your environment."
	@echo "Don't forget to generate the SSL certificates for simplesamlphp if you're using it for authentication."
	@echo "And don't forget to set dehydrate_test_cert to False if you're sure Let's Encrypt is working."
	@echo "Press enter to continue"
	@read
	@echo "Installing external Ansible roles"
	/bin/bash scripts/role_update.sh

check-env:
ifndef env
	$(error env is not defined)
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
