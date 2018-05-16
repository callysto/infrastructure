UNAME := $(shell uname)
TOP := $(shell pwd)
TF_PATH := $(TOP)/../terraform

ANSIBLE_CMD = TF_STATE=$(TF_PATH)/$(env) ansible-playbook -i ./bin/$(UNAME)/ansible-terraform-inventory

check-env:
ifndef env
	$(error env is not defined)
endif

list-tasks: check-env
	$(ANSIBLE_CMD) --list-tasks plays/init.yml
