UNAME = $(shell uname)
TOP := $(shell pwd)
PATH := $(TOP)/bin/$(UNAME)

check-env:
ifndef env
	$(error env is not defined)
endif

setup:
	@echo ""
	@echo "Make sure to read the various main.tf files and modify accordingly."
	@echo "Press enter to continue"
	@read

init: check-env
	cd $(env) ; \
	$(PATH)/terraform init

plan: init
	cd $(env) ; \
	$(PATH)/terraform plan

apply: plan
	cd $(env) ; \
	$(PATH)/terraform apply

destroy: check-env
	cd $(env) ; \
	$(PATH)/terraform destroy

show: check-env
	cd $(env) ; \
	$(PATH)/terraform show

hub/taint/instance: check-env
	cd $(env) ; \
	$(PATH)/terraform taint -module=hub openstack_compute_instance_v2.hub

hub/taint/volumes: check-env
	cd $(env) ; \
	$(PATH)/terraform taint -module=hub openstack_blockstorage_volume_v2.zfs.0 ; \
	$(PATH)/terraform taint -module=hub openstack_blockstorage_volume_v2.zfs.1

hub/rebuild: | hub/taint/instance hub/taint/volumes apply
