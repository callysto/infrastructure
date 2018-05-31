UNAME = $(shell uname)
TOP := $(shell pwd)
PATH := $(TOP)/bin/$(UNAME)

check-env:
ifndef env
	$(error env is not defined)
endif

setup:
	@echo ""
	@echo "Make sure to edit modules/dns/vars.tf with your Designate zone ID!"
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
