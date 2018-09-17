export PATH := $(TOP)/bin/$(UNAME):/bin:/usr/bin
UNAME = $(shell uname)
TOP := $(shell pwd)
TF_PATH := $(TOP)/bin/$(UNAME)

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
	$(TF_PATH)/terraform init

plan: init
	cd $(env) ; \
	$(TF_PATH)/terraform plan

apply: plan
	cd $(env) ; \
	$(TF_PATH)/terraform apply

destroy: check-env
	cd $(env) ; \
	$(TF_PATH)/terraform destroy

show: check-env
	cd $(env) ; \
	$(TF_PATH)/terraform show

hub/taint/instance: check-env
	cd $(env) ; \
	$(TF_PATH)/terraform taint -module=hub openstack_compute_instance_v2.hub

hub/taint/volumes: check-env
	cd $(env) ; \
	$(TF_PATH)/terraform taint -module=hub openstack_blockstorage_volume_v2.zfs.0 ; \
	$(TF_PATH)/terraform taint -module=hub openstack_blockstorage_volume_v2.zfs.1

hub/rebuild: | hub/taint/instance hub/taint/volumes apply

new-hub/dev: check-env
	/usr/bin/cp -a hub-dev-template hub-$(env)
	/usr/bin/sed -i -e 's/ENV/$(env)/g' hub-$(env)/main.tf
	/usr/bin/mkdir ../ansible/group_vars/hub-$(env)
	/usr/bin/cp ../ansible/local_vars.yml.example ../ansible/group_vars/hub-$(env)/local_vars.yml
	@echo ""
	@echo "Make sure to edit ../ansible/group_vars/hub-$(env)/local_vars.yml."
	@echo ""

new-hub/prod: check-env
	/usr/bin/cp -a hub-prod-template hub-$(env)
	/usr/bin/mkdir ../ansible/group_vars/hub-$(env)
	/usr/bin/cp ../ansible/local_vars.yml.example ../ansible/group_vars/hub-$(env)/local_vars.yml
	@echo ""
	@echo "Make sure to edit ../ansible/group_vars/hub-$(env)/local_vars.yml."
	@echo ""

new-swarm: check-env
	/usr/bin/cp -a swarm-template swarm-$(env)
