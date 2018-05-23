UNAME := $(shell uname)
TOP := $(shell pwd)
TF_PATH := $(TOP)/../terraform

PLAYBOOK_CMD = TF_STATE=$(TF_PATH)/$(env) ansible-playbook --private-key=../keys/id_rsa -i ./inventory
ANSIBLE_CMD = TF_STATE=$(TF_PATH)/$(env) ansible --private-key=../keys/id_rsa -i ./inventory

setup:
	ln -s ./bin/$(UNAME)/ansible-terraform-inventory inventory

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
