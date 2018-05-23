UNAME = $(shell uname)
TOP := $(shell pwd)
PATH := $(TOP)/bin/$(UNAME)

check-env:
ifndef env
	$(error env is not defined)
endif

setup:
	@echo "All OK!"

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
