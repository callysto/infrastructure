UNAME = $(shell uname)
TOP := $(shell pwd)
PACKER_PATH := $(TOP)/bin/$(UNAME)

export PATH := $(PACKER_PATH):$(PATH)

setup:
	@echo ""
	@echo "Make sure to build the Packer security group:"
	@echo "cd terraform"
	@echo "make env=packer apply"
	@echo ""
	@echo "Press enter to continue"
	@read

build/hub:
	$(PACKER_PATH)/packer build -var region=Calgary -var flavor=m1.large -var image_name="CentOS 7" -var network_id=b0b12e8f-a695-480e-9dc2-3dc8ac2d55fd hub.json
